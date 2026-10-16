--[[
Unit tests: koassistant/ui/data_access.lua's pure helpers (B395 slice 5) and the
attachments' stamps.

- carriedKinds: the kinds a request's context carried, from message_data
- stampsFromKinds: a chat's record as an artifact's (a pin's) stamps
- resumeNeeds: what a resumed chat needs (Never refuses, another provider asks the
  Ask kinds, the same provider passes, legacy chats pass)
- sendableMessages: the saved context messages left out after "Continue without
  the stored context"
- needsFor: a kinds list mixing required and optional kinds; a set of books, each
  with its own kinds
- makeArtifact / makePinned carry their book and stamps; artifactAllowed and
  forProvider judge them for the provider

Run: lua tests/run_tests.lua --unit
]]

local function setupPaths()
    local info = debug.getinfo(1, "S")
    local script_path = info.source:match("@?(.*)")
    local unit_dir = script_path:match("(.+)/[^/]+$") or "."
    local tests_dir = unit_dir:match("(.+)/[^/]+$") or "."
    local plugin_dir = tests_dir:match("(.+)/[^/]+$") or "."
    package.path = table.concat({
        plugin_dir .. "/?.lua",
        plugin_dir .. "/?/init.lua",
        tests_dir .. "/?.lua",
        tests_dir .. "/lib/?.lua",
        package.path,
    }, ";")
end
setupPaths()
require("mock_koreader")

local TestRunner = require("test_runner"):new()
local DataAccess = require("koassistant.ui.data_access")
local Gates = require("koassistant.request.privacy_gates")
local A = require("koassistant.request.attachments")
local SDS = require("koassistant.storage.doc_settings")
local UIManager = require("ui/uimanager")
local saved = { resolve = SDS.resolve, show = UIManager.show }
SDS.resolve = function() return nil end  -- no book values in these tests
local shown = {}
UIManager.show = function(_self, w) shown[#shown + 1] = w end

print("Running: test_data_access")
print("")
print("  [the chat's record]")

TestRunner:test("carriedKinds lists what the gather put in the request, in KINDS order", function()
    TestRunner:assertEqual(DataAccess.carriedKinds({}), nil, "nothing of the reader's: no record")
    local k = DataAccess.carriedKinds({ highlights = "h", book_text = "t", library_content = "l",
        stats_groups = { deep = {} }, surrounding_context = "s" })
    TestRunner:assertEqual(table.concat(k, ","), "book_text,highlights,habits,book_list,nearby_text")
    k = DataAccess.carriedKinds({ cached_used_book_text = true, _inherited_stamps = { annotations = true } })
    TestRunner:assertEqual(table.concat(k, ","), "book_text,annotations", "stored material read along counts")
    TestRunner:assertEqual(DataAccess.carriedKinds({ highlights = "" }), nil, "an empty section is nothing")
end)

TestRunner:test("stampsFromKinds: a record as an artifact's stamps; nothing recorded is text-free", function()
    local s = DataAccess.stampsFromKinds({ "book_text", "notebook" })
    TestRunner:assertEqual(s.used_book_text, true)
    TestRunner:assertEqual(s.used_notebook, true)
    TestRunner:assertEqual(s.used_highlights, false)
    TestRunner:assertEqual(DataAccess.stampsFromKinds(nil).used_book_text, false)
    TestRunner:assertEqual(Gates.stampedKinds(DataAccess.stampsFromKinds({ "notebook" })).notebook, true,
        "the gates read the notebook stamp")
end)

print("  [resume]")

TestRunner:test("resumeNeeds: Never refuses, another provider asks the Ask kinds, the same provider passes", function()
    local chat = { data_kinds = { "book_text", "highlights" }, provider = "anthropic" }
    local r = DataAccess.resumeNeeds(chat, {}, "anthropic", "/b/x.epub", nil)
    TestRunner:assertEqual(#r.asked, 0, "the provider that answered has the data")
    TestRunner:assertEqual(r.refused, nil)
    r = DataAccess.resumeNeeds(chat, {}, "openai", "/b/x.epub", nil)
    TestRunner:assertEqual(table.concat(r.asked, ","), "book_text,highlights", "another provider: asked once")
    r = DataAccess.resumeNeeds(chat, { enable_book_text_extraction = "never" }, "anthropic", "/b/x.epub", nil)
    TestRunner:assertEqual(r.refused and r.refused.kind, "book_text", "Never refuses whatever the provider")
    TestRunner:assertEqual(r.refused and r.refused.layer, "global")
    r = DataAccess.resumeNeeds(chat, { trusted_providers = { "ollama" } }, "ollama", "/b/x.epub", nil)
    TestRunner:assertEqual(#r.asked, 0, "a trusted provider's column is Allow by default")
    TestRunner:assertEqual(DataAccess.resumeNeeds({ provider = "openai" }, {}, "anthropic", nil, nil).refused, nil,
        "no record: nothing to check")
    TestRunner:assertEqual(#DataAccess.resumeNeeds({ data_kinds = {} }, {}, "anthropic", nil, nil).asked, 0)
end)

TestRunner:test("sendableMessages drops only the context messages saved with the chat", function()
    local msgs = {
        { role = "user", content = "ctx", is_context = true },
        { role = "user", content = "q" },
        { role = "assistant", content = "a" },
        { role = "user", content = "attached", is_context = true },
    }
    TestRunner:assertEqual(#DataAccess.sendableMessages(msgs, {}), 4, "no choice made: everything")
    local out = DataAccess.sendableMessages(msgs, { _drop_stored_context = 3 })
    TestRunner:assertEqual(#out, 3)
    TestRunner:assertEqual(out[1].content, "q", "the saved context message is out")
    TestRunner:assertEqual(out[3].content, "attached", "a context message added since rides")
end)

print("  [needs]")

TestRunner:test("needsFor: a list may mix required and optional kinds; a set judges each book's own kinds", function()
    local needs = DataAccess.needsFor(nil, { features = {}, provider = "openai",
        kinds = { { kind = "book_text", required = true }, { kind = "highlights", required = false } } })
    TestRunner:assertEqual(needs[1].required, true)
    TestRunner:assertEqual(needs[2].required, false)
    TestRunner:assertEqual(needs[1].state, "ask")
    local set_needs, never_books = DataAccess.needsFor(nil, { features = {}, provider = "openai",
        books = { { file = "/b/1.epub", kinds = { book_text = true } }, { file = "/b/2.epub", kinds = { highlights = true } } } })
    local asked = {}
    for _idx, n in ipairs(set_needs) do asked[n.kind] = n.state end
    TestRunner:assertEqual(asked.book_text, "ask", "the first book's kind")
    TestRunner:assertEqual(asked.highlights, "ask", "the second book's kind")
    TestRunner:assertEqual(never_books, 0)
    local _n2, never2 = DataAccess.needsFor(nil, { features = { enable_book_text_extraction = "never" }, provider = "openai",
        books = { { file = "/b/1.epub", kinds = { book_text = true } } } })
    TestRunner:assertEqual(never2, 1, "a book whose kind is Never is counted")
end)

print("  [attachments carry their stamps]")

TestRunner:test("makeArtifact and makePinned carry the book and the stamps; an old general pin is text-free", function()
    local e = A.makeArtifact("Summary", "summarize_full_document",
        { result = "text", used_book_text = true, used_highlights = false }, "B", nil, "/b/x.epub")
    TestRunner:assertEqual(e.path, "/b/x.epub")
    TestRunner:assertEqual(e.used_book_text, true)
    TestRunner:assertEqual(table.concat(Gates.stampedList(e), ","), "book_text")
    local p = A.makePinned({ result = "r", name = "P", document_path = "/b/x.epub", context_type = "book" })
    TestRunner:assertEqual(Gates.stampedKinds(p).book_text, true, "an old book pin counts as built from text")
    TestRunner:assertEqual(p.path, "/b/x.epub")
    local g = A.makePinned({ result = "r", name = "G", document_path = "__GENERAL_CHATS__", context_type = "general" })
    TestRunner:assertEqual(Gates.stampedKinds(g).book_text, false, "an old general pin sent nothing of a book")
    local n = A.makePinned({ result = "r", name = "N", document_path = "/b/x.epub", context_type = "book",
        used_book_text = false, used_notebook = true })
    TestRunner:assertEqual(table.concat(Gates.stampedList(n), ","), "notebook", "a new pin's record")
end)

TestRunner:test("artifactAllowed and forProvider judge a text-built artifact for the provider", function()
    local e = A.makeArtifact("Summary", "summarize_full_document", { result = "text", used_book_text = true }, "B", nil, "/b/x.epub")
    TestRunner:assertFalse(A.artifactAllowed({}, "openai", e, nil), "Ask: not allowed to send")
    TestRunner:assertTrue(A.artifactAllowed({ enable_book_text_extraction = true }, "openai", e, nil), "Allow")
    TestRunner:assertTrue(A.artifactAllowed({ trusted_providers = { "ollama" } }, "ollama", e, nil), "a trusted provider's column")
    TestRunner:assertTrue(A.artifactAllowed({ _data_once = { book = "/b/x.epub", kinds = { book_text = true } } }, "openai", e, nil),
        "the run's allowance for its book")
    TestRunner:assertFalse(A.artifactAllowed({ _data_once = { book = "/b/other.epub", kinds = { book_text = true } } }, "openai", e, nil),
        "another book's allowance is not this one's")
    TestRunner:assertTrue(A.artifactAllowed({}, "openai", { type = "artifact", used_book_text = false }, nil),
        "no text stamp: nothing to judge")
    shown = {}
    local note = A.makeNote("a note")
    local kept = A.forProvider({ e, note }, {}, "openai", nil)
    TestRunner:assertEqual(#kept, 1, "the artifact is left out")
    TestRunner:assertEqual(kept[1].type, "note")
    TestRunner:assertTrue(#shown == 1 and tostring(shown[1].text):find("attached artifact", 1, true) ~= nil, "a notice says so")
    TestRunner:assertEqual(#A.forProvider({ e, note }, { enable_book_text_extraction = true }, "openai", nil), 2, "Allow: both ride")
end)

-- B395 slice 3 and B500: the Data chip's pure parts, the no-title rule, the
-- tile's words, the presets' names, the group's privacy keys

TestRunner:test("the Data chip lists a chat's kinds with their states and counts the asks", function()
    local DataChip = require("koassistant.ui.data_chip")
    TestRunner:assertEqual(#DataChip.kindsFor("book"), 5, "a book or highlight chat: the five book kinds")
    TestRunner:assertEqual(DataChip.kindsFor("library")[1], "book_list", "a library chat: the book list first")
    local rows, n_ask = DataChip.rows(DataChip.kindsFor("book"),
        { features = { enable_highlights_sharing = true, _chat_data = { never = { notebook = true } } },
          provider = "openai", once = { book_text = true } })
    TestRunner:assertEqual(n_ask, 1, "notes still ask")
    local by = {}
    for _idx, r in ipairs(rows) do by[r.kind] = r end
    TestRunner:assertEqual(by.book_text.layer, "once", "allowed for this chat")
    TestRunner:assertEqual(by.notebook.layer, "chat", "left out of this chat")
    TestRunner:assertEqual(by.nearby_text.state, "allow", "the text around: Allow by default")
    TestRunner:assertEqual(DataChip.label(0, false, false), "Data")
    TestRunner:assertEqual(DataChip.label(2, false, false), "Data: 2 ask")
    TestRunner:assertEqual(DataChip.label(2, true, false), "Data: this chat", "the chat's own choice first")
end)

TestRunner:test("needsTitle: an action with nothing of the book but its title (B500)", function()
    TestRunner:assertTrue(DataAccess.needsTitle({ prompt = 'Tell me about "{title}"{author_clause}.' }, nil),
        "an AI-knowledge book action")
    TestRunner:assertTrue(DataAccess.needsTitle({ template = "book_info" }, nil), "through its template")
    TestRunner:assertFalse(DataAccess.needsTitle({ prompt = 'X-Ray of "{title}"', use_book_text = true }, nil),
        "the text goes")
    TestRunner:assertTrue(DataAccess.needsTitle({ prompt = 'Summarize "{title}"', use_book_text = true }, "ai_knowledge"),
        "the AI-knowledge source sends no text")
    TestRunner:assertFalse(DataAccess.needsTitle({ prompt = 'My notes on "{title}"', use_annotations = true }, nil),
        "the reader's notes go")
    TestRunner:assertFalse(DataAccess.needsTitle({ prompt = "Explain this." }, nil), "no title in the prompt")
end)

TestRunner:test("the tile's words and the presets' names", function()
    TestRunner:assertEqual(DataAccess.shortSummary({ "ask", "ask" }), "Ask")
    TestRunner:assertEqual(DataAccess.shortSummary({ "allow", "allow" }), "Allow")
    TestRunner:assertEqual(DataAccess.shortSummary({ "allow", "ask", "ask", "never" }), "1 allowed, 2 ask, 1 never")
    TestRunner:assertEqual(DataAccess.presetLabel("default"), "Default (Ask)")
    TestRunner:assertEqual(DataAccess.presetLabel(nil), "Custom")
    TestRunner:assertEqual(DataAccess.layerLabel("chat"), "this chat")
end)

TestRunner:test("a group can hold the five privacy values (B395 slice 4)", function()
    local GS = require("koassistant.books.group_settings")
    local BS = require("koassistant.books.book_settings")
    local keys = {}
    for _idx, k in ipairs(GS.keys()) do keys[k] = true end
    for _kind, key in pairs(BS.PRIVACY_KEY_OF_KIND) do
        TestRunner:assertTrue(keys[key], key .. " is a group key")
        TestRunner:assertTrue(GS.keyLabel(key) ~= key, key .. " has a label")
    end
    TestRunner:assertEqual(GS.valueLabel(BS.KEY_TEXT_EXTRACTION, false), "Never")
    TestRunner:assertEqual(GS.valueLabel(BS.KEY_HIGHLIGHTS_SHARING, true), "Allow")
end)

TestRunner:test("the privacy picker's spec: the book holds Allow or Never, all books Ask, Allow or Never", function()
    local BS = require("koassistant.books.book_settings")
    local spec = BS.privacySpec("book_text")
    TestRunner:assertEqual(#spec.book_options, 2)
    TestRunner:assertEqual(#spec.options, 3)
    local f = {}
    spec.set_global(f, "never")
    TestRunner:assertEqual(f.enable_book_text_extraction, "never")
    spec.set_global(f, "allow")
    TestRunner:assertEqual(f.enable_book_text_extraction, true)
    spec.set_global(f, "ask")
    TestRunner:assertEqual(Gates.globalState(f, "book_text"), "ask")
    local notes = BS.privacySpec("annotations")
    local g = {}
    notes.set_global(g, "allow")
    TestRunner:assertEqual(g.enable_highlights_sharing, true, "allowing notes allows highlights")
    local near = BS.privacySpec("nearby_text")
    local h = {}
    near.set_global(h, "never")
    TestRunner:assertEqual(h.nearby_text_sharing, "never", "string-valued")
    TestRunner:assertEqual(BS.privacySpec("position").global({}), true, "position on unless off")
end)

TestRunner:test("a refusal or a Cancel runs the caller's hook; nothing runs", function()
    shown = {}
    local refused, ran = false, false
    local ok = DataAccess.withAccess(nil, nil, {
        features = { enable_book_text_extraction = "never" }, provider = "openai",
        kinds = { "book_text" }, action_name = "X-Ray",
        on_refused = function() refused = true end,
    }, function() ran = true end)
    TestRunner:assertFalse(ok, "refused")
    TestRunner:assertTrue(refused, "the hook ran")
    TestRunner:assertFalse(ran, "the run did not")
end)

SDS.resolve = saved.resolve
UIManager.show = saved.show

return TestRunner:summary()
