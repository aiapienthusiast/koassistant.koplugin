--[[
The question before a kind of the reader's data goes out for the first time,
and the funnel that asks it (docs/data_access_picture.md sections 4.4 and 4.6,
B395 slice 2).

One dialog, built once, used everywhere:

    Explain in Context will send to OpenAI:
    • text from this book, up to your position (42%)
    • your highlights (12)

    [ Allow once ]  [ Allow for this book ]
    [ Not for this book ]            (only when nothing asked is required)
    [ More… ]  [ Cancel ]

One question per run, listing every kind still on Ask. Allow once covers the
run and that chat's replies (Gates.grantOnce on the request's config copy,
never stored). Allow for this book writes the book's own value; Not for this
book writes Never for the optional kinds asked (the run goes on without them).
The two kinds no book can hold (the book list, reading habits) get Always
allow instead, which writes the global value. More… opens the book's Privacy
screen (or the settings) and asks again when it closes. A required kind on
Never is a refusal that names the layer, with one button to the same screen.

koassistant/request/privacy_gates.lua decides the states; this module only
asks and applies the answer. koassistant/ui/dialogs.lua's dispatch entry calls
`withAccess` before anything is read or sent; the surfaces that ask earlier
(the source popup's Run, the Scope and Tools chips, the attachments, the
X-Ray chat, the library Send, the X-Ray builds) call it with what they know.
]]

local UIManager = require("ui/uimanager")
local ButtonDialog = require("ui/widget/buttondialog")
local InfoMessage = require("ui/widget/infomessage")
local Gates = require("koassistant.request.privacy_gates")
local logger = require("koassistant.core.logger")
local _ = require("koassistant.core.gettext")
local T = require("ffi/util").template

local DataAccess = {}

--- The plain words for a kind, as the question lists it.
function DataAccess.kindLabel(kind)
    if kind == "book_text" then return _("text from this book") end
    if kind == "highlights" then return _("your highlights") end
    if kind == "annotations" then return _("your notes on highlights") end
    if kind == "notebook" then return _("your notebook") end
    if kind == "position" then return _("your reading position") end
    if kind == "habits" then return _("your reading habits") end
    if kind == "book_list" then return _("your book list") end
    if kind == "nearby_text" then return _("the text around what you tapped") end
    return tostring(kind)
end

--- The kind as a setting's name (the refusal, the screens).
function DataAccess.kindName(kind)
    if kind == "book_text" then return _("Book text") end
    if kind == "highlights" then return _("Highlights") end
    if kind == "annotations" then return _("Annotation notes") end
    if kind == "notebook" then return _("Notebook") end
    if kind == "position" then return _("Reading position") end
    if kind == "habits" then return _("Reading habits") end
    if kind == "book_list" then return _("Book list") end
    if kind == "nearby_text" then return _("Text around what you tap") end
    return tostring(kind)
end

--- Where a value comes from, in words.
function DataAccess.layerLabel(layer)
    if layer == "book" then return _("this book") end
    if layer == "trusted" then return _("trusted providers") end
    if layer == "once" then return _("this run") end
    return _("all books")
end

--- Pure: what a list of needs (Gates.needs) means for the dialog.
--- @return table { asked = { need, ... } (state ask, KINDS order), refused = need|nil
---   (the first required kind on Never), optional_only = boolean (nothing asked
---   is required), per_book = boolean (some asked kind can be stored for a book),
---   global_only = boolean (every asked kind is one no book can hold) }
function DataAccess.plan(needs)
    local out = { asked = {}, optional_only = true, per_book = false, global_only = true }
    for _idx, n in ipairs(needs or {}) do
        if n.state == "never" and n.required and not out.refused then
            out.refused = n
        elseif n.state == "ask" then
            out.asked[#out.asked + 1] = n
            if n.required then out.optional_only = false end
            if Gates.BOOK_KINDS[n.kind] then out.per_book = true; out.global_only = false end
        end
    end
    return out
end

--- Pure: the question's text. spec.action_name, spec.provider_name,
--- spec.amounts = { kind = line } (a line per kind, else the plain label),
--- spec.asked = the plan's list, spec.note = an extra sentence (the spoiler
--- reach, the books left out), spec.optional_only.
function DataAccess.questionText(spec)
    local lines = {}
    lines[#lines + 1] = T(_("%1 will send to %2:"), spec.action_name or _("This action"),
        spec.provider_name or _("your AI provider"))
    for _idx, n in ipairs(spec.asked or {}) do
        local line = spec.amounts and spec.amounts[n.kind] or DataAccess.kindLabel(n.kind)
        lines[#lines + 1] = "• " .. line
    end
    if spec.note and spec.note ~= "" then
        lines[#lines + 1] = ""
        lines[#lines + 1] = spec.note
    end
    return table.concat(lines, "\n")
end

--- Show the question. on_answer(choice): "once" | "book" | "not_book" |
--- "always" | "more" | "cancel". spec: the questionText fields plus
--- spec.plan (DataAccess.plan), spec.set (a request over many books: Allow
--- once and Cancel only), spec.standing_only (no Allow once: a feature with no
--- moment to ask offers Allow for this book alone).
function DataAccess.ask(plugin, spec, on_answer)
    local dialog
    local answered = false
    local function answer(choice)
        if answered then return end
        answered = true
        if dialog then UIManager:close(dialog) end
        on_answer(choice)
    end
    local plan = spec.plan or { asked = spec.asked or {}, optional_only = false, per_book = true }
    local first = {}
    if not spec.standing_only then
        first[#first + 1] = { text = _("Allow once"), callback = function() answer("once") end }
    end
    if not spec.set then
        if plan.global_only then
            first[#first + 1] = { text = _("Always allow"), callback = function() answer("always") end }
        else
            first[#first + 1] = { text = _("Allow for this book"), callback = function() answer("book") end }
        end
    end
    local rows = { first }
    if not spec.set and plan.optional_only and plan.per_book then
        rows[#rows + 1] = { { text = _("Not for this book"), callback = function() answer("not_book") end } }
    end
    local last = {}
    if not spec.set then
        last[#last + 1] = { text = _("More…"), callback = function() answer("more") end }
    end
    last[#last + 1] = { text = _("Cancel"), id = "close", callback = function() answer("cancel") end }
    rows[#rows + 1] = last
    dialog = ButtonDialog:new{
        title = DataAccess.questionText(spec),
        buttons = rows,
        tap_close_callback = function() answer("cancel") end,
    }
    UIManager:show(dialog)
    return dialog
end

-- The book's own Privacy screen for a path, then `after` when it closes.
local function openBookPrivacy(plugin, path, ui, after)
    require("koassistant.books.book_settings").showPrivacyConfig({
        plugin = plugin, ui = ui, document_path = path, on_close = after,
    })
end

--- The refusal for a required kind on Never: names the layer, one button to
--- the screen that holds the value. spec: kind, layer, action_name, path, ui,
--- hint (the action's blocked_hint).
function DataAccess.refuse(plugin, spec)
    local name = DataAccess.kindName(spec.kind)
    local text
    if spec.layer == "book" then
        text = T(_("%1 needs %2, which is set to Never for this book (Book Settings → Privacy)."),
            spec.action_name or _("This action"), name:lower())
    elseif spec.layer == "trusted" then
        text = T(_("%1 needs %2, which is set to Never for trusted providers (Settings → Privacy & Data → What trusted providers may use)."),
            spec.action_name or _("This action"), name:lower())
    else
        text = T(_("%1 needs %2, which is set to Never for all books (Settings → Privacy & Data)."),
            spec.action_name or _("This action"), name:lower())
    end
    if spec.hint and spec.hint ~= "" then text = text .. "\n\n" .. spec.hint end
    local dialog
    local rows = {}
    if spec.layer == "book" and spec.path then
        rows[#rows + 1] = { { text = _("Change for this book…"), callback = function()
            UIManager:close(dialog)
            openBookPrivacy(plugin, spec.path, spec.ui, nil)
        end } }
    elseif plugin and plugin.onKOAssistantSettings then
        rows[#rows + 1] = { { text = _("Open Settings"), callback = function()
            UIManager:close(dialog)
            plugin:onKOAssistantSettings()
        end } }
    end
    rows[#rows + 1] = { { text = _("Close"), id = "close", callback = function() UIManager:close(dialog) end } }
    dialog = ButtonDialog:new{ title = text, buttons = rows }
    UIManager:show(dialog)
end

-- The provider's display name.
local function providerName(plugin, provider)
    if plugin and plugin.getProviderDisplayName and provider then
        local ok, name = pcall(function() return plugin:getProviderDisplayName(provider) end)
        if ok and name then return name end
    end
    return provider or _("your AI provider")
end

-- Write a book's own value for the kinds (true = Allow, false = Never).
local function writeBookValues(path, ui, kinds, value)
    if not path then return false end
    local ok, ds = pcall(function()
        return require("koassistant.storage.doc_settings").resolve(path, ui)
    end)
    if not (ok and ds) then return false end
    local BookSettings = require("koassistant.books.book_settings")
    local wrote = false
    for _idx, kind in ipairs(kinds) do
        local key = BookSettings.PRIVACY_KEY_OF_KIND[kind]
        if key then
            ds:saveSetting(key, value)
            wrote = true
        end
    end
    if wrote then
        ds:flush()
        logger.info("KOAssistant: privacy value written for the book:", value and "allow" or "never", #kinds, "kinds")
    end
    return wrote
end

--- "Allow for this book" from a surface that is its own question (the
--- automatic X-Ray's start confirm): writes the book's value for the kinds.
function DataAccess.allowForBook(path, ui, kinds)
    return writeBookValues(path, ui, kinds, true)
end

-- Write the global value of the kinds no book can hold (Always allow).
local function writeGlobalAllow(plugin, kinds)
    if not (plugin and plugin.settings) then return end
    local f = plugin.settings:readSetting("features") or {}
    for _idx, kind in ipairs(kinds) do
        local key = Gates.GLOBAL_KEY[kind]
        if key then f[key] = true end
    end
    plugin.settings:saveSetting("features", f)
    plugin.settings:flush()
    if plugin.updateConfigFromSettings then plugin:updateConfigFromSettings() end
    logger.info("KOAssistant: privacy value set to Allow for all books:", #kinds, "kinds")
end

--- The needs of a run over several books (a library request with picked
--- books): each book's own values decide for its data; one question for the
--- set. Returns the needs list (per kind, state ask when any book asks) plus
--- the kinds no book holds (the book list, reading habits) as the action
--- declares them, and the count of books on Never.
local function needsForSet(action, opts)
    local kinds = { "highlights", "annotations", "notebook" }
    local wanted = {}
    if action.use_highlights then wanted.highlights = true end
    if action.use_annotations then wanted.annotations = true; wanted.highlights = true end
    if action.use_notebook then wanted.notebook = true end
    local out, never_books = {}, 0
    local never_seen = {}
    for _idx, kind in ipairs(kinds) do
        if wanted[kind] then
            local any_ask = false
            for _b, book in ipairs(opts.books) do
                local ctx = Gates.context(opts.features, opts.provider, { path = book.file, ui = opts.ui })
                local state = Gates.resolve(kind, ctx)
                if state == "ask" then any_ask = true end
                if state == "never" and not never_seen[book.file] then
                    never_seen[book.file] = true
                    never_books = never_books + 1
                end
            end
            if any_ask then
                out[#out + 1] = { kind = kind, state = "ask", layer = "global", required = false }
            end
        end
    end
    local ctx = Gates.context(opts.features, opts.provider, {})
    for _idx, n in ipairs(Gates.needs(action, ctx, { source = opts.source, stamps = opts.stamps })) do
        if not Gates.BOOK_KINDS[n.kind] then out[#out + 1] = n end
    end
    return out, never_books
end

--- What a run wants, with each kind's state: the action's declarations for
--- its book (Gates.needs), a set of picked books (needsForSet), or an
--- explicit list of kinds (a pick that is not an action).
--- @return table needs, number|nil never_books (sets only)
function DataAccess.needsFor(action, opts)
    action = action or {}
    opts = opts or {}
    if opts.needs then return opts.needs, opts.never_books end
    local features = opts.features or {}
    if opts.books then
        return needsForSet(action, opts)
    end
    local ctx = Gates.context(features, opts.provider, { path = opts.path, ui = opts.ui, book = opts.book })
    if opts.kinds then
        local needs = {}
        for _idx, kind in ipairs(opts.kinds) do
            local state, layer = Gates.resolve(kind, ctx)
            needs[#needs + 1] = { kind = kind, state = state, layer = layer, required = opts.required ~= false }
        end
        return needs
    end
    return Gates.needs(action, ctx, { source = opts.source, stamps = opts.stamps, nearby = opts.nearby })
end

--- The funnel: resolve what the run wants, refuse a required kind on Never,
--- ask for the kinds on Ask, then run.
--- opts: features (the config the run uses), provider (the dispatch provider),
--- path (the book's file, nil = no book), ui, action_name, source, stamps,
--- nearby, amounts (kind = line), note, standing_only, kinds (an explicit list
--- of kinds, for a pick that is not an action), books (a set, see needsForSet),
--- hint, required (with kinds: whether they are required).
--- run_fn(granted) runs the request; granted = { once = kinds } after Allow
--- once, {} otherwise. Never called after Cancel or a refusal.
function DataAccess.withAccess(plugin, action, opts, run_fn)
    opts = opts or {}
    action = action or {}
    local features = opts.features or {}
    local needs, never_books = DataAccess.needsFor(action, opts)
    local plan = DataAccess.plan(needs)
    if plan.refused then
        DataAccess.refuse(plugin, { kind = plan.refused.kind, layer = plan.refused.layer,
            action_name = opts.action_name or action.text, path = opts.path, ui = opts.ui, hint = opts.hint })
        return false
    end
    if #plan.asked == 0 then
        run_fn({})
        return true
    end
    local asked_kinds = {}
    for _idx, n in ipairs(plan.asked) do asked_kinds[#asked_kinds + 1] = n.kind end
    local note = opts.note
    if opts.books then
        local n_books = #opts.books
        local set_note = T(_("One answer for the %1 picked books; each book's own Privacy setting still applies."), n_books)
        if never_books and never_books > 0 then
            set_note = set_note .. " " .. T(_("%1 of them are set to Never and stay out."), never_books)
        end
        note = note and (note .. "\n" .. set_note) or set_note
    end
    DataAccess.ask(plugin, {
        action_name = opts.action_name or action.text,
        provider_name = providerName(plugin, opts.provider),
        asked = plan.asked, plan = plan, amounts = opts.amounts, note = note,
        set = opts.books ~= nil, standing_only = opts.standing_only,
    }, function(choice)
        if choice == "once" then
            Gates.grantOnce(features, opts.books and nil or opts.path, asked_kinds)
            run_fn({ once = asked_kinds })
        elseif choice == "book" then
            local stored, once = {}, {}
            for _idx, kind in ipairs(asked_kinds) do
                if Gates.BOOK_KINDS[kind] then stored[#stored + 1] = kind else once[#once + 1] = kind end
            end
            if not writeBookValues(opts.path, opts.ui, stored, true) then
                -- no book to write to (none known): this run only
                for _idx, kind in ipairs(stored) do once[#once + 1] = kind end
            end
            if #once > 0 then Gates.grantOnce(features, opts.path, once) end
            run_fn({ once = #once > 0 and once or nil })
        elseif choice == "not_book" then
            local stored = {}
            for _idx, kind in ipairs(asked_kinds) do
                if Gates.BOOK_KINDS[kind] then stored[#stored + 1] = kind end
            end
            writeBookValues(opts.path, opts.ui, stored, false)
            run_fn({})
        elseif choice == "always" then
            writeGlobalAllow(plugin, asked_kinds)
            run_fn({})
        elseif choice == "more" then
            if plan.per_book and opts.path then
                openBookPrivacy(plugin, opts.path, opts.ui, function()
                    -- the screen may have set a value: resolve again
                    opts.needs, opts.never_books = nil, nil
                    DataAccess.withAccess(plugin, action, opts, run_fn)
                end)
            elseif plugin and plugin.onKOAssistantSettings then
                plugin:onKOAssistantSettings()
                if opts.on_cancel then opts.on_cancel() end
            end
        elseif opts.on_cancel then
            opts.on_cancel()
        end
    end)
    return true
end

--- The dispatch entry's funnel (the dialogs module's handlePredefinedPrompt):
--- what this request wants, read from the action and the config's transients
--- (the picked source, a section scope, the stored material it reads, the
--- selection's window), with the amounts the reader can judge. Returns true
--- when a question or a refusal is up (the run continues through run_fn, or
--- not at all), false when nothing needs asking (the caller goes on).
function DataAccess.askForDispatch(plugin, action, features, ui, config, run_fn)
    local cf = features or {}
    -- The book this request is about (the dispatch's own per-book rule): a
    -- book-level request names its target, a highlight belongs to the open
    -- book, a library request may carry picked books, a general one none
    local path, books
    if cf.is_library_context then
        if type(cf.books_info) == "table" and #cf.books_info > 0 then
            books = {}
            for _idx, b in ipairs(cf.books_info) do
                if type(b) == "table" and b.file then books[#books + 1] = { file = b.file, title = b.title } end
            end
            if #books == 0 then books = nil end
        end
    elseif cf.is_general_context then
        path = nil
    elseif cf.is_book_context then
        path = (cf.book_metadata and cf.book_metadata.file) or (ui and ui.document and ui.document.file)
    else
        path = (ui and ui.document and ui.document.file) or (cf.book_metadata and cf.book_metadata.file)
    end
    local provider = require("koassistant.ui.dialogs").effectiveDispatchProvider(
        cf, action, action.provider or (config and config.provider))
    local sm = cf._source_mode
    local live = ui and ui.document and ui.document.file ~= nil and ui.document.file == path
    -- The stored material the run will read: its stamps are the kinds it needs
    local stamps
    if path and (action.use_xray_cache or action.use_analyze_cache or action.use_summary_cache or sm == "summary") then
        local ok, CE = pcall(require, "koassistant.request.context_extractor")
        if ok and CE then
            local ex = CE:new(live and ui or nil, { document_path = path })
            local function stored(get)
                local okr, r = pcall(get)
                if okr and type(r) == "table" and type(r.text) == "string" and r.text ~= "" then return r end
                return nil
            end
            stamps = {}
            if action.use_xray_cache then stamps.xray = stored(function() return ex:getXrayCache() end) end
            if action.use_analyze_cache then stamps.analyze = stored(function() return ex:getAnalyzeCache() end) end
            if action.use_summary_cache or sm == "summary" then
                stamps.summary = stored(function() return ex:getSummaryCache() end)
            end
        end
    end
    local prompt_text = action.prompt or ""
    local nearby = (cf._selection_context_window ~= nil and action.use_surrounding_context ~= false)
        or prompt_text:find("{page_text", 1, true) ~= nil
    -- The amounts, where known
    local amounts = {}
    if cf._section_scope and cf._section_scope.label then
        amounts.book_text = T(_("the text of \"%1\" from this book"), cf._section_scope.label)
    elseif cf._highlight_section_scope then
        amounts.book_text = _("text from this book, the part you chose")
    elseif sm == "smart_retrieval" then
        amounts.book_text = _("the passages it looks up in this book")
    elseif sm == "summary" then
        amounts.book_text = _("a summary built from this book's text")
    elseif cf._full_document_xray or cf._update_to_full_progress
            or prompt_text:find("{full_document", 1, true)
            or (sm ~= nil and sm ~= "ai_knowledge" and prompt_text:find("{document_context", 1, true)) then
        amounts.book_text = _("the whole text of this book")
    else
        local pct
        if live then
            local ok, CE = pcall(require, "koassistant.request.context_extractor")
            if ok and CE then
                local okp, p = pcall(function() return CE:new(ui):getReadingProgress() end)
                if okp and type(p) == "table" and p.formatted then pct = p.formatted end
            end
        end
        amounts.book_text = pct and T(_("text from this book, up to your position (%1)"), pct)
            or _("text from this book, up to your reading position")
    end
    if live and ui.annotation and type(ui.annotation.annotations) == "table" then
        local n, notes = 0, 0
        for _idx, a in ipairs(ui.annotation.annotations) do
            if type(a) == "table" and type(a.text) == "string" and a.text ~= "" then
                n = n + 1
                if type(a.note) == "string" and a.note ~= "" then notes = notes + 1 end
            end
        end
        amounts.highlights = T(_("your highlights (%1)"), n)
        amounts.annotations = T(_("your notes on highlights (%1)"), notes)
    end
    amounts.book_list = _("your book list (titles, authors, reading status)")
    amounts.habits = _("your reading habits (books read a lot, stalled, barely started)")
    local opts = { features = cf, provider = provider, path = path, ui = ui, books = books,
        action_name = action.text or action.id, source = sm, stamps = stamps, nearby = nearby,
        amounts = amounts, hint = action.blocked_hint }
    local needs, never_books = DataAccess.needsFor(action, opts)
    local plan = DataAccess.plan(needs)
    if not plan.refused and #plan.asked == 0 then return false end
    opts.needs, opts.never_books = needs, never_books
    DataAccess.withAccess(plugin, action, opts, run_fn)
    return true
end

--- A one-time notice after the upgrade that made Ask the default (ruling 2
--- of 2026-10-14). Shown at the first interaction, before other prompts;
--- the pending flag is written by the migration.
--- @return boolean shown
function DataAccess.maybeShowUpgradeNotice(plugin)
    if not (plugin and plugin.settings) then return false end
    local f = plugin.settings:readSetting("features") or {}
    if not f._privacy_notice_pending then return false end
    f._privacy_notice_pending = nil
    plugin.settings:saveSetting("features", f)
    plugin.settings:flush()
    UIManager:show(InfoMessage:new{
        text = _("Privacy has been redone.") .. "\n\n"
            .. _("KOAssistant now asks before it sends your highlights, notes, notebook, book text, book list or reading habits for the first time, and remembers your answer for the book. Every sharing switch in Settings → Privacy & Data is set to Ask; your per-book settings and trusted providers are kept.")
            .. "\n\n" .. _("Each switch can also be set to Allow (sent without asking) or Never."),
    })
    return true
end

return DataAccess
