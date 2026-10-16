--[[
The Data chip of the input dialog (B395 slice 3, ruled 2026-10-16): what this
chat may send, and the chat's own choices about it.

Tap: one row per kind of data this chat can send (a book or highlight chat:
the five kinds a book can hold a value for; a library chat: the book list and
reading habits), each with its state and where the state comes from, then
Book info (B500). A row allows the kind for this chat (the same allowance the
question's "Allow once" grants, `features._data_once`), leaves it out of this
chat (`features._chat_data.never`, a layer of its own in the gates, below the
book's Never), or goes back to the usual value; "Change for this book…" opens
the shared picker. Book info can be turned off for this chat
(`features._chat_data.book_info_off`, read by BookSettings.resolveBookInfoLevel).
Hold: the book's Data access screen (Book Settings → Privacy), or the values
for all books in a library chat.

The chat's choices live on the dialog's config: the dispatch copies them into
the request's config and consumes them from the source, a fresh dialog clears
them, a refresh keeps them (koassistant/ui/dialogs.lua). Pure parts: kindsFor,
rows, label.
]]

local UIManager = require("ui/uimanager")
local ButtonDialog = require("ui/widget/buttondialog")
local Gates = require("koassistant.request.privacy_gates")
local _ = require("koassistant.core.gettext")
local T = require("ffi/util").template

local DataChip = {}

local BOOK_CHAT_KINDS = { "book_text", "highlights", "annotations", "notebook", "nearby_text" }
local LIBRARY_CHAT_KINDS = { "book_list", "habits" }

--- The kinds a chat of this kind can send. chat = "library" | anything else
--- (a book or highlight chat). Pure.
function DataChip.kindsFor(chat)
    return chat == "library" and LIBRARY_CHAT_KINDS or BOOK_CHAT_KINDS
end

-- The chat's own choices table, created on demand.
local function chatData(features)
    local cd = features._chat_data
    if type(cd) ~= "table" then
        cd = {}
        features._chat_data = cd
    end
    return cd
end

-- Whether the chat holds any choice of its own (an allowance or a left-out
-- kind or the book info switch).
local function chatChanged(features, path)
    local cd = Gates.chatData(features)
    if cd then
        if cd.book_info_off then return true end
        if type(cd.never) == "table" and next(cd.never) ~= nil then return true end
    end
    local once = Gates.onceFor(features, path)
    return once ~= nil and next(once) ~= nil
end

--- Each kind's state for the chat. ctx = a gates context. Pure.
--- @return table { { kind, state, layer }, ... }, number of kinds on Ask
function DataChip.rows(kinds, ctx)
    local out, n_ask = {}, 0
    for _idx, kind in ipairs(kinds) do
        local state, layer = Gates.resolve(kind, ctx)
        if state == "ask" then n_ask = n_ask + 1 end
        out[#out + 1] = { kind = kind, state = state, layer = layer }
    end
    return out, n_ask
end

--- The chip's text: a choice of this chat's own first, else how many kinds
--- would be asked. Pure.
function DataChip.label(n_ask, changed, enable_emoji)
    if changed then
        return enable_emoji and ("\u{1F512} " .. _("this chat")) or _("Data: this chat")
    end
    if n_ask > 0 then
        return enable_emoji and ("\u{1F512} " .. T(_("%1 ask"), n_ask)) or T(_("Data: %1 ask"), n_ask)
    end
    return enable_emoji and ("\u{1F512} " .. _("Data")) or _("Data")
end

-- Where a state comes from, for the chip: an allowance for one run is this
-- chat's here (the chat is the run).
local function whereLabel(layer)
    if layer == "once" or layer == "chat" then return _("this chat") end
    return require("koassistant.ui.data_access").layerLabel(layer)
end

-- A context for the chip's book and provider.
local function context(o)
    local features = o.configuration.features
    local provider = require("koassistant.ui.dialogs").effectiveDispatchProvider(
        features, nil, o.configuration.provider)
    return Gates.context(features, provider, { path = o.document_path, ui = o.ui }), provider
end

--- The chip's text for the dialog. o = { configuration, ui, document_path, chat, enable_emoji }
function DataChip.chipText(o)
    local ctx = context(o)
    local _rows, n_ask = DataChip.rows(DataChip.kindsFor(o.chat), ctx)
    return DataChip.label(n_ask, chatChanged(o.configuration.features, o.document_path), o.enable_emoji)
end

--- The hold: the book's Data access screen, or the values for all books.
function DataChip.hold(o)
    require("koassistant.books.book_settings").showPrivacyConfig({
        plugin = o.plugin,
        ui = o.chat ~= "library" and o.ui or nil,
        document_path = o.chat ~= "library" and o.document_path or nil,
        all_books = o.chat == "library" or o.document_path == nil,
        on_close = o.on_change,
    })
end

--- The tap: the popup. o = { configuration, ui, document_path, chat, plugin,
--- enable_emoji, on_change } (on_change re-renders the dialog's chip row,
--- once, when the popup closes).
function DataChip.open(o)
    local features = o.configuration.features
    local path = o.document_path
    local DataAccess = require("koassistant.ui.data_access")
    local BookSettings = require("koassistant.books.book_settings")
    local ctx, provider = context(o)
    local dialog
    local function close()
        if dialog then UIManager:close(dialog); dialog = nil end
        if o.on_change then o.on_change() end
    end
    local function reopen()
        if dialog then UIManager:close(dialog); dialog = nil end
        DataChip.open(o)
    end

    local function setOnce(kind, on)
        local once = Gates.onceFor(features, path)
        if on then
            local kinds = { kind }
            -- allowing notes allows their highlights (the pairing)
            if kind == "annotations" then kinds[2] = "highlights" end
            Gates.grantOnce(features, path, kinds)
        elseif once then
            once[kind] = nil
        end
    end
    local function setNever(kind, on)
        local cd = chatData(features)
        cd.never = cd.never or {}
        cd.never[kind] = on or nil
    end

    -- One kind's choices for this chat
    local function kindMenu(row)
        if dialog then UIManager:close(dialog); dialog = nil end
        local name = DataAccess.kindName(row.kind)
        local own_never = row.state == "never" and row.layer == "book"
        local chat_set = row.layer == "once" or row.layer == "chat"
        local sub
        local buttons = {}
        local function pick(fn)
            return function()
                UIManager:close(sub)
                fn()
                reopen()
            end
        end
        if row.state ~= "allow" and not own_never then
            buttons[#buttons + 1] = {{ text = _("Allow for this chat"), callback = pick(function()
                setNever(row.kind, false)
                -- notes carry their highlights: a highlights left out of this
                -- chat would keep the notes out too (the pairing)
                if row.kind == "annotations" then setNever("highlights", false) end
                setOnce(row.kind, true)
            end) }}
        end
        if row.state ~= "never" then
            buttons[#buttons + 1] = {{ text = _("Leave out of this chat"), callback = pick(function()
                setOnce(row.kind, false)
                setNever(row.kind, true)
            end) }}
        end
        if chat_set then
            buttons[#buttons + 1] = {{ text = _("Back to the usual value"), callback = pick(function()
                setOnce(row.kind, false)
                setNever(row.kind, false)
            end) }}
        end
        if Gates.BOOK_KINDS[row.kind] and path then
            buttons[#buttons + 1] = {{ text = _("Change for this book…"), callback = function()
                UIManager:close(sub)
                BookSettings.showPrivacyPicker({
                    kind = row.kind, plugin = o.plugin, ui = o.ui, document_path = path,
                    target_override = "book", on_close = reopen,
                })
            end }}
        end
        buttons[#buttons + 1] = {{ text = _("Back"), id = "close", callback = function()
            UIManager:close(sub)
            reopen()
        end }}
        local note
        if own_never then
            note = _("Set to Never for this book: nothing here changes that.")
        end
        sub = ButtonDialog:new{
            title = T(_("%1: %2 (%3)"), name, BookSettings.privacyStateLabel(row.state), whereLabel(row.layer))
                .. (note and ("\n" .. note) or ""),
            buttons = buttons,
            tap_close_callback = function() reopen() end,
        }
        UIManager:show(sub)
    end

    -- Book info for this chat (B500): off, or back on
    local function bookInfoMenu(level, off)
        if dialog then UIManager:close(dialog); dialog = nil end
        local sub
        local buttons = {}
        buttons[#buttons + 1] = {{ text = off and _("Back on for this chat") or _("Off for this chat"),
            callback = function()
                UIManager:close(sub)
                chatData(features).book_info_off = (not off) or nil
                reopen()
            end }}
        if path then
            buttons[#buttons + 1] = {{ text = _("Change for this book…"), callback = function()
                UIManager:close(sub)
                BookSettings.showBookInfoPicker({
                    plugin = o.plugin, ui = o.ui, document_path = path,
                    target_override = "book", on_close = reopen,
                })
            end }}
        end
        buttons[#buttons + 1] = {{ text = _("Back"), id = "close", callback = function()
            UIManager:close(sub)
            reopen()
        end }}
        sub = ButtonDialog:new{
            title = T(_("Book info: %1"), off and _("off for this chat") or BookSettings.bookInfoLabel(level))
                .. "\n" .. _("What the AI is told about the book with every request. Off sends nothing that names it."),
            buttons = buttons,
            tap_close_callback = function() reopen() end,
        }
        UIManager:show(sub)
    end

    local rows = DataChip.rows(DataChip.kindsFor(o.chat), ctx)
    local buttons = {}
    for _idx, row in ipairs(rows) do
        buttons[#buttons + 1] = {{
            text = T(_("%1: %2 (%3)"), DataAccess.kindName(row.kind),
                BookSettings.privacyStateLabel(row.state), whereLabel(row.layer)),
            callback = function() kindMenu(row) end,
        }}
    end
    if o.chat ~= "library" then
        local cd = Gates.chatData(features)
        local off = cd and cd.book_info_off == true or false
        local ds = path and require("koassistant.storage.doc_settings").resolve(path, o.ui) or nil
        -- the level this chat would use without its own switch
        local level = BookSettings.resolveBookInfoLevel(ds, { book_info_in_chat = features.book_info_in_chat })
        buttons[#buttons + 1] = {{
            text = T(_("Book info: %1"), off and _("off for this chat") or BookSettings.bookInfoLabel(level)),
            callback = function() bookInfoMenu(level, off) end,
        }}
    end
    buttons[#buttons + 1] = {{
        text = (o.chat == "library" or not path) and _("Privacy for all books…") or _("Data access for this book…"),
        callback = function()
            if dialog then UIManager:close(dialog); dialog = nil end
            DataChip.hold({ plugin = o.plugin, ui = o.ui, document_path = path, chat = o.chat,
                on_change = function() DataChip.open(o) end })
        end,
    }}
    buttons[#buttons + 1] = {{ text = _("Close"), id = "close", callback = close }}

    local provider_name = provider
    if o.plugin and o.plugin.getProviderDisplayName and provider then
        local ok, name = pcall(function() return o.plugin:getProviderDisplayName(provider) end)
        if ok and name then provider_name = name end
    end
    dialog = ButtonDialog:new{
        title = T(_("What this chat may send to %1"), provider_name or _("your AI provider"))
            .. "\n" .. _("Tap a row to allow it or leave it out for this chat."),
        buttons = buttons,
        tap_close_callback = function()
            dialog = nil
            if o.on_change then o.on_change() end
        end,
    }
    UIManager:show(dialog)
end

return DataChip
