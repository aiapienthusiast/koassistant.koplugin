# Privacy and Data

KOAssistant sends data to the AI provider you choose so it can answer you. This page explains what is sent, what stays on your device until you allow it, and every control you have: the global switches and presets, per-book overrides, trusted providers, and the per-action flags of custom actions.

> ⚠️ **Some features are opt-in.** To protect your privacy, personal reading data (highlights, annotations, notebook) is NOT sent to AI providers by default. You must enable sharing in **Settings → Privacy & Data** if you want features like Analyze Notes or Connect (With Notes) to work fully. Book text is off by default too (see [Text Extraction and Double-gating](#text-extraction-and-double-gating)).

This is not privacy theater: the "threat model" is simply users including sensitive data (annotations, notes, content) by accident. You are already being permissive by using online AIs at all, this plugin encourages AI analysis of your reading material, and the available placeholders (template variables) can carry a substantial amount of sensitive data. Advanced Stats (opt-in, off by default) reads KOReader's Statistics plugin locally to derive reading engagement groups; see [Design Choices](#design-choices) for what this means and why it is opt-in. Best practice is to pick providers thoughtfully, and the very best practice is to use local or self-hosted solutions, such as Ollama (see [Local Processing](#local-processing)).

## What Gets Sent

### Always sent (cannot be disabled)

- Your question or prompt.
- The selected text, for highlight actions.

### Sent by default (for actions that use it)

- **Document metadata** such as title, author and identifiers (a DOI when one is detected). A highlight action leaves it out when you uncheck **Include book info** in its settings in the action manager. **Settings → Chat & Export Settings → Book Info in Chat** sets how much book context freeform chats and book-aware actions get (None, Title only, Title & author, or Title, author & position), and Book Settings can change that per book, or change or blank the title and author the AI is told (see [Book Settings and Book Hub](Book-Settings-and-Book-Hub)).
- **Enabled system content**, like your languages, domain and behavior.
- **Basic stats**: reading progress (percentage), chapter title, chapters read count, time since last opened, and the print page number when the book carries a page list. The data used to calculate them (the exact date you last opened the document, and so on) stays local.
- **Per-book Background**: if you have written a standing note about a book in Book Settings (what you're reading it for, how to treat it), it is sent with requests for that book alongside behavior and domain. Most actions that leave the domain out, such as translation and dictionary lookups, leave it out too. There is no separate privacy toggle: writing it is the consent, and it stays empty otherwise. See [Prompts, Behaviors and Domains](Prompts-Behaviors-and-Domains).

### Opt-in (off by default)

- **Highlights**: your highlighted passages (with their chapter or page), separate from annotations.
- **Annotations**: your highlighted text with the personal notes you attached.
- **Notebook entries**: your KOAssistant notebook for the book, with the dates of its entries.
- **Book text content**: actual text from the document (for X-Ray, Recap and others).
- **Library catalog**: metadata of the books in your scan folders: title, author, series and reading status, with the progress percentage of books you are reading or have put on hold. Books are grouped by status and ordered by when you last read them; the dates themselves are not sent. Only sent by library actions when library scanning is enabled with folders configured.
- **Advanced stats**: reading engagement data derived from KOReader's Statistics plugin: curated groups based on reading time and completion patterns (books read extensively, stalled reads, briefly started, recently finished). Raw statistics (session logs, pages per session, reading speed, exact timestamps) are computed locally and **never** sent; only book lists with rounded labels reach the AI (see [Design Choices](#design-choices)). Only used by library scan actions.

## Privacy Controls

### Presets

**Settings → Privacy & Data** provides three quick presets:

| Preset | What it does |
|--------|--------------|
| **Preset: Default** | Basic stats (progress, chapter info) shared for context-aware features. Personal content (highlights, annotations, notebook) stays private. Advanced stats, library scanning and text extraction off. |
| **Preset: Minimal** | Maximum privacy. Only your question and book metadata are sent. All stats (including basic stats), library scanning, personal content and text extraction off. |
| **Preset: Full** | All data sharing enabled for full functionality, including library scanning and advanced stats. Does not turn on text extraction (see [Why It Is Off by Default](#why-it-is-off-by-default)); it leaves that toggle as it was. |

A preset changes only these global toggles. Your trusted providers, per-book overrides and scan folders stay as they are.

### Data Sharing Toggles

The individual toggles sit under the presets in **Settings → Privacy & Data**. They govern every provider you have not marked trusted.

- **Allow Annotation Notes** (default: off): your personal notes attached to highlights. Turning it on also turns on Allow Highlights. Actions requesting annotations degrade gracefully: when this is off but Allow Highlights is on, they receive highlights only (labeled "My highlights so far:" instead of "My annotations:"). Used by Analyze Notes, Connect (With Notes), Analyze in Context and actions with `{annotations}` placeholders.
- **Allow Highlights** (default: off): your highlighted text passages, without notes. Used by Recap, Analyze Notes and actions with `{highlights}` placeholders. It also unlocks the local "Your highlights (N)…" list on X-Ray entity pages, which is read from the book and not sent anywhere until you chat about that entry. Grayed out while Allow Annotation Notes is on (annotations imply highlights).
- **Allow Notebook** (default: off): the notebook entries for the book. Used by Connect (With Notes), Analyze Notes, Analyze in Context and actions with the `{notebook}` placeholder, and needed to attach your notebook in a chat or to chat about it.
- **Allow Basic Stats** (default: on): reading progress percentage, chapter title, chapters read count, time since last opened. Used by X-Ray, Recap and other context-aware features.
- **Allow Library Scanning** (default: off): the same toggle as in Reading & Library; see [Library Scanning Settings](#library-scanning-settings).
- **Allow Advanced Stats** (default: off): reading engagement data derived from KOReader's Statistics plugin, shared as curated groups with library scan actions. See [Design Choices](#design-choices).
- **Text Extraction**: a submenu; see [Text Extraction Settings](#text-extraction-settings).
- **Tip: Per-book overrides** explains the two ways to use [Per-Book Overrides](#per-book-overrides).

### Library Scanning Settings

In **Settings → Reading & Library**, under Library:

- **Allow Library Scanning** (default: off): allows scanning your folders for book metadata. Required for the scan-based library actions (Next Read, Discover New, Analyze Library, Challenge My Taste) and the Suggest from Library book action. Find Similar and Recommend add your library to their answer when scanning is allowed, but don't need it.
- **Permanent Scan Folders**: folders always scanned for library actions (grayed out until scanning is allowed). You can also pick folders on the fly in the input dialog.

The global toggle is an absolute gate: all library scanning, including folders picked on the fly in the input dialog, requires it. The per-action "Allow library use" flag is the second gate, and a folder is the third (see [Design Choices](#design-choices)).

### Graceful Degradation

When you disable a data type, actions adapt automatically. Section placeholders like `{highlights_section}` simply disappear from prompts, so you don't need to modify your actions. For text extraction, most actions fall back to the AI's training knowledge; see [Text Extraction and Double-gating](#text-extraction-and-double-gating). When an action asked for data it did not get, its response starts with a line such as *Response generated without: highlights (sharing disabled)*.

Attaching your notebook with the Attach chip in a chat is gated the same way as the `{notebook}` placeholder: it will not attach if the underlying data isn't allowed to be shared.

### Seeing What an Action Uses

If your device supports emoji fonts, turn on **Settings → Display Settings → Emoji → Emoji Data Access Indicators** (independent of Emoji Menu Icons) to see at a glance what data each action accesses. The marks follow action names in the action manager, Quick Actions, the highlight and dictionary menus and the file browser buttons:

- 📄 document text (directly or through a saved summary, analysis or X-Ray)
- 🔖 highlights only (no personal notes)
- 📝 annotations (highlights with your notes)
- 📓 notebook
- 📚 library catalog
- 📊 advanced stats (reading engagement groups)
- 🌐 web search, always on for this action; (🌐) web search through your default, which is on (in an input dialog, through its Web chip)
- (🔍), in an input dialog: the action may search the book with AI Book Tools (smart retrieval is available and the Tools chip is on)

## Per-Book Overrides

Every sharing toggle that concerns one book's data (highlights, annotations, notebook, text extraction) can also be set per book in **Book Settings → Privacy**. Each row (Highlights sharing, Annotations sharing, Notebook sharing, Text extraction) offers **Follow global**, **On** (allow for this book) or **Off** (deny for this book).

- **Deny always wins**, even over [trusted providers](#trusted-providers), and it binds background features such as Automatic X-Ray too.
- **Allow satisfies only the global gate**: per-action flags still apply (see [Double-gating for Custom Actions](#double-gating-for-custom-actions)).
- Allowing annotations for a book implies highlights; denying highlights denies annotations too.
- Basic stats, library scanning and advanced stats have no per-book override.

This lets you keep sharing off globally but allow it for specific books, or keep it on and fence off a sensitive one. **How overrides work…** at the bottom of the screen restates these rules.

A book that is not open is judged by its own overrides: an action on it from the file browser, or from a chat about that book (opened from its Book Hub, for example), reads its highlights, annotations and notebook from disk under the same gates, and checks that book's settings before it starts. A library action on several selected books applies each book's own overrides.

The Quick Settings panel's **Text Extraction** tile shows "(book)" when this book's override masks the global setting; tapping it changes the global setting, and holding it opens this book's Privacy screen (see [Setup, Gestures and Panels](Setup-Gestures-and-Panels)).

## Trusted Providers

**Settings → Privacy & Data → Trusted Providers** lists every provider, built-in and custom. Tick the ones you fully trust (for example a local Ollama) and tap Save.

A request to a trusted provider bypasses all data sharing controls AND text extraction AND the library scanning toggle: highlights, annotations, notebook, reading progress and chapter info, advanced stats, book text and the library catalog are all available without toggling individual settings.

- Trust replaces the global switches only. Each action still needs its own per-action flags, and a [per-book deny](#per-book-overrides) still wins.
- Library scanning still needs at least one folder (permanent or picked on the fly).
- Trust also satisfies the consent check that background features (such as Automatic X-Ray and X-Ray checkpoint builds) run against: those can then extract text in the background without a per-request tap.

**Which provider counts.** Trust is judged for the provider a request actually goes to: your active provider, an action's own pinned provider, a model picked from the long-press menu of an action or of Send, or the Quick chip's preset model. Pinning an action to a different provider never inherits trust it shouldn't. When the receiving provider may not get something, it is left out of that request:

- book passages gathered by smart retrieval, a notebook attached with the Attach chip (in a new chat, a reply, or a chat reopened from Chat History) and the book list of a library chat, each with a short notice;
- the highlights an X-Ray entry's "Chat about this" carries.

A chat about your notebook from the notebook viewer ("Chat about this notebook") does not start unless notebook sharing allows it for the provider that chat goes to: the book's own override decides first, then Allow Notebook or a trusted provider.

## Text Extraction and Double-gating

> ⚠️ **Text extraction is OFF by default.** To use features like X-Ray, Recap and context-aware highlight actions with actual book content (rather than the AI's training knowledge), you must enable it in **Settings → Privacy & Data → Text Extraction → Allow Text Extraction**.

Text extraction sends actual book or document content to the AI, enabling features like X-Ray, Recap, Document Summary and Document Analysis, and highlight actions like Explain in Context, to analyze what you've read. Without it, most actions gracefully fall back to the AI's training knowledge: the AI is explicitly told no document text was provided and asked to use what it knows about the work (or say so honestly if it doesn't recognize it). This works reasonably for well-known titles but will be inaccurate for obscure works, and is basically unusable for research papers and articles the AI hasn't seen. **Exception:** X-Ray, Document Summary and Document Analysis require text extraction and block generation without it (see [When an Action Is Blocked](#when-an-action-is-blocked)); use X-Ray (Simple) for a prose overview from AI knowledge.

> **Tip:** If you enable text extraction but don't want to send the *whole* document, you have finer-grained options: choose "Use document summary" or a specific section in an action's source-selection popup, attach a text range with the **Scope** chip on a freeform chat, or let **AI Book Tools** retrieve only the relevant passages (see [Reasoning, Web Search and Book Tools](Reasoning-Web-Search-and-Book-Tools)). KOReader's Hidden Flows also exclude front matter, appendices and the like from extraction (see [Using X-Ray](Using-X-Ray)).

### Why It Is Off by Default

1. **Token costs and context window** (the primary reasons, and also why no privacy preset turns it on, not even Full): extracting book text uses significantly more context than you might expect. A full book can consume 60K+ tokens per request, which adds up quickly with paid APIs, so you should opt into this cost consciously. Large contexts also significantly degrade response quality, especially for follow-up questions. That's why actions with source selection let you choose "Use document summary" instead: your queries run on a previously generated summary (~2-8K tokens) rather than the full document text.
2. **Content awareness** (see [Double-gating for Custom Actions](#double-gating-for-custom-actions)): for most readers of mainstream books the text itself isn't privacy-sensitive. But if you're reading something non-standard, subversive, controversial or otherwise sensitive, be aware that the actual content is sent to cloud AI providers. This is a secondary consideration for most users, but important for some.

### How to Enable

1. Go to **Settings → Privacy & Data → Text Extraction**.
2. Enable **Allow Text Extraction** (the master toggle).
3. Built-in actions (X-Ray, Recap, Explain in Context, Analyze in Context and the others that read text) already have the per-action flag enabled.

After you have turned it on here once, the Quick Settings panel's **Text Extraction** tile toggles it directly. AI Book Tools also need it (a trusted provider satisfies it too).

### Text Extraction Settings

**Settings → Privacy & Data → Text Extraction** (the row reads "Text Extraction (enabled)" or "(disabled)"). Every row below the master toggle is grayed out until text extraction is on.

- **Allow Text Extraction**: the master toggle (default: off). When on, actions can extract and send book text to the AI: X-Ray, Recap, Explain in Context, Analyze in Context, AI Book Tools and actions with text placeholders (`{book_text}`, `{full_document}` and so on). Turning it on shows a notice about token costs, with a tip about using Hidden Flows to save tokens.
- **Max Text Characters**: the most characters to extract (100,000 to 10,000,000; default 4,000,000, about 1M tokens). The default covers most books with Gemini's 1M-token context; lower it for smaller models. The API rejects requests that exceed the model's context window.
- **Max Pages (PDF, DJVU, CBZ…)**: the most pages to extract from page-based formats (100 to 5,000; default 2,000).
- **Don't warn about truncated extractions**: when unchecked (the default), a blocking warning appears before sending a request whose extracted text was cut to fit the character limit. It shows the coverage (for example "covers 0%–85% of the document") so you know how much of the document was included, and offers Cancel or Continue Anyway. This setting is the way to turn it off.
- **Don't warn about large extractions**: when unchecked (the default), a warning appears before sending a request with over 500K characters (~125K tokens) of extracted text, and below that size when the text likely exceeds the current model's known context window. Most models except Gemini will struggle at this size. The warning offers Cancel or Continue; this setting is the way to turn it off.
- **Delete Book Artifacts**: deletes every saved artifact of the open book: the X-Ray with its archived versions and checkpoints, X-Ray (Simple), Recap, Summary, Analysis, About, Analyze Notes, Key Arguments, Counterarguments, Discussion Questions, Quiz, Insights, Reading Guide, AI Wiki entries and the rest. Chats, notebook, pinned items and generated images are kept. It asks first, cannot be undone, and needs the book to be open. To delete just one artifact, use the delete button in the artifact viewer instead (see [Artifacts and Caching](Artifacts-and-Caching)).

### Background Features

The same consent covers background runs you opt into separately: [Automatic X-Ray and X-Ray checkpoint builds](Using-X-Ray) extract text and spend tokens **without a per-request confirmation**.

- They re-check consent when they fire, so revoking it stops them.
- Their size is bounded by their own guards: the progress-gap window and incremental checkpoint steps.
- The interactive warnings don't interrupt them. A background extraction cut to fit the character limit aborts the run instead of sending partial text, and a checkpoint step that would be a large request pauses the build ("Checkpoint build paused at N of M: the next step is a large request") until you resume it. Only the first request of a build you start yourself can show the size warning, right after you confirm; accepting it covers the rest of that build.

### Two Text Extraction Types

The placeholder in an action's prompt decides how much is extracted:

- `{book_text_section}`: from the start to your current reading position (used by X-Ray and Recap).
- `{full_document_section}`: the entire document regardless of position (used by Document Summary and Document Analysis).

Actions with a source-selection popup (Explain in Context, Analyze in Context, Key Arguments, Discussion Questions and more) use `{document_context_section}`, which carries the full document, a section, a document summary or the passages smart retrieval found, depending on the source you pick. Every placeholder is listed in [Template Variables](Template-Variables).

### Double-gating for Custom Actions

When you create a custom action from scratch, sensitive data requires both a global privacy setting AND a per-action permission flag. This prevents accidental data leakage when you use sensitive placeholders: enabling a global setting doesn't automatically expose that data in all your custom actions. A placeholder alone never switches these flags on; you tick them in the action's settings (see [Actions and Menus](Actions-and-Menus)).

> **For built-in actions:** you only need to enable the global setting. Built-in actions already have the appropriate per-action flags set, and a copy of a built-in action inherits its data-access flags.

Which flags each data type needs (relevant when you create custom actions from scratch):

| Data Type | Global Setting | Per-Action Flag |
|-----------|----------------|-----------------|
| Book text | Allow Text Extraction | "Allow text extraction" checked |
| X-Ray analysis cache | Allow Text Extraction if the cache was built with text (+ Allow Highlights if it was built with highlights) | The action's `use_xray_cache` field (no in-app checkbox), plus "Allow highlight use" if the cache was built with highlights |
| Analyze / Summary caches | Allow Text Extraction if the cache was built with text | The action's `use_analyze_cache` or `use_summary_cache` field (no in-app checkbox; the built-in actions that offer a summary source carry `use_summary_cache`) |
| Highlights | Allow Highlights (or Allow Annotation Notes) | "Allow highlight use" checked |
| Annotations | Allow Annotation Notes (degrades to highlights when off but Allow Highlights is on) | "Allow annotation use (notes)" checked |
| Notebook | Allow Notebook | "Allow notebook use" checked |
| Library catalog | Allow Library Scanning + folders configured | "Allow library use" checked |
| Advanced stats | Allow Advanced Stats (it rides the library catalog, so library scanning too) | "Allow advanced stats" checked (with "Allow library use") |
| Surrounding context* | None (hard-capped at 2000 characters) | Field `use_surrounding_context` (no in-app checkbox): unset = follow the global Surrounding Context setting (the default for custom actions), `true` = always on (also set automatically when your prompt contains `{surrounding_context}`), `false` = never |
| Per-book overrides | Book Settings → Privacy (tri-state per book; deny beats everything, trusted providers included) | Same per-action flags as above |
| Page text* | None (single current page, exempt) | Automatic when the prompt uses a `{page_text}` placeholder |

\* **Surrounding context** is the text around a highlight (more than you actually selected). It has no global privacy gate because it is hard-capped at 2000 characters, but it is *off by default*: it only rides along when the Surrounding Context mode (**Settings → Highlight Settings → Surrounding Context**, per book in Book Settings → Chat behavior → Highlight context, or the **Ctx** chip, which is the Scope chip of a highlight chat) is set to Sentence, Paragraph(s) or Characters rather than "None (off)". Dictionary lookups and actions with their own source selection don't use it. Per action it is a tri-state value in the action's Lua definition (not an editor checkbox): leave `use_surrounding_context` unset to follow that setting, or set it to `true` or `false` in a custom action to pin it always on or never. **Page text** is the single currently visible page and is likewise exempt from the global gate; it is included only when an action's prompt uses the `{page_text}` placeholder. The Scope chip's "Current page" pick is exempt the same way; every larger range it attaches needs text extraction.

> **Tip:** turn on **Emoji Data Access Indicators** (see [Seeing What an Action Uses](#seeing-what-an-action-uses)) to see each action's flags on its name, with no need to open its settings.

### When an Action Is Blocked

Built-in actions that cannot work without a kind of data check before anything is sent, and stop with a message that names the setting to change:

| Needs | Actions |
|-------|---------|
| Text extraction | X-Ray, Document Summary, Document Analysis |
| Highlight or annotation sharing | Analyze Notes, Connect (With Notes) |
| Library scanning and a scan folder | Next Read, Discover New, Analyze Library, Challenge My Taste, Suggest from Library |

The check follows the same rules as the extraction: a trusted provider passes it, a per-book deny fails it, and for a book that isn't open it reads that book's own overrides.

### Highlights, Recap and X-Ray

**Recap** uses highlights, never annotations, so your personal notes never reach it. If you want it to see your highlighted passages, enable **Allow Highlights** (Allow Annotation Notes is not needed for Recap, and would share your notes with the actions that use them); with both off it analyzes the book text alone.

**X-Ray does not read your highlights at all.** It works from book text only, and X-Ray (Simple) from AI knowledge only, so neither setting changes what they send. With Allow Highlights on, an X-Ray entity page matches your highlights locally and offers them as "Your highlights (N)…"; they go to the AI only when you tap "Chat about this", and only to a provider that may receive highlights.

### Cache Permission Inheritance

When caches (saved artifacts) are built, they record what data was used. Actions that later reference cache placeholders inherit requirements from what the cache actually contains:

- Cache built **without text extraction**: no Allow Text Extraction needed (the AI used training knowledge only).
- Cache built **with text extraction**: Allow Text Extraction needed.
- Recap cache built **without highlights**: no Allow Highlights needed.
- Recap cache built **with highlights**: Allow Highlights (or Allow Annotation Notes) also required.
- Older X-Ray caches built before X-Ray stopped reading highlights carry the same requirement until they are rebuilt.

The same check runs when you update an artifact: if a permission its cache needs is now off, the update is skipped and a fresh full generation runs instead.

The artifact viewer shows "Based on AI training data knowledge" or "Based on extracted document text", so you always know what a cache contains. If you change privacy settings after building a cache (for example, disable text extraction), actions may render the cache placeholder empty. To fix it, either re-enable the required permissions or regenerate the cache with your current settings. See [Troubleshooting](Troubleshooting) if text extraction isn't working.

## Local Processing

For maximum privacy, **Ollama** can run AI models entirely on your own device(s):

- Data never leaves your hardware.
- It works offline after the model download.
- See [Ollama's official docs](https://github.com/ollama/ollama) for installation and its [FAQ](https://github.com/ollama/ollama/blob/main/docs/faq.md) for network setup (hosting on another machine).
- Quick start: install Ollama → `ollama pull qwen2.5:0.5b` → select "Ollama" as the provider in KOAssistant's settings.
- For network hosting, open the **Server: …** row of **Settings → Model → Ollama**, tap **Add server...** and enter the machine's address (for example `http://192.168.1.100:11434`). Tap a server to switch to it; hold it to rename or remove it.

**Other local options:** LM Studio, llama.cpp, Jan, vLLM, KoboldCpp and LocalAI all have **one-tap presets**: go to **Settings → Model → Quick setup: Local provider...**, pick your engine, and the name and URL are pre-filled. Just change `localhost` to your server's IP if it runs on another machine. See [Providers and Models](Providers-and-Models) for custom providers.

Anyone using local LLMs is encouraged to open [issues](https://github.com/zeeyado/koassistant.koplugin/issues) or [discussions](https://github.com/zeeyado/koassistant.koplugin/discussions) (feature requests welcome) to help improve support for local, privacy-focused use.

## Provider Policies

Cloud providers have their own data handling practices. Check their policies on data retention and model training, and remember that API policies often differ from those of the web interface.

The **OpenAI Subscription** provider authenticates with your consumer ChatGPT account rather than the API platform. Consumer data-handling and model-training policies differ from the API platform's, so review your ChatGPT account's data settings if you use it.

## Design Choices

### Library Scanning

Library scanning is opt-in. When enabled (**Settings → Reading & Library**), KOAssistant scans your configured folders for book metadata (title, author, series, reading status, progress) to power library-aware features like Next Read and reading pattern analysis (Analyze Library). Your last-read dates only order the list and are not sent. Only catalog metadata is sent, **not** book content, highlights or annotations.

Library scanning is triple-gated:

1. the global **Allow Library Scanning** toggle;
2. at least one folder, permanent or picked on the fly;
3. the action's "Allow library use" flag.

Trusted providers bypass the global toggle but still need a folder.

### Reading Engagement Data (Advanced Stats)

KOReader's Statistics plugin collects extensive local data (reading time, pages per session, reading speed, session history, daily patterns). With **Allow Advanced Stats** on (**Settings → Privacy & Data**, default off), KOAssistant queries this database **locally** to compute engagement groups, which library scan actions can compose through template variables (`{deep_reads_section}`, `{stalled_section}`, `{briefly_started_section}`, `{recently_finished_section}`):

| Group | Which books | What a line adds |
|-------|-------------|------------------|
| Books read extensively | finished, more than 5 hours of reading | total hours |
| Recently finished | finished and last opened within 30 days | how long ago |
| Stalled reads | past 20%, not finished, not opened for over 30 days | progress and how long since you last opened it |
| Briefly started | not finished, under 30 minutes of reading | minutes read |

In the library list itself, a book with notable engagement gets one short label: "read extensively", "stalled", "opened briefly" or "recently finished".

**What reaches the AI:** only human-readable book lists, for example `"Title" by Author (47 hours)`. Raw statistics (exact timestamps, pages per session, reading speed, session logs) are used for local computation only and **never** leave the device. The AI sees categorized book lists, not behavioral data.

**Why opt-in:** reading patterns over time create a surprisingly detailed personal profile. Even the curated groups reveal information about reading habits: which books were abandoned, which consumed obsessively, which ignored for months. This warrants conscious opt-in rather than a default-on toggle.

## Related

- [Book Settings and Book Hub](Book-Settings-and-Book-Hub): the per-book Privacy, Identity and Chat behavior screens.
- [Actions and Menus](Actions-and-Menus): the action editor's data-access checkboxes for custom actions.
- [Template Variables](Template-Variables): every placeholder and the privacy setting it needs.
- [Using X-Ray](Using-X-Ray): Automatic X-Ray and checkpoints, which run under your text extraction consent.
- [Providers and Models](Providers-and-Models): local presets, custom providers and the OpenAI Subscription.
- [Troubleshooting](Troubleshooting): what to check when an action finds no highlights or no text.
