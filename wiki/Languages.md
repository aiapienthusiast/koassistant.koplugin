# Languages

Three different things are called "language" in KOAssistant: the languages the AI answers in, the target languages of the Translate and Dictionary actions, and the language of the plugin's own interface. This page covers all three, the per-book overrides, and right-to-left scripts.

## The AI's languages

**Settings → AI Language Settings** controls what language the AI responds in.

**Auto-detection.** KOAssistant takes your language from KOReader's UI language. If you have not configured any languages, the AI answers in your KOReader language (KOReader in Français: the AI answers in French), and translation and dictionary actions follow it too. The detected language shows as "(auto)" in Quick Settings. Once you set a language yourself, auto-detection is no longer used. A reader who completed the setup wizard before this feature existed and never configured languages gets a one-time prompt offering the detected KOReader language (non-English UIs only).

- **Your Languages**: the languages you speak or understand. The picker lists 47 languages in their own scripts (日本語, Français, Español …); pick several. They are sent to the AI in the system prompt ("The user understands: …").
- **Primary Language**: which of your languages the AI answers in by default. The first in your list unless you choose another.
- **Additional Languages**: extra languages for translation and dictionary targets that do not affect the AI's response language. They are not sent in the system prompt; they appear in the translation and dictionary pickers and in the Language button of the dictionary and translate windows. Use them for scholarly work (Latin, Sanskrit, Ancient Greek), for a language you are learning (translate into it), or for a language you understand but do not want the AI to default to.
- **Tell the AI the Book's Language**: off by default. Set to "From the book's metadata", [book-tool](Reasoning-Web-Search-and-Book-Tools) sessions tell the AI what language the book's text is in, when the book records one, so its searches use that language even if you ask in another; nothing is sent when the book records no language. It can be overridden per book or group in Book Settings → Languages, where you can also pick or type a language.

**Native scripts.** Languages appear in their own scripts in menus and settings; the system prompt uses their English names, which language models follow more reliably. Classical languages (Ancient Greek, Biblical Hebrew, Classical Arabic, Latin, Sanskrit) are shown in English only. **Custom languages:** "Add Custom Language..." at the top of each picker takes a language that is not in the list; it is remembered for later pickers.

**How answers work.** The AI answers in your primary language by default; if you type in another of Your Languages, it switches to that one. It switches only among Your Languages and never answers in an Additional Language of its own accord, even when the content is in that language, because Additional Languages are not part of the language instruction. Examples: Your Languages `English`: always English. Your Languages `Deutsch, English, Français`, primary `English`: English by default, German or French when you write in them. Additional `Latin, Sanskrit`: in the translation and dictionary pickers only.

**How it reaches the AI.** Your languages go into the system message after the behavior and the domain; the instruction tells the AI to answer in your primary language and to switch when you type in another configured one ([Prompts, Behaviors and Domains](Prompts-Behaviors-and-Domains)). Translate and Dictionary set "Skip language instruction" because their prompts name the target language themselves (`{translation_language}`, `{dictionary_language}`). A custom action whose prompt already names a response language should enable "Skip language instruction" too; otherwise leave it off so your language preference applies ([Actions and Menus](Actions-and-Menus)).

## Translation and dictionary languages

Four settings work together:

1. **Your Languages**: sent to the AI.
2. **Primary Language**: the default response language, one of Your Languages.
3. **Translation Language** (**Settings → Translate Settings**): the target of the Translate action; it can follow the primary language (`↵`) or be set on its own; its picker lists Your Languages and the Additional Languages.
4. **Dictionary Language** (**Settings → Dictionary Settings**): the response language of dictionary lookups; it can follow the primary (`↵`), follow the translation language (`↵T`), or be set on its own, with the same picker.

The return symbols mean: `↵` follows another setting, `↵T` follows the translation setting. Two example setups:

- Your Languages English and Spanish, primary English, additional Latin, translation `↵`, dictionary `↵T`: the AI knows you understand English and Spanish, answers in English, translates into English, defines words in English, and Latin is available in the pickers for scholarly texts.
- Your Languages English, primary English, additional Spanish and Latin, translation Spanish, dictionary `↵T`: the AI answers in English, translates into Spanish, defines words in Spanish (useful while reading Spanish), and Latin is there for translation when needed.

The dictionary's and translator's other settings are on [Dictionary and Translation](Dictionary-and-Translation).

## Per book

[Book Settings](Book-Settings-and-Book-Hub) → Languages holds four overrides, each Follow global by default:

- **AI response language**: the language the AI replies in for every action on this book (the "Always respond in X" directive). Keep your global answers in English and set a French novel to French; the book's language is added to your "understands" list, so the AI still switches if you write in one of your other languages.
- **Translation language**: the Translate action's target for this book.
- **Dictionary language**: the definition language for lookups in this book.
- **Book text language**: what language the book's text is in, told to the AI in book-tool sessions: Off, From metadata, a language from the list, or Custom (typed, so "German and Latin" works). It follows the global "Tell the AI the Book's Language" unless set here or in a group.

The AI response language changes the default reply language for every action; the other two affect only Translate and Dictionary.

## Right-to-left scripts

Right-to-left answers are shown in plain text, which renders their fonts properly, aligned to the right:

- **Dictionary and translate windows** switch when your dictionary or translation language is right-to-left (Arabic, Classical Arabic, Persian or Urdu), and keep mixed entries (an Arabic headword with an English pronunciation guide) in the right order: see [Dictionary and Translation](Dictionary-and-Translation#right-to-left-languages).
- **Chat and artifact windows** (X-Ray, X-Ray (Simple), Analyze, Summary) check the answer itself and switch to right-to-left mode when right-to-left characters outnumber Latin ones.

The switches are **Settings → Display Settings → Rendering → Text Mode for RTL Dictionary**, **Text Mode for RTL Translate** and **Auto RTL mode for Chat**, all on by default ([Chat Windows](Chat-Windows#markdown-and-plain-text)); your Markdown or plain-text preference is kept when the content is not predominantly right-to-left. Fonts that do not render at all are a KOReader font question: see [Troubleshooting](Troubleshooting#font-issues-with-arabic-and-other-right-to-left-scripts).

## The interface's language

The plugin's own menus, buttons and messages are available in 26 languages: French, German, Italian, Spanish, Portuguese, Brazilian Portuguese, Dutch, Finnish, Norwegian Bokmål, Swedish, Russian, Polish, Czech, Ukrainian, Chinese, Japanese, Korean, Vietnamese, Indonesian, Thai, Hindi, Bengali, Urdu, Arabic, Persian (Farsi) and Turkish. By default the interface follows KOReader's language; **Settings → Display Settings → Plugin UI Language** picks another, or English for the original wording.

The translations are made by AI and marked "needs editing" on Weblate; reviewing them is the most useful small contribution there is ([Contributing](Contributing)).

## Related

- [Dictionary and Translation](Dictionary-and-Translation): the actions whose targets these settings set.
- [Prompts, Behaviors and Domains](Prompts-Behaviors-and-Domains): where the language instruction sits in the prompt.
- [Book Settings and Book Hub](Book-Settings-and-Book-Hub): the per-book rows.
- [Contributing](Contributing): translating the interface.
