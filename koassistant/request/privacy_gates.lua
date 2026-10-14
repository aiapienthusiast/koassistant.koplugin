--[[
The ONE place that decides whether a kind of the reader's data may go into a
request (docs/data_access_picture.md section 4.5, slice 1, B074 / B395).

Pure: everything comes in through `ctx`, nothing is read from KOReader here.
The sites that used to decide for themselves (the extractor, the pre-flight,
the Scope chip, the attachments, the tool runner, the background X-Ray check,
the merge check, the library dialog, the multi-book loop, the update re-check,
the X-Ray browser, the unified popup) ask `resolve` / `allows` instead, and
tests/unit/test_privacy_gates.lua fails when any other file compares a privacy
switch or walks `trusted_providers` itself (`-- raw-gate: <reason>` escapes).

Today's semantics (slice 1, behaviour unchanged except that every site judges
trust against the provider the request really goes to, `dispatchProvider`):
  1. the book's own value (Book Settings ▸ Privacy) wins both ways;
  2. a trusted provider counts every global switch as on;
  3. else the global switch: reading position is on unless false, every other
     kind on only when true.
The states are the model's, so slice 2 (Ask / Allow / Never, the question)
changes this file and the funnel, not the sites: today an unset switch reads
as "off"; slice 2 reads it as "ask".
]]

local Gates = {}

--- The kinds of data that can leave the device (section 1 of the picture).
--- nearby_text is the eighth kind (ruled 2026-10-14): the bounded text around
--- a tap; ungated today, its own value in slice 2.
Gates.KINDS = { "book_text", "highlights", "annotations", "notebook", "position",
    "habits", "book_list", "nearby_text" }

--- Each kind's global switch (today's keys; the names stay in slice 2).
Gates.GLOBAL_KEY = {
    book_text   = "enable_book_text_extraction",
    highlights  = "enable_highlights_sharing",
    annotations = "enable_annotations_sharing",
    notebook    = "enable_notebook_sharing",
    position    = "enable_basic_stats",
    habits      = "enable_advanced_stats",
    book_list   = "enable_library_scanning",
}

--- Is this provider on the trusted list? One copy.
function Gates.isTrusted(features, provider)
    if type(features) ~= "table" or not provider then return false end
    if type(features.trusted_providers) ~= "table" then return false end
    for _idx, id in ipairs(features.trusted_providers) do
        if id == provider then return true end
    end
    return false
end

-- The global switch's state for a kind: "allow" or "off".
local function globalState(features, kind)
    features = features or {}
    if kind == "nearby_text" then return "allow" end
    if kind == "position" then
        if features.enable_basic_stats ~= false then return "allow" end
        return "off"
    end
    if kind == "highlights" then
        -- allowing notes allows highlights: the pairing the globals have
        if features.enable_highlights_sharing == true
                or features.enable_annotations_sharing == true then
            return "allow"
        end
        return "off"
    end
    local key = Gates.GLOBAL_KEY[kind]
    if key and features[key] == true then return "allow" end
    return "off"
end

--- Whether a kind may go into the request, and which layer said so.
--- ctx.features  the settings the request runs under (configuration.features,
---               or the extractor's own settings table)
--- ctx.provider  the provider the request really goes to (dispatchProvider)
--- ctx.book      the book's own values, BookSettings.effectivePrivacyOverrides
---               (nil = none known); a deny beats everything, trust included
--- @return string state "allow" | "never" | "off"; string layer "book" | "trusted" | "global"
function Gates.resolve(kind, ctx)
    ctx = ctx or {}
    local book = ctx.book
    if type(book) == "table" and book[kind] ~= nil then
        if book[kind] == true then return "allow", "book" end
        return "never", "book"
    end
    if kind ~= "nearby_text" and Gates.isTrusted(ctx.features, ctx.provider) then
        return "allow", "trusted"
    end
    return globalState(ctx.features, kind), "global"
end

--- The yes-or-no every site needs.
function Gates.allows(kind, ctx)
    local state = Gates.resolve(kind, ctx)
    return state == "allow"
end

--- Every kind's state for a book, for the surfaces (the tile, the screen).
function Gates.summary(ctx)
    local out = {}
    for _idx, kind in ipairs(Gates.KINDS) do
        local state, layer = Gates.resolve(kind, ctx)
        out[kind] = { state = state, layer = layer }
    end
    return out
end

--- The kinds a stored artifact was built from, by its stamps. A missing text
--- stamp means built from text (the legacy rule); the highlights stamp falls
--- back to the old annotations stamp; the annotations stamp counts only on
--- caches that tracked both.
--- @return table { book_text = boolean, highlights = boolean, annotations = boolean }
function Gates.stampedKinds(entry)
    entry = entry or {}
    return {
        book_text = entry.used_book_text ~= false,
        highlights = entry.used_highlights == true
            or (entry.used_highlights == nil and entry.used_annotations == true),
        annotations = entry.used_annotations == true and entry.used_highlights ~= nil,
    }
end

--- The book's own values for ctx.book, from a DocSettings or the facade a
--- site already holds. Never throws; nil when nothing is known.
function Gates.overridesOf(ds)
    if not ds then return nil end
    local ok, out = pcall(function()
        return require("koassistant.books.book_settings").effectivePrivacyOverrides(ds)
    end)
    if ok and type(out) == "table" then return out end
    return nil
end

--- The book's own values for ctx.book, by path (nil = the open book of `ui`).
--- Never throws; nil when nothing is known.
function Gates.bookOverrides(path, ui)
    local ok, ds = pcall(function()
        return require("koassistant.storage.doc_settings").resolve(path, ui)
    end)
    if not (ok and ds) then return nil end
    return Gates.overridesOf(ds)
end

--- The provider a request really goes to, the way the bake applies it: a run
--- option's picked model beats the action's own pin, then a pending one-shot
--- model pick, then the Quick preset's model (only for an action that accepts
--- Quick), then a usable global tier pin for the action's tier hint, then the
--- base provider. Judging trust against anything earlier let data extracted
--- under a trusted provider's bypass go to an untrusted one (audit v0.20.0
--- finding C4 and its re-openings). Reads only; consumption stays in the bake.
--- quick_model_fn resolves the Quick preset's model (the dialogs module's
--- resolveQuickPresetModel); when absent, the loaded dialogs module's is used.
function Gates.dispatchProvider(features, action, base_provider, quick_model_fn)
    features = features or {}
    local rv = features._run_variant
    if type(rv) ~= "table" then rv = nil end
    if rv and rv.provider then return rv.provider end
    if action and action.provider then return base_provider end
    -- The *_active consumables are set just-in-time at dispatch; before that
    -- point (the freeform Send's scope check) the same pending state lives in
    -- the _session_* chip keys. Direct entries drop inherited chip state, then
    -- may seed the quick consumable from the Quick Answer default.
    local override = features._model_override_active or features._session_model
    if override and override.provider then return override.provider end
    local quick = features._quick_answer_active or features._session_quick_answer
    if rv and rv.quick ~= nil
            and not require("koassistant.request.run_options").isModelOnly(action) then
        quick = rv.quick
    end
    if quick and action and action.accept_quick_answer ~= true then quick = nil end
    if quick then
        local resolver = quick_model_fn
        if not resolver then
            local D = package.loaded["koassistant.ui.dialogs"]
            resolver = D and D.resolveQuickPresetModel or nil
        end
        local preset = resolver and resolver(features, base_provider)
        if preset and preset.provider then return preset.provider end
    end
    -- Per-action tier hint (weakest rung): a usable GLOBAL tier pin re-points
    -- the dispatch provider; ladder hits return the base provider unchanged.
    if features.use_action_tiers ~= false and action and action.model_tier
            and not action.provider and not action.model then
        local p2 = require("koassistant.request.model_lists")
            .resolveTierTarget(base_provider, action.model_tier)
        if p2 then return p2 end
    end
    return base_provider
end

return Gates
