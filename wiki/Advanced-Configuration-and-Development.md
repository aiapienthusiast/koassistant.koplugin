# Advanced Configuration and Development

The configuration files for things the Settings menu does not cover, the debugging switches, the request inspector that shows exactly what a request contains without a device, and what a developer needs to run the test suite or work off the main branch.

## configuration.lua

Most settings are managed in the Settings menu (Tools → KOAssistant). The main reason to use `configuration.lua` is **custom API endpoints**, such as proxies and regional mirrors, for the built-in providers. Copy `configuration.lua.sample` to `configuration.lua` in the plugin folder and uncomment what you need:

```lua
return {
    -- Default provider/model (used until changed in the Settings UI)
    -- provider = "openai",
    -- model = "gpt-5.5",

    -- Custom API endpoints: override the default URL for any built-in provider
    provider_settings = {
        openai = {
            base_url = "https://your-proxy.example.com/v1/chat/completions",
        },
        anthropic = {
            base_url = "https://your-proxy.example.com/v1/messages",
        },
        gemini = {
            -- Gemini base_url is the prefix; the handler appends /{model}:generateContent
            base_url = "https://your-proxy.example.com/v1beta/models",
        },
    },

    -- Feature defaults (Settings UI values take priority)
    features = {
        enable_streaming = true,
        -- Reasoning is per model. Optional global stance: "minimal" | "default" | "maximum".
        -- Per-model overrides are keyed "provider/model". Usually set this in the UI instead.
        reasoning_prefs = {
            stance = "default",
            -- models = { ["anthropic/claude-opus-5-5"] = { state = "on", effort = "high" } },
        },
    },
}
```

The sample documents more feature keys (display, translation, streaming, behavior, web search, debug and others); all are optional. **Priority:** Settings menu > `configuration.lua` > built-in defaults. Once a setting is changed in the menu, the menu's value wins over the file.

**The file is not actively maintained.** Development moved to the Settings menu and the file has drifted behind it. `provider_settings` (custom endpoints) and the documented `features` keys are the supported path. Beyond those, some keys are accepted without ever taking effect, because a few parts of the plugin read their values from the saved settings rather than from this file. One confirmed case: `features.custom_providers` does nothing on an existing install (it is read only on a first run, before any settings exist); add custom providers through **Settings → Model → Add custom provider...** instead. If something you set here does not take effect, [open an issue](https://github.com/zeeyado/koassistant.koplugin/issues) saying what you set and what happened; these are fixed one key at a time, and only reported gaps get fixed.

**Proxy services and custom providers are different things.** A proxy or relay that speaks each provider's own API format (an OpenAI-compatible endpoint for OpenAI, an Anthropic-compatible one for Anthropic) is a `base_url` override in `provider_settings`, not a custom provider. Custom providers (**Settings → Model → Add custom provider...**) are services with their own model catalog that speak the OpenAI-compatible format; see [Providers and Models](Providers-and-Models).

## Other files in the plugin folder

- `apikeys.lua`: file-based API keys, an alternative to entering them in Settings ([Getting Started](Getting-Started)).
- `custom_actions.lua`: actions defined in a file rather than in the action editor ([Actions and Menus](Actions-and-Menus)).
- `custom_models.lua`: models and capabilities for providers the plugin does not know, from `custom_models.lua.sample` ([Providers and Models](Providers-and-Models)).
- `behaviors/` and `domains/`: your own behavior and domain files, which override the built-in ones of the same name ([Prompts, Behaviors and Domains](Prompts-Behaviors-and-Domains)).

Updates preserve all of them ([Backups and Updates](Backups-and-Updates)). A file that is not text (a macOS `._name` companion file copied along with a folder, for one) is skipped by the behavior and domain loaders, so it cannot break requests.

## Debugging

The debug rows sit under **Settings → Advanced**:

- **Console Debug**: KOAssistant's own tracing in the terminal and in `crash.log`. **For a bug report, this is the switch that fills `crash.log`.** The plugin's tracing is silent by default; Console Debug turns it on without raising KOReader's global log level, so the log stays readable instead of drowning in KOReader's per-repaint output. KOReader's own verbose logging (its gear menu → Help → Developer options) also turns the tracing on, but the request and response dumps below come from Console Debug alone. With it on, every API response prints its token usage: input tokens, output tokens, total, and cache hits (cache read and cache write) when the provider reports them, for streaming and non-streaming answers alike.
- **Show Debug in Chat**: the full request body sent to the provider, the raw response and the configuration (provider, model, temperature and the rest), in the chat window.
- **Debug Detail Level**: Minimal, Names or Full.
- **Truncate Large Content (debug)**: long content (book text, saved results) in debug output is cut to its first and last 1,500 characters or so with a notice.
- **AI Book Tools: Show Lookups (debug)**: appends the AI's book lookups and their raw results to each answer; may include book text. See [Reasoning, Web Search and Book Tools](Reasoning-Web-Search-and-Book-Tools).
- **Test Connection**: checks that the current provider's key and endpoint answer.

The debug view and the "Everything (debug)" export level are under review for consistency; some metadata may not appear in exports as expected.

## The request inspector

The test suite includes an interactive web inspector that lets you test and experiment with KOAssistant on a computer, without KOReader:

- test API keys before using them on the e-reader;
- try behaviors, domains, temperature and reasoning;
- see exactly what is sent to each provider;
- send real requests and read the responses, including multi-turn chats with history;
- simulate every context (a highlight, book metadata, library selections);
- try your custom actions before putting them on the device;
- load your actual `domains/` folder.

**Requirements:** Lua 5.3 or newer with LuaSocket, LuaSec and dkjson; a clone from GitHub (the tests are left out of release zips to keep them small); the setup in `tests/README.md`.

```bash
cd /path/to/koassistant.koplugin

# Put the rocks on Lua's path first, matching your `lua -v`.
# Without this the web UI fails at startup with a setoption error.
eval "$(luarocks --lua-version 5.5 path)"

lua tests/inspect.lua --web
# Then open http://localhost:8080 in a browser
```

The command-line modes need no browser and are the quickest way to see what a change does to a request:

```bash
lua tests/inspect.lua --list                 # providers available for inspection
lua tests/inspect.lua --inspect anthropic    # the request for one provider
lua tests/inspect.lua --compare openai gemini
lua tests/inspect.lua --export anthropic     # the same thing as JSON
```

The inspector reads your actual settings file (`koassistant_settings.lua`), so run KOReader once on the same computer first, or restore a backup from your device there ([Backups and Updates](Backups-and-Updates#moving-settings-to-another-device)), to work with your real languages, behavior and temperature.

## For developers

The test suite lives in `tests/` and is left out of release zips, so clone the repository. `tests/README.md` has the setup.

```bash
lua tests/run_tests.lua --unit   # unit tests, no API calls
lua tests/run_tests.lua --full   # provider tests, real API calls
lua tests/inspect.lua anthropic  # the request one provider would get
lua tests/inspect.lua --web      # the interactive web UI
```

The plugin runs on KOReader's LuaJIT, which has Lua 5.1's limits (60 upvalues per function, 200 locals), so a file that loads under a desktop Lua can still fail to load on the device; `luacheck .` and the unit tests are the first checks, and the wiki's own rules (links, menu paths, the generated Settings Reference) are among them. Running off the main branch: clone, or Code → Download Zip, and install as in [Getting Started](Getting-Started); the updater leaves a git checkout alone. **Settings → Advanced → Setup Wizard v2 (dev)** opens the next setup wizard, which is still being built and is not what a new install sees.

## Related

- [Troubleshooting](Troubleshooting): the problems the debug switches help with.
- [Providers and Models](Providers-and-Models): custom providers, custom models, endpoints.
- [Backups and Updates](Backups-and-Updates): what updates preserve, moving a configuration to a computer.
- [Contributing](Contributing): pull requests, the wiki's sources, translations.
