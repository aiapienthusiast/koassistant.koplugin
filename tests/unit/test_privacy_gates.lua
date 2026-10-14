-- koassistant/request/privacy_gates.lua: the one place that decides whether a
-- kind of the reader's data may go into a request (data_access_picture.md 4.5,
-- slice 1). A table of layers against expected states, the stamp reader, the
-- dispatch provider's precedence, and the guard: no other file compares a
-- privacy switch or walks trusted_providers itself (`-- raw-gate: <reason>`
-- escapes a display-only read).
--
-- Run: lua tests/unit/test_privacy_gates.lua  (or lua tests/run_tests.lua --unit)

local function setupPaths()
    local info = debug.getinfo(1, "S")
    local script_path = info.source:match("@?(.*)")
    local unit_dir = script_path:match("(.+)/[^/]+$") or "."
    local tests_dir = unit_dir:match("(.+)/[^/]+$") or "."
    local plugin_dir = tests_dir:match("(.+)/[^/]+$") or "."
    package.path = table.concat({
        plugin_dir .. "/?.lua",
        tests_dir .. "/?.lua",
        tests_dir .. "/lib/?.lua",
        package.path,
    }, ";")
    return plugin_dir
end
local plugin_dir = setupPaths()
require("mock_koreader")
local TestRunner = require("test_runner"):new()
local Gates = require("koassistant.request.privacy_gates")

local function eq(got, want, msg)
    TestRunner:assertTrue(got == want, (msg or "") .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

print("\n  [the layers]")

TestRunner:test("nothing set: every kind is off except reading position, which is on", function()
    for _idx, kind in ipairs(Gates.KINDS) do
        local state, layer = Gates.resolve(kind, { features = {}, provider = "openai" })
        if kind == "position" or kind == "nearby_text" then
            eq(state, "allow", kind)
        else
            eq(state, "off", kind)
        end
        eq(layer, "global", kind .. " layer")
    end
end)

TestRunner:test("each global switch allows its kind, and only its kind", function()
    for kind, key in pairs(Gates.GLOBAL_KEY) do
        local f = { [key] = true }
        eq(Gates.resolve(kind, { features = f, provider = "openai" }), "allow", key)
        for _idx, other in ipairs(Gates.KINDS) do
            if other ~= kind and other ~= "position" and other ~= "nearby_text"
                    and not (kind == "annotations" and other == "highlights") then
                eq(Gates.resolve(other, { features = f, provider = "openai" }), "off", key .. " leaves " .. other)
            end
        end
    end
end)

TestRunner:test("allowing notes allows highlights; reading position is off only when false", function()
    eq(Gates.resolve("highlights", { features = { enable_annotations_sharing = true } }), "allow", "pairing")
    eq(Gates.resolve("annotations", { features = { enable_highlights_sharing = true } }), "off", "not the reverse")
    eq(Gates.resolve("position", { features = { enable_basic_stats = false } }), "off", "position off")
    eq(Gates.resolve("position", { features = { enable_basic_stats = "no" } }), "allow", "anything but false is on")
end)

TestRunner:test("a trusted provider counts every switch as on, nearby text aside", function()
    local f = { trusted_providers = { "ollama" } }
    for _idx, kind in ipairs(Gates.KINDS) do
        local state, layer = Gates.resolve(kind, { features = f, provider = "ollama" })
        eq(state, "allow", kind)
        eq(layer, kind == "nearby_text" and "global" or "trusted", kind .. " layer")
    end
    eq(Gates.resolve("book_text", { features = f, provider = "openai" }), "off", "another provider")
    eq(Gates.resolve("book_text", { features = f }), "off", "no provider")
    TestRunner:assertFalse(Gates.isTrusted({ trusted_providers = "ollama" }, "ollama"), "a list, never a string")
    TestRunner:assertFalse(Gates.isTrusted(nil, "ollama"), "no features")
end)

TestRunner:test("the book's own value wins both ways: a deny beats trust, an allow needs no switch", function()
    local f = { trusted_providers = { "ollama" }, enable_book_text_extraction = true }
    local state, layer = Gates.resolve("book_text", { features = f, provider = "ollama", book = { book_text = false } })
    eq(state, "never", "deny"); eq(layer, "book", "deny layer")
    state, layer = Gates.resolve("notebook", { features = {}, provider = "openai", book = { notebook = true } })
    eq(state, "allow", "allow"); eq(layer, "book", "allow layer")
    eq(Gates.resolve("highlights", { features = f, provider = "ollama", book = { notebook = false } }), "allow",
        "another kind's deny is not this kind's")
    TestRunner:assertTrue(Gates.allows("notebook", { features = {}, book = { notebook = true } }), "allows: yes")
    TestRunner:assertFalse(Gates.allows("notebook", { features = { enable_notebook_sharing = true }, book = { notebook = false } }), "allows: no")
    TestRunner:assertFalse(Gates.allows("notebook", nil), "no context: off")
end)

TestRunner:test("summary lists every kind with its state and layer", function()
    local s = Gates.summary({ features = { enable_notebook_sharing = true }, provider = "openai", book = { book_text = false } })
    local n = 0
    for _idx, kind in ipairs(Gates.KINDS) do
        TestRunner:assertTrue(s[kind] and s[kind].state and s[kind].layer, kind .. " present")
        n = n + 1
    end
    eq(n, #Gates.KINDS, "count")
    eq(s.notebook.state, "allow", "notebook"); eq(s.book_text.state, "never", "text"); eq(s.book_text.layer, "book", "text layer")
end)

print("\n  [the stamps]")

TestRunner:test("stampedKinds: legacy means text; the old annotations stamp meant highlights", function()
    local k = Gates.stampedKinds({})
    TestRunner:assertTrue(k.book_text and not k.highlights and not k.annotations, "no stamps: text only")
    k = Gates.stampedKinds({ used_book_text = false })
    TestRunner:assertFalse(k.book_text, "built without text")
    k = Gates.stampedKinds({ used_annotations = true })
    TestRunner:assertTrue(k.highlights and not k.annotations, "legacy annotations stamp = highlights")
    k = Gates.stampedKinds({ used_highlights = true, used_annotations = true })
    TestRunner:assertTrue(k.highlights and k.annotations, "both tracked")
    k = Gates.stampedKinds({ used_highlights = false, used_annotations = true })
    TestRunner:assertTrue(not k.highlights and k.annotations, "notes without highlights")
    TestRunner:assertTrue(Gates.stampedKinds(nil).book_text, "nil entry: legacy")
end)

print("\n  [the dispatch provider]")

TestRunner:test("precedence: a run option's model, the action's pin, a pending pick, the Quick preset, the base", function()
    local quick = function(features, base) return { provider = "groq", model = "fast" } end
    local act = { accept_quick_answer = true }
    eq(Gates.dispatchProvider({ _run_variant = { provider = "xai" }, _session_model = { provider = "mistral" } }, act, "openai", quick),
        "xai", "run option first")
    eq(Gates.dispatchProvider({ _session_model = { provider = "mistral" } }, { provider = "deepseek" }, "deepseek", quick),
        "deepseek", "a pinned action keeps its base")
    eq(Gates.dispatchProvider({ _session_model = { provider = "mistral" }, _session_quick_answer = true }, act, "openai", quick),
        "mistral", "a pending pick beats the Quick preset")
    eq(Gates.dispatchProvider({ _session_quick_answer = true }, act, "openai", quick), "groq", "the Quick preset's model")
    eq(Gates.dispatchProvider({ _session_quick_answer = true }, {}, "openai", quick), "openai",
        "Quick only for an action that accepts it")
    eq(Gates.dispatchProvider({ _quick_answer_active = true }, act, "openai", function() return nil end), "openai",
        "no preset model: the base")
    eq(Gates.dispatchProvider({ use_action_tiers = false }, { model_tier = "fast" }, "openai", quick), "openai",
        "tier hints off: the base")
    eq(Gates.dispatchProvider(nil, nil, "openai", quick), "openai", "nothing: the base")
end)

print("\n  [the book helpers]")

TestRunner:test("overridesOf and bookOverrides never throw and read as none when nothing is known", function()
    TestRunner:assertTrue(Gates.overridesOf(nil) == nil, "no settings")
    TestRunner:assertTrue(Gates.overridesOf(42) == nil, "not a settings object")
    TestRunner:assertTrue(Gates.bookOverrides("/nowhere/such.epub", nil) == nil, "no such book")
end)

print("\n  [the guard]")

TestRunner:test("no other file compares a privacy switch or walks trusted_providers itself", function()
    local keys = { "enable_book_text_extraction", "enable_highlights_sharing", "enable_annotations_sharing",
        "enable_notebook_sharing", "enable_basic_stats", "enable_advanced_stats", "enable_library_scanning" }
    local p = io.popen('cd "' .. plugin_dir .. '" && ls main.lua && find koassistant -name "*.lua" | LC_ALL=C sort')
    local files = {}
    for line in p:lines() do files[#files + 1] = line end
    p:close()
    TestRunner:assertTrue(#files > 100, "the tree was listed")
    local hits = {}
    for _idx, rel in ipairs(files) do
        if rel ~= "koassistant/request/privacy_gates.lua" then
            local n = 0
            for line in io.lines(plugin_dir .. "/" .. rel) do
                n = n + 1
                if not line:find("-- raw-gate:", 1, true) and not line:match("^%s*%-%-") then
                    local bad = line:find("ipairs%([^)]*trusted_providers")
                    for _k, key in ipairs(keys) do
                        if line:find(key .. "%s*[=~]=%s*true") or line:find(key .. "%s*[=~]=%s*false") then
                            bad = true
                        end
                    end
                    if bad then hits[#hits + 1] = rel .. ":" .. n .. ": " .. line:gsub("^%s+", "") end
                end
            end
        end
    end
    TestRunner:assertTrue(#hits == 0, "raw gate reads:\n      " .. table.concat(hits, "\n      "))
end)

return TestRunner:summary()
