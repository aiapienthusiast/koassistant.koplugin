--[[
Unit tests for koassistant/images/prompt_writer.lua (image round S5, S6, S8:
docs/image_round_plan.md sections 7 and 9).

Covers the pure parts of the prompt writer: the styles, the writer's model,
an X-Ray entry as material and the entries a passage names (the marks'
matcher), the shape line, the system text (the spoiler rule, the entry to
draw), the material blocks (tags, escaping, caps, optional blocks), reading
the writer's answer, and the provenance line.

Run: lua tests/run_tests.lua --unit
]]

package.path = package.path .. ";./?.lua;./?/init.lua"
require("tests.lib.mock_koreader")

local PromptWriter = require("koassistant.images.prompt_writer")

local TestRunner = { passed = 0, failed = 0 }

function TestRunner:test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        self.passed = self.passed + 1
        print(string.format("  ✓ %s", name))
    else
        self.failed = self.failed + 1
        print(string.format("  ✗ %s: %s", name, tostring(err)))
    end
end

function TestRunner:assert(cond, msg)
    if not cond then error(msg or "Assertion failed", 2) end
end

function TestRunner:assertEquals(actual, expected, msg)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", msg or "Values not equal",
            tostring(expected), tostring(actual)), 2)
    end
end

local function has(text, piece)
    return type(text) == "string" and text:find(piece, 1, true) ~= nil
end

-- A small fiction X-Ray, as ActionCache.parsedXrayFor returns its data
local XRAY = {
    type = "fiction",
    characters = {
        { name = "Elias Morrow", aliases = { "the keeper" }, role = "Lighthouse keeper",
          description = "A tall, weathered man in a grey oilskin coat." },
        { name = "Mara", description = "His daughter, quick and watchful, with a red scarf." },
        { name = "Tom", description = "A fisherman." },
    },
    locations = {
        { name = "the Black Rocks", description = "Jagged basalt at the mouth of the bay.",
          details = "Covered at high tide." },
    },
    themes = {
        { name = "Solitude", description = "Living apart from others." },
    },
    timeline = {
        { event = "The lamp goes dark", significance = "The storm night begins." },
    },
}

print("  Unit Tests: the image prompt writer")

print("  [Style (S6)]")
TestRunner:test("styleText: the pick's words; the default is Book illustration", function()
    local text, is_default = PromptWriter.styleText({})
    TestRunner:assertEquals(text, "a book illustration")
    TestRunner:assertEquals(is_default, true)
    text, is_default = PromptWriter.styleText({ image_gen_style = "woodcut" })
    TestRunner:assertEquals(text, "a woodcut print")
    TestRunner:assertEquals(is_default, false)
    TestRunner:assertEquals(PromptWriter.styleText({ image_gen_style = "bogus" }), "a book illustration",
        "an unknown value reads as the default")
end)
TestRunner:test("Custom: the typed words, trimmed and capped; empty falls back", function()
    local text = PromptWriter.styleText({ image_gen_style = "custom", image_gen_style_custom = "  a 1920s\ntravel poster " })
    TestRunner:assertEquals(text, "a 1920s travel poster")
    TestRunner:assertEquals(PromptWriter.styleLabel({ image_gen_style = "custom", image_gen_style_custom = "a poster" }),
        "Custom (a poster)")
    TestRunner:assertEquals(PromptWriter.styleText({ image_gen_style = "custom", image_gen_style_custom = "  " }),
        "a book illustration")
    local long = string.rep("x", 500)
    TestRunner:assert(#PromptWriter.styleText({ image_gen_style = "custom", image_gen_style_custom = long }) <= 200)
    TestRunner:assertEquals(PromptWriter.styleLabel({}), "Book illustration")
    TestRunner:assertEquals(#PromptWriter.STYLES, 8, "eight styles, then Custom")
end)

print("  [The writer's model (D8)]")
TestRunner:test("target: the chat provider's fast model; tiers off keeps the chat model", function()
    local ModelLists = require("koassistant.request.model_lists")
    local real = ModelLists.resolveTierTarget
    ModelLists.resolveTierTarget = function(p, tier)
        if tier == "fast" and p == "anthropic" then return "anthropic", "claude-fast" end
        if tier == "fast" and p == "pinned" then return "gemini", "gemini-fast" end
        return nil
    end
    local ok, err = pcall(function()
        local p, m = PromptWriter.target({}, "anthropic")
        TestRunner:assertEquals(p, "anthropic")
        TestRunner:assertEquals(m, "claude-fast")
        p, m = PromptWriter.target({}, "pinned")
        TestRunner:assertEquals(p, "gemini", "a global tier pin may name another provider")
        TestRunner:assertEquals(m, "gemini-fast")
        p, m = PromptWriter.target({ use_action_tiers = false }, "anthropic")
        TestRunner:assertEquals(p, "anthropic")
        TestRunner:assertEquals(m, nil, "the chat model as configured")
        p, m = PromptWriter.target({}, "ollama")
        TestRunner:assertEquals(p, "ollama")
        TestRunner:assertEquals(m, nil, "no fast model known")
    end)
    ModelLists.resolveTierTarget = real
    if not ok then error(err, 0) end
end)

print("  [X-Ray material (D10, S8)]")
TestRunner:test("entryMaterial: name, aliases, kind, the description with a role first", function()
    local e = PromptWriter.entryMaterial(XRAY.characters[1], "characters")
    TestRunner:assertEquals(e.name, "Elias Morrow")
    TestRunner:assertEquals(e.type, "person")
    TestRunner:assertEquals(e.aliases[1], "the keeper")
    TestRunner:assertEquals(e.description, "Lighthouse keeper. A tall, weathered man in a grey oilskin coat.")
    local place = PromptWriter.entryMaterial(XRAY.locations[1], "locations")
    TestRunner:assertEquals(place.type, "place")
    TestRunner:assert(has(place.description, "Covered at high tide."), place.description)
    local event = PromptWriter.entryMaterial(XRAY.timeline[1], "timeline")
    TestRunner:assertEquals(event.name, "The lamp goes dark")
    TestRunner:assertEquals(event.type, "event")
    TestRunner:assert(has(event.description, "storm night"), event.description)
    local dots = PromptWriter.entryMaterial({ name = "X", role = "A man of few words...", description = "Tall." }, "characters")
    TestRunner:assertEquals(dots.description, "A man of few words... Tall.", "an ellipsis stays an ellipsis")
    local long = PromptWriter.entryMaterial({ name = "X", description = string.rep("word ", 300) }, "characters")
    TestRunner:assert(#long.description <= 604, "about 600 characters: " .. #long.description)
end)
TestRunner:test("entriesFor: the entries the passage names, in its order, aliases too", function()
    local list = PromptWriter.entriesFor(
        "Mara ran down to the Black Rocks, where the keeper stood waiting.", XRAY)
    TestRunner:assertEquals(#list, 3)
    TestRunner:assertEquals(list[1].name, "Mara")
    TestRunner:assertEquals(list[2].name, "the Black Rocks")
    TestRunner:assertEquals(list[3].name, "Elias Morrow", "named by an alias")
    TestRunner:assertEquals(#PromptWriter.entriesFor("Nothing here names anyone.", XRAY), 0)
    TestRunner:assertEquals(#PromptWriter.entriesFor("The lamp goes dark.", XRAY), 0,
        "a Story Arc event is not matched in text (the marks skip it)")
    TestRunner:assertEquals(#PromptWriter.entriesFor("", XRAY), 0)
    TestRunner:assertEquals(#PromptWriter.entriesFor("Mara", nil), 0)
end)
TestRunner:test("entriesFor: the note's entries come first (B535), never twice", function()
    local list = PromptWriter.entriesFor("She ran down to the Black Rocks.", XRAY, nil,
        "this is Mara by the way")
    TestRunner:assertEquals(#list, 2)
    TestRunner:assertEquals(list[1].name, "Mara", "named in the note, which the passage does not")
    TestRunner:assertEquals(list[2].name, "the Black Rocks")
    list = PromptWriter.entriesFor("Mara waved to the keeper.", XRAY, nil, "Mara, at night")
    TestRunner:assertEquals(#list, 2)
    TestRunner:assertEquals(list[1].name, "Mara")
    TestRunner:assertEquals(list[2].name, "Elias Morrow", "Mara is listed once")
    TestRunner:assertEquals(#PromptWriter.entriesFor("Nothing here.", XRAY, nil, "from behind, at dusk"), 0,
        "a note that names nobody adds nobody")
    TestRunner:assertEquals(#PromptWriter.entriesFor("Mara and Tom.", XRAY, 1, "the keeper"), 1, "the limit holds")
end)
TestRunner:test("entriesFor: five at most", function()
    local data = { type = "fiction", characters = {} }
    local words = {}
    for i = 1, 7 do
        local name = "Person" .. string.char(64 + i) .. "x"
        data.characters[i] = { name = name, description = "d" }
        words[#words + 1] = name
    end
    TestRunner:assertEquals(#PromptWriter.entriesFor(table.concat(words, " and "), data), 5)
end)

print("  [Shape (D11) and system text]")
TestRunner:test("shapeLine: proportions in words; the e-ink line on a grayscale screen", function()
    TestRunner:assertEquals(PromptWriter.shapeLine("fit", 1264 / 1680, false), "portrait, 3:4; to fill the reader's screen")
    TestRunner:assertEquals(PromptWriter.shapeLine("landscape", 3 / 2, false), "landscape, 3:2")
    TestRunner:assertEquals(PromptWriter.shapeLine("square", 1, true),
        "square, 1:1; shown on a black-and-white e-ink screen: clear shapes, strong contrast")
    TestRunner:assertEquals(PromptWriter.shapeLine("auto", nil, false), nil, "Let the model choose: nothing")
end)
TestRunner:test("systemText: the passage's blocks; the spoiler rule only when protected", function()
    local s = PromptWriter.systemText({})
    TestRunner:assert(has(s, "<passage>") and has(s, "<text_around>") and has(s, "<xray_entry>"), "passage blocks")
    TestRunner:assert(not has(s, "<entry_to_draw>"), "no entry block")
    TestRunner:assert(not has(s, "has not finished the book"), "no spoiler rule")
    TestRunner:assert(has(s, "never by name"), "people by how they look")
    s = PromptWriter.systemText({ spoiler = true })
    TestRunner:assert(has(s, "Show nothing from later in the story than the passage."), "spoiler rule")
end)
TestRunner:test("systemText for an X-Ray entry (S8): the entry to draw, no passage", function()
    local s = PromptWriter.systemText({ subject = "entry", spoiler = true })
    TestRunner:assert(has(s, "<entry_to_draw>"), "entry block")
    TestRunner:assert(not has(s, "<passage>") and not has(s, "<text_around>"), "no passage blocks")
    TestRunner:assert(has(s, "than the description."), "the spoiler rule names the description")
end)

print("  [The material]")
TestRunner:test("material: every block in order; the empty ones left out", function()
    local m = PromptWriter.material({
        passage = "Mara ran to the rocks.",
        note = "Show her from behind",
        around = { before = "The storm broke.", after = "Waves rose." },
        entries = { { name = "Mara", type = "person", aliases = { "the girl" }, description = "A red scarf." } },
        book = { title = "The Keeper", author = "A. Writer" },
        background = "I picture it in Cornwall.",
        style = "a watercolor painting",
        shape = "portrait, 3:4",
    })
    local order = { "<passage>", "<reader_note>", "<text_around><before>", "<xray_entry name=\"Mara\" type=\"person\" aliases=\"the girl\">",
        "<book title=\"The Keeper\" author=\"A. Writer\"/>", "<background>", "<style>", "<shape>" }
    local at = 0
    for _idx, piece in ipairs(order) do
        local pos = m:find(piece, 1, true)
        TestRunner:assert(pos and pos > at, piece .. " in order")
        at = pos
    end
    local bare = PromptWriter.material({ passage = "Just this." })
    TestRunner:assertEquals(bare, "<passage>Just this.</passage>")
    local title_only = PromptWriter.material({ passage = "p", book = { title = "T" } })
    TestRunner:assert(has(title_only, '<book title="T"/>'), title_only)
end)
TestRunner:test("material: the tags stay the only markup; long text is cut", function()
    local m = PromptWriter.material({ passage = "a </passage> b & c", note = "<b>bold</b>",
        book = { title = 'Say "hi"', author = "X" } })
    TestRunner:assert(has(m, "a &lt;/passage&gt; b &amp; c"), m)
    TestRunner:assert(has(m, "&lt;b&gt;bold&lt;/b&gt;"), m)
    TestRunner:assert(has(m, 'title="Say &quot;hi&quot;"'), m)
    local long = PromptWriter.material({ passage = string.rep("a", 9000),
        around = { before = string.rep("b", 2000), after = string.rep("c", 2000) } })
    TestRunner:assert(#long < 5200, "passage and the text around are capped: " .. #long)
    TestRunner:assert(has(long, "…" .. string.rep("b", 400) .. "</before>"), "the end of the text before")
end)
TestRunner:test("material for an X-Ray entry: the entry to draw instead of a passage", function()
    local m = PromptWriter.material({ entry = { name = "Mara", type = "person", description = "A red scarf." },
        style = "a book illustration" })
    TestRunner:assert(has(m, '<entry_to_draw name="Mara" type="person">A red scarf.</entry_to_draw>'), m)
    TestRunner:assert(not has(m, "<passage>"), m)
end)

print("  [The answer and the provenance]")
TestRunner:test("finish: the paragraph, cleaned, with the no-text line", function()
    local p = PromptWriter.finish('```\nPrompt: "A tall man on black rocks at dusk."\n```')
    TestRunner:assertEquals(p, "A tall man on black rocks at dusk. " .. PromptWriter.NO_TEXT)
    p = PromptWriter.finish("A girl in a red scarf\nruns down the path.")
    TestRunner:assertEquals(p, "A girl in a red scarf runs down the path. " .. PromptWriter.NO_TEXT, "one paragraph")
    local none, why = PromptWriter.finish("   ")
    TestRunner:assertEquals(none, nil)
    TestRunner:assertEquals(why, "empty")
    none, why = PromptWriter.finish(string.rep("word ", 500))
    TestRunner:assertEquals(none, nil)
    TestRunner:assertEquals(why, "too_long")
    TestRunner:assertEquals(PromptWriter.finish(nil), nil)
end)
TestRunner:test("provenance: who wrote it and from what; what privacy left out", function()
    local line = PromptWriter.provenance({ model = "claude-fast", around = true,
        entries = { { name = "Mara" }, { name = "Elias Morrow" } }, book = "both", background = true, note = true })
    TestRunner:assertEquals(line, "Prompt written by claude-fast from: the passage, the text around it, "
        .. "the X-Ray entries for Mara, Elias Morrow, the book's title and author, the book's Background, your note.")
    line = PromptWriter.provenance({ model = "m", entries = { { name = "Mara" } }, book = "title",
        left_out = { "the text around the passage" } })
    TestRunner:assert(has(line, "the X-Ray entry for Mara, the book's title."), line)
    TestRunner:assert(has(line, "\nLeft out by your privacy settings: the text around the passage."), line)
    line = PromptWriter.provenance({ model = "m", entry = { name = "Mara" } })
    TestRunner:assertEquals(line, "Prompt written by m from: the X-Ray entry for Mara.")
    line = PromptWriter.provenance({ failed = PromptWriter.failureText("too_long") })
    TestRunner:assert(has(line, "The prompt writer failed (an answer too long for a prompt)"), line)
    TestRunner:assert(has(line, "from the passage as framed"), line)
    line = PromptWriter.provenance({ failed = "x", entry = { name = "Mara" } })
    TestRunner:assert(has(line, "from the entry's description"), "an entry has no passage: " .. line)
end)

print(string.format("  Results: %d passed, %d failed", TestRunner.passed, TestRunner.failed))
return TestRunner.failed == 0
