-- Wiki shots for the Backups and Updates page (docs/assets/wiki_shotlist.txt)
local S = dofile(os.getenv("KOA_PLUGIN") .. "/tests/scenarios/boot.lua")
local W = dofile(S.PLUGIN .. "/tests/scenarios/wiki_lib.lua")(S)

S.open(S.shotsBook("standalone") or "Mock Series 3")
W.prose()

-- Two backups and a restore point in the run's home, made at three moments
-- (the clock stands at each for its call: names, records and file dates agree)
local BackupManager = require("koassistant.storage.backup_manager")
BackupManager:_ensureBackupDirectory()
local function at(stamp, fn)
    local y, mo, d, h, mi, se = stamp:match("^(%d%d%d%d)(%d%d)(%d%d)_(%d%d)(%d%d)(%d%d)$")
    local t = os.time({ year = tonumber(y), month = tonumber(mo), day = tonumber(d),
        hour = tonumber(h), min = tonumber(mi), sec = tonumber(se) })
    local real_time, real_date = os.time, os.date
    os.time = function(tt) if tt then return real_time(tt) end return t end --luacheck: ignore
    os.date = function(fmt, tt) return real_date(fmt, tt or t) end --luacheck: ignore
    local ok, r = pcall(fn)
    os.time, os.date = real_time, real_date --luacheck: ignore
    assert(ok, r)
    return r
end
local r1 = at("20261019_211502", function()
    return BackupManager:createBackup({ include_settings = true, include_configs = true })
end)
local r2 = at("20261021_090233", function()
    return BackupManager:createBackup({ include_settings = true, include_configs = true, include_content = true })
end)
local r3 = at("20261022_183010", function() return BackupManager:createRestorePoint() end)
S.check(r1 and r1.success and r2 and r2.success, "two backups made")
S.note("restore point:", tostring(r3 and (r3.success or r3.error)))
-- each file dated by its name, as if made then
local lfs = require("libs/libkoreader-lfs")
for entry in lfs.dir(BackupManager.BACKUP_DIR) do
    local y, mo, d, h, mi, se = entry:match("_(%d%d%d%d)(%d%d)(%d%d)_(%d%d)(%d%d)(%d%d)%.koa$")
    if y then
        local t = os.time({ year = tonumber(y), month = tonumber(mo), day = tonumber(d),
            hour = tonumber(h), min = tonumber(mi), sec = tonumber(se) })
        lfs.touch(BackupManager.BACKUP_DIR .. "/" .. entry, t, t)
    end
end

-- Settings → Backup & Reset → View Backups
S.menuPath({ "KOAssistant", "Backup & Reset", "View Backups" })
S.note("backups:", table.concat(S.texts(), " | "))
S.wiki("backups-view-backups.png")
S.closeAll()

-- Settings → Backup & Reset → Reset Settings... open
S.menuPath({ "KOAssistant", "Backup & Reset", "Reset Settings..." })
S.wiki("reset-settings-menu.png")
S.closeAll()

-- Create Backup: what to include, at its defaults
S.menuPath({ "KOAssistant", "Backup & Reset", "Create Backup" })
S.note("create:", table.concat(S.texts(), " | "))
S.wiki("backup_options.png")
S.closeAll()

-- Restore from Backup: what to restore, for the newer backup
S.menuPath({ "KOAssistant", "Backup & Reset", "Restore from Backup" })
S.tap({ "^koassistant_backup_20261021" })
S.tap({ "^Restore" })
S.note("restore:", table.concat(S.texts(), " | "))
S.wiki("restore_options.png")
S.finish()
