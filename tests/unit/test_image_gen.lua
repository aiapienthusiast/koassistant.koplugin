--[[
Unit Tests for image generation (PR #96 polish)

Covers:
- ModelLists image-model inventory (getImageModels/getDefaultImageModel)
- BaseHandler.getApiKey / isPlaceholderKey (shared key resolution)
- ImageGenerator.effectiveProvider resolution chain:
  explicit image_gen_provider > image-capable main provider; key required;
  no fallback to merely-keyed providers
- Book-association index (agenda 2b): recordImage/readIndex roundtrip,
  booksWithImages join + stale pruning, removeIndexEntries,
  updateIndexForMove move/delete/copy semantics

Run: lua tests/run_tests.lua --unit
]]

-- Setup test environment
package.path = package.path .. ";./?.lua;./?/init.lua"
require("tests.lib.mock_koreader")

-- luasocket's mime module is not in the shared mock; the image generator only
-- calls it at response time, so a passthrough stub is enough here
package.loaded["mime"] = {
    b64 = function(s) return s end,
    unb64 = function(s) return s end,
}

local ModelLists = require("koassistant.request.model_lists")
local BaseHandler = require("koassistant.api.base")
local ImageGenerator = require("koassistant.images.image_generator")

-- Test suite
local TestRunner = {
    passed = 0,
    failed = 0,
}

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

function TestRunner:assert(condition, message)
    if not condition then
        error(message or "Assertion failed", 2)
    end
end

function TestRunner:assertEquals(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s\n  expected: %s\n  actual:   %s",
            message or "Values not equal",
            tostring(expected), tostring(actual)), 2)
    end
end

-- Helpers -------------------------------------------------------------------

local function mockSettings(features)
    return {
        readSetting = function(_self, key)
            if key == "features" then return features end
            return nil
        end,
    }
end

local function withApikeys(keys, fn)
    local prev = package.loaded["apikeys"]
    package.loaded["apikeys"] = keys
    local ok, err = pcall(fn)
    package.loaded["apikeys"] = prev
    if not ok then error(err, 0) end
end

-- Index test helpers ---------------------------------------------------------
-- The index helpers lazily require("luasettings") per call, so an in-memory
-- mock can be swapped in around each test. Image files are real files under
-- the mock datastorage dir (booksWithImages joins index against directory).

local IMAGES_DIR = "/tmp/koreader/koassistant_images"

local index_store  -- in-memory backing for the mocked LuaSettings

local MockLuaSettings = {
    open = function(_self, path)
        index_store[path] = index_store[path] or {}
        local data = index_store[path]
        return {
            readSetting = function(_s, key) return data[key] end,
            saveSetting = function(_s, key, val) data[key] = val end,
            flush = function() end,
        }
    end,
}

local function touchFile(name)
    local f = assert(io.open(IMAGES_DIR .. "/" .. name, "w"))
    f:write("png")
    f:close()
end

--- Run fn with a fresh images dir + in-memory index store
local function withImageIndex(fn)
    local prev = package.loaded["luasettings"]
    package.loaded["luasettings"] = MockLuaSettings
    index_store = {}
    os.execute('rm -rf "' .. IMAGES_DIR .. '" && mkdir -p "' .. IMAGES_DIR .. '"')
    -- updateIndexForMove stat-guards on the index file existing on disk
    touchFile(ImageGenerator.getIndexFilename())
    local ok, err = pcall(fn)
    package.loaded["luasettings"] = prev
    os.execute('rm -rf "' .. IMAGES_DIR .. '"')
    if not ok then error(err, 0) end
end

-- Tests ----------------------------------------------------------------------

local function runAll()
    print("  Unit Tests: Image generation")

    print("  [ModelLists image-model inventory]")
    TestRunner:test("image-capable providers have model lists with a default", function()
        for _idx, provider in ipairs({ "openai", "xai", "gemini" }) do
            local list = ModelLists.getImageModels(provider)
            TestRunner:assert(type(list) == "table" and #list > 0,
                provider .. " has a non-empty image model list")
            TestRunner:assertEquals(ModelLists.getDefaultImageModel(provider), list[1],
                provider .. " default = first list entry")
        end
    end)
    TestRunner:test("non-image providers return nil", function()
        TestRunner:assertEquals(ModelLists.getImageModels("anthropic"), nil)
        TestRunner:assertEquals(ModelLists.getDefaultImageModel("anthropic"), nil)
    end)
    TestRunner:test("_image_models is skipped by provider iteration", function()
        for _idx, p in ipairs(ModelLists.getAllProviders()) do
            TestRunner:assert(p ~= "_image_models", "_image_models leaked into getAllProviders")
        end
    end)

    print("  [BaseHandler.getApiKey / isPlaceholderKey]")
    TestRunner:test("placeholder keys are rejected", function()
        TestRunner:assertEquals(BaseHandler.isPlaceholderKey("YOUR_OPENAI_API_KEY"), true)
        TestRunner:assertEquals(BaseHandler.isPlaceholderKey("put-key-_HERE"), true)
        TestRunner:assertEquals(BaseHandler.isPlaceholderKey(""), true)
        TestRunner:assertEquals(BaseHandler.isPlaceholderKey(nil), true)
        TestRunner:assertEquals(BaseHandler.isPlaceholderKey("sk-real-key-123"), false)
    end)
    TestRunner:test("GUI key wins over apikeys.lua and is trimmed", function()
        withApikeys({ openai = "sk-file-key" }, function()
            local settings = mockSettings({ api_keys = { openai = "  sk-gui-key \n" } })
            TestRunner:assertEquals(BaseHandler.getApiKey("openai", settings), "sk-gui-key")
        end)
    end)
    TestRunner:test("falls back to apikeys.lua; placeholders ignored", function()
        withApikeys({ openai = "sk-file-key", xai = "YOUR_XAI_API_KEY" }, function()
            local settings = mockSettings({})
            TestRunner:assertEquals(BaseHandler.getApiKey("openai", settings), "sk-file-key")
            TestRunner:assertEquals(BaseHandler.getApiKey("xai", settings), nil)
        end)
    end)

    print("  [ImageGenerator.effectiveProvider]")
    TestRunner:test("auto: follows image-capable main provider", function()
        withApikeys({ openai = "sk-file-key" }, function()
            local settings = mockSettings({})
            local p = ImageGenerator.effectiveProvider({}, "openai", settings)
            TestRunner:assertEquals(p, "openai")
        end)
    end)
    TestRunner:test("auto: nil for non-image main provider (no key hunting)", function()
        withApikeys({ openai = "sk-file-key" }, function()
            local settings = mockSettings({})
            local p, reason = ImageGenerator.effectiveProvider({}, "anthropic", settings)
            TestRunner:assertEquals(p, nil)
            TestRunner:assertEquals(reason, "no_endpoint")
        end)
    end)
    TestRunner:test("explicit provider overrides main provider", function()
        withApikeys({ xai = "xai-real-key" }, function()
            local settings = mockSettings({})
            local p = ImageGenerator.effectiveProvider(
                { image_gen_provider = "xai" }, "anthropic", settings)
            TestRunner:assertEquals(p, "xai")
        end)
    end)
    TestRunner:test("explicit provider without a key -> no_key", function()
        withApikeys({}, function()
            local settings = mockSettings({})
            local p, reason = ImageGenerator.effectiveProvider(
                { image_gen_provider = "gemini" }, "openai", settings)
            TestRunner:assertEquals(p, nil)
            TestRunner:assertEquals(reason, "no_key")
        end)
    end)
    TestRunner:test("explicit 'auto' sentinel behaves like nil", function()
        withApikeys({ openai = "sk-file-key" }, function()
            local settings = mockSettings({})
            local p = ImageGenerator.effectiveProvider(
                { image_gen_provider = "auto" }, "openai", settings)
            TestRunner:assertEquals(p, "openai")
        end)
    end)
    TestRunner:test("nil main provider -> no_endpoint", function()
        local p, reason = ImageGenerator.effectiveProvider({}, nil, mockSettings({}))
        TestRunner:assertEquals(p, nil)
        TestRunner:assertEquals(reason, "no_endpoint")
    end)

    print("  [Images index: book associations]")
    TestRunner:test("recordImage → readIndex roundtrip; no-op without book info", function()
        withImageIndex(function()
            ImageGenerator.recordImage("a.png",
                { file = "/books/b1.epub", title = "Book One" }, "a castle")
            ImageGenerator.recordImage("b.png", nil, "ignored")
            local index = ImageGenerator.readIndex()
            TestRunner:assertEquals(index["a.png"].book_file, "/books/b1.epub")
            TestRunner:assertEquals(index["a.png"].book_title, "Book One")
            TestRunner:assertEquals(index["a.png"].prompt, "a castle")
            TestRunner:assert(type(index["a.png"].created) == "number", "created timestamp set")
            TestRunner:assertEquals(index["b.png"], nil)
        end)
    end)
    TestRunner:test("booksWithImages counts per book and prunes stale entries", function()
        withImageIndex(function()
            touchFile("a.png")
            touchFile("b.png")
            ImageGenerator.recordImage("a.png", { file = "/books/b1.epub", title = "Book One" }, "p1")
            ImageGenerator.recordImage("b.png", { file = "/books/b1.epub", title = "Book One" }, "p2")
            ImageGenerator.recordImage("gone.png", { file = "/books/b2.epub", title = "Book Two" }, "p3")
            local books = ImageGenerator.booksWithImages()
            TestRunner:assertEquals(books["/books/b1.epub"].count, 2)
            TestRunner:assertEquals(books["/books/b1.epub"].book_title, "Book One")
            TestRunner:assert(books["/books/b1.epub"].modified > 0, "modified from created timestamps")
            TestRunner:assertEquals(books["/books/b2.epub"], nil, "stale entry not counted")
            TestRunner:assertEquals(ImageGenerator.readIndex()["gone.png"], nil, "stale entry pruned")
        end)
    end)
    TestRunner:test("removeIndexEntries removes only the listed names", function()
        withImageIndex(function()
            ImageGenerator.recordImage("a.png", { file = "/books/b1.epub" }, "p1")
            ImageGenerator.recordImage("b.png", { file = "/books/b1.epub" }, "p2")
            ImageGenerator.removeIndexEntries({ "a.png", "never-there.png" })
            local index = ImageGenerator.readIndex()
            TestRunner:assertEquals(index["a.png"], nil)
            TestRunner:assert(index["b.png"] ~= nil, "unrelated entry kept")
        end)
    end)
    TestRunner:test("updateIndexForMove: move rewrites, delete unassigns, copy no-ops", function()
        withImageIndex(function()
            ImageGenerator.recordImage("a.png", { file = "/books/b1.epub" }, "p1")
            ImageGenerator.recordImage("b.png", { file = "/books/b2.epub" }, "p2")
            -- copy: images stay with the original book
            ImageGenerator.updateIndexForMove("/books/b1.epub", "/copied/b1.epub", true)
            TestRunner:assertEquals(ImageGenerator.readIndex()["a.png"].book_file, "/books/b1.epub")
            -- move: association follows the book
            ImageGenerator.updateIndexForMove("/books/b1.epub", "/moved/b1.epub", false)
            TestRunner:assertEquals(ImageGenerator.readIndex()["a.png"].book_file, "/moved/b1.epub")
            -- delete: association dropped (image becomes global-only)
            ImageGenerator.updateIndexForMove("/books/b2.epub", nil, false)
            TestRunner:assertEquals(ImageGenerator.readIndex()["b.png"], nil)
            TestRunner:assert(ImageGenerator.readIndex()["a.png"] ~= nil, "other book untouched")
        end)
    end)

    -- The image round's S1 (docs/image_round_plan.md, 2026-10-14) ------------

    print("  [Image models: defaults and retired picks]")
    TestRunner:test("resolveImageModel: default, retired, explicit", function()
        TestRunner:assertEquals(ModelLists.resolveImageModel("openai", nil), "gpt-image-2.5-flare")
        TestRunner:assertEquals(ModelLists.resolveImageModel("openai", "default"), "gpt-image-2.5-flare")
        TestRunner:assertEquals(ModelLists.resolveImageModel("gemini", ""), "gemini-nano-banana-2.1")
        TestRunner:assertEquals(ModelLists.resolveImageModel("xai", "grok-imagine-image-quality"),
            "grok-imagine-image-2.0", "xAI serves the retired id with 2.0")
        TestRunner:assertEquals(ModelLists.resolveImageModel("xai", "grok-imagine-image-pro"), "grok-imagine-image-2.0")
        TestRunner:assertEquals(ModelLists.resolveImageModel("gemini", "gemini-3.1-flash-image"),
            "gemini-3.1-flash-image", "a pick that only left the picker is kept")
        TestRunner:assertEquals(ModelLists.resolveImageModel("openai", "gpt-image-1"), "gpt-image-1")
    end)
    TestRunner:test("_image_retired is skipped by provider iteration", function()
        for _idx, p in ipairs(ModelLists.getAllProviders()) do
            TestRunner:assert(p ~= "_image_retired", "_image_retired leaked into getAllProviders")
        end
    end)

    print("  [The request as sent (B064)]")
    TestRunner:test("OpenAI: size and quality only when set; no response_format", function()
        local r = ImageGenerator.buildRequest("openai", "gpt-image-2.5-flare", "p",
            { image_gen_quality = "low", image_gen_size = "default" })
        TestRunner:assertEquals(r.url, "https://api.openai.com/v1/images/generations")
        TestRunner:assertEquals(r.key_header, "Authorization")
        TestRunner:assertEquals(r.body.model, "gpt-image-2.5-flare")
        TestRunner:assertEquals(r.body.quality, "low")
        TestRunner:assertEquals(r.body.size, nil, "Default = omitted")
        TestRunner:assertEquals(r.body.response_format, nil, "gpt-image refuses response_format")
        TestRunner:assertEquals(r.body.n, 1)
    end)
    TestRunner:test("xAI: base64 answer, the aspect ratio when set", function()
        local r = ImageGenerator.buildRequest("xai", "grok-imagine-image", "p", { image_gen_aspect = "2:3" })
        TestRunner:assertEquals(r.body.response_format, "b64_json")
        TestRunner:assertEquals(r.body.aspect_ratio, "2:3")
        TestRunner:assertEquals(r.body.size, nil, "xAI refuses size")
    end)
    TestRunner:test("Gemini: model in the path, image output, the Content Filter setting", function()
        local r = ImageGenerator.buildRequest("gemini", "gemini-nano-banana-2.1", "p", {})
        TestRunner:assertEquals(r.url,
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-nano-banana-2.1:generateContent")
        TestRunner:assertEquals(r.key_header, "x-goog-api-key")
        TestRunner:assertEquals(r.body.contents[1].parts[1].text, "p")
        TestRunner:assertEquals(r.body.generationConfig.responseModalities[1], "IMAGE")
        TestRunner:assert(type(r.body.safetySettings) == "table" and #r.body.safetySettings == 4,
            "the relaxed filter, as chat requests carry it")
        local g = ImageGenerator.buildRequest("gemini", "gemini-nano-banana-2.1", "p", { gemini_safety = "google" })
        TestRunner:assertEquals(g.body.safetySettings, nil, "Google's own filter: nothing sent")
    end)
    TestRunner:test("a provider with no image endpoint builds nothing", function()
        TestRunner:assertEquals(ImageGenerator.buildRequest("anthropic", "x", "p", {}), nil)
    end)

    print("  [The answer read (B064, B459)]")
    -- mime.unb64 is a passthrough stub in this file: the "base64" is the bytes
    TestRunner:test("OpenAI-style: b64_json, a link, nothing", function()
        local r = ImageGenerator.parseResponse("openai", '{"data":[{"b64_json":"PNGBYTES"}]}')
        TestRunner:assertEquals(r.bytes, "PNGBYTES")
        r = ImageGenerator.parseResponse("xai", '{"data":[{"url":"https://x.ai/i.jpg"}]}')
        TestRunner:assertEquals(r.url, "https://x.ai/i.jpg")
        local none, msg = ImageGenerator.parseResponse("openai", '{"data":[]}')
        TestRunner:assertEquals(none, nil)
        TestRunner:assert(type(msg) == "string" and msg ~= "", "a message")
        none, msg = ImageGenerator.parseResponse("openai", "not json")
        TestRunner:assertEquals(none, nil)
        TestRunner:assert(type(msg) == "string" and msg ~= "", "a message for a broken answer")
    end)
    TestRunner:test("an error inside a 200 answer is worded", function()
        local r, msg = ImageGenerator.parseResponse("openai", '{"error":{"message":"Billing hard limit"}}')
        TestRunner:assertEquals(r, nil)
        TestRunner:assert(msg:find("Billing hard limit", 1, true), msg)
    end)
    TestRunner:test("Gemini: the image part; the model's text and thoughts are not the image", function()
        local r = ImageGenerator.parseResponse("gemini", '{"candidates":[{"finishReason":"STOP","content":{"parts":['
            .. '{"text":"thinking","thought":true},{"text":"Here is the picture"},'
            .. '{"inlineData":{"mimeType":"image/jpeg","data":"JPEGBYTES"}}]}}]}')
        TestRunner:assertEquals(r.bytes, "JPEGBYTES")
    end)
    TestRunner:test("Gemini without a picture names its reason (B459)", function()
        local _r, msg = ImageGenerator.parseResponse("gemini",
            '{"candidates":[{"finishReason":"IMAGE_SAFETY","content":{"parts":[{"text":"I cannot draw that."}]}}]}')
        TestRunner:assert(msg:find("IMAGE_SAFETY", 1, true) and msg:find("I cannot draw that.", 1, true), msg)
        _r, msg = ImageGenerator.parseResponse("gemini", '{"promptFeedback":{"blockReason":"PROHIBITED_CONTENT"}}')
        TestRunner:assert(msg:find("PROHIBITED_CONTENT", 1, true), msg)
        _r, msg = ImageGenerator.parseResponse("gemini",
            '{"candidates":[{"finishReason":"STOP","content":{"parts":[{"text":"Here is"},{"text":"secret","thought":true}]}}]}')
        TestRunner:assert(msg:find("without a picture", 1, true) and msg:find("Here is", 1, true)
            and not msg:find("secret", 1, true), msg)
    end)
    TestRunner:test("errorMessage: the provider's words; OpenAI moderation named with its stage", function()
        local m = ImageGenerator.errorMessage(400, '{"error":{"code":"moderation_blocked",'
            .. '"message":"Your request was rejected","moderation_details":{"moderation_stage":"output"}}}')
        TestRunner:assert(m:find("picture it made", 1, true) and m:find("Your request was rejected", 1, true), m)
        m = ImageGenerator.errorMessage(400, '{"error":{"code":"moderation_blocked","message":"x",'
            .. '"moderation_details":{"moderation_stage":"input"}}}')
        TestRunner:assert(m:find("refused the prompt", 1, true), m)
        TestRunner:assertEquals(ImageGenerator.errorMessage(401, '{"error":{"message":"Incorrect API key"}}'),
            "HTTP 401: Incorrect API key")
        TestRunner:assertEquals(ImageGenerator.errorMessage(500, "upstream down"), "HTTP 500: upstream down")
    end)
    TestRunner:test("imageExtension: the file type from the bytes", function()
        TestRunner:assertEquals(ImageGenerator.imageExtension("\255\216\255\224rest"), "jpg")
        TestRunner:assertEquals(ImageGenerator.imageExtension("\137PNG\r\n\26\nrest"), "png")
        TestRunner:assertEquals(ImageGenerator.imageExtension("RIFF\0\0\0\0WEBPVP8 "), "webp")
        TestRunner:assertEquals(ImageGenerator.imageExtension("??"), "png", "unknown = png")
    end)

    print("  [The frame (B461, P7, the nearby_text kind)]")
    TestRunner:test("Book info level: None drops the identity, Title keeps the title", function()
        local opts = { book_metadata = { title = "T", author = "A" } }
        local p = ImageGenerator.buildPrompt("sel", opts, {})
        TestRunner:assert(p:find('"T" by A', 1, true), p)
        opts.book_info_level = "title"
        p = ImageGenerator.buildPrompt("sel", opts, {})
        TestRunner:assert(p:find('"T"', 1, true) and not p:find("by A", 1, true), p)
        opts.book_info_level = "full"
        p = ImageGenerator.buildPrompt("sel", opts, {})
        TestRunner:assert(p:find('"T" by A', 1, true), "Full sends both")
        opts.book_info_level = "none"
        TestRunner:assertEquals(ImageGenerator.buildPrompt("sel", opts, {}), "sel", "no frame left: the selection alone")
    end)
    TestRunner:test("the text after the selection follows the clamp", function()
        local window = { prev = "Before it.", next = " rest of the sentence. Next sentence.\nNext paragraph." }
        local p = ImageGenerator.buildPrompt("sel", { window = window, after_limit = "sentence" }, {})
        TestRunner:assert(p:find("rest of the sentence.", 1, true) and not p:find("Next sentence", 1, true), p)
        p = ImageGenerator.buildPrompt("sel", { window = window, after_limit = "paragraph" }, {})
        TestRunner:assert(p:find("Next sentence.", 1, true) and not p:find("Next paragraph", 1, true), p)
        p = ImageGenerator.buildPrompt("sel", { window = window, after_limit = "none" }, {})
        TestRunner:assert(p:find("Before it.", 1, true) and not p:find("rest of", 1, true), p)
        p = ImageGenerator.buildPrompt("sel", { window = window }, {})
        TestRunner:assert(p:find("Next paragraph.", 1, true), "no limit: all of it")
    end)
    TestRunner:test("allowedFrame: the text around goes only where nearby_text is allowed", function()
        local opts = { window = { prev = "a", next = "b" }, book_metadata = { title = "T" }, after_limit = "none" }
        TestRunner:assert(ImageGenerator.allowedFrame(opts, {}, "openai").window ~= nil, "allowed by default")
        opts.book_privacy = { nearby_text = false }
        local kept = ImageGenerator.allowedFrame(opts, {}, "openai")
        TestRunner:assertEquals(kept.window, nil, "a book's Never for the kind drops it")
        TestRunner:assertEquals(kept.book_metadata.title, "T", "the identity stays")
        TestRunner:assertEquals(kept.after_limit, "none")
    end)

    print("  [The main provider (B462)]")
    TestRunner:test("ConfigHelper.mainProvider: Settings, then configuration.lua, then Anthropic", function()
        local CH = require("koassistant.core.config_helper")
        CH.setFileProvider(nil)
        TestRunner:assertEquals(CH.mainProvider({}), "anthropic")
        TestRunner:assertEquals(CH.mainProvider(nil), "anthropic")
        CH.setFileProvider("gemini")
        TestRunner:assertEquals(CH.mainProvider({}), "gemini", "configuration.lua's provider")
        TestRunner:assertEquals(CH.mainProvider({ provider = "openai" }), "openai", "the Settings pick wins")
        CH.setFileProvider(nil)
    end)

    print(string.format("  Results: %d passed, %d failed", TestRunner.passed, TestRunner.failed))
    return TestRunner.failed == 0
end

-- Run tests if executed directly
if arg and arg[0] and arg[0]:match("test_image_gen%.lua$") then
    local success = runAll()
    os.exit(success and 0 or 1)
end

return {
    runAll = runAll,
    TestRunner = TestRunner,
}
