--[[
Headless scenario boot (docs/test_automation_plan.md, layer 2): KOReader's own
frontend on its dummy framebuffer, a fresh home inside a scratch run folder,
this plugin linked from the working tree, the mock books and groups generated
into the run folder. Nothing of the maintainer's is read or written: the home
is asserted to sit inside the run folder, the API keys are never loaded (an
empty table stands in for apikeys.lua before the plugin loads), every network
path is blocked and a blocked call fails the scenario.

Run through tests/scenarios/run.sh, which makes the run folder, generates the
fixture and runs each scenario as:
  cd <KOReader.app>/Contents/koreader && KO_HOME=<run>/home KOA_RUN=<run> \
      KOA_PLUGIN=<working tree> ./luajit <working tree>/tests/scenarios/<s>.lua

A scenario:
  local S = dofile(os.getenv("KOA_PLUGIN") .. "/tests/scenarios/boot.lua")
  local ui = S.open("Mock Series 3")
  S.check(cond, "what it shows")
  S.shot("name")            -- <run>/shots/<scenario>_name.png, for the session to view
  S.finish()                -- PASS/FAIL summary, exit code
]]

local S = {}

local PLUGIN = assert(os.getenv("KOA_PLUGIN"), "KOA_PLUGIN unset")
local RUN = assert(os.getenv("KOA_RUN"), "KOA_RUN unset")
local HOME = assert(os.getenv("KO_HOME"), "KO_HOME unset")
-- The home is the run's own, never a real one
assert(HOME:sub(1, #RUN + 1) == RUN .. "/", "KO_HOME must be inside the run folder")
S.PLUGIN, S.RUN, S.HOME = PLUGIN, RUN, HOME
S.BOOKS = RUN .. "/Books"
S.NAME = (arg and arg[0] or "scenario"):match("([^/]+)%.lua$") or "scenario"

require("setupkoenv")
require("dbg"):turnOff()
local logger = require("logger")
logger:setLevel(logger.levels.warn)
local DataStorage = require("datastorage")
local lfs = require("libs/libkoreader-lfs")

G_defaults = require("luadefaults"):open()
G_reader_settings = require("luasettings"):open(DataStorage:getDataDir() .. "/settings.reader.lua")
-- Only this plugin loads: the stock plugins stay out of the run
do
    local disabled = {}
    for entry in lfs.dir("plugins") do
        local name = entry:match("^(.+)%.koplugin$")
        if name then disabled[name] = true end
    end
    G_reader_settings:saveSetting("plugins_disabled", disabled)
    G_reader_settings:saveSetting("koassistant_last_update_check", os.time())
end

-- ── Results ─────────────────────────────────────────────────────────────────
local passed, failed = 0, 0
function S.check(cond, what)
    if cond then
        passed = passed + 1
        print("  PASS " .. what)
    else
        failed = failed + 1
        print("  FAIL " .. what)
    end
    return cond
end
function S.note(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    print("    " .. table.concat(parts, " "))
end

-- ── The screen and input, headless ──────────────────────────────────────────
einkfb = require("ffi/framebuffer") --luacheck: ignore
einkfb.dummy = true --luacheck: ignore
local Device = require("device")
local Screen = Device.screen
Screen:init()
require("document/canvascontext"):init(Device)
Device.input.dummy = true
S.Screen = Screen

-- ── The network and the keys, kept out ──────────────────────────────────────
local blocked = {}
local function block(name)
    return function()
        blocked[#blocked + 1] = name
        error("scenario: network blocked (" .. name .. ")", 2)
    end
end
package.loaded["apikeys"] = {}
do
    local http = require("socket.http")
    http.request = block("socket.http.request")
    local ok_https, https = pcall(require, "ssl.https")
    if ok_https and type(https) == "table" then https.request = block("ssl.https.request") end
    local socket = require("socket")
    socket.connect = block("socket.connect")
    -- No child processes either: a request's child would connect on its own
    -- (the name index's background pass is refused too; it says so and the
    -- marks fall back to once per page)
    local ffiutil = require("ffi/util")
    ffiutil.runInSubProcess = function()
        S.forks_refused = (S.forks_refused or 0) + 1
        return false
    end
    local NetworkMgr = require("ui/network/manager")
    NetworkMgr.isOnline = function() return false end
    NetworkMgr.isConnected = function() return false end
    NetworkMgr.isWifiOn = function() return false end
end

local UIManager = require("ui/uimanager")
S.UIManager = UIManager

-- The plugin's own modules, for the scenarios and for the request block
package.path = PLUGIN .. "/?.lua;" .. package.path
do
    local GptQuery = require("koassistant.request.gpt_query")
    GptQuery.query = block("gpt_query.query")
    local BaseHandler = require("koassistant.api.base")
    for _idx, fn in ipairs({ "backgroundRequest", "fetchInSubprocess", "fetchAsync",
            "resolveForSubprocess", "connectSSLInSubprocess" }) do
        if BaseHandler[fn] then BaseHandler[fn] = block("BaseHandler." .. fn) end
    end
end

--- The plugin's settings before it loads (features merged over its defaults)
function S.features(values)
    local LuaSettings = require("luasettings")
    local s = LuaSettings:open(DataStorage:getSettingsDir() .. "/koassistant_settings.lua")
    local f = s:readSetting("features") or {}
    for k, v in pairs(values) do f[k] = v end
    s:saveSetting("features", f)
    s:flush()
end
S.features({ auto_check_updates = false })

--- Every scheduled task now (the 2 s debounces, the marks' settle)
function S.settle(rounds)
    for _i = 1, rounds or 3 do
        UIManager:shiftScheduledTasksBy(-1e9)
        UIManager:setInputTimeout(0)
        UIManager:handleInput()
    end
end

--- A book of the run's fixture by part of its file name
function S.book(part)
    for _idx, folder in ipairs({ "Mock Series", "Mock Project", "Mock Shelf" }) do
        local dir = S.BOOKS .. "/" .. folder
        if lfs.attributes(dir, "mode") == "directory" then
            for entry in lfs.dir(dir) do
                if entry:match("%.epub$") and entry:find(part, 1, true) then
                    return dir .. "/" .. entry
                end
            end
        end
    end
    error("no fixture book matches " .. tostring(part))
end

local current_ui
--- Open a book in the reader (the plugins load with it); returns the ReaderUI
function S.open(part)
    if current_ui then S.close() end
    local DocumentRegistry = require("document/documentregistry")
    local ReaderUI = require("apps/reader/readerui")
    local file = S.book(part)
    local doc = DocumentRegistry:openDocument(file)
    assert(doc, "could not open " .. file)
    current_ui = ReaderUI:new{ dimen = Screen:getSize(), document = doc }
    UIManager:show(current_ui)
    S.settle()
    UIManager:forceRePaint()
    S.ui = current_ui
    S.plugin = current_ui.koassistant
    return current_ui
end

function S.close()
    if not current_ui then return end
    current_ui:onClose()
    UIManager:close(current_ui)
    S.settle(1)
    current_ui, S.ui, S.plugin = nil, nil, nil
end

--- Go to the chapter of this title (its first page)
function S.chapter(title)
    local ui = assert(current_ui, "no book open")
    for _idx, item in ipairs(ui.toc.toc or ui.document:getToc() or {}) do
        if item.title and item.title:find(title, 1, true) then
            ui:handleEvent(require("ui/event"):new("GotoPage", item.page))
            S.settle()
            UIManager:forceRePaint()
            return item.page
        end
    end
    error("no chapter " .. tostring(title))
end

--- The visible page's X-Ray marks, after the deferred scan: { {name, text, x, y, w, h, words} }
--- with `words` = the text under the mark, read back from the page
function S.marks()
    local XrayMarks = require("koassistant.xray.xray_marks")
    XrayMarks.sync(S.plugin)
    S.settle()
    local out = {}
    for _idx, m in ipairs(XrayMarks._pageMarks() or {}) do
        local words
        local ok, sel = pcall(current_ui.document.getTextFromPositions, current_ui.document,
            { x = m.x + 1, y = m.y + math.floor(m.h / 2) },
            { x = m.x + m.w - 1, y = m.y + math.floor(m.h / 2) }, true)
        if ok and type(sel) == "table" then words = sel.text end
        out[#out + 1] = { name = m.name, text = m.text, words = words,
            x = m.x, y = m.y, w = m.w, h = m.h }
    end
    return out
end

--- A screenshot for the session to view
function S.shot(name)
    lfs.mkdir(RUN .. "/shots")
    UIManager:forceRePaint()
    local path = RUN .. "/shots/" .. S.NAME .. "_" .. name .. ".png"
    Screen.bb:writePNG(path)
    print("    shot: " .. path)
    return path
end

function S.finish()
    S.check(#blocked == 0, "nothing tried the network" .. (#blocked > 0
        and (" (" .. table.concat(blocked, ", ") .. ")") or ""))
    pcall(S.close)
    print(string.format("%s: %d passed, %d failed", S.NAME, passed, failed))
    os.exit(failed == 0 and 0 or 1)
end

return S
