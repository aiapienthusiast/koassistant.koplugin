# Prompts, Behaviors and Domains

What the AI is told besides your question: how the request is assembled, the behavior (how the AI speaks), the domain (what it knows), the per-book Background note, and where each kind of instruction belongs. Actions and their prompts are on [Actions and Menus](Actions-and-Menus); the placeholders on [Template Variables](Template-Variables).

## How the prompt is built

When you trigger an action, KOAssistant builds a request from several parts.

The **system message** sets the context:

1. **Behavior**: the communication style, tone, formatting and verbosity.
2. **Domain**: the knowledge context, subject expertise and terminology.
3. **Background**: your standing note about the book, if you set one in [Book Settings](Book-Settings-and-Book-Hub), framed as context rather than instruction.
4. **Language instruction**: which language to answer in ([Languages](Languages)).

The **user message** carries the request itself: the context data (the highlighted text, the book's metadata, surrounding sentences, added on their own), the action's prompt with its placeholders filled in, and the text you typed, if any.

**Book metadata reaches a request in one of two ways.** A `[Context]` section is added at the start of the user message when the action's "Include book info" flag is on, which suits highlight actions (the passage is the subject, the book is supplementary). The `{title}`, `{author}` and `{author_clause}` placeholders go straight into the prompt, which suits book actions ("Tell me about {title}": the book is the subject).

**Some actions skip parts of the system message** because they would interfere. Translate and the dictionary actions skip the domain and the language instruction: domain context can change a translation or a definition, and their target language is named in the prompt itself. A custom action controls this from its editor: the **Domain** row ("None (no domain)"), the **Skip language** checkbox, and a separate **Background** row. By default an action that skips the domain skips the Background note too, unless its own `skip_background` setting says otherwise. For precise linguistic tasks skipping the domain usually helps; for analytical tasks in a field, the domain improves results; try both.

**Which instruction goes where:**

| Part | Scope | Best for |
|---|---|---|
| **Behavior** | global, one selection for every chat | communication style, formatting rules, verbosity |
| **Domain** | sticky, global or per book | subject expertise, terminology, analytical frameworks |
| **Action prompt** | one action, one task | task instructions, the output's shape, what to analyze |

For most custom actions a standard behavior with the detailed instructions in the action's prompt works best. Keep custom behaviors for broad style preferences you want everywhere, and domains for deep subject expertise you want across several actions. The two overlap: both sit in the system message and both shape the approach. Behavior controls the manner, domain the substance: a "scholarly" behavior makes the AI formal and rigorous, a "philosophy" domain makes it cite philosophers and logical frameworks. Both benefit from prompt caching ([Artifacts and Caching](Artifacts-and-Caching#prompt-caching)).

## Behaviors

A behavior defines the AI's personality, communication style and response guidelines: the tone (conversational, academic, concise), formatting preferences (when to use lists or headers), and the length of explanations. It is sent first in the system message.

**Built-in behaviors.** Twenty-four ship with the plugin. The provider-inspired styles come in three sizes, Mini (about 100 words), Standard (about 250) and Full (about 700), and every style works with every provider:

- **Claude Style** (Mini, Standard, Full), based on Anthropic's published guidelines. **Claude Style (Standard) is the default.**
- **DeepSeek Style** (Mini, Standard, Full): analytical and methodical.
- **Gemini Style** (Mini, Standard, Full): clear and adaptable.
- **GPT Style** (Mini, Standard, Full): conversational and helpful.
- **Grok Style** (Mini, Standard, Full): witty, with dry humour.
- **Perplexity Style** (Mini, Standard, Full): research-focused, with source transparency.
- **Reader Assistant**: a reading-companion persona suited to book actions such as X-Ray, Recap, Analyze Notes and Connect (With Notes); those actions use whichever behavior you selected, they do not force this one.
- **Concise** and **Terse**: brevity-focused, minimal guidance for direct answers.
- **Direct Dictionary**, **Linguistic Analysis** and **Direct Translator**: used by the Dictionary, Deep Analysis and Translate actions; minimal guidance for a lookup, a linguistic breakdown, and a translation without commentary.

**Changing the default:** **Settings → Actions & Prompts → Manage Behaviors**, tap one to select it, or the Behavior tile in Quick Settings.

**Sample behaviors.** The `behaviors.sample/` folder in the plugin holds more: reading-specialized ones (scholarly, religious and classical, creative writing) and further provider-style variations. Copy the files you want into `behaviors/` and they appear in the selector under "From behaviors/ folder".

**Custom behaviors.** Add `.md` or `.txt` files to the `behaviors/` folder, or use **Settings → Actions & Prompts → Manage Behaviors** → Create New. The file format is the domains' (below): the file name is the id, the first `# Heading` the display name, the rest the text sent to the AI. `behaviors.sample/README.md` has the full description. A file in `behaviors/` with a built-in's name replaces it; files that are not text are skipped.

**Per-action overrides.** An action can name another behavior by its id (mini, standard, full, or any other), use none, or carry its own behavior text; the built-in Translate uses the Direct Translator behavior that way ([Actions and Menus](Actions-and-Menus)).

Behavior is HOW the AI speaks, domain is WHAT it knows. Combine them: Perplexity Style with a research domain gives source-focused academic analysis. The request inspector shows how a combination changes the request before you use it on the device ([Advanced Configuration and Development](Advanced-Configuration-and-Development#the-request-inspector)).

## Domains

A domain gives a conversation project-like context. Its text goes into the system message after the behavior and before the language instruction, and the AI treats it as background knowledge. A domain can be small and focused or large and interdisciplinary.

**Built-in domain.** One ships with the plugin, **Synthesis**, as an example of what a domain can do; `domains.sample/` holds specialized samples for inspiration.

**Creating domains.** Add `.md` or `.txt` files to the `domains/` folder, or use **Settings → Actions & Prompts → Manage Domains** → Create New. The file name becomes the id (`my_domain.md` is `my_domain`), the first `# Heading` the display name (or it is derived from the file name), a comment block at the top is optional (it can record the token cost), and the rest of the file is the context sent to the AI. `domains.sample/` has examples, classical-language support and interpretive frameworks among them.

**Selecting a domain.** Tap the **Domain** chip in the input dialog, or use Quick Settings; the chip opens the **Domain & Research** picker, which also holds the Research Mode switch below the domain list ([Research Mode](Research-Mode)). A selected domain stays active for every later chat until you change it or pick "None". The chip shows the active domain's name (with a 🏛️ icon when emoji icons are on, swapped for a microscope, or prefixed "(research)" in text mode, when Research Mode is on for the book).

**Per-book domains.** With a book open, or targeted from the file browser or an artifact, the picker shows a target toggle, **For this book / Global**. For this book saves the domain with the book (in KOAssistant's own per-book file in the book's sidecar folder), and it is used every time you open that book, from the file browser and artifact views too; Global applies to every book without its own; **Follow global (name)** returns a book to the global domain; **None** on the book target opts a book out of the global domain. The Quick Settings Domain tile marks a per-book domain with "(book)". The order is: an action's own domain, then the book's, then the global one. General and library chats use the global domain only. The target toggle is shared with Research Mode for the session; the picker itself is described on [Research Mode](Research-Mode#turning-it-on-or-off). The per-book domain is one of the rows of [Book Settings](Book-Settings-and-Book-Hub), and a group can set it for its books ([Book Groups and Series](Book-Groups-and-Series)).

Keep the sticky behaviour in mind: a global domain set for one task applies to every later action, quick actions that open no dialog included, unless an action skips the domain, until you clear it.

**Browsing by domain.** Chat History → ☰ → View by Domain. Domains are context, not storage: chats still save with their book or in General AI Chats, but can be filtered by domain ([Conversations, Notebooks and Export](Conversations-Notebooks-and-Export)).

**Tips.** Translate and Dictionary skip the domain because it alters their output, and any custom action can skip it from its Domain row. If content could fit either, the rule of thumb is: how to respond goes in the behavior, what to know goes in a domain. A domain applies to every message of a conversation; an action that gains nothing from it should skip it. A large domain costs tokens on every request; keep domains focused, and note that most major providers cache the system prompt (a 50 to 90% reduction on the repeated context). The request inspector previews the effect of a domain.

## The per-book Background

A standing note about one book, written in Book Settings (up to 2,000 characters): what you are reading it for, how to treat it ("I'm reading this critically; flag questionable claims"). It is sent with every request for that book, next to the behavior and the domain, framed as context rather than instruction, so it reaches every action, gesture and chat on its own. There is no privacy switch: writing it is the consent, and it stays empty otherwise. An action that skips the domain skips it too unless its own setting says otherwise, and **Settings → Chat & Export Settings → Quick Answer Preset → Skip Book Background** leaves it out of Quick Answer chats. A group can set a Background for its books.

## Better results

- **Good document metadata** improves answers: correct titles, authors and identifiers (a DOI for a paper, which triggers [Research Mode](Research-Mode)). Calibre or a similar tool fixes them; KOReader's own Book information editor works too.
- **Choose models by task:** a fast model (Haiku 5.5, Gemini 3.5-flash) for quick queries, a powerful one (Sonnet 5, Opus 4.8) for deep analysis. An action can have its own model ([Actions and Menus](Actions-and-Menus)).
- **Try the behavior styles**, and combine a behavior with a domain: Perplexity Style with a research domain for source-focused academic analysis.

## Related

- [Actions and Menus](Actions-and-Menus): the action's prompt, its domain and behavior overrides.
- [Template Variables](Template-Variables): the placeholders inside a prompt.
- [Languages](Languages): the language instruction.
- [Book Settings and Book Hub](Book-Settings-and-Book-Hub): the per-book domain and Background.
- [Research Mode](Research-Mode): the picker's other half.
