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

SDS.resolve = saved.resolve
UIManager.show = saved.show

return TestRunner:summary()
