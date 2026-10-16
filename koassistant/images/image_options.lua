--[[--
The image settings panel (image round S9, B496): the settings a picture is
drawn with, one tap from where pictures are made, and the buttons that draw.
Its rows are the Settings rows themselves (Provider, the model of the
provider that draws, Style, Shape, Detail, and Write the prompt with AI where
a prompt is written), built from the schema through SettingsManager, so a
pick is the setting, saved as Settings → Advanced → Image Generation saves
it, and every picker comes back to the panel with the new value. Opened from
Generate Image's long-press (Image settings…) and from a picture's hold view
in the gallery. docs/image_round_plan.md section 12.
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

--- The panel's rows, by schema id: Provider, the model row of the provider
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

--- Show the panel. spec = { title, writer (the Write the prompt with AI row),
--- actions = { { text, callback }, ... } (each closes the panel first) }.
--- plugin = the KOAssistant instance (its settings, the quick-settings popup
--- and the Style and OpenRouter pickers).
function ImageOptions.show(plugin, spec)
    local UIManager = require("ui/uimanager")
    local ButtonDialog = require("ui/widget/buttondialog")
    local SettingsSchema = require("koassistant.ui.settings_schema")
    local SettingsManager = require("koassistant.ui.settings_manager")
    local ImageGenerator = require("koassistant.images.image_generator")
    spec = spec or {}
    local features = plugin.settings:readSetting("features") or {}
    local drawing = ImageGenerator.effectiveProvider(features,
        require("koassistant.core.config_helper").mainProvider(features), plugin.settings)
    local dialog
    local function reopen() ImageOptions.show(plugin, spec) end
    local buttons = {}
    for _idx, id in ipairs(ImageOptions.rowIds(drawing, spec.writer)) do
        local item = SettingsSchema:getItemById(id)
        local mi = item and SettingsManager:createMenuItem(plugin, item, SettingsSchema)
        if mi then
            local label = mi.text_func and mi.text_func() or mi.text or id
            if item.type == "toggle" then
                label = T(_("%1: %2"), label, mi.checked_func() and _("On") or _("Off"))
            end
            buttons[#buttons + 1] = { {
                text = label,
                enabled = not mi.enabled_func or mi.enabled_func(),
                callback = function()
                    UIManager:close(dialog)
                    if item.type == "toggle" then
                        mi.callback()
                        reopen()
                        return
                    end
                    -- the two pickers that open a dialog of their own come
                    -- back through reopen whatever its exit
                    local items
                    if id == "image_gen_style" then
                        items = plugin:imageStyleItems(reopen)
                    elseif id == "image_gen_model_openrouter" then
                        items = plugin:openRouterImageModelItems(reopen)
                    else
                        items = mi.sub_item_table or (mi.sub_item_table_func and mi.sub_item_table_func()) or {}
                    end
                    plugin:showQuickSettingsPopup(label, ImageOptions.popupItems(items), true, reopen)
                end,
            } }
        end
    end
    local row = {}
    for _idx, a in ipairs(spec.actions or {}) do
        local action = a
        row[#row + 1] = {
            text = action.text,
            callback = function()
                UIManager:close(dialog)
                action.callback()
            end,
        }
        if #row == 2 then
            buttons[#buttons + 1] = row
            row = {}
        end
    end
    if #row > 0 then buttons[#buttons + 1] = row end
    buttons[#buttons + 1] = { {
        text = _("Close"),
        id = "close",
        callback = function() UIManager:close(dialog) end,
    } }
    dialog = ButtonDialog:new{
        title = spec.title or _("Image settings"),
        buttons = buttons,
    }
    UIManager:show(dialog)
    return dialog
end

return ImageOptions
