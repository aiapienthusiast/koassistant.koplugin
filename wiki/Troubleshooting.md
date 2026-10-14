# Troubleshooting

What to check when something does not work, in the order people usually need it: missing data, text extraction, fonts and icons, keys and connections, menus, and the reset options. Most problems are a setting that is still off; the first two sections cover almost all reports.

## Features not working or empty data

If Analyze Notes, Connect (With Notes), X-Ray or Recap seem to ignore your reading data: **most reading data is opt-in.** Check **Settings → Privacy & Data** and enable the setting the feature needs.

| Feature not working | Enable this setting |
|---|---|
| Analyze Notes is blocked ("This action requires access to your highlights or annotations") | Allow Highlights or Allow Annotation Notes |
| Connect (With Notes) ignores your notes | Allow Annotation Notes and Allow Notebook |
| Recap misses your highlights | Allow Highlights (or Allow Annotation Notes). X-Ray does not use highlights: it reads the book's text only |
| X-Ray is blocked ("Text extraction is required to generate this artifact") | Allow Text Extraction (**Settings → Privacy & Data → Text Extraction**), or use X-Ray (Simple) instead |
| Document Analysis or Document Summary is blocked | Allow Text Extraction |
| Recap uses only the book's title | Allow Text Extraction |
| Explain in Context or Analyze in Context use only the title | Allow Text Extraction |
| Analyze in Context ignores your highlights or notes | Allow Highlights; Allow Annotation Notes adds your notes, Allow Notebook your notebook |
| A custom action with `{highlights}` stays empty | Allow Highlights (or Allow Annotation Notes), and the action's own "Allow highlight use" flag |
| A custom action with `{notebook}` stays empty | Allow Notebook, and the action's own "Allow notebook use" flag |
| A custom action with `{book_text}` stays empty | Allow Text Extraction, and the action's own "Allow text extraction" flag |

**Why:** personal data (highlights, annotations, notebook) is not shared with AI providers by default; you opt in. Highlights, annotations, notebook and text extraction can each be set for one book in **Book Settings → Privacy**, and a book set to deny wins over the setting here, even for a trusted provider. The whole model is on [Privacy and Data](Privacy-and-Data).

Actions that use document text still work when text extraction is off: they do not fail, the AI is told to use its training knowledge and to be honest about what it does not recognize. For well-known books that often gives reasonable results; for obscure works or papers, enable text extraction. With text extraction on and a provider and model that support tool calls, Explain in Context and Analyze in Context can search the book for the passages they need (**Smart retrieval** in their source popup) instead of sending a full extraction; see [Reasoning, Web Search and Book Tools](Reasoning-Web-Search-and-Book-Tools).

**Quick fix:** **Settings → Privacy & Data → Preset: Full** turns on all data sharing at once; then enable **Allow Text Extraction** separately, since the preset leaves it alone and most rows above need it.

**See what an action needs:** **Settings → Display Settings → Emoji → Emoji Data Access Indicators** adds a suffix to each action's name showing what it accesses (📄 🔖 📝 📓 📚 📊 🌐; the legend is on [Privacy and Data](Privacy-and-Data#seeing-what-an-action-uses)). It needs an emoji font, below.

## Text extraction not working

If Recap, Explain in Context, Analyze in Context or a custom action with `{book_text}` or `{full_document}` return empty or generic answers based only on the title (X-Ray blocks generation entirely without it; X-Ray (Simple) is the alternative):

**Text extraction is off by default.** Turn it on by hand:

1. Open **Settings → Privacy & Data → Text Extraction**.
2. Enable **Allow Text Extraction**, the master switch.
3. A notice explains the token cost; that is expected.

For a custom action, also check that the action has **Allow text extraction** on in its settings, and that its prompt uses a text placeholder (`{book_text_section}` or `{full_document_section}`).

Why it is off by default: extraction sends the book's content to the provider, raises token use and cost, some readers prefer AI knowledge only, and the content may be sensitive. Without it most actions degrade rather than fail: the AI is told that no document text was provided and asked to use its knowledge of the work, with a guard against inventing details for works it does not recognize. X-Ray, Document Summary and Document Analysis are the exception: they do not run without extraction ([Privacy and Data](Privacy-and-Data#when-an-action-is-blocked)).

**Quick check:** if a Recap or a context-aware highlight action answers from the book's title and author alone, extraction is not on. X-Ray shows a blocking message with instructions.

## Emoji font setup

Emoji icons in the plugin's menus and buttons (Emoji Menu Icons, Emoji Data Access Indicators) need an emoji font installed in KOReader, which ships none. The icons work in menus, the action manager, the X-Ray browser and chat-window buttons; they do not render inside the Markdown chat view, whose renderer (MuPDF) has no per-glyph font fallback. That is a KOReader limitation.

**The short route:** **Settings → Display Settings → Emoji → Emoji Font** installs the bundled Noto Emoji font into KOReader's fonts folder, enables it as a UI fallback font and asks for a restart; after the restart the same row shows a display test whose **Yes, enable** turns the icons on. The row's label says where you are (Not Installed, Restart KOReader, Installed). If the icons are on and no emoji font is there, the plugin offers the install once when it starts. The steps below are the same thing by hand.

**Step 1, install the font.** KOAssistant carries a copy in its own folder, `koassistant.koplugin/fonts/NotoEmoji-Regular.ttf`; you can also download **Noto Emoji** (monochrome, `.ttf`) from [Google Fonts](https://fonts.google.com/noto/specimen/Noto+Emoji): `NotoEmoji-Regular.ttf`, not Noto Color Emoji, which KOReader's text renderer cannot use. Copy it to KOReader's fonts folder (KOReader does not look for fonts inside plugin folders) and restart KOReader:

| Platform | Font folder |
|---|---|
| Kobo | `/.adds/koreader/fonts/` |
| Kindle | `koreader/fonts/` (on the USB root) |
| PocketBook | `/applications/koreader/fonts/` |
| Android | `/koreader/fonts/` on device storage |

On Android, KOReader's **Enable system fonts** does not help here: the only emoji font the Additional UI fallback fonts menu offers is one named Noto Emoji, and Android's own is Noto Color Emoji, so copy the file as on the other platforms.

**Step 2, enable it as a UI fallback font.** Installing the file is not enough: from any screen, open KOReader's gear menu → **Device** → **Additional UI fallback fonts**, check **Noto Emoji**, and restart when asked.

**Step 3, enable the icons in KOAssistant:** **Settings → Display Settings → Emoji → Emoji Menu Icons** and, if you want them, **Emoji Data Access Indicators**.

Platform notes: Android, Kobo and PocketBook: copy the file, enable it as a fallback. Kindle has limited emoji support; some glyphs may stay question marks even with the font installed, and if results are poor, turn the emoji options off.

Still not working? The font must be Noto Emoji itself (the fallback menu lists no other emoji font); the font must be enabled under Additional UI fallback fonts, not just copied; restart KOReader fully, not just the book; as a last resort turn Emoji Menu Icons off, the plugin works without them.

## Font issues with Arabic and other right-to-left scripts

If text renders wrongly in the Markdown view, switch to plain text: on the fly with the **MD ON / TXT ON** button in the chat window, or for good with **Settings → Display Settings → Rendering → View Mode → Plain Text**. The Markdown view uses KOReader's MuPDF HTML renderer, which lacks per-glyph font fallback; plain text uses KOReader's native text rendering with proper font support, and keeps headers, bold and lists readable ([Chat Windows](Chat-Windows#markdown-and-plain-text)).

Right-to-left answers already switch to plain text on their own (dictionary and translate windows by their language, chat and artifact windows by their content), unless you turned the automatic switches off ([Languages](Languages#right-to-left-scripts)).

## "No API key found"

Add the key for the selected provider in **Settings → API Keys & Auth** or in `apikeys.lua`. A key still set to a placeholder from `apikeys.lua.sample` (such as `YOUR_GEMINI_API_KEY`) counts as no key. Pasted keys are cleaned on read: spaces, line breaks (including one in the middle of the key, which is how a key copied from a wrapped text file usually fails) and invisible characters are dropped, so a key saved with them starts working without re-entering it; saving a key in Settings says how many stray characters it removed.

Once any provider has a key, the provider pickers (inside the **Settings → Model** row and in Quick Settings) list only the providers that have one, plus keyless ones such as Ollama and the current provider marked "(no key)"; **Show all providers** at the end of the list shows the rest. A provider missing from the list has no key yet.

## No response or a timeout

1. Check the internet connection.
2. Read the error: a provider's refusal names the provider and the model, and when the cause is a known one (a rate limit, an account out of credits, a request too large for the model) one tip says what to do. **Settings → Advanced → Console Debug** also writes the provider's own error text to `crash.log`.
3. Try **Settings → Advanced → Test Connection**.
4. Be patient with very long requests: the plugin waits up to 15 minutes for the provider to send something, so a big X-Ray or a full-document run on a slow model is not cut off early.
5. If the provider stopped the answer for a reason of its own (a content filter, a recitation block, a refusal), the reply says so by name instead of reporting a broken response; a partial answer is kept and marked as cut short, never saved as complete. For Gemini, see **Settings → Advanced → Provider Settings → Gemini Content Filter**.

## Streaming not working

Check **Settings → Chat & Export Settings → Streaming**; some providers differ in what they support. Dictionary and translate windows also have their own **Enable Streaming** row (under **Settings → Dictionary Settings** and **Settings → Translate Settings**), and answers shown in the Minimal Popup never stream.

## The wrong model is used

Check the **Settings → Model** row for the current global default. When you switch providers, the model resets to that provider's default. If a chat still uses an unexpected model, something is redirecting that request: the action's own provider and model (set in its editor), a per-action tier hint (**Settings → Advanced → Faster Models for Quick Actions** turns those off), a global tier pin (**Settings → Advanced → Tier Models (Global)**), the Quick Answer preset's **Model override**, or a model picked for one run by holding Send or the action. See [Providers and Models](Providers-and-Models).

## Chats not saving

Check the auto-save rows under **Settings → Chat & Export Settings**, or save by hand with the chat window's Save button. Dictionary lookups and translations are not auto-saved by default: **Settings → Dictionary Settings → Disable Auto-save for Dictionary** and **Settings → Translate Settings → Disable Auto-Save for Translate** start on. See [Conversations, Notebooks and Export](Conversations-Notebooks-and-Export).

## Bypass or highlight menu actions do not appear

KOReader's own text selection settings can get in the way. In a book, open KOReader's gear menu → Taps and gestures → Long-press on text:

- **Dictionary on single word selection** must be on for dictionary bypass to work; off, a single word is handled like a longer selection (highlight bypass when that is on, otherwise the highlight menu).
- The long-press action chosen below it must be **Ask with popup dialog** for the highlight menu actions and highlight bypass to work; with any other choice KOReader skips its highlight menu and KOAssistant's actions with it; holding the press a moment longer still opens the menu.

## Settings reset

After a problematic update, or for a fresh start: **Settings → Backup & Reset → Reset Settings...**

- **Settings wrong?** **Quick: Settings only** resets the settings, keeps API keys, languages, your selections and actions.
- **Action problems?** **Quick: Actions only** resets every action setting, keeps everything else.
- **Strange behaviour after an update?** **Quick: Settings only** is the safest first step.
- **Many things broken?** **Quick: Fresh start** resets everything except API keys, languages, gesture registrations and chats, and the setup wizard runs again the next time KOAssistant starts.
- **Want to redo language, gestures or emoji?** **Re-run Setup Wizard**.
- **Exact control?** **Custom reset...** lists what to reset.

A long press on any reset row shows exactly what it resets and keeps. The options are described on [Backups and Updates](Backups-and-Updates#reset-settings).

## Debug mode

**Settings → Advanced → Console Debug** is the switch that fills `crash.log` for a bug report: KOAssistant's own tracing is silent by default, and this turns it on without raising KOReader's global log level. **Show Debug in Chat** shows the messages sent and the provider, model and settings used, above the conversation in the chat window. What each shows, and the token usage line: [Advanced Configuration and Development](Advanced-Configuration-and-Development#debugging).

## Related

- [Privacy and Data](Privacy-and-Data): the settings most "not working" reports come down to.
- [Getting Started](Getting-Started): install paths and the key options.
- [Backups and Updates](Backups-and-Updates): the reset options, updating, restore.
- [Advanced Configuration and Development](Advanced-Configuration-and-Development): debugging, configuration.lua, the request inspector.
- [Contributing](Contributing): what to include in a bug report.
