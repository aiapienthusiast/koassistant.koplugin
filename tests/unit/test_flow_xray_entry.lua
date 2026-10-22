-- Flow tests on the koamock fixture (docs/test_automation_plan.md, layer 1):
-- an X-Ray entry's More… popup and what it opens, driven through the browser's
-- REAL code with the dialogs recorded (tests/lib/ui_recorder.lua), on the
-- invented "Mock Series 3" X-Ray the desktop fixture writes to disk
-- (tests/lib/koamock.lua). The device round's do-X-expect-Y steps, minus
-- what only a screen shows:
--   * B534: Move back to carried list only on an entry added from the carried
--     list, never on one that only carries history from an earlier book
--   * B535: Illustrate… opens the image settings panel; Illustrate with a
--     note… asks for the note and draws the entry with it
--   * B535: a note that names an entry brings it to the prompt writer
--   * Merge with another entry…: the entry page stays under the pick (Cancel,
--     Back and a tap outside land on it); a merge, by hand or by the AI,
--     lands on the kept entry
--
-- Run: lua tests/unit/test_flow_xray_entry.lua  (or lua tests/run_tests.lua --unit)

local function setupPaths()
    local info = debug.getinfo(1, "S")
    local script_path = info.source:match("@?(.*)")
    local unit_dir = script_path:match("(.+)/[^/]+$") or "."
    local tests_dir = unit_dir:match("(.+)/[^/]+$") or "."
    local plugin_dir = tests_dir:match("(.+)/[^/]+$") or "."
    package.path = table.concat({
        plugin_dir .. "/?.lua",
        plugin_dir .. "/koassistant/api/?.lua",
        tests_dir .. "/?.lua",
        tests_dir .. "/lib/?.lua",
        package.path,
    }, ";")
end
setupPaths()
require("mock_koreader")
local TestRunner = require("test_runner"):new()
local Recorder = require("ui_recorder")
local KoaMock = require("koamock")

-- ------------------------------------------------------------------ stubs
-- One Lua process runs every test file: everything replaced here goes back.
local saved = {}
local function stub(name, value)
    saved[#saved + 1] = { name = name, value = package.loaded[name] }
    package.loaded[name] = value
end
local function class()
    local C = {}
    function C:new(o) return setmetatable(o or {}, { __index = self }) end
    function C:extend(o) return setmetatable(o or {}, { __index = self }) end
    return C
end
for _idx, name in ipairs({ "ui/event", "ui/widget/menu" }) do
    if not package.loaded[name] then stub(name, class()) end
end
stub("ui/widget/textwidget", {
    new = function(_self, o)
        return { getSize = function() return { w = #(o.text or "") * 8 } end, free = function() end }
    end,
})
stub("device", {
    screen = {
        getWidth = function() return 800 end,
        getHeight = function() return 600 end,
        scaleBySize = function(_self, n) return n end,
        isColorEnabled = function() return false end,
    },
    isTouchDevice = function() return false end,
    hasKeys = function() return false end,
})
stub("ui/font", { getFace = function() return {} end })
stub("ui/size", { padding = { default = 0, large = 0, fullscreen = 0 }, margin = { default = 0 },
    line = { thick = 1 }, border = { default = 1 } })
stub("ui/network/manager", { runWhenConnected = function(_self, fn) fn() end })
-- luasocket's mime is not in the shared mock; the image generator calls it
-- only at response time
if not package.loaded["mime"] then
    stub("mime", { b64 = function(s) return s end, unb64 = function(s) return s end })
end
stub("koassistant.books.book_groups", {
    KIND_SERIES = "series", KIND_PROJECT = "project", KIND_PLAIN = "plain",
    groupsFor = function() return {} end,
    kindOf = function(g) return g.kind end,
    displayTitle = function(path) return path end,
})
local SDS = require("koassistant.storage.doc_settings")
local saved_resolve, saved_overlay = SDS.resolve, SDS.overlayCustomProps
SDS.resolve = function()
    return { readSetting = function() return nil end }
end
SDS.overlayCustomProps = function(props) return props or {} end
_G.G_reader_settings = _G.G_reader_settings or {
    _store = {},
    readSetting = function(self, key, default)
        local v = self._store[key]
        if v == nil then return default end
        return v
    end,
    saveSetting = function(self, key, value) self._store[key] = value end,
    flush = function() end,
}
package.loaded["docsettings"] = package.loaded["docsettings"] or {
    getSidecarDir = function(_self, _doc_path, _force) return "/tmp" end,
    isHashLocationEnabled = function() return false end,
}
-- The dialogs are recorded from here on; the browser is loaded fresh so it
-- picks up this file's stubs
local ui = Recorder.install()
local ActionCache = require("koassistant.artifacts.action_cache")
local promoted = {}
local saved_promoted, saved_ladder = ActionCache.getPromotedStubs, ActionCache.getXrayLadderCount
ActionCache.getPromotedStubs = function() return promoted end
ActionCache.getXrayLadderCount = function() return 0 end
local had_browser = package.loaded["koassistant.xray.xray_browser"]
package.loaded["koassistant.xray.xray_browser"] = nil
local XrayBrowser = require("koassistant.xray.xray_browser")
local XrayParser = require("koassistant.xray.xray_parser")
local ImageGenerator = require("koassistant.images.image_generator")

-- ------------------------------------------------------------------ fixture
-- The plugin as the browser sees it: settings with an image provider that has
-- a key, so Illustrate is offered (the keys are fake and nothing is sent: the
-- picture itself is stubbed below)
local features = { image_gen_provider = "openai", provider = "anthropic" }
local plugin = {
    settings = { data = { features = features },
        readSetting = function(_self, k) return k == "features" and features or nil end },
    updateConfigFromSettings = function() end,
    imageStyleItems = function() return {} end,
    showQuickSettingsPopup = function() end,
}

local function browser(data, file)
    return setmetatable({
        xray_data = data,
        metadata = { book_file = file, plugin = plugin, enable_emoji = false,
            configuration = { features = features }, title = "Mock Series 3 - The Orchard" },
        nav_stack = {},
        menu = { item_table = {}, paths = {}, switchItemTable = function() end },
        _ledger_gen = 0,
    }, { __index = XrayBrowser })
end

local function entry(data, cat, name)
    for _idx, item in ipairs(data[cat] or {}) do
        if XrayParser.getItemName(item, cat) == name then return item end
    end
    error("no entry " .. name)
end

local function withKeys(fn)
    local prev = package.loaded["apikeys"]
    package.loaded["apikeys"] = { openai = "sk-flow-test" }
    local ok, err = pcall(fn)
    package.loaded["apikeys"] = prev
    if not ok then error(err, 0) end
end

local function moreOf(b, item, cat)
    ui.stack = {}
    b:_showEntityManagePopup(item, cat, XrayParser.getItemName(item, cat), nil, nil, nil, true, {})
    return ui:top()
end

-- ------------------------------------------------------------------ tests
print("")
print("  [More… on an entry (B534)]")

TestRunner:test("an entry with history from an earlier book: no Move back", function()
    local data, file = KoaMock.xray("Mock Series 3")
    local tamsin = entry(data, "characters", "Tamsin Vael")
    TestRunner:assertTrue(type(tamsin.background) == "table" and #tamsin.background > 0,
        "the fixture gives her a line from volume 1")
    local popup = moreOf(browser(data, file), tamsin, "characters")
    TestRunner:assertTrue(ui:has("Names and matching…", popup), table.concat(ui:texts(popup), " | "))
    TestRunner:assertTrue(not ui:has("Edit search terms", popup) and not ui:has("Rename…", popup),
        "B533: one row for both")
    TestRunner:assertTrue(not ui:has("Move back to carried list", popup),
        "never carried here: " .. table.concat(ui:texts(popup), " | "))
end)

TestRunner:test("an entry added from the carried list: Move back, then its confirm", function()
    local data, file = KoaMock.xray("Mock Series 3")
    -- Oswin Tarr: the fixture's hand-added entry and its record
    promoted = KoaMock.promoted("Mock Series 3")
    local ok, err = pcall(function()
        TestRunner:assertEqual(promoted["oswin tarr"], "Oswin Tarr", "the planted record")
        local popup = moreOf(browser(data, file), entry(data, "characters", "Oswin Tarr"), "characters")
        ui:tap("Move back to carried list", popup)
        local confirm = ui:top()
        TestRunner:assertTrue(confirm and confirm.ok_text == "Move", "the confirm")
        TestRunner:assertTrue(tostring(confirm.text):find("Oswin Tarr", 1, true) ~= nil, tostring(confirm.text))
        -- the same record on Tamsin, who has history but was never added by hand
        local tamsin = moreOf(browser(data, file), entry(data, "characters", "Tamsin Vael"), "characters")
        TestRunner:assertTrue(not ui:has("Move back to carried list", tamsin), "the record names Oswin only")
    end)
    promoted = {}
    if not ok then error(err, 0) end
end)

print("")
print("  [Illustrate (B535)]")

TestRunner:test("Illustrate… opens the image settings, then the note, then the picture", function()
    local saved_generate = ImageGenerator.generate
    local drawn
    ImageGenerator.generate = function(_text, _config, _settings, book_info, gen_opts)
        drawn = { book_info = book_info, gen_opts = gen_opts }
    end
    local ok, err = pcall(withKeys, function()
        local data, file = KoaMock.xray("Mock Series 3")
        local popup = moreOf(browser(data, file), entry(data, "characters", "Gil Rook"), "characters")
        ui:tap("Illustrate…", popup)
        local panel = ui:top()
        TestRunner:assertEqual(panel.title, "Illustrate \"Gil Rook\"")
        local all = table.concat(ui:texts(panel), " | ")
        TestRunner:assertTrue(all:find("Style:", 1, true) ~= nil, "the settings rows: " .. all)
        TestRunner:assertTrue(ui:has("Illustrate", panel) and ui:has("Illustrate with a note…", panel)
            and ui:has("Close", panel), all)
        ui:tap("Illustrate with a note…", panel)
        local note = ui:top()
        TestRunner:assertEqual(note.title, "Note for the picture")
        ui:type("up the ladder, at dusk", note)
        ui:tap("Illustrate", note)
        TestRunner:assertTrue(drawn ~= nil, "the picture was asked for")
        TestRunner:assertEqual(drawn.gen_opts.note, "up the ladder, at dusk")
        TestRunner:assertEqual(drawn.gen_opts.entry.name, "Gil Rook")
        TestRunner:assertEqual(drawn.book_info.file, file)
        drawn = nil
        moreOf(browser(data, file), entry(data, "characters", "Gil Rook"), "characters")
        ui:tap("Illustrate…")
        ui:tap("Illustrate")
        TestRunner:assertTrue(drawn ~= nil and drawn.gen_opts.note == nil, "straight from the panel: no note")
    end)
    ImageGenerator.generate = saved_generate
    if not ok then error(err, 0) end
end)

TestRunner:test("a note that names an entry brings it to the prompt writer", function()
    local data, file = KoaMock.xray("Mock Series 3")
    local saved_parsed, saved_run = ActionCache.parsedXrayFor, ImageGenerator._run
    local DataAccess = require("koassistant.ui.data_access")
    local saved_access = DataAccess.withAccess
    local run
    ActionCache.parsedXrayFor = function() return { data = data, entry = { used_book_text = true } } end
    DataAccess.withAccess = function(_plugin, _action, _opts, run_fn) run_fn({}) end
    ImageGenerator._run = function(st) run = st end
    local ok, err = pcall(function()
        ImageGenerator._askAndRun("openai", "He handed her the knife by way of hello.",
            { provider = "anthropic", features = { image_gen_frame_context = false } }, plugin.settings,
            { file = file, title = "Mock Series 3 - The Orchard" },
            { note = "this is Gil Rook by the way", plugin = plugin })
        TestRunner:assertTrue(run ~= nil, "the run went ahead")
        TestRunner:assertEqual(#run.entries, 1, "the passage names nobody; the note names one")
        TestRunner:assertEqual(run.entries[1].name, "Gil Rook")
    end)
    ActionCache.parsedXrayFor, ImageGenerator._run = saved_parsed, saved_run
    DataAccess.withAccess = saved_access
    if not ok then error(err, 0) end
end)

print("")
print("  [Names and matching (B533)]")

-- The book's alias file and its live X-Ray "on disk", in memory: the screen's
-- writes are checked without files. The view is the disk copy with the alias
-- file merged, as the browser reads it after every commit.
local function deepcopy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = deepcopy(x) end
    return out
end
local function namesHarness()
    local data, file = KoaMock.xray("Mock Series 3")
    local disk = KoaMock.xray("Mock Series 3")
    -- Gil Rook gets an alias from the AI, on both copies
    entry(data, "characters", "Gil Rook").aliases = { "the grafter" }
    entry(disk, "characters", "Gil Rook").aliases = { "the grafter" }
    local store, replays = {}, {}
    local saved_get, saved_set, saved_wiki = ActionCache.getUserAliases, ActionCache.setUserAliases,
        ActionCache.getWikiEntry
    ActionCache.getUserAliases = function() return deepcopy(store) end
    ActionCache.setUserAliases = function(_file, t) store = deepcopy(t) return true end
    ActionCache.getWikiEntry = function() return nil end
    local WriteBack = require("koassistant.xray.artifact_writeback")
    local saved_replay = WriteBack.replayIntoRungs
    WriteBack.replayIntoRungs = function(_file, fn) replays[#replays + 1] = fn return 0 end
    local b = browser(data, file)
    local function view()
        local v = XrayParser.parse(XrayParser.serialize(disk))
        XrayParser.mergeUserAliases(v, store)
        return v
    end
    b.showItemDetail = function() end
    b._rebuildToDetail = function() end
    b._dismissDetail = function() end
    b._commitDormantOp = function(self, apply_fn)
        if not apply_fn(disk) then return false end
        self.xray_data = view()
        return true
    end
    b.reloadLiveMain = function(self)
        self.xray_data = view()
        return true
    end
    local h = { b = b, disk = disk, replays = replays }
    function h.store() return store end
    function h.restore()
        ActionCache.getUserAliases, ActionCache.setUserAliases = saved_get, saved_set
        ActionCache.getWikiEntry = saved_wiki
        WriteBack.replayIntoRungs = saved_replay
    end
    return h
end
local function rowsOf(w)
    return table.concat(ui:texts(w), " | ")
end

TestRunner:test("every name with what it is and whether it is matched", function()
    local h = namesHarness()
    local ok, err = pcall(function()
        ui.stack = {}
        h.b:editSearchTerms(entry(h.b.xray_data, "characters", "Gil Rook"), "characters", "Gil Rook")
        local names = ui:top()
        TestRunner:assertEqual(names.title, "Names of \"Gil Rook\"")
        TestRunner:assertTrue(ui:has("Gil Rook · main name · matched", names), rowsOf(names))
        TestRunner:assertTrue(ui:has("the grafter · from the AI · matched", names), rowsOf(names))
        TestRunner:assertTrue(ui:has("Add a name…", names) and ui:has("Close", names), rowsOf(names))
        TestRunner:assertTrue(not ui:has("Reset to the AI's names", names), "nothing differs yet")
    end)
    h.restore()
    if not ok then error(err, 0) end
end)

TestRunner:test("the main name stops matching: no form, no direct hit, still the entry's name", function()
    local h = namesHarness()
    local ok, err = pcall(function()
        local gil = entry(h.b.xray_data, "characters", "Gil Rook")
        ui.stack = {}
        h.b:editSearchTerms(gil, "characters", "Gil Rook")
        ui:tap("Gil Rook · main name · matched")
        TestRunner:assertTrue(ui:has("Rename…") and ui:has("Stop matching"), rowsOf())
        TestRunner:assertTrue(not ui:has("Delete"), "the AI's name is never deleted")
        ui:tap("Stop matching")
        TestRunner:assertEqual(h.store()["Gil Rook"].ignore[1], "Gil Rook", "written to the alias file")
        TestRunner:assertTrue(ui:has("Gil Rook · main name · not matched"), rowsOf())
        TestRunner:assertTrue(ui:has("Reset to the AI's names"), rowsOf())
        -- a fresh read of the book, as every surface does
        local fresh = XrayParser.parse(XrayParser.serialize(h.disk))
        XrayParser.mergeUserAliases(fresh, h.store())
        local item = entry(fresh, "characters", "Gil Rook")
        local set = XrayParser.matchTermSet(item)
        TestRunner:assertEqual(table.concat(set.all, ","), "the grafter", "only the alias is matched")
        TestRunner:assertEqual(#XrayParser.searchAll(fresh, "Gil Rook", { exact = true }), 0, "no direct hit")
        TestRunner:assertEqual(#XrayParser.searchAll(fresh, "Gil Rook"), 1, "a typed search still lists it")
        local terms = XrayParser.collectSearchTerms(item)
        TestRunner:assertEqual(#terms, 1, "the search hand-over leaves it out")
        local handles = {}
        XrayParser.foldExactHandles(fresh, handles)
        TestRunner:assertTrue(not XrayParser.matchExactHandle(handles, "gil rook"), "the selection intercept too")
        -- and back
        ui:tap("Gil Rook · main name · not matched")
        ui:tap("Match again")
        TestRunner:assertTrue(ui:has("Gil Rook · main name · matched"), rowsOf())
        TestRunner:assertEqual(#(h.store()["Gil Rook"] or { ignore = {} }).ignore, 0, "out of the alias file")
    end)
    h.restore()
    if not ok then error(err, 0) end
end)

TestRunner:test("a rename keeps the AI's name matched, asks nothing, and Reset undoes it all", function()
    local h = namesHarness()
    local ok, err = pcall(function()
        ui.stack = {}
        h.b:editSearchTerms(entry(h.b.xray_data, "characters", "Gil Rook"), "characters", "Gil Rook")
        ui:tap("Gil Rook · main name · matched")
        ui:tap("Rename…")
        ui:type("Gil Rookwood")
        ui:tap("Rename")
        local names = ui:top()
        TestRunner:assertEqual(names.title, "Names of \"Gil Rookwood\"", "the screen of the renamed entry, no question")
        TestRunner:assertTrue(ui:has("Gil Rook · the AI's name · matched", names), rowsOf(names))
        local rec = h.store()["Gil Rookwood"]
        TestRunner:assertEqual(rec.ai_name, "Gil Rook", "the record holds the AI's name")
        TestRunner:assertEqual(rec.typed[1], "Gil Rookwood", "and the typed one")
        TestRunner:assertEqual(#h.replays, 1, "the built checkpoints take the rename")
        -- the AI's alias as the main name: the typed name becomes a name of the reader's
        ui:tap("the grafter · from the AI · matched", names)
        ui:tap("Make it the main name")
        names = ui:top()
        TestRunner:assertEqual(names.title, "Names of \"the grafter\"")
        TestRunner:assertTrue(ui:has("Gil Rookwood · your name · matched", names), rowsOf(names))
        TestRunner:assertEqual(h.store()["the grafter"].ai_name, "Gil Rook", "the AI's name kept through renames")
        TestRunner:assertEqual(#h.store()["the grafter"].typed, 1, "the AI's alias is not a typed name")
        -- the reader's own name deletes
        ui:tap("Gil Rookwood · your name · matched", names)
        ui:tap("Delete")
        local grafter = entry(h.disk, "characters", "the grafter")
        for _idx, a in ipairs(grafter.aliases or {}) do
            TestRunner:assertTrue(a ~= "Gil Rookwood", "out of the X-Ray's aliases")
        end
        TestRunner:assertTrue(h.store()["the grafter"].typed == nil or #h.store()["the grafter"].typed == 0,
            "out of the record")
        -- Reset: the AI's name and aliases back, the record gone
        ui:tap("Reset to the AI's names")
        ui:tap("Reset")
        local gil = entry(h.disk, "characters", "Gil Rook")
        TestRunner:assertEqual(table.concat(gil.aliases or {}, ","), "the grafter", "the AI's aliases as they were")
        TestRunner:assertTrue(h.store()["Gil Rook"] == nil and h.store()["the grafter"] == nil, "the record cleared")
    end)
    h.restore()
    if not ok then error(err, 0) end
end)

TestRunner:test("capitals only: the option names its example, the row says it, Reset clears it (S2)", function()
    local h = namesHarness()
    local ok, err = pcall(function()
        local CAPS = "Match capitals only (\"the Drowned\", not \"the drowned\")"
        ui.stack = {}
        h.b:editSearchTerms(entry(h.b.xray_data, "characters", "The Drowned"), "characters", "The Drowned")
        ui:tap("The Drowned · main name · matched")
        ui:tap(CAPS)
        TestRunner:assertEqual(h.store()["The Drowned"].case["the drowned"], "capitals", "written to the alias file")
        TestRunner:assertTrue(ui:has("The Drowned · main name · capitals only"), rowsOf())
        TestRunner:assertTrue(ui:has("Reset to the AI's names"), rowsOf())
        -- a fresh read of the book, as every surface does: the matcher asks the capitals
        local fresh = XrayParser.parse(XrayParser.serialize(h.disk))
        XrayParser.mergeUserAliases(fresh, h.store())
        TestRunner:assertEqual(XrayParser.matchTermSet(entry(fresh, "characters", "The Drowned")).caps["the drowned"], 2)
        -- and back
        ui:tap("The Drowned · main name · capitals only")
        TestRunner:assertTrue(ui:has("Match any case") and ui:has("Stop matching"), rowsOf())
        ui:tap("Match any case")
        TestRunner:assertTrue(ui:has("The Drowned · main name · matched"), rowsOf())
        TestRunner:assertEqual(h.store()["The Drowned"].case, nil, "out of the alias file")
        -- Reset clears it with the rest
        ui:tap("The Drowned · main name · matched")
        ui:tap(CAPS)
        ui:tap("Reset to the AI's names")
        ui:tap("Reset")
        TestRunner:assertEqual(h.store()["The Drowned"], nil, "the record cleared")
        TestRunner:assertTrue(ui:has("The Drowned · main name · matched") and not ui:has("Reset to the AI's names"),
            rowsOf())
        -- a one-word term names itself; a name with no capital is offered nothing
        ui.stack = {}
        h.b:editSearchTerms(entry(h.b.xray_data, "lexicon", "Warden"), "lexicon", "Warden")
        ui:tap("Warden · main name · matched")
        TestRunner:assertTrue(ui:has("Match capitals only (\"Warden\", not \"warden\")"), rowsOf())
        ui.stack = {}
        h.b:editSearchTerms(entry(h.b.xray_data, "characters", "Gil Rook"), "characters", "Gil Rook")
        ui:tap("the grafter · from the AI · matched")
        for _idx, t in ipairs(ui:texts()) do
            TestRunner:assertTrue(not t:find("capitals", 1, true), "no capital to require: " .. rowsOf())
        end
    end)
    h.restore()
    if not ok then error(err, 0) end
end)

TestRunner:test("a rebuild that names the entry as the AI did gets the reader's name back", function()
    local rebuilt = KoaMock.xray("Mock Series 3")
    local records = { ["Gil Rookwood"] = { ai_name = "Gil Rook", typed = { "Gil Rookwood", "Rook the Younger" } } }
    TestRunner:assertEqual(XrayParser.keepRenames(rebuilt, records), 1)
    local gil = entry(rebuilt, "characters", "Gil Rookwood")
    TestRunner:assertEqual(gil.aliases[1], "Gil Rook", "the AI's name as the first alias")
    TestRunner:assertTrue(table.concat(gil.aliases, ","):find("Rook the Younger", 1, true) ~= nil,
        "the reader's other typed names as aliases")
    TestRunner:assertEqual(XrayParser.keepRenames(rebuilt, records), 0, "an update that carried it: nothing to do")
end)

print("")
print("  [Merge with another entry]")

-- The duplicate flow seeded from an entry, on an in-memory disk copy; the
-- entry page is a shown widget, so the test sees whether it stays
local UIManager = require("ui/uimanager")
local function mergeHarness()
    local data, file = KoaMock.xray("Mock Series 3")
    local h = { disk = KoaMock.xray("Mock Series 3"), writes = 0 }
    local WriteBack = require("koassistant.xray.artifact_writeback")
    local saved_cache, saved_get, saved_set = ActionCache.getXrayCache, ActionCache.getUserAliases,
        ActionCache.setUserAliases
    local saved_ladder, saved_never, saved_commit = ActionCache.getXrayLadder, ActionCache.addNeverMergePair,
        WriteBack.commitXray
    ActionCache.getXrayCache = function()
        return { result = XrayParser.serialize(h.disk), progress_decimal = 0.5 }
    end
    ActionCache.getUserAliases = function() return {} end
    ActionCache.setUserAliases = function() return true end
    ActionCache.getXrayLadder = function() return {} end
    ActionCache.addNeverMergePair = function() h.never = true end
    WriteBack.commitXray = function(_file, json_text)
        h.disk = XrayParser.parse(json_text)
        h.writes = h.writes + 1
        return true
    end
    local b = browser(data, file)
    b.reloadLiveMain = function(self)
        self.xray_data = XrayParser.parse(XrayParser.serialize(h.disk))
        return true
    end
    b._rebuildToDetail = function(_self, cat, name) h.rebuilt = cat .. "/" .. name end
    -- the entry page: closes like the TextViewer it is
    h.page = { onClose = function(w) UIManager:close(w) end }
    h.b = b
    function h.open()
        ui.stack = {}
        UIManager:show(h.page)
        b._detail_viewer = h.page
        b:_showEntityManagePopup(entry(b.xray_data, "characters", "Gil Rook"), "characters",
            "Gil Rook", nil, nil, h.page, true, {})
        ui:tap("Merge with another entry…")
    end
    function h.restore()
        ActionCache.getXrayCache, ActionCache.getUserAliases = saved_cache, saved_get
        ActionCache.setUserAliases, ActionCache.getXrayLadder = saved_set, saved_ladder
        ActionCache.addNeverMergePair, WriteBack.commitXray = saved_never, saved_commit
    end
    return h
end
local PICK = "Pick the entry to pair with \"Gil Rook\""

TestRunner:test("the entry page stays under the pick: Cancel, Back and a tap outside land on it", function()
    local h = mergeHarness()
    local ok, err = pcall(function()
        h.open()
        local pick = ui:top()
        TestRunner:assertEqual(pick.title, PICK)
        TestRunner:assertTrue(UIManager:isWidgetShown(h.page), "the entry page is still open")
        TestRunner:assertTrue(ui:has("Jory", pick) and not ui:has("Gil Rook", pick), rowsOf(pick))
        ui:tap("Cancel", pick)
        TestRunner:assertTrue(ui:top() == h.page, "Cancel: the entry page")
        -- the pair's Back and a tap outside it: the pick again, never the duplicates list
        h.open()
        ui:tap("Jory")
        TestRunner:assertTrue(ui:has("Merge: keep \"Gil Rook\""), rowsOf())
        ui:tap("Back")
        TestRunner:assertEqual(ui:top().title, PICK)
        ui:tap("Jory")
        ui:tapOutside()
        TestRunner:assertEqual(ui:top().title, PICK)
        ui:tap("Cancel")
        TestRunner:assertTrue(ui:top() == h.page and h.writes == 0, "nothing written, the page on top")
        -- Never suggest: remembered, and back on the page
        h.open()
        ui:tap("Jory")
        ui:tap("Never suggest this pair")
        ui:tap("Never merge")
        TestRunner:assertTrue(h.never, "the pair remembered")
        TestRunner:assertTrue(UIManager:isWidgetShown(h.page) and h.rebuilt == nil, "the page stays")
        TestRunner:assertTrue(not tostring(ui:top().title or ""):find("Possible duplicate", 1, true),
            "no duplicates list")
    end)
    h.restore()
    if not ok then error(err, 0) end
end)

TestRunner:test("a merge lands on the kept entry", function()
    local h = mergeHarness()
    local ok, err = pcall(function()
        h.open()
        ui:tap("Jory")
        ui:tap("Merge: keep \"Gil Rook\"")
        TestRunner:assertEqual(h.writes, 1, "the merge written")
        TestRunner:assertTrue(not UIManager:isWidgetShown(h.page), "the old page closed")
        TestRunner:assertEqual(h.rebuilt, "characters/Gil Rook", "rebuilt onto the kept entry")
        local gil = entry(h.b.xray_data, "characters", "Gil Rook")
        TestRunner:assertTrue(table.concat(gil.aliases or {}, ","):find("Jory", 1, true) ~= nil,
            "Jory is one of his names now")
        for _idx, w in ipairs(ui.stack) do
            TestRunner:assertTrue(not tostring(w.title or ""):find("Possible duplicate", 1, true),
                "no duplicates list")
        end
    end)
    h.restore()
    if not ok then error(err, 0) end
end)

TestRunner:test("an AI merge lands on the kept entry; one the AI declines leaves the page", function()
    local XrayMerge = require("koassistant.xray.xray_merge")
    local saved_access, saved_cfg = XrayMerge.withDataAccess, XrayMerge.buildHeadlessConfig
    local saved_dialogs = package.loaded["koassistant.ui.dialogs"]
    local answer
    XrayMerge.withDataAccess = function(_opts, _books, _name, run) run({ features = features }) end
    XrayMerge.buildHeadlessConfig = function() return {}, {} end
    package.loaded["koassistant.ui.dialogs"] = {
        executeActionForResult = function(_action, _text, _ui, _config, _plugin, _bm, done) done(answer) end,
    }
    local AI_ROW = "AI merge: combined description, keep \"Gil Rook\""
    local ok, err = pcall(function()
        local h = mergeHarness()
        local ok2, err2 = pcall(function()
            answer = "DIFFERENT ENTITIES\nA grafter and a boy who share an orchard."
            h.open()
            ui:tap("Jory")
            ui:tap(AI_ROW)
            ui:tap("Not now")
            TestRunner:assertTrue(h.writes == 0 and h.rebuilt == nil, "declined: nothing written or rebuilt")
            TestRunner:assertTrue(UIManager:isWidgetShown(h.page), "the page stays")
            answer = "A grafter of the orchard, also called Jory."
            h.open()
            ui:tap("Jory")
            ui:tap(AI_ROW)
            TestRunner:assertEqual(h.writes, 1, "the merge written")
            TestRunner:assertEqual(h.rebuilt, "characters/Gil Rook", "rebuilt onto the kept entry")
            TestRunner:assertTrue(not UIManager:isWidgetShown(h.page), "the old page closed")
            TestRunner:assertEqual(entry(h.b.xray_data, "characters", "Gil Rook").description,
                "A grafter of the orchard, also called Jory.", "the combined description")
        end)
        h.restore()
        if not ok2 then error(err2, 0) end
    end)
    XrayMerge.withDataAccess, XrayMerge.buildHeadlessConfig = saved_access, saved_cfg
    package.loaded["koassistant.ui.dialogs"] = saved_dialogs
    if not ok then error(err, 0) end
end)

-- ------------------------------------------------------------------ cleanup
ui:restore()
ActionCache.getPromotedStubs, ActionCache.getXrayLadderCount = saved_promoted, saved_ladder
SDS.resolve, SDS.overlayCustomProps = saved_resolve, saved_overlay
package.loaded["koassistant.xray.xray_browser"] = had_browser
for i = #saved, 1, -1 do package.loaded[saved[i].name] = saved[i].value end

return TestRunner:summary()
