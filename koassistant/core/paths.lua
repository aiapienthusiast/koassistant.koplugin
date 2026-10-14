-- The plugin's folders, from this file's own location: it sits at
-- koassistant/core/paths.lua, two levels below the plugin's root. ONE copy:
-- every module that needs the root (the reader's files, locale/, fonts/,
-- _meta.lua, the built-in prompts) asks here instead of reading its own
-- location, which stopped meaning the root when the modules moved into folders.
local Paths = {}

local here = debug.getinfo(1, "S").source:match("^@(.*/)") or "./"
local root, found = here:gsub("koassistant/core/$", "")
if found ~= 1 then
    -- Never guess: the updater moves the folder this names aside, and the
    -- reader's files are read from it.
    error("koassistant: paths.lua expected under koassistant/core/, found at " .. here)
end
if root == "" then root = "./" end
Paths.ROOT = root                                    -- ends with "/"
Paths.CODE = Paths.ROOT .. "koassistant/"            -- the modules and the built-in prompts

return Paths
