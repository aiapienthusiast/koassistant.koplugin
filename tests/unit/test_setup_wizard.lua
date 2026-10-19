-- Unit tests for koassistant/ui/setup_wizard.lua pure helpers (2026-08-11).
--
-- The wizard's UI steps are device-tested; these pin the decision logic the
-- steps stand on: the font install dir rule (maintainer 2026-08-11: the user
-- koreader folder everywhere, desktop the lone exception), the
-- font_ui_fallbacks append semantics (position 1, cap 4, never evict, never
-- duplicate), and the completer probes (respect what is already set).
-- No API calls.
--
-- Run: lua tests/run_tests.lua --unit   (or: lua tests/unit/test_setup_wizard.lua)

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

    return plugin_dir, tests_dir
end

setupPaths()

require("mock_koreader")

local SetupWizard = require("koassistant.ui.setup_wizard")

local TestRunner = {
    passed = 0,
    failed = 0,
    current_suite = "",
}

function TestRunner:suite(name)
    self.current_suite = name
    print(string.format("\n  [%s]", name))
end

function TestRunner:test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        self.passed = self.passed + 1
        print(string.format("    \226\156\147 %s", name))
    else
        self.failed = self.failed + 1
        print(string.format("    \226\156\151 %s", name))
        print(string.format("      Error: %s", tostring(err)))
    end
end

function TestRunner:assertEqual(actual, expected, msg)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", msg or "Assertion failed",
            tostring(expected), tostring(actual)))
    end
end

function TestRunner:assertTrue(value, msg)
    if not value then
        error(string.format("%s: expected true", msg or "Assertion failed"))
    end
end

function TestRunner:assertFalse(value, msg)
    if value then
        error(string.format("%s: expected false/nil, got %s",
            msg or "Assertion failed", tostring(value)))
    end
end

function TestRunner:summary()
    print("")
    print(string.rep("-", 50))
    local total = self.passed + self.failed
    if self.failed == 0 then
        print(string.format("  All %d tests passed!", total))
    else
        print(string.format("  %d/%d tests passed, %d failed", self.passed, total, self.failed))
    end
    return self.failed == 0
end

print("\nSetup wizard pure helpers")

--=== resolveFontDir ===--

TestRunner:suite("resolveFontDir — the koreader folder everywhere, desktop excepted")

TestRunner:test("e-ink (non-desktop): data_dir/fonts", function()
    local dir = SetupWizard.resolveFontDir({
        is_desktop = false, data_dir = ".", user_font_path = nil,
    })
    TestRunner:assertEqual(dir, "./fonts")
end)

TestRunner:test("android (non-desktop, external-storage data dir): data_dir/fonts", function()
    local dir = SetupWizard.resolveFontDir({
        is_desktop = false, data_dir = "/sdcard/koreader",
        user_font_path = "/sdcard/fonts;/sdcard/koreader/fonts",
    })
    TestRunner:assertEqual(dir, "/sdcard/koreader/fonts")
end)

TestRunner:test("desktop: first getPath() entry wins", function()
    local dir = SetupWizard.resolveFontDir({
        is_desktop = true,
        data_dir = "/Users/x/Library/Application Support/koreader",
        user_font_path = "/Users/x/Library/fonts;/Library/fonts",
    })
    TestRunner:assertEqual(dir, "/Users/x/Library/fonts")
end)

TestRunner:test("desktop with nil getPath(): falls back to data_dir/fonts", function()
    local dir = SetupWizard.resolveFontDir({
        is_desktop = true, data_dir = "/home/x/.config/koreader",
        user_font_path = nil,
    })
    TestRunner:assertEqual(dir, "/home/x/.config/koreader/fonts")
end)

TestRunner:test("desktop with empty getPath(): falls back to data_dir/fonts", function()
    local dir = SetupWizard.resolveFontDir({
        is_desktop = true, data_dir = "/d", user_font_path = "",
    })
    TestRunner:assertEqual(dir, "/d/fonts")
end)

--=== appendFallback ===--

TestRunner:suite("appendFallback — position 1, cap, dedupe, no mutation")

TestRunner:test("nil list: creates one-entry list", function()
    local list = SetupWizard.appendFallback(nil, "/f/NotoEmoji-Regular.ttf", 4)
    TestRunner:assertEqual(#list, 1)
    TestRunner:assertEqual(list[1], "/f/NotoEmoji-Regular.ttf")
end)

TestRunner:test("inserts at position 1, preserves existing order, input unmutated", function()
    local existing = { "/a/NotoSansHebrew-Regular.ttf", "/b/NotoSansThai-Regular.ttf" }
    local list = SetupWizard.appendFallback(existing, "/f/NotoEmoji-Regular.ttf", 4)
    TestRunner:assertEqual(#list, 3)
    TestRunner:assertEqual(list[1], "/f/NotoEmoji-Regular.ttf")
    TestRunner:assertEqual(list[2], "/a/NotoSansHebrew-Regular.ttf")
    TestRunner:assertEqual(list[3], "/b/NotoSansThai-Regular.ttf")
    TestRunner:assertEqual(#existing, 2, "input list must not be mutated")
end)

TestRunner:test("same basename in another dir: nil + 'present'", function()
    local list, reason = SetupWizard.appendFallback(
        { "/elsewhere/NotoEmoji-Regular.ttf" }, "/f/NotoEmoji-Regular.ttf", 4)
    TestRunner:assertFalse(list)
    TestRunner:assertEqual(reason, "present")
end)

TestRunner:test("full list (cap 4): nil + 'cap', never evicts", function()
    local four = { "/1/a.ttf", "/2/b.ttf", "/3/c.ttf", "/4/d.ttf" }
    local list, reason = SetupWizard.appendFallback(four, "/f/NotoEmoji-Regular.ttf", 4)
    TestRunner:assertFalse(list)
    TestRunner:assertEqual(reason, "cap")
    TestRunner:assertEqual(#four, 4)
end)

TestRunner:test("findEmojiFallback: matches by basename, nil when absent", function()
    TestRunner:assertEqual(
        SetupWizard.findEmojiFallback({ "/x/a.ttf", "/y/NotoEmoji-Regular.ttf" }),
        "/y/NotoEmoji-Regular.ttf")
    TestRunner:assertFalse(SetupWizard.findEmojiFallback({ "/x/a.ttf" }))
    TestRunner:assertFalse(SetupWizard.findEmojiFallback(nil))
end)

--=== probes ===--

TestRunner:suite("completer probes — respect what is already set")

TestRunner:test("language: unset / new format / legacy format", function()
    TestRunner:assertFalse(SetupWizard.probeLanguageF({}))
    local ok, detail = SetupWizard.probeLanguageF({ interaction_languages = { "German" } })
    TestRunner:assertTrue(ok)
    TestRunner:assertEqual(detail, "German")
    TestRunner:assertFalse(SetupWizard.probeLanguageF({ user_languages = "" }))
    TestRunner:assertTrue(SetupWizard.probeLanguageF({ user_languages = "Arabic" }))
end)

TestRunner:test("privacy: nil keys = untouched; explicit false IS a decision", function()
    TestRunner:assertFalse(SetupWizard.probePrivacyF({}))
    TestRunner:assertTrue(SetupWizard.probePrivacyF({ enable_basic_stats = false }))
    TestRunner:assertTrue(SetupWizard.probePrivacyF({ enable_book_text_extraction = true }))
    TestRunner:assertFalse(SetupWizard.probePrivacyF({ unrelated_key = true }))
end)

local function fakePlaceholder(key)
    return key == "" or key:find("YOUR_", 1, true) ~= nil
end

TestRunner:test("provider: placeholder-only keys do not count", function()
    TestRunner:assertFalse(SetupWizard.probeProviderF(
        { anthropic = "YOUR_KEY" }, { openai = "YOUR_OPENAI_KEY" }, false, fakePlaceholder))
end)

TestRunner:test("provider: GUI key / file key / oauth each satisfy", function()
    TestRunner:assertTrue(SetupWizard.probeProviderF(
        { anthropic = "sk-real" }, nil, false, fakePlaceholder))
    TestRunner:assertTrue(SetupWizard.probeProviderF(
        nil, { gemini = "AIza-real" }, false, fakePlaceholder))
    TestRunner:assertTrue(SetupWizard.probeProviderF(nil, nil, true, fakePlaceholder))
    TestRunner:assertFalse(SetupWizard.probeProviderF(nil, nil, false, fakePlaceholder))
end)

TestRunner:test("scanGestures: finds koassistant bindings in both sections", function()
    local count, first = SetupWizard.scanGestures({
        gesture_reader = {
            tap_right_bottom_corner = { koassistant_quick_actions = true },
        },
        gesture_fm = {
            tap_left_bottom_corner = { koassistant_ai_settings = true, settings = { order = {} } },
        },
    })
    TestRunner:assertEqual(count, 2)
    TestRunner:assertTrue(first ~= nil)
end)

TestRunner:test("scanGestures: foreign actions and settings subtables ignored", function()
    local count = SetupWizard.scanGestures({
        gesture_reader = {
            tap_right_bottom_corner = { toggle_frontlight = true },
            tap_left_bottom_corner = { settings = { order = {} } },
        },
    })
    TestRunner:assertEqual(count, 0)
    TestRunner:assertEqual(SetupWizard.scanGestures({}), 0)
    TestRunner:assertEqual(SetupWizard.scanGestures(nil), 0)
end)

TestRunner:test("slotState: nil/empty free, entries counted without 'settings'", function()
    TestRunner:assertEqual(SetupWizard.slotState(nil), "free")
    TestRunner:assertEqual(SetupWizard.slotState({}), "free")
    local state, n = SetupWizard.slotState({ toggle_frontlight = true })
    TestRunner:assertEqual(state, "taken")
    TestRunner:assertEqual(n, 1)
    local state2, n2 = SetupWizard.slotState({ a = true, b = true, settings = { order = {} } })
    TestRunner:assertEqual(state2, "taken")
    TestRunner:assertEqual(n2, 2)
end)

--=== static tables ===--

TestRunner:suite("static tables")

TestRunner:test("provider choices: unique non-empty ids", function()
    local seen = {}
    for _idx, choice in ipairs(SetupWizard.PROVIDER_CHOICES) do
        TestRunner:assertTrue(type(choice.id) == "string" and choice.id ~= "")
        TestRunner:assertFalse(seen[choice.id], "duplicate provider id " .. choice.id)
        seen[choice.id] = true
    end
    TestRunner:assertTrue(seen.anthropic and seen.openai and seen.ollama)
end)

TestRunner:suite("the two faces (2026-10-19)")

TestRunner:test("baseVersion drops the -dev suffix", function()
    TestRunner:assertEqual(SetupWizard.baseVersion("0.24.0-dev"), "0.24.0")
    TestRunner:assertEqual(SetupWizard.baseVersion("0.24.0"), "0.24.0")
    TestRunner:assertEqual(SetupWizard.baseVersion(nil), "")
end)

TestRunner:test("faceFor: fresh, the update check once per listed release, else none", function()
    local steps = { ["0.24.0"] = { "privacy" } }
    TestRunner:assertEqual(SetupWizard.faceFor(false, false, nil, "0.24.0-dev", steps), "fresh", "nothing set up")
    TestRunner:assertEqual(SetupWizard.faceFor(true, false, nil, "0.24.0", steps), "update", "the old wizard's completion, no stamp")
    TestRunner:assertEqual(SetupWizard.faceFor(false, true, nil, "0.24.0", steps), "update", "a provider set up without any wizard")
    TestRunner:assertEqual(SetupWizard.faceFor(true, true, "0.24.0", "0.24.0-dev", steps), "none", "stamped: once per release")
    TestRunner:assertEqual(SetupWizard.faceFor(true, true, "0.23.0", "0.25.0", steps), "none", "a release without update steps")
    TestRunner:assertEqual(SetupWizard.faceFor(true, true, "0.23.0", "0.24.0", {}), "none", "no steps at all")
    TestRunner:assertEqual(#(SetupWizard.UPDATE_STEPS["0.24.0"] or {}), 3, "this release lists three steps")
end)

TestRunner:test("iconsPlan: by the icons and the font", function()
    TestRunner:assertEqual(SetupWizard.iconsPlan(false, "missing"), "offer")
    TestRunner:assertEqual(SetupWizard.iconsPlan(false, "installed"), "offer")
    TestRunner:assertEqual(SetupWizard.iconsPlan(true, "installed"), "test")
    TestRunner:assertEqual(SetupWizard.iconsPlan(true, "restart"), "restart")
    TestRunner:assertEqual(SetupWizard.iconsPlan(true, "missing"), "install")
end)

TestRunner:test("shouldRun: the update check runs the listed steps forced and the unset ones", function()
    local upd = { update = true, only = { privacy = true } }
    local run, forced = SetupWizard.shouldRun("privacy", upd, true)
    TestRunner:assertTrue(run and forced, "listed: forced")
    run, forced = SetupWizard.shouldRun("provider", upd, false)
    TestRunner:assertTrue(run and not forced, "not set: runs on its own probe")
    run = SetupWizard.shouldRun("language", upd, true)
    TestRunner:assertFalse(run, "set and unlisted: skipped")
    run = SetupWizard.shouldRun("welcome", upd, false)
    TestRunner:assertFalse(run, "the welcome is the fresh face's")
    run = SetupWizard.shouldRun("finish", upd, false)
    TestRunner:assertTrue(run, "finish always")
    run, forced = SetupWizard.shouldRun("privacy", { force = true }, true)
    TestRunner:assertTrue(run and forced, "a forced chain")
    run, forced = SetupWizard.shouldRun("privacy", {}, true)
    TestRunner:assertTrue(run and not forced, "the fresh chain: the step decides")
end)

--=== the Emoji Font row (B397) ===--

TestRunner:suite("fontState / fontRowLabel — the Emoji Font row in Settings")

TestRunner:test("not registered: missing", function()
    TestRunner:assertEqual(SetupWizard.fontState(nil, false, false), "missing")
end)

TestRunner:test("registered but the file is gone: missing (the install copies it again)", function()
    TestRunner:assertEqual(SetupWizard.fontState("/fonts/NotoEmoji-Regular.ttf", false, false), "missing")
end)

TestRunner:test("registered, present, not loaded yet: restart", function()
    TestRunner:assertEqual(SetupWizard.fontState("/fonts/NotoEmoji-Regular.ttf", true, false), "restart")
end)

TestRunner:test("registered, present, loaded: installed", function()
    TestRunner:assertEqual(SetupWizard.fontState("/fonts/NotoEmoji-Regular.ttf", true, true), "installed")
end)

TestRunner:test("every state has its own label, all under the static head", function()
    local seen = {}
    for _idx, state in ipairs({ "missing", "restart", "installed" }) do
        local label = SetupWizard.fontRowLabel(state)
        TestRunner:assertTrue(label:find("^Emoji Font: ") ~= nil, state .. " label starts with the head")
        TestRunner:assertFalse(seen[label], "label reused for " .. state)
        seen[label] = true
    end
end)

return TestRunner:summary()
