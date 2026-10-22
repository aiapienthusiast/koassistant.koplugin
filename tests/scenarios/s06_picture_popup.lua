-- B537 on the real widgets: a tap of Generate Image opens the picture popup
-- (the scope popup's shape). For this picture: a note and the X-Ray entries
-- the prompt writer reads; then Style, Shape and Detail as radio rows, the
-- provider and model that draw, Write the prompt with AI; Generate at the
-- foot. A pick is the setting; the note and the picks go with this picture
-- only. Long-press → Generate now draws at once. Illustrate… and a gallery
-- picture's Image settings… open the same popup. Nothing is drawn: the
-- generator is replaced by a recorder (the network is blocked anyway).
local S = dofile(os.getenv("KOA_PLUGIN") .. "/tests/scenarios/boot.lua")
-- An image provider with a key (a fake key in the run's own settings)
S.features({ image_gen_provider = "openai", api_keys = { openai = "sk-scenario-not-a-key" } })

local ui = S.open("Mock Series 3")
local file = ui.document.file
local Dialogs = require("koassistant.ui.dialogs")
local Actions = require("koassistant.prompts.actions")
local ActionCache = require("koassistant.artifacts.action_cache")
local XrayParser = require("koassistant.xray.xray_parser")
local XrayBrowser = require("koassistant.xray.xray_browser")
local ImageGenerator = require("koassistant.images.image_generator")
local NetworkMgr = require("ui/network/manager")

local drawn
ImageGenerator.generate = function(text, _config, _settings, book_info, gen_opts)
    drawn = { text = text, book_info = book_info, gen_opts = gen_opts }
end
NetworkMgr.runWhenConnected = function(_self, fn) fn() end

local function features() return S.plugin.settings:readSetting("features") or {} end
local function checked(text)
    for _idx, b in ipairs(S.buttons()) do
        if b.text == text then return b.checked end
    end
end
local function title()
    local w = S.top()
    return w and w._frame and w._frame[1] and w._frame[1][1] and w._frame[1][1].title or ""
end

local passage = "He handed Tamsin the knife by way of hello."
S.chapter("The Grafter")

-- ── A tap: the popup ──
Dialogs.executeDirectAction(ui, Actions.highlight.image_gen, passage, S.plugin.configuration, S.plugin)
S.settle()
local all = table.concat(S.texts(), " | ")
S.note("popup:", all)
S.check(title() == "Generate Image", "a tap opens the picture popup")
S.check(all:find("Add a note…", 1, true) and all:find("Pick X-Ray entries…", 1, true),
    "for this picture: a note and X-Ray entries")
S.check(checked("Book illustration") == true and checked("Fit my screen") == true and checked("Draft") == true,
    "Style, Shape and Detail as radio rows, on the settings' values")
S.check(all:find("OpenAI | gpt-image-2.5-flare", 1, true) ~= nil, "the provider and the model that draw")
S.check(checked("Write the prompt with AI") == true, "Write the prompt with AI, on")
S.check(all:find("Generate", 1, true) ~= nil, "Generate at the foot")
S.check(drawn == nil, "nothing drawn yet")
local frame = S.top()._frame
S.check(frame.dimen.h <= S.Screen:getHeight() and S.top()._scroll == nil,
    "the popup fits a portrait screen without scrolling")
S.shot("popup")

-- ── A pick is the setting ──
S.tap("Watercolor")
S.check(features().image_gen_style == "watercolor", "Watercolor is saved as the style")
S.check(checked("Watercolor") == true and checked("Book illustration") == false, "the popup shows the new pick")
S.tap("Portrait")
S.check(features().image_gen_shape == "portrait", "Portrait is saved as the shape")

-- ── The note, for this picture ──
S.tap("Add a note…")
local box = S.top()
S.check(box and box.title == "Note for the picture", "the note box opens over the popup")
box:setInputText("at dusk, one lit window")
S.tap("OK")
S.check(S.find("Note: at dusk, one lit window") ~= nil, "the popup shows the note")

-- ── The X-Ray entries, for this picture ──
S.tap("Pick X-Ray entries…")
S.tap({ "Gil Rook" })
S.tap({ "Hollowmere" })
S.shot("picker")
S.tap("Done")
S.check(S.find("X-Ray entries: Gil Rook, Hollowmere") ~= nil, "the popup shows the picks, in the order picked")
S.shot("popup_filled")

-- ── The writer off: nothing reads the picks ──
S.tap("Write the prompt with AI")
S.check(features().image_gen_writer == false, "Write the prompt with AI is saved off")
local picks_button
for _idx, b in ipairs(S.buttons()) do
    if b.text:find("^X%-Ray entries") then picks_button = b.button end
end
S.check(picks_button and picks_button.enabled == false, "the picks row is grayed while the writer is off")
S.tap("Write the prompt with AI")
S.check(features().image_gen_writer ~= false, "and back on")

-- ── Generate: the note and the picks go with this picture ──
S.tap("Generate")
S.check(drawn ~= nil and drawn.text == passage, "Generate draws the passage")
S.check(drawn and drawn.gen_opts.note == "at dusk, one lit window", "with the note")
S.check(drawn and table.concat(drawn.gen_opts.picked or {}, "|") == "Gil Rook|Hollowmere", "with the picks")
S.check(S.top() == ui, "the popup is gone")

-- ── The next tap starts without them ──
drawn = nil
Dialogs.executeDirectAction(ui, Actions.highlight.image_gen, passage, S.plugin.configuration, S.plugin)
S.settle()
S.check(S.find("Add a note…") ~= nil and S.find("Pick X-Ray entries…") ~= nil,
    "the next picture starts with no note and no picks")
S.check(checked("Watercolor") == true, "but the style stays as picked")
S.closeAll()
S.check(drawn == nil, "closing the popup draws nothing")

-- ── The long-press: Generate now draws at once ──
local ActionHold = require("koassistant.ui.action_hold")
local variant
ActionHold.show(S.plugin, Actions.highlight.image_gen, { surface = "highlight",
    run = function(v) variant = v end })
S.settle()
S.note("hold menu:", table.concat(S.texts(), " | "))
S.check(S.find("Generate now") ~= nil, "the long-press offers Generate now")
S.tap("Generate now")
S.check(variant and variant.image_now == true, "as a run option")
S.closeAll()
Dialogs.executeDirectAction(ui, Actions.highlight.image_gen, passage, S.plugin.configuration, S.plugin,
    { run_variant = variant })
S.settle()
S.check(drawn ~= nil and S.top() == ui, "Generate now draws without the popup")

-- ── Illustrate…: the same popup, a note, no picks ──
drawn = nil
local data = XrayParser.parse(ActionCache.getXrayCache(file).result)
XrayParser.mergeUserAliases(data, ActionCache.getUserAliases(file))
local gil
for _idx, item in ipairs(data.characters or {}) do
    if item.name == "Gil Rook" then gil = item end
end
XrayBrowser:show(data, { title = "Mock Series 3 - The Orchard", book_file = file, plugin = S.plugin,
    configuration = S.plugin.configuration, enable_emoji = false }, ui)
S.settle()
XrayBrowser:_illustrate(gil, "characters")
S.settle()
all = table.concat(S.texts(), " | ")
S.note("Illustrate:", all)
S.check(title() == "Illustrate \"Gil Rook\"", "Illustrate… opens the picture popup")
S.check(all:find("Add a note…", 1, true) and not all:find("Pick X-Ray entries", 1, true),
    "a note, no picks (the entry is the subject)")
S.shot("illustrate")
S.tap("Illustrate")
S.check(drawn and drawn.gen_opts.entry and drawn.gen_opts.entry.name == "Gil Rook", "Illustrate draws the entry")
S.closeAll()

-- ── A gallery picture's Image settings…: the settings and the two Regenerates ──
local ImageOptions = require("koassistant.images.image_options")
ImageOptions.show(S.plugin, { actions = {
    { text = "Regenerate", callback = function() end },
    { text = "Regenerate and replace", callback = function() end },
} })
S.settle()
all = table.concat(S.texts(), " | ")
S.note("Image settings:", all)
S.check(title() == "Image settings" and not all:find("Add a note", 1, true)
    and not all:find("Write the prompt with AI", 1, true), "the gallery's: settings only")
S.check(all:find("Regenerate and replace", 1, true) ~= nil, "with the two Regenerates")
S.closeAll()

S.finish()
