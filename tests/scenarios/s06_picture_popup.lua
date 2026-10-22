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

-- ── A long passage stays on one line: the popup still fits without scrolling ──
S.closeAll()
local long_passage = string.rep("He handed Tamsin the knife by way of hello, and the cart came up the lane. ", 4)
Dialogs.executeDirectAction(ui, Actions.highlight.image_gen, long_passage, S.plugin.configuration, S.plugin)
S.settle()
S.check(S.top()._scroll == nil and S.top()._frame.dimen.h <= S.Screen:getHeight(),
    "a 300-character passage: one line, no scrolling")
S.shot("long_passage")
S.closeAll()
Dialogs.executeDirectAction(ui, Actions.highlight.image_gen, passage, S.plugin.configuration, S.plugin)
S.settle()

-- ── A pick is the setting ──
S.tap("Watercolor")
S.check(features().image_gen_style == "watercolor", "Watercolor is saved as the style")
S.check(checked("Watercolor") == true and checked("Book illustration") == false, "the popup shows the new pick")
S.tap("Portrait")
S.check(features().image_gen_shape == "portrait", "Portrait is saved as the shape")

-- ── The note, for this picture ──
S.tap("Add a note…")
-- (on a device without a keyboard, KOReader's on-screen one sits above it)
local box
for i = #S.UIManager._window_stack, 1, -1 do
    local w = S.UIManager._window_stack[i].widget
    if not box and w.title == "Note for the picture" then box = w end
end
S.check(box ~= nil, "the note box opens over the popup")
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
local drawn_from = S.top()
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

-- ── Every exit closes it and draws nothing: the X, a tap outside, Back ──
local Event = require("ui/event")
local Geom = require("ui/geometry")
local popup = S.top()
popup._frame[1][1].right_button.callback()
S.settle()
S.check(not S.UIManager:isWidgetShown(popup), "the X closes it")
Dialogs.executeDirectAction(ui, Actions.highlight.image_gen, passage, S.plugin.configuration, S.plugin)
S.settle()
popup = S.top()
popup:onTapClose(nil, { pos = Geom:new{ x = 2, y = 2, w = 0, h = 0 } })
S.settle()
S.check(not S.UIManager:isWidgetShown(popup), "a tap outside closes it")
Dialogs.executeDirectAction(ui, Actions.highlight.image_gen, passage, S.plugin.configuration, S.plugin)
S.settle()
popup = S.top()
if require("device"):hasKeys() then
    S.UIManager:sendEvent(Event:new("KeyPress", require("device/key"):new("Back", {})))
    S.settle()
    S.check(not S.UIManager:isWidgetShown(popup), "Back closes it")
else
    -- a device without keys (the wiki runs' e-reader) has no Back to bind
    popup._frame[1][1].right_button.callback()
    S.settle()
end
S.check(drawn == nil, "no exit draws anything")

-- ── A picker's late callback never reopens a popup that drew ──
-- (OpenRouter's catalog can arrive after Generate: its pick calls the
-- popup's rebuild, here a row of the drawn popup's own)
for _idx, row in ipairs(drawn_from._rows) do
    if row.id == "shape" then
        for _j, it in ipairs(row.items) do
            if it.text == "Square" then it.callback() end
        end
    end
end
S.settle()
S.check(S.top() == ui, "the drawn popup stays closed")

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

-- ── The chat provider cannot draw: the provider question first ──
local f = S.plugin.settings:readSetting("features")
f.image_gen_provider, f.provider = "auto", "anthropic"
drawn = nil
Dialogs.executeDirectAction(ui, Actions.highlight.image_gen, passage, S.plugin.configuration, S.plugin)
S.settle()
local question = S.top()
S.check(question and question.title and question.title:find("can't make images", 1, true) ~= nil,
    "the provider question comes before the popup")
S.tap("Cancel")
S.check(S.top() == ui and drawn == nil, "Cancel: no popup, nothing drawn")
Dialogs.executeDirectAction(ui, Actions.highlight.image_gen, passage, S.plugin.configuration, S.plugin)
S.settle()
S.tap("OpenAI")
S.check(title() == "Generate Image" and table.concat(S.texts(), " | "):find("OpenAI | gpt-image-2.5-flare", 1, true) ~= nil,
    "after the answer: the popup, on the provider that draws and its model")
S.check(S.plugin.settings:readSetting("features").image_gen_provider == "openai", "the answer saved as Provider")
S.closeAll()

-- ── The model button names the model that draws (a retired id's replacement) ──
local ImageOptions = require("koassistant.images.image_options")
f = S.plugin.settings:readSetting("features")
f.image_gen_provider, f.image_gen_model_xai = "xai", "grok-imagine-image-pro"
f.api_keys = f.api_keys or {}
f.api_keys.xai = "xai-scenario-not-a-key"
ImageOptions.show(S.plugin, { actions = { { text = "Regenerate", callback = function() end } } })
S.settle()
S.check(table.concat(S.texts(), " | "):find("grok-imagine-image-2.0", 1, true) ~= nil,
    "a retired id shows as its replacement")
S.closeAll()
f.image_gen_provider = "openai"

-- ── A long typed style is cut on its row, so the popup keeps its size ──
-- (and were a row to grow, the clamp keeps the bottom on the screen)
popup = ImageOptions.show(S.plugin, { actions = {
    { text = "Regenerate", callback = function() end },
    { text = "Regenerate and replace", callback = function() end },
} })
S.settle()
f.image_gen_style, f.image_gen_style_custom = "custom", string.rep("a 1920s travel poster ", 9)
S.tap("Square")
popup = S.top()
local fd = popup._frame.dimen
S.note("frame with the long style:", fd.y, fd.h, "screen", S.Screen:getHeight())
S.check(fd.y >= 0 and fd.y + fd.h <= S.Screen:getHeight(), "with a 200-character style it stays on the screen")
S.check(S.find("Regenerate and replace") ~= nil, "the buttons stay reachable")
local custom_text
for _idx, b in ipairs(S.buttons()) do
    if b.text:find("^Custom") then custom_text = b.text end
end
S.check(custom_text and custom_text:sub(-3) == "…", "a long typed style is cut on its row")
S.closeAll()
f.image_gen_style, f.image_gen_style_custom = "watercolor", nil

-- ── A gallery picture's Image settings…: the settings and the two Regenerates ──
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
