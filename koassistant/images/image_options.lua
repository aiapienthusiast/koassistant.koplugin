--[[--
The picture popup (B537): what one picture is drawn with, on a tap of Generate
Image, at Illustrate… and from a gallery picture's Image settings…, in the
shape of the scope and source popup (labelled radio groups, the button that
draws at the foot). For this picture: a note, and the X-Ray entries the prompt
writer reads (a passage picture), both gone after the run. Then the settings
(image round S9, B496): Style, Shape, Detail, the provider and model that
draw, Write the prompt with AI where a prompt is written. Those are the
Settings rows themselves, built from the schema through SettingsManager, so a
pick is the setting, saved as Settings → Advanced → Image Generation saves it.
The popup stays open under the pickers it opens (the note box, the entry
list, the provider and model lists), so every exit of a picker returns to it;
a change rebuilds it in place. docs/image_round_plan.md sections 12 and 13.
]]

local _ = require("koassistant.core.gettext")
local T = require("ffi/util").template

local ImageOptions = {}

-- Each image provider's model row (settings_schema.lua)
local MODEL_ROW = {
    openai = "image_gen_model_openai",
    xai = "image_gen_model_xai",
    gemini = "image_gen_model_gemini",
    openrouter = "image_gen_model_openrouter",
}

-- The longest a note or the picked names show on their button
local SHOWN_MAX = 40

--- The settings rows, by schema id: Provider, the model row of the provider
--- that draws (none when nothing can), Style, Shape, Detail, and Write the
--- prompt with AI when with_writer. Pure.
function ImageOptions.rowIds(drawing_provider, with_writer)
    local ids = { "image_gen_provider" }
    if MODEL_ROW[drawing_provider] then ids[#ids + 1] = MODEL_ROW[drawing_provider] end
    ids[#ids + 1] = "image_gen_style"
    ids[#ids + 1] = "image_gen_shape"
    ids[#ids + 1] = "image_gen_detail"
    if with_writer then ids[#ids + 1] = "image_gen_writer" end
    return ids
end

--- A picker's items as the quick-settings popup shows them: a label for an
--- item that only computes one (Custom…). Pure.
function ImageOptions.popupItems(items)
    local out = {}
    for _idx, it in ipairs(items or {}) do
        local copy = {}
        for k, v in pairs(it) do copy[k] = v end
        if not copy.text and copy.text_func then copy.text = copy.text_func() end
        out[#out + 1] = copy
    end
    return out
end

-- A text on one line, cut on a whole character
local function shown(text)
    local flat = text:gsub("%s+", " "):match("^%s*(.-)%s*$")
    local head = require("koassistant.request.scope_resolver").utf8Head(flat, SHOWN_MAX)
    if #head < #flat then head = head .. "…" end
    return head
end

--- The note's button: Add a note…, or the note's first words. Pure.
function ImageOptions.noteLabel(note)
    if not (type(note) == "string" and note:match("%S")) then return _("Add a note…") end
    return T(_("Note: %1"), shown(note))
end

--- The picks' button: Pick X-Ray entries…, or the names picked. Pure.
function ImageOptions.picksLabel(picked)
    if type(picked) ~= "table" or #picked == 0 then return _("Pick X-Ray entries…") end
    return T(_("X-Ray entries: %1"), shown(table.concat(picked, ", ")))
end

--- The popup's rows in order, without widgets. Each:
---   { id, label, kind = "buttons", items = { { id, text, enabled, callback } } }
---   { id, label, kind = "radio", columns, items = { { text, checked, enabled, callback } } }
---   { id, kind = "check", item = { text, checked, callback } }
--- A callback changes a setting or the picture's state and then calls
--- rebuild; one that opens a picker leaves the popup open under it.
--- spec: { writer, note (offer the note row), pickable (PromptWriter.pickable's
--- rows, nil = no picks row), state = { note, picked } (the picture's own) }.
function ImageOptions.rows(plugin, spec, rebuild)
    local SettingsSchema = require("koassistant.ui.settings_schema")
    local SettingsManager = require("koassistant.ui.settings_manager")
    local ImageGenerator = require("koassistant.images.image_generator")
    spec = spec or {}
    local state = spec.state or {}
    local features = plugin.settings:readSetting("features") or {}
    local drawing = ImageGenerator.effectiveProvider(features,
        require("koassistant.core.config_helper").mainProvider(features), plugin.settings)
    local function menuItem(id)
        local item = SettingsSchema:getItemById(id)
        return item and SettingsManager:createMenuItem(plugin, item, SettingsSchema), item
    end
    local function picker(label, items)
        plugin:showQuickSettingsPopup(label, ImageOptions.popupItems(items), true, rebuild)
    end
    -- A schema radio row's options as radio items
    local function radioItems(mi, enabled)
        local out = {}
        for _idx, sub in ipairs(mi and mi.sub_item_table or {}) do
            local s = sub
            local checked = s.checked_func and s.checked_func() or false
            out[#out + 1] = {
                text = s.text, checked = checked, enabled = enabled,
                callback = function()
                    if checked then return end
                    s.callback()
                    rebuild()
                end,
            }
        end
        return out
    end
    local rows = {}

    -- For this picture
    local mine = {}
    if spec.note then
        mine[#mine + 1] = {
            id = "note",
            text = ImageOptions.noteLabel(state.note),
            callback = function()
                ImageGenerator.askNote(state.note, function(text)
                    state.note = text
                    rebuild()
                end)
            end,
        }
    end
    if type(spec.pickable) == "table" and #spec.pickable > 0 then
        mine[#mine + 1] = {
            id = "picks",
            text = ImageOptions.picksLabel(state.picked),
            -- only the prompt writer reads them
            enabled = not spec.writer or features.image_gen_writer ~= false,
            callback = function()
                ImageGenerator.pickEntries(spec.pickable, state.picked, function(names)
                    state.picked = names
                    rebuild()
                end)
            end,
        }
    end
    if #mine > 0 then
        rows[#rows + 1] = { id = "picture", label = _("For this picture"), kind = "buttons", items = mine }
    end

    -- Style: the styles, then Custom…, which asks for the reader's words
    local styles = {}
    for _idx, it in ipairs(plugin:imageStyleItems(rebuild) or {}) do
        local s = it
        local checked = s.checked_func and s.checked_func() or false
        styles[#styles + 1] = {
            text = s.text or (s.text_func and s.text_func()) or "",
            checked = checked,
            callback = function()
                if s.opens_dialog then
                    s.callback()
                    return
                end
                if checked then return end
                s.callback()
                rebuild()
            end,
        }
    end
    rows[#rows + 1] = { id = "style", label = _("Style"), kind = "radio", columns = 2, items = styles }

    local shape_mi = menuItem("image_gen_shape")
    rows[#rows + 1] = { id = "shape", label = _("Shape"), kind = "radio", columns = 2,
        items = radioItems(shape_mi, true) }
    local detail_mi = menuItem("image_gen_detail")
    local detail_on = not (detail_mi and detail_mi.enabled_func) or detail_mi.enabled_func()
    rows[#rows + 1] = { id = "detail", label = _("Detail"), kind = "radio", columns = 3,
        items = radioItems(detail_mi, detail_on) }

    -- Drawn by: the provider and the model that draws, side by side, each
    -- by its value alone (the label says what they are); a tap opens the
    -- Settings row's picker, titled as Settings titles it
    local drawn = {}
    local provider_mi, provider_item = menuItem("image_gen_provider")
    if provider_mi then
        local value = features.image_gen_provider
        if not (type(value) == "string" and value ~= "") then value = provider_item.default end
        local text
        for _idx, o in ipairs(provider_item.options or {}) do
            if o.value == value then text = o.text end
        end
        local title = provider_mi.text_func and provider_mi.text_func() or provider_mi.text
        drawn[#drawn + 1] = { id = "provider", text = text or tostring(value), callback = function()
            picker(title, provider_mi.sub_item_table)
        end }
    end
    local model_id = MODEL_ROW[drawing]
    local model_mi = model_id and menuItem(model_id)
    if model_mi then
        local ModelLists = require("koassistant.request.model_lists")
        local value = features["image_gen_model_" .. drawing]
        if not (type(value) == "string" and value ~= "" and value ~= "default") then
            value = ModelLists.getDefaultImageModel(drawing)
        end
        local title = model_mi.text_func and model_mi.text_func() or model_mi.text
        drawn[#drawn + 1] = { id = "model", text = value or title, callback = function()
            local items
            if model_id == "image_gen_model_openrouter" then
                items = plugin:openRouterImageModelItems(rebuild)
            else
                items = model_mi.sub_item_table
            end
            picker(title, items)
        end }
    end
    rows[#rows + 1] = { id = "drawn", label = _("Drawn by"), kind = "buttons", items = drawn }

    if spec.writer then
        local writer_mi = menuItem("image_gen_writer")
        if writer_mi then
            rows[#rows + 1] = { id = "writer", kind = "check", item = {
                text = writer_mi.text,
                checked = writer_mi.checked_func(),
                callback = function()
                    writer_mi.callback()
                    rebuild()
                end,
            } }
        end
    end
    return rows
end

--- Show the popup. spec = { title, subtitle (a gray line under the title: the
--- passage), writer (the Write the prompt with AI row), note (the note row),
--- pickable (the picks row's entries), state = { note, picked },
--- actions = { { text, callback }, ... } (each closes the popup first) }.
--- plugin = the KOAssistant instance (its settings, the quick-settings popup
--- and the Style and OpenRouter pickers). Returns the shown window.
function ImageOptions.show(plugin, spec)
    local UIManager = require("ui/uimanager")
    local Blitbuffer = require("ffi/blitbuffer")
    local ButtonTable = require("ui/widget/buttontable")
    local CenterContainer = require("ui/widget/container/centercontainer")
    local CheckButton = require("ui/widget/checkbutton")
    local Font = require("ui/font")
    local FrameContainer = require("ui/widget/container/framecontainer")
    local Geom = require("ui/geometry")
    local GestureRange = require("ui/gesturerange")
    local InputContainer = require("ui/widget/container/inputcontainer")
    local MovableContainer = require("ui/widget/container/movablecontainer")
    local RadioButtonTable = require("ui/widget/radiobuttontable")
    local ScrollableContainer = require("ui/widget/container/scrollablecontainer")
    local Size = require("ui/size")
    local TextBoxWidget = require("ui/widget/textboxwidget")
    local TextWidget = require("ui/widget/textwidget")
    local TitleBar = require("ui/widget/titlebar")
    local VerticalGroup = require("ui/widget/verticalgroup")
    local VerticalSpan = require("ui/widget/verticalspan")
    local Screen = require("device").screen
    spec = spec or {}
    spec.state = spec.state or {}

    local current, first_frame_h, scrolled
    local function build()
        local screen_w, screen_h = Screen:getWidth(), Screen:getHeight()
        local dialog_w = math.floor(math.min(screen_w, screen_h) * 0.8)
        local content_w = dialog_w - 2 * Size.padding.large
        local label_face = Font:getFace("cfont", 18)
        local radio_face = Font:getFace("cfont", 20)
        local info_face = Font:getFace("cfont", 16)
        local function rebuild()
            if current then
                scrolled = current._scroll and current._scroll:getScrolledOffset() or nil
                UIManager:close(current)
            end
            build()
        end
        local rows = ImageOptions.rows(plugin, spec, rebuild)
        -- The rows at a width: the column's, or narrower beside a scrollbar
        local function body(width)
            local vgroup = VerticalGroup:new{ align = "left" }
            local function addLabel(text)
                table.insert(vgroup, VerticalSpan:new{ width = Size.padding.default })
                table.insert(vgroup, TextWidget:new{
                    text = text, face = label_face, bold = true, fgcolor = Blitbuffer.COLOR_DARK_GRAY,
                })
                table.insert(vgroup, VerticalSpan:new{ width = Size.padding.small })
            end
            if type(spec.subtitle) == "string" and spec.subtitle ~= "" then
                table.insert(vgroup, VerticalSpan:new{ width = Size.padding.default })
                table.insert(vgroup, TextBoxWidget:new{
                    text = spec.subtitle, face = info_face, width = width,
                    fgcolor = Blitbuffer.COLOR_DARK_GRAY,
                })
            end
            for _idx, row in ipairs(rows) do
                if row.label then addLabel(row.label) end
                if row.kind == "radio" then
                    local layout, line = {}, {}
                    for _j, it in ipairs(row.items) do
                        line[#line + 1] = { text = it.text, checked = it.checked, enabled = it.enabled ~= false, entry = it }
                        if #line == row.columns then
                            layout[#layout + 1] = line
                            line = {}
                        end
                    end
                    if #line > 0 then layout[#layout + 1] = line end
                    table.insert(vgroup, RadioButtonTable:new{
                        radio_buttons = layout,
                        width = width,
                        no_sep = true,
                        sep_width = 0,
                        face = radio_face,
                        show_parent = plugin,
                        parent = plugin,
                        button_select_callback = function(btn)
                            if btn.enabled == false then return end
                            btn.entry.callback()
                        end,
                    })
                elseif row.kind == "buttons" then
                    local buttons, line = {}, {}
                    for _j, it in ipairs(row.items) do
                        line[#line + 1] = { text = it.text, id = it.id, enabled = it.enabled ~= false, callback = it.callback }
                    end
                    if #line > 0 then buttons[#buttons + 1] = line end
                    if #buttons > 0 then
                        table.insert(vgroup, ButtonTable:new{
                            width = width, buttons = buttons, zero_sep = true, show_parent = plugin,
                        })
                    end
                elseif row.kind == "check" then
                    table.insert(vgroup, VerticalSpan:new{ width = Size.padding.default })
                    table.insert(vgroup, CheckButton:new{
                        text = row.item.text, checked = row.item.checked, face = radio_face,
                        width = width, parent = plugin, show_parent = plugin,
                        callback = row.item.callback,
                    })
                end
            end
            table.insert(vgroup, VerticalSpan:new{ width = Size.padding.default })
            return vgroup
        end
        local vgroup = body(content_w)

        -- The buttons that draw, at the foot
        local action_rows, line = {}, {}
        for _idx, a in ipairs(spec.actions or {}) do
            local action = a
            line[#line + 1] = {
                text = action.text,
                callback = function()
                    UIManager:close(current)
                    action.callback()
                end,
            }
            if #line == 2 then
                action_rows[#action_rows + 1] = line
                line = {}
            end
        end
        if #line > 0 then action_rows[#action_rows + 1] = line end
        local actions = #action_rows > 0 and ButtonTable:new{
            width = content_w, buttons = action_rows, zero_sep = true, show_parent = plugin,
        } or nil

        local title_bar = TitleBar:new{
            width = dialog_w,
            align = "left",
            with_bottom_line = true,
            title = spec.title or _("Image settings"),
            title_shrink_font_to_fit = true,
            close_callback = function() UIManager:close(current) end,
        }
        -- Taller than the screen (a landscape screen): the rows scroll, the
        -- title and the buttons that draw stay
        local fixed_h = title_bar:getSize().h + (actions and actions:getSize().h or 0) + 2 * Size.padding.default
        local max_body = math.floor(screen_h * 0.96) - fixed_h
        local body_h = vgroup:getSize().h
        local scroll
        if body_h > max_body then
            vgroup = body(dialog_w - ScrollableContainer:getScrollbarWidth() - 2 * Size.padding.large)
            body_h = vgroup:getSize().h
            scroll = ScrollableContainer:new{
                dimen = Geom:new{ w = dialog_w, h = max_body },
                show_parent = nil, -- set below, once the window exists
                CenterContainer:new{ dimen = Geom:new{ w = dialog_w - ScrollableContainer:getScrollbarWidth(), h = body_h }, vgroup },
            }
        end
        local column = VerticalGroup:new{ align = "left", title_bar }
        if scroll then
            table.insert(column, scroll)
        else
            table.insert(column, CenterContainer:new{ dimen = Geom:new{ w = dialog_w, h = body_h }, vgroup })
        end
        if actions then
            table.insert(column, CenterContainer:new{ dimen = Geom:new{ w = dialog_w, h = actions:getSize().h }, actions })
            table.insert(column, VerticalSpan:new{ width = Size.padding.default })
        end
        local frame = FrameContainer:new{
            radius = Size.radius.window, padding = 0, margin = 0,
            background = Blitbuffer.COLOR_WHITE,
            column,
        }
        local movable = MovableContainer:new{ frame }
        -- The top stays where it opened while rows change (the scope popup's trick)
        local frame_h = frame:getSize().h
        if not first_frame_h then first_frame_h = frame_h end
        movable:setMovedOffset({ x = 0, y = math.floor((frame_h - first_frame_h) / 2) })

        current = InputContainer:new{
            dimen = Geom:new{ x = 0, y = 0, w = screen_w, h = screen_h },
            CenterContainer:new{ dimen = Geom:new{ w = screen_w, h = screen_h }, movable },
        }
        current._frame = frame
        current._rows = rows
        if scroll then
            current._scroll = scroll
            current.cropping_widget = scroll
            scroll.show_parent = current
            if scrolled then scroll:setScrolledOffset(scrolled) end
        end
        current.ges_events = {
            TapClose = { GestureRange:new{ ges = "tap", range = Geom:new{ w = screen_w, h = screen_h } } },
        }
        function current:onTapClose(_arg, ges_ev)
            if ges_ev.pos:notIntersectWith(frame.dimen) then UIManager:close(self) end
            return true
        end
        function current:onClose()
            UIManager:close(self)
            return true
        end
        function current:onCloseWidget()
            UIManager:setDirty(nil, function() return "ui", frame.dimen end)
        end
        function current:onShow()
            UIManager:setDirty(self, function() return "ui", frame.dimen end)
            return true
        end
        UIManager:show(current)
    end
    build()
    return current
end

return ImageOptions
