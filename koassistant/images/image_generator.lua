--[[--
KOAssistant Image Generator

Generates an image from a text description using the currently configured
AI provider's image-generation endpoint and displays the result in
KOReader's full-screen ImageViewer.

Currently supported providers and their image-generation endpoints:
  • openai     → https://api.openai.com/v1/images/generations   (gpt-image family)
  • xai        → https://api.x.ai/v1/images/generations         (grok-imagine-image)
  • gemini     → generateContent with IMAGE modality             (gemini-*-image)

Model inventory lives in koassistant/request/model_lists.lua (`_image_models`);
this file holds only wire/endpoint facts. Generated images are kept in
data_dir/koassistant_images (filename = date + prompt snippet); the
Generated Images browser (koassistant/images/image_browser.lua) manages them.

Public API:
  ImageGenerator.generate(word, configuration, settings, book_info)
      `word` = selected text / description; `configuration` = global config
      table (resolved by updateConfigFromSettings); `settings` = LuaSettings
      instance (for GUI-entered API keys); `book_info` = optional
      { file, title } — associates the saved image with a book in the
      images index (per-book gallery / artifact browser row).
  ImageGenerator.effectiveProvider(features, main_provider, settings)
      → provider|nil, reason — the button-visibility / dispatch gate.
  ImageGenerator.buildPrompt / buildRequest / parseResponse / errorMessage /
      imageExtension — pure: the framed prompt, the request as sent, the
      answer read, the refusal worded, the file type from the bytes
      (unit-tested; tests/inspect.lua --image and the audit's image probe
      build and read with them).
  ImageGenerator.getImagesDir()
  Index API (book associations): readIndex, recordImage, removeIndexEntries,
  booksWithImages, updateIndexForMove, getIndexFilename.
]]

local json   = require("json")
local ffi    = require("ffi")
local ffiutil = require("ffi/util")
local logger = require("koassistant.core.logger")
local mime   = require("mime")
local BaseHandler = require("koassistant.api.base")
local ModelLists = require("koassistant.request.model_lists")
local _ = require("koassistant.core.gettext")
local T = ffiutil.template

local ImageGenerator = {}

-- ---------------------------------------------------------------------------
-- Provider image-generation endpoint table
-- ---------------------------------------------------------------------------

--[[
 Provider entries (wire/endpoint facts ONLY — model inventory lives in
 koassistant/request/model_lists.lua `_image_models`, first entry = default):
   url        - base URL (OpenAI-style) or base URL for Gemini model interpolation
   key_header - HTTP header used for authentication
   is_gemini  - when true, use Gemini's generateContent protocol instead of OpenAI images API

 Gemini ("Nano Banana") note:
   The gemini-*-image models use the standard generateContent endpoint with
   responseModalities=["IMAGE","TEXT"] and return images as inlineData
   base64 parts in candidates[] -- not the OpenAI images response shape.
]]
local IMAGE_ENDPOINTS = {
    openai = {
        url        = "https://api.openai.com/v1/images/generations",
        key_header = "Authorization",  -- "Bearer <key>"
    },
    xai = {
        url        = "https://api.x.ai/v1/images/generations",
        key_header = "Authorization",
    },
    gemini = {
        -- Base URL; model is appended as: <base>/<model>:generateContent
        url        = "https://generativelanguage.googleapis.com/v1beta/models",
        key_header = "x-goog-api-key",
        is_gemini  = true,
    },
}

-- ---------------------------------------------------------------------------
-- Internal helpers
-- ---------------------------------------------------------------------------

--- Resolve the API key for a provider (GUI keys > apikeys.lua, placeholder-
--- aware). Shared logic lives in koassistant/api/base.lua.
local function resolveApiKey(provider, settings)
    return BaseHandler.getApiKey(provider, settings)
end

--- Resolve which provider image generation should use.
--- Chain (maintainer decision 2026-07-16): explicit `image_gen_provider`
--- ("auto"/nil = follow the main provider) > main provider when image-capable.
--- No fallback hunting through other configured keys — never spend on a
--- provider the user didn't pick for the job.
--- @param features table       resolved config features (image_gen_* keys)
--- @param main_provider string the active chat provider
--- @param settings table       LuaSettings instance (for GUI API keys)
--- @return string|nil provider, nil|"no_endpoint"|"no_key" reason
function ImageGenerator.effectiveProvider(features, main_provider, settings)
    local pick = features and features.image_gen_provider
    local provider
    if type(pick) == "string" and pick ~= "" and pick ~= "auto" then
        provider = pick
    else
        provider = main_provider
    end
    if not provider or not IMAGE_ENDPOINTS[provider] then
        return nil, "no_endpoint"
    end
    if not resolveApiKey(provider, settings) then
        return nil, "no_key"
    end
    return provider
end

--- Resolve the image model: explicit per-provider setting (a retired id sent
--- as its replacement) > list default.
local function resolveImageModel(provider, features)
    return ModelLists.resolveImageModel(provider, features and features["image_gen_model_" .. provider])
end

--- Show a simple error / informational notice.
local function showNotice(text)
    local UIManager  = require("ui/uimanager")
    local InfoMessage = require("ui/widget/infomessage")
    UIManager:show(InfoMessage:new{ text = text })
end

--- Return v only when it is a string, nil otherwise. KOReader's json.decode
--- maps JSON null to a truthy sentinel, so decoded fields must be
--- type-checked, never truthiness-checked.
local function str(v)
    return type(v) == "string" and v or nil
end

function ImageGenerator.getImagesDir()
    local DataStorage = require("datastorage")
    return DataStorage:getDataDir() .. "/koassistant_images"
end

--- The file extension an image's bytes call for: JPEG and WebP by their magic
--- bytes, PNG otherwise. Gemini and xAI answer JPEG; every image used to be
--- named .png. KOReader decodes by content either way.
function ImageGenerator.imageExtension(bytes)
    if type(bytes) == "string" then
        if bytes:sub(1, 3) == "\255\216\255" then return "jpg" end
        if bytes:sub(1, 4) == "RIFF" and bytes:sub(9, 12) == "WEBP" then return "webp" end
    end
    return "png"
end

--- What a refused or failed request (status other than 200) shows (B459): the
--- provider's own message where the body carries one, and OpenAI's moderation
--- refusal named as such, with the stage it refused at. Runs in the fetch child.
function ImageGenerator.errorMessage(code, body)
    local msg = type(body) == "string" and body or ""
    local okj, parsed = pcall(json.decode, msg)
    local err = okj and type(parsed) == "table" and parsed.error or nil
    if type(err) == "table" then
        local text = str(err.message) or ""
        if str(err.code) == "moderation_blocked" then
            local details = type(err.moderation_details) == "table" and err.moderation_details
                or (type(parsed.moderation_details) == "table" and parsed.moderation_details) or {}
            local stage = str(details.moderation_stage)
            local head
            if stage == "input" then
                head = _("OpenAI's moderation refused the prompt (the passage or its framing).")
            elseif stage == "output" then
                head = _("OpenAI's moderation refused the picture it made.")
            else
                head = _("OpenAI's moderation refused this request.")
            end
            if text ~= "" then head = head .. "\n\n" .. text:sub(1, 300) end
            return head
        end
        if text ~= "" then msg = text end
    elseif type(err) == "string" and err ~= "" then
        msg = err
    end
    return "HTTP " .. tostring(code) .. ": " .. msg:sub(1, 300)
end

-- ---------------------------------------------------------------------------
-- Book-association index
-- Maps image filename → { book_file, book_title, prompt, created } so the
-- gallery and artifact browser can offer per-book views. Lives INSIDE the
-- images dir (already registry-tracked, so reset/backup flows cover it with
-- no new registry work). Images absent from the index stay valid — they just
-- appear in the global gallery only.
-- ---------------------------------------------------------------------------

local INDEX_FILENAME = "koassistant_index.lua"

--- The index file's basename (the gallery excludes it from image listings).
function ImageGenerator.getIndexFilename()
    return INDEX_FILENAME
end

local function openIndex()
    local LuaSettings = require("luasettings")
    return LuaSettings:open(ImageGenerator.getImagesDir() .. "/" .. INDEX_FILENAME)
end

--- Read the whole index: { [filename] = { book_file, book_title, prompt, created } }
function ImageGenerator.readIndex()
    local idx = openIndex():readSetting("images")
    return type(idx) == "table" and idx or {}
end

local function writeIndex(index)
    local store = openIndex()
    store:saveSetting("images", index)
    store:flush()
end

--- Record a saved image's book association (called at save time; no-op
--- without book info — the image just stays unassigned).
function ImageGenerator.recordImage(filename, book_info, prompt)
    if not (book_info and book_info.file) then return end
    local index = ImageGenerator.readIndex()
    index[filename] = {
        book_file = book_info.file,
        book_title = book_info.title,
        prompt = prompt,
        created = os.time(),
    }
    writeIndex(index)
end

--- Drop index entries for deleted images.
--- @param filenames table array of image basenames
function ImageGenerator.removeIndexEntries(filenames)
    local index = ImageGenerator.readIndex()
    local changed = false
    for _idx, name in ipairs(filenames) do
        if index[name] ~= nil then
            index[name] = nil
            changed = true
        end
    end
    if changed then writeIndex(index) end
end

--- Map of book_file → { count, modified, book_title } for books with images.
--- Joins the index against the directory; stale entries (image file removed
--- outside the gallery) are pruned in passing.
function ImageGenerator.booksWithImages()
    local lfs = require("libs/libkoreader-lfs")
    local dir = ImageGenerator.getImagesDir()
    -- Cheap stat guard: this runs from every View Artifacts surface incl.
    -- file-browser long-press rows and the QS panel — skip the settings-file
    -- read while no index exists
    if not lfs.attributes(dir .. "/" .. INDEX_FILENAME, "mode") then
        return {}
    end
    local index = ImageGenerator.readIndex()
    local books = {}
    local stale = false
    for filename, entry in pairs(index) do
        local valid = type(entry) == "table" and type(entry.book_file) == "string"
            and lfs.attributes(dir .. "/" .. filename, "mode") == "file"
        if valid then
            local b = books[entry.book_file]
            if not b then
                b = { count = 0, modified = 0 }
                books[entry.book_file] = b
            end
            b.count = b.count + 1
            if (entry.created or 0) > b.modified then b.modified = entry.created end
            if type(entry.book_title) == "string" and entry.book_title ~= "" then
                b.book_title = entry.book_title
            end
        else
            index[filename] = nil
            stale = true
        end
    end
    if stale then writeIndex(index) end
    return books
end

--- Keep book associations valid across file-manager operations (called from
--- the DocSettings.updateLocation patch in main.lua). Move rewrites
--- book_file; delete drops the association (images are kept and become
--- global-only); copy leaves images with the original book.
function ImageGenerator.updateIndexForMove(old_path, new_path, copy)
    if copy then return end
    -- Cheap stat guard: this runs on EVERY file-manager move/delete
    local lfs = require("libs/libkoreader-lfs")
    if not lfs.attributes(ImageGenerator.getImagesDir() .. "/" .. INDEX_FILENAME, "mode") then
        return
    end
    local index = ImageGenerator.readIndex()
    local changed = false
    for filename, entry in pairs(index) do
        if type(entry) == "table" and entry.book_file == old_path then
            if new_path then
                entry.book_file = new_path
            else
                index[filename] = nil
            end
            changed = true
        end
    end
    if changed then writeIndex(index) end
end

--- Filesystem-safe fragment from the prompt (FAT-safe: device storage).
local function sanitizeForFilename(s)
    s = s:gsub("[%c/\\:*?\"<>|%.]", " "):gsub("%s+", " "):match("^%s*(.-)%s*$") or ""
    if #s > 40 then
        -- Byte-truncate, then drop a possibly split trailing UTF-8 sequence
        s = require("util").fixUtf8(s:sub(1, 40), ""):match("^%s*(.-)%s*$") or ""
    end
    return s
end

--- Show the generated image in KOReader's ImageViewer.
--- `image_data` is the raw PNG/JPEG binary string. Images are KEPT
--- (maintainer decision 2026-07-16): the filename carries the metadata
--- (date + prompt snippet) and the Generated Images browser handles deletion.
--- `book_info` = optional { file, title } → recorded in the images index.
--- full_prompt (optional): the exact prompt sent to the API (context-framed);
--- recorded in the index so the gallery's "Show full prompt" shows the truth.
--- `description` stays the raw selection — it drives filename + viewer title.
local function showImage(image_data, description, on_close, book_info, full_prompt)
    local UIManager  = require("ui/uimanager")
    local lfs = require("libs/libkoreader-lfs")

    local dir = ImageGenerator.getImagesDir()
    if not lfs.attributes(dir, "mode") then
        lfs.mkdir(dir)
    end
    local snippet = description and sanitizeForFilename(description) or ""
    if snippet == "" then snippet = "image" end
    local base = string.format("%s/%s %s", dir, os.date("%Y-%m-%d %H.%M.%S"), snippet)
    local ext = ImageGenerator.imageExtension(image_data)
    local path = base .. "." .. ext
    local n = 1
    while lfs.attributes(path, "mode") do
        n = n + 1
        path = string.format("%s (%d).%s", base, n, ext)
    end
    local f = io.open(path, "wb")
    if not f then
        showNotice(_("Failed to save generated image to disk."))
        return
    end
    f:write(image_data)
    f:close()
    ImageGenerator.recordImage(path:match("([^/]+)$"), book_info, full_prompt or description)

    -- Try to load KOReader's ImageViewer
    local ok, ImageViewer = pcall(require, "ui/widget/imageviewer")
    if not ok then
        -- Older KOReader builds may not have ImageViewer — offer a save notice
        showNotice(T(_("Image saved to:\n%1"), path))
        if on_close then on_close() end
        return
    end

    local title_text = _("Generated image")
    if description then
        title_text = description
        if #title_text > 60 then
            -- Byte-truncate, then drop a possibly split trailing UTF-8 sequence
            title_text = require("util").fixUtf8(title_text:sub(1, 60), "") .. "…"
        end
    end

    -- Framed prompt rides as the native ImageViewer caption (triangle icon in
    -- the title bar toggles it; starts hidden). Truncated — a full multi-side
    -- frame as a title-bar subtitle would squeeze the image out; the complete
    -- prompt is a gallery hold away. Skipped when unframed (= title already).
    local caption
    if full_prompt and full_prompt ~= description then
        caption = full_prompt
        if #caption > 400 then
            caption = require("util").fixUtf8(caption:sub(1, 400), "") .. "…"
        end
    end
    local viewer = ImageViewer:new{
        file = path,
        with_title_bar = true,
        title_text = title_text,
        caption = caption,
        caption_visible = false,
        is_doc_page = false,
    }
    if on_close then
        local orig_onClose = viewer.onClose
        viewer.onClose = function(self_v, ...)
            if orig_onClose then orig_onClose(self_v, ...) end
            on_close()
        end
    end
    UIManager:show(viewer)
end

-- ---------------------------------------------------------------------------
-- Background subprocess fetches (transport shared with base.lua)
-- ---------------------------------------------------------------------------

--- Build a background function for ffiutil.runInSubProcess that runs `fetch`
--- (returning status_code, body) and writes "OK:<body>" / "ERR:<message>" to
--- the pipe. Transport lives in BaseHandler.fetchInSubprocess (macOS raw-SSL
--- + standard paths); writes go through the looped BaseHandler.writeAllToFD.
local function makePipeFetchFn(fetch, err_prefix)
    return function(pid, child_write_fd)
        if not pid or not child_write_fd then return end
        local ok, err = pcall(function()
            local code, body = fetch()
            if code ~= 200 then
                -- a refusal arrives as JSON with error.message (an OpenAI
                -- moderation refusal is a 400): show the message, not the body (B459)
                BaseHandler.writeAllToFD(child_write_fd, "ERR:" .. ImageGenerator.errorMessage(code, body))
            else
                BaseHandler.writeAllToFD(child_write_fd, "OK:" .. (body or ""))
            end
        end)
        if not ok then
            BaseHandler.writeAllToFD(child_write_fd, "ERR:" .. err_prefix .. tostring(err))
        end
        ffi.C.close(child_write_fd)
        pcall(function() ffi.C._exit(0) end)
    end
end

--- POST the image-generation request; pipe carries "OK:<json>" or "ERR:<msg>".
--- @param endpoint table: IMAGE_ENDPOINTS entry (used for key_header)
local function makeBackgroundFn(url, api_key, request_body_str, endpoint)
    -- Pre-resolve DNS in parent (needed on macOS after fork)
    local resolved_ip = BaseHandler.resolveForSubprocess(url)

    local auth_header_name  = (endpoint and endpoint.key_header) or "Authorization"
    local auth_header_value = (auth_header_name == "Authorization")
        and ("Bearer " .. api_key)
        or api_key
    local headers = {
        ["Content-Type"]   = "application/json",
        [auth_header_name] = auth_header_value,
        ["Content-Length"] = tostring(#request_body_str),
    }

    return makePipeFetchFn(function()
        return BaseHandler.fetchInSubprocess(url, {
            method = "POST",
            headers = headers,
            body = request_body_str,
            resolved_ip = resolved_ip,
            -- OpenAI: "complex prompts may take up to 2 minutes"
            timeout = 180,
        })
    end, "Subprocess error: ")
end

--- GET binary content from a URL; pipe carries "OK:<binary>" or "ERR:<msg>".
local function makeDownloadFn(image_url)
    local resolved_ip = BaseHandler.resolveForSubprocess(image_url)

    return makePipeFetchFn(function()
        return BaseHandler.fetchInSubprocess(image_url, {
            resolved_ip = resolved_ip,
            timeout = 60,
        })
    end, "Download subprocess error: ")
end

-- ---------------------------------------------------------------------------
-- Poll helper: read subprocess pipe until EOF, then reap the child
-- ---------------------------------------------------------------------------

--- Non-blocking polling via ffiutil.getNonBlockingReadSize (portable — raw
--- O_NONBLOCK constants differ between Linux and macOS).
local function pollSubprocess(pid, parent_read_fd, on_done)
    local UIManager = require("ui/uimanager")
    local chunksize = 1024 * 64
    local buf = ffi.new("char[?]", chunksize)
    local buf_ptr = ffi.cast("void*", buf)
    local response_parts = {}
    local poll_task

    local function finish()
        ffi.C.close(parent_read_fd)
        -- Reap the child so it doesn't linger as a zombie (EOF can arrive a
        -- moment before the process is collectable)
        if not ffiutil.isSubProcessDone(pid) then
            local collect
            collect = function()
                if not ffiutil.isSubProcessDone(pid) then
                    UIManager:scheduleIn(1, collect)
                end
            end
            UIManager:scheduleIn(1, collect)
        end
        on_done(table.concat(response_parts))
    end

    poll_task = function()
        while true do
            local readsize = ffiutil.getNonBlockingReadSize(parent_read_fd) or 0
            if readsize > 0 then
                local bytes = tonumber(ffi.C.read(parent_read_fd, buf_ptr, chunksize))
                if bytes and bytes > 0 then
                    table.insert(response_parts, ffi.string(buf_ptr, bytes))
                else
                    finish()  -- 0 = EOF, negative = read error
                    return
                end
            elseif ffiutil.isSubProcessDone(pid) then
                -- Child exited (and is now reaped); its pipe end is closed, so
                -- blocking reads drain the remainder and then return 0
                while true do
                    local bytes = tonumber(ffi.C.read(parent_read_fd, buf_ptr, chunksize))
                    if bytes and bytes > 0 then
                        table.insert(response_parts, ffi.string(buf_ptr, bytes))
                    else
                        break
                    end
                end
                finish()
                return
            else
                UIManager:scheduleIn(0.15, poll_task)
                return
            end
        end
    end

    UIManager:scheduleIn(0.15, poll_task)
    return poll_task
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

--- Generate an image from `word` using the currently selected agent/provider.
---
--- @param word         string  The selected text (place / person description)
--- @param config_table table   The global `configuration` table from main.lua
--- @param settings     table   LuaSettings instance (for GUI API keys)
--- @param book_info    table|nil { file, title } for the images index
--- Assemble the prompt actually sent to the image API (context framing,
--- 2026-08-13). Exported so the action-details view and the settings screen
--- render the SAME template through the same code — no display copy to drift.
--- opts: { book_metadata = {title, author}, window = {prev, next},
---        after_limit = ScopeResolver.limitAfter's value (Context Direction and
---        the spoiler clamp, B461), book_info_level = "none"|"title"|"basic"|"full"
---        (the Book info level, P7; nil = basic) }.
--- features gates the frame parts: image_gen_frame_identity /
--- image_gen_frame_context (both opt-out, default on — schema defaults).
--- `description` stays the raw selection (filename + viewer title); English
--- frame on purpose — model-facing, like the quiz/nudge templates.
function ImageGenerator.buildPrompt(description, opts, features)
    local fixUtf8 = require("util").fixUtf8
    features = features or {}
    local frame = {}
    local meta = (features.image_gen_frame_identity ~= false)
        and opts and opts.book_metadata or nil
    -- The Book info level decides the identity, as it does in chat: None sends
    -- neither, Title the title alone (data_access_picture.md P7)
    local info_level = opts and opts.book_info_level or "basic"
    if info_level == "none" then meta = nil end
    if meta and meta.title and meta.title ~= "" then
        if info_level ~= "title" and meta.author and meta.author ~= "" then
            table.insert(frame, string.format('The passage is from the book "%s" by %s; match the book\'s setting and period.', meta.title, meta.author))
        else
            table.insert(frame, string.format('The passage is from the book "%s"; match the book\'s setting and period.', meta.title))
        end
    end
    local w = (features.image_gen_frame_context ~= false)
        and opts and opts.window or nil
    local prev = w and type(w.prev) == "string" and w.prev or ""
    local next_ = w and type(w.next) == "string" and w.next or ""
    -- The text after the selection is cut as chat's context is: Context
    -- Direction "before" drops it, spoiler protection keeps the selection's
    -- own sentence or paragraph (B461)
    next_ = require("koassistant.request.scope_resolver").limitAfter(next_, opts and opts.after_limit)
    if prev ~= "" or next_ ~= "" then
        -- Image prompts reward brevity: ~400 chars a side, UTF-8-safe cuts
        if #prev > 400 then prev = "…" .. fixUtf8(prev:sub(-400), "") end
        if #next_ > 400 then next_ = fixUtf8(next_:sub(1, 400), "") .. "…" end
        table.insert(frame, "Surrounding text, for context only: "
            .. prev .. " […] " .. next_)
    end
    -- Subject-first (2026-08-14 audit): the passage leads, the frame follows as
    -- labeled context — image models weight the opening as the subject, and the
    -- old shape (up to ~900 frame chars before the passage) risked the model
    -- illustrating the context window. The no-text rule guards against the
    -- title/author frame inviting book-cover compositions with rendered text.
    if #frame > 0 then
        return "Create an illustration of the following passage from a book. "
            .. "Illustrate the passage itself; do not render any text, titles, or captions in the image."
            .. "\n\nPassage to illustrate: " .. description
            .. "\n\n" .. table.concat(frame, " ")
    end
    return description
end

--- The prompt template as display text: the real builder run with placeholder
--- tokens, honoring the caller's current frame toggles. Tokens stay English —
--- this shows the wire truth, and the frame itself is English.
function ImageGenerator.promptTemplateText(features)
    return ImageGenerator.buildPrompt("{selected text}", {
        book_metadata = { title = "{book title}", author = "{book author}" },
        window = { prev = "{text before selection}", next = "{text after selection}" },
    }, features)
end

--- The frame options a request may use. The text around the selection is a
--- kind of its own ("text around what you tap", data_access_picture.md), asked
--- for the provider that receives it, the image provider; without it the frame
--- keeps the title and author alone.
function ImageGenerator.allowedFrame(opts, features, provider)
    if opts and opts.window and not require("koassistant.request.privacy_gates").allows("nearby_text",
            { features = features, provider = provider, book = opts.book_privacy }) then
        return { book_metadata = opts.book_metadata, after_limit = opts.after_limit,
                 book_info_level = opts.book_info_level }
    end
    return opts
end

--- The request one image costs (B064): the URL, the authentication header's
--- name and the body, exactly as sent. Pure; tests/inspect.lua --image and the
--- audit's image probe build with it too.
--- @return table|nil { url, key_header, body } (nil for a provider with no image endpoint)
function ImageGenerator.buildRequest(provider, model, prompt, features)
    features = features or {}
    local endpoint = IMAGE_ENDPOINTS[provider]
    if not endpoint then return nil end
    if endpoint.is_gemini then
        -- generateContent with image output; model in the path. The Gemini
        -- Content Filter setting applies here as it does to chat (a book
        -- passage is refused by Google's default filter more often)
        return {
            url = endpoint.url .. "/" .. model .. ":generateContent",
            key_header = endpoint.key_header,
            body = {
                contents = { { role = "user", parts = { { text = prompt } } } },
                generationConfig = { responseModalities = { "IMAGE", "TEXT" } },
                safetySettings = require("koassistant.api.gemini").safetySettings(features),
            },
        }
    end
    -- OpenAI-style images/generations request. Parameter support diverges
    -- (verified live 2026-07-16): OpenAI's gpt-image models reject
    -- response_format (b64_json is their default output); xAI rejects
    -- size/quality/style but honors response_format.
    local body = { model = model, prompt = prompt, n = 1 }
    if provider == "openai" then
        -- "default"/nil = omit the param and let the API decide
        local size = str(features.image_gen_size)
        if size and size ~= "default" then body.size = size end
        local quality = str(features.image_gen_quality)
        if quality and quality ~= "default" then body.quality = quality end
    else
        body.response_format = "b64_json"
        if provider == "xai" then
            local aspect = str(features.image_gen_aspect)
            if aspect and aspect ~= "default" then body.aspect_ratio = aspect end
        end
    end
    return { url = endpoint.url, key_header = endpoint.key_header, body = body }
end

-- A Gemini answer without a picture, worded with its reason (B459): the
-- prompt's blockReason, else the candidate's finishReason, then whatever the
-- model said in text.
local function geminiNoImageMessage(resp, candidate, texts)
    local feedback = type(resp.promptFeedback) == "table" and resp.promptFeedback or {}
    local block = str(feedback.blockReason)
    local finish = str(candidate.finishReason)
    local head
    if block then
        head = T(_("Gemini refused the prompt (%1)."), block)
    elseif finish == "IMAGE_SAFETY" or finish == "SAFETY" or finish == "IMAGE_PROHIBITED_CONTENT"
            or finish == "PROHIBITED_CONTENT" or finish == "BLOCKLIST" or finish == "SPII" then
        head = T(_("Google's safety filter refused the picture (%1)."), finish)
    elseif finish and finish ~= "STOP" then
        head = T(_("Gemini returned no picture (%1)."), finish)
    else
        head = _("Gemini answered without a picture.")
    end
    local said = table.concat(texts, " "):gsub("%s+", " "):match("^%s*(.-)%s*$") or ""
    if said ~= "" then
        if #said > 300 then said = require("util").fixUtf8(said:sub(1, 300), "") .. "…" end
        head = head .. "\n\n" .. said
    end
    return head
end

--- Read an image provider's answer (B064): { bytes = <binary> }, or
--- { url = <string> } when an OpenAI-style answer links the image, or nil and
--- the message to show. A Gemini answer without a picture names its reason.
function ImageGenerator.parseResponse(provider, body)
    local ok_parse, resp = pcall(json.decode, body or "")
    if not ok_parse or type(resp) ~= "table" then
        return nil, _("Failed to parse image generation response.")
    end
    -- API-level error ({ error = {...} } or { error = "..." }); type-checked
    -- so a JSON null (truthy sentinel) doesn't trip this on a success response
    if type(resp.error) == "table" or type(resp.error) == "string" then
        local err_msg = str(resp.error)
            or (type(resp.error) == "table" and str(resp.error.message))
            or _("Unknown API error")
        return nil, T(_("Image generation API error:\n\n%1"), err_msg)
    end
    local endpoint = IMAGE_ENDPOINTS[provider]
    if endpoint and endpoint.is_gemini then
        -- Images arrive as inlineData parts inside candidates[].content.parts
        local candidates = type(resp.candidates) == "table" and resp.candidates or {}
        local first = type(candidates[1]) == "table" and candidates[1] or {}
        local content = type(first.content) == "table" and first.content or {}
        local parts = type(content.parts) == "table" and content.parts or {}
        local texts = {}
        for _idx, part in ipairs(parts) do
            if type(part) == "table" and type(part.inlineData) == "table" then
                local mime_type = str(part.inlineData.mimeType)
                local data_b64 = str(part.inlineData.data)
                if mime_type and mime_type:sub(1, 6) == "image/" and data_b64 then
                    local bytes = mime.unb64(data_b64)
                    if not bytes or bytes == "" then
                        return nil, _("Failed to decode image data.")
                    end
                    return { bytes = bytes }
                end
            elseif type(part) == "table" and type(part.text) == "string" and part.thought ~= true then
                table.insert(texts, part.text)
            end
        end
        return nil, geminiNoImageMessage(resp, first, texts)
    end
    -- OpenAI-style answer: data[1].b64_json (preferred) or data[1].url
    local data_list = type(resp.data) == "table" and resp.data or nil
    local entry = data_list and type(data_list[1]) == "table" and data_list[1] or nil
    if not entry then
        return nil, _("No image data in response.")
    end
    local b64 = str(entry.b64_json)
    if b64 and b64 ~= "" then
        local bytes = mime.unb64(b64)
        if not bytes or bytes == "" then
            return nil, _("Failed to decode image data.")
        end
        return { bytes = bytes }
    end
    local image_url = str(entry.url)
    if image_url and image_url ~= "" then
        return { url = image_url }
    end
    return nil, _("No image URL in response.")
end

function ImageGenerator.generate(word, config_table, settings, book_info, opts)
    local ok, err = pcall(function()
        ImageGenerator._generateImpl(word, config_table, settings, book_info, opts)
    end)
    if not ok then
        logger.err("KOAssistant: image generation error:", err)
        showNotice(T(_("Image generation error:\n\n%1"), tostring(err)))
    end
end

--- Internal implementation — called via pcall from generate() for error catching.
--- opts (optional): { book_metadata = {title, author}, window = {prev, next},
--- after_limit, book_info_level, book_privacy } — context the prompt is framed
--- with (2026-08-13). book_metadata carries the per-book AI-identity overrides
--- already applied; window is the pre-extracted surrounding-context selection
--- window (hard-capped upstream; sent only where privacy_gates allows the
--- "nearby_text" kind for the image provider); book_privacy is the book's own
--- privacy values (PrivacyGates.overridesOf).
function ImageGenerator._generateImpl(word, config_table, settings, book_info, opts)
    local UIManager = require("ui/uimanager")

    -- Effective provider (maintainer decision 2026-07-16): explicit
    -- image_gen_provider > image-capable main provider; never fall back to a
    -- merely-keyed provider. Model: per-provider setting > list default.
    local features = (config_table and config_table.features) or {}
    local provider, unavailable = ImageGenerator.effectiveProvider(
        features, config_table and config_table.provider, settings)
    if not provider then
        if unavailable == "no_key" then
            showNotice(_("No API key found for the image generation provider.\n\nPlease add your key in KOAssistant settings."))
        else
            showNotice(_("Image generation is not available for the current provider.\n\nSupported: OpenAI, xAI (Grok), Gemini. You can also pick a dedicated image provider in KOAssistant settings (Advanced)."))
        end
        return
    end
    local endpoint = IMAGE_ENDPOINTS[provider]
    local api_key = resolveApiKey(provider, settings)
    local resolved_model = resolveImageModel(provider, features)

    -- Trim and validate description
    local description = word:match("^%s*(.-)%s*$")
    if description == "" then
        showNotice(_("No description selected."))
        return
    end

    opts = ImageGenerator.allowedFrame(opts, features, provider)

    -- Context-framed prompt (device 2026-08-13 "more context"): book identity +
    -- a trimmed slice of the surrounding passage, framed as context so the
    -- model illustrates the SELECTION, not the frame. The FULL prompt is what
    -- gets sent and recorded (viewable via the gallery + viewer caption).
    local final_prompt = ImageGenerator.buildPrompt(description, opts, features)

    -- The request as the provider takes it (OpenAI-style images API, or
    -- Gemini's generateContent with image output)
    local request = ImageGenerator.buildRequest(provider, resolved_model, final_prompt, features)
    local request_body_str = BaseHandler.encodeBody(request.body)

    -- Progress window: the tool-status dialog (setText handle + Stop button)
    -- avoids InfoMessage's fire-dismiss_callback-on-any-close trap and gives
    -- the user elapsed-time feedback during the long blocking POST
    local StreamHandler = require("koassistant.request.stream_handler")
    local cancelled = false
    local active_pid  -- reassigned per fork; Stop kills whichever is live
    local start_ts = os.time()
    local provider_label = string.upper(provider:sub(1,1)) .. provider:sub(2)
    local phase_text = T(_("Generating image with %1 / %2…"), provider_label, resolved_model)
    local status, tick
    local ticking = false
    local function statusText()
        return phase_text .. "\n\n" .. T(_("Elapsed: %1 s"), os.time() - start_ts)
    end
    local function stopTicker()
        if ticking then
            UIManager:unschedule(tick)
            ticking = false
        end
    end
    tick = function()
        if not ticking then return end
        status.setText(statusText())
        UIManager:scheduleIn(5, tick)
    end
    local function cancelRequest()
        cancelled = true
        stopTicker()
        if active_pid then
            ffiutil.terminateSubProcess(active_pid)
        end
        if status then status.close() end
    end
    local function openStatus(text)
        if status then status.close() end
        phase_text = text
        status = StreamHandler.showToolStatusDialog({
            settings = { large_stream_dialog = false, response_font_size = features.markdown_font_size },
            title = _("Generating image"),
            initial_text = statusText(),
            on_stop = cancelRequest,
        })
        ticking = true
        UIManager:scheduleIn(5, tick)
    end
    openStatus(phase_text)

    -- pollSubprocess callbacks run from the UI task queue, outside generate()'s
    -- pcall — guard them so a parsing bug can't crash KOReader
    local function guarded(fn)
        return function(...)
            local cb_ok, cb_err = pcall(fn, ...)
            if not cb_ok then
                stopTicker()
                if status then status.close() end
                logger.err("KOAssistant: image generation callback error:", cb_err)
                showNotice(T(_("Image generation error:\n\n%1"), tostring(cb_err)))
            end
        end
    end

    -- Launch subprocess
    logger.dbg("KOAssistant: image gen request:", provider, resolved_model)
    local bg_fn = makeBackgroundFn(request.url, api_key, request_body_str, endpoint)
    local pid, parent_read_fd = ffiutil.runInSubProcess(bg_fn, true)

    if not pid then
        stopTicker()
        status.close()
        showNotice(_("Failed to start image generation subprocess."))
        return
    end
    active_pid = pid

    -- Close the status window and report an error
    local function fail(msg)
        stopTicker()
        status.close()
        showNotice(msg)
    end

    -- Poll for result
    pollSubprocess(pid, parent_read_fd, guarded(function(raw)
        stopTicker()
        logger.dbg("KOAssistant: image gen result:", raw and #raw or 0, "bytes; head:", raw and raw:sub(1, 120) or "<empty>")
        if cancelled then return end

        if not raw or raw == "" then
            fail(_("Empty response from image generation API."))
            return
        end

        -- Check for error prefix
        if raw:sub(1, 4) == "ERR:" then
            fail(T(_("Image generation failed:\n\n%1"), raw:sub(5)))
            return
        end
        if raw:sub(1, 3) ~= "OK:" then
            -- Subprocess died mid-write; show what we got
            fail(T(_("Image generation failed:\n\n%1"), raw:sub(1, 200)))
            return
        end

        -- Strip "OK:" prefix and read the answer: the image's bytes, a link
        -- to it, or the reason there is none
        local result, parse_err = ImageGenerator.parseResponse(provider, raw:sub(4))
        if not result then
            fail(parse_err)
            return
        end
        if result.bytes then
            status.close()
            showImage(result.bytes, description, nil, book_info, final_prompt)
            return
        end
        local image_url = result.url

        -- Download phase: fresh status window, same elapsed clock
        openStatus(_("Downloading generated image…"))

        local dl_fn = makeDownloadFn(image_url)
        local dl_pid, dl_fd = ffiutil.runInSubProcess(dl_fn, true)
        if not dl_pid then
            fail(_("Failed to download generated image."))
            return
        end
        active_pid = dl_pid

        pollSubprocess(dl_pid, dl_fd, guarded(function(dl_raw)
            stopTicker()
            if cancelled then return end
            if not dl_raw or dl_raw:sub(1, 4) == "ERR:" then
                fail(T(_("Image download failed:\n\n%1"), dl_raw and dl_raw:sub(5) or ""))
                return
            end
            if dl_raw:sub(1, 3) ~= "OK:" or #dl_raw <= 3 then
                fail(_("Image download failed."))
                return
            end
            -- "OK:" prefix + binary
            status.close()
            showImage(dl_raw:sub(4), description, nil, book_info, final_prompt)
        end))
    end))
end

return ImageGenerator
