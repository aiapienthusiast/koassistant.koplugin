-- B533 S2, capitals only, on the real reader: The Drowned (Mock Series 3) is
-- written "the drowned trees" and "the Drowned" in "Rented Quiet", and "the
-- drowned rows" in "What the Salt Takes". Set to capitals only, it keeps
-- only "the Drowned": in the underlines, in the name index's counts
-- (Chapter Appearances, Mentions) and in KOReader's own search after a
-- mention (the case-sensitive pattern on crengine's regex engine).
local S = dofile(os.getenv("KOA_PLUGIN") .. "/tests/scenarios/boot.lua")
S.features({ xray_marking_density = "all" }) -- every occurrence marked

local ui = S.open("Mock Series 3")
local XrayParser = require("koassistant.xray.xray_parser")
local XrayIndex = require("koassistant.xray.xray_index")
local XrayBrowser = require("koassistant.xray.xray_browser")
local ActionCache = require("koassistant.artifacts.action_cache")
local file = ui.document.file

local function drownedMarks()
    local out = {}
    for _idx, m in ipairs(S.marks()) do
        if m.name == "The Drowned" then out[#out + 1] = m.words or "?" end
    end
    return out
end

local function theDrowned()
    local data = XrayParser.parse(ActionCache.getXrayCache(file).result)
    XrayParser.mergeUserAliases(data, ActionCache.getUserAliases(file))
    for _idx, item in ipairs(data.characters or {}) do
        if item.name == "The Drowned" then return item end
    end
end

local rented = S.chapter("Rented Quiet")
local salt
for _idx, t in ipairs(ui.toc.toc or {}) do
    if t.title and t.title:find("What the Salt Takes", 1, true) then salt = t.page end
end

-- ── Any case (the default) ──
local before = drownedMarks()
S.note("marked, any case:", table.concat(before, " | "))
local any_lower, any_cap = false, false
for _idx, w in ipairs(before) do
    if w:find("drowned", 1, true) then any_lower = true end
    if w:find("Drowned", 1, true) then any_cap = true end
end
S.check(any_lower and any_cap, "any case: \"the drowned trees\" and \"the Drowned\" are both underlined")
S.shot("any_case")

local item = theDrowned()
local set = XrayParser.matchTermSet(item)
local layout = { forms = XrayIndex.scan(ui.document, set.all, 1, ui.document.info.number_of_pages) }
local counts = XrayIndex.entityPages(layout, set, nil)
S.check(counts and counts[rented] and counts[salt], "any case: the index counts \"Rented Quiet\" and \"What the Salt Takes\"")

-- ── Match capitals only, recorded as the names screen records it ──
local all = ActionCache.getUserAliases(file)
local entry = all["The Drowned"] or { add = {}, ignore = {} }
entry.case = { ["the drowned"] = "capitals" }
all["The Drowned"] = entry
ActionCache.setUserAliases(file, all)

S.chapter("Rented Quiet")
local after = drownedMarks()
S.note("marked, capitals only:", table.concat(after, " | "))
local only_cap = #after > 0
for _idx, w in ipairs(after) do
    if not w:find("Drowned", 1, true) then only_cap = false end
end
S.check(only_cap, "capitals only: only \"the Drowned\" is underlined")
S.shot("capitals_only")

item = theDrowned()
set = XrayParser.matchTermSet(item)
S.check(set and set.caps ~= nil, "the matcher holds the capitals rule")
counts = XrayIndex.entityPages(layout, set, nil)
S.check(counts and counts[rented] == 1 and counts[salt] == nil,
    "capitals only: the index counts one in \"Rented Quiet\", none in \"What the Salt Takes\"")

-- ── KOReader's search after a mention: the browser's pattern ──
local pattern, cased = XrayBrowser._buildSearchPattern(XrayParser.collectSearchTerms(item))
S.note("pattern:", tostring(pattern), "case-sensitive:", tostring(cased))
S.check(cased == true and type(pattern) == "string", "the session is case-sensitive with a pattern")
local flags = 0x0001
for _idx, st in ipairs(ui.search.search_types or {}) do
    if st.regex then flags = st.flags or flags end
end
local plain = ui.document:findAllText("the drowned", true, 3, 100, false, 0x00FF) or {}
local hits = pattern and ui.document:findAllText(pattern, false, 3, 100, true, flags) or {}
S.note("any-case search:", #plain, "| the pattern:", #hits)
S.check(#plain == 3, "any case, KOReader's search finds three")
S.check(#hits == 1, "the pattern, case-sensitive, finds one: \"the Drowned\"")
if hits[1] then
    S.note("the hit:", tostring(hits[1].matched_text or hits[1].text))
end

-- ── Match any case puts both back ──
entry.case = nil
all["The Drowned"] = entry
ActionCache.setUserAliases(file, all)
S.chapter("Rented Quiet")
local again = drownedMarks()
local back_lower = false
for _idx, w in ipairs(again) do
    if w:find("drowned", 1, true) then back_lower = true end
end
S.check(back_lower, "Match any case: \"the drowned trees\" is underlined again")

S.finish()
