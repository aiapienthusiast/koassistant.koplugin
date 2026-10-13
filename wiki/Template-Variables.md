# Template Variables

The placeholders an action's prompt can use. Each is replaced at run time with the value it names; the "section" forms carry a label and vanish when they have nothing to say, so a prompt never refers to data that is not there. Where a placeholder needs a privacy setting, the setting is named; without it the placeholder is empty. How to write and edit actions is on [Actions and Menus](Actions-and-Menus).

## The variables

| Variable | Context | Description | Privacy setting |
|---|---|---|---|
| `{highlighted_text}` | Highlight | The selected text | |
| `{user_input}` | Any | The text typed in the input dialog, placed where the placeholder sits (without it, typed text is appended after the prompt). Actions using it stay out of the tap-only menus (highlight menu, dictionary popup); run without typed text, the placeholder is left in the prompt as written, which is why such actions are kept off those menus | |
| `{title}` | Book, Highlight | Book title | |
| `{author}` | Book, Highlight | Book author | |
| `{author_clause}` | Book, Highlight | " by Author", or empty | |
| `{count}` | Library | Number of selected books | |
| `{books_list}` | Library | The selected books as a list, enriched with per-book highlights, annotations and notebook when the action declares those flags | Allow Highlights / Annotation Notes / Notebook, when those flags are set |
| `{library}` | Library, Book | The library catalog, raw, no label | Allow Library Scanning and a scan folder |
| `{library_section}` | Library, Book | The catalog with the label "My library:", or empty | Allow Library Scanning and a scan folder |
| `{deep_reads}` | Library | Books read extensively (complete, with significant reading time) | Allow Advanced Stats |
| `{deep_reads_section}` | Library | The same with "Books I read extensively:", or empty | Allow Advanced Stats |
| `{recently_finished}` | Library | Books finished in the last 30 days | Allow Advanced Stats |
| `{recently_finished_section}` | Library | The same with "Books I recently finished:", or empty | Allow Advanced Stats |
| `{stalled}` | Library | Started books inactive for 30 days or more | Allow Advanced Stats |
| `{stalled_section}` | Library | The same with "Books I started but haven't returned to:", or empty | Allow Advanced Stats |
| `{briefly_started}` | Library | Books opened but barely read | Allow Advanced Stats |
| `{briefly_started_section}` | Library | The same with "Books I opened briefly:", or empty | Allow Advanced Stats |
| `{previous_results}` | General | This action's own recent results: the AI's replies from your last 3 saved general-context chats of this action, raw | none (your own AI output) |
| `{previous_results_section}` | General | The same in a labelled "Previous results from earlier runs of this action…" block with an avoid-repeating hint, or empty | none |
| `{translation_language}` | Any | The translation target from the settings | |
| `{dictionary_language}` | Any | The dictionary response language from the settings | |
| `{response_language}` | Any | The response language in effect for this request, a per-book override included (defaults to "English") | |
| `{context}` | Highlight | The text around the selection (sentence, paragraph or characters) | |
| `{context_section}` | Highlight | The context with the label "Word appears in this context:" | |
| `{reading_progress}` | Book | The current position, as "42%" | Allow Basic Stats |
| `{progress_decimal}` | Book | The position as a decimal, "0.42" | Allow Basic Stats |
| `{chapter_title}` | Book (reading) | The current chapter's name | Allow Basic Stats |
| `{chapters_read}` | Book (reading) | Chapters read, "5 of 12" | Allow Basic Stats |
| `{page_number}` | Book (reading) | The EPUB's reference page label, "37" (the print edition's page from the book's page map; empty when the EPUB has none) | Allow Basic Stats |
| `{time_since_last_read}` | Book (reading) | Time since the last reading session, "3 days ago" | Allow Basic Stats |
| `{highlights}` | Book, Highlight | All highlights of the document | Allow Highlights (or Allow Annotation Notes) |
| `{annotations}` | Book, Highlight | All highlights that carry a note | Allow Annotation Notes |
| `{highlights_section}` | Book, Highlight | Highlights with "My highlights so far:" | Allow Highlights (or Allow Annotation Notes) |
| `{annotations_section}` | Book, Highlight | Annotations with an adaptive label: "My annotations:" when the notes may be sent, "My highlights so far:" when degraded to highlights only | Allow Annotation Notes (degrades to Allow Highlights) |
| `{notebook}` | Book, Highlight | The book's KOAssistant notebook | Allow Notebook |
| `{notebook_section}` | Book, Highlight | The notebook with "My notebook entries:" | Allow Notebook |
| `{book_text}` | Book, Highlight (reading) | The book's text from the start to the current position | Allow Text Extraction |
| `{book_text_section}` | Book, Highlight (reading) | The same with "Book content so far:" | Allow Text Extraction |
| `{full_document}` | Book, Highlight (reading) | The whole document, start to end, whatever the position | Allow Text Extraction |
| `{full_document_section}` | Book, Highlight (reading) | The same with "Full document:" | Allow Text Extraction |
| `{surrounding_context}` | Highlight (reading) | The text surrounding the highlighted passage | |
| `{surrounding_context_section}` | Highlight (reading) | The same in a labelled block that marks the passage with >>> <<< and tells the AI to answer about the passage only | |
| `{page_text}` | Book, Highlight (reading) | The text of the visible page | |
| `{page_text_section}` | Book, Highlight (reading) | The same with "Current page text:" | |
| `{xray_cache}` | Book (reading) | The saved X-Ray, if any | Allow Text Extraction (and Allow Highlights if the X-Ray used them) |
| `{xray_cache_section}` | Book (reading) | The same with a progress label | as above |
| `{analyze_cache}` | Book (reading) | The saved document analysis, if any | Allow Text Extraction |
| `{analyze_cache_section}` | Book (reading) | The same with its label | Allow Text Extraction |
| `{summary_cache}` | Book (reading) | The saved document summary, if any | Allow Text Extraction |
| `{summary_cache_section}` | Book (reading) | The same with its label | Allow Text Extraction |
| `{document_context_section}` | Book (reading) | The unified source block: the full text, a saved summary, targeted passages (Smart retrieval) or nothing, as chosen in the source popup of an action with source selection | Allow Text Extraction (for the full text and the summary) |
| `{doi_clause}` | Book, Highlight (reading) | A sentence naming the book's DOI when one was detected, for [Research Mode](Research-Mode) prompts; empty otherwise | |

**Contexts:** Book = reading mode and the file browser (there, highlights, annotations, the notebook and the reading progress are read from the book's files on disk); Highlight = reading mode (there is no highlight without an open book); General = a standalone chat with no book; (reading) = reading mode only, an open book required. Whether the file browser offers an action is decided by its flags, not by its placeholders ([Actions and Menus](Actions-and-Menus#tips-for-custom-actions)). The privacy setting is the one under **Settings → Privacy & Data** that must be on for the variable to have content; off, the variable is empty and its section form disappears ([Privacy and Data](Privacy-and-Data)).

## Section and raw forms

A section form carries its label and disappears when empty:

- `{book_text_section}` → "Book content so far:" and the text, or nothing
- `{full_document_section}` → "Full document:" and the text, or nothing
- `{context_section}` → "Word appears in this context:" and the text, or nothing
- `{highlights_section}` → "My highlights so far:" and the highlights, or nothing
- `{annotations_section}` → "My annotations:" and the annotations; "My highlights so far:" when degraded (annotations off, highlights on); nothing when both are off
- `{notebook_section}` → "My notebook entries:" and the notebook, or nothing
- `{surrounding_context_section}` → "Surrounding context from the document (the highlighted passage is marked with >>> <<<)…" and the text, or nothing
- `{page_text_section}` → "Current page text:" and the text, or nothing
- `{xray_cache_section}` → "Previous X-Ray (as of X%):" and the X-Ray, or nothing
- `{analyze_cache_section}` → "Document analysis:" and the analysis, or nothing
- `{summary_cache_section}` → "Document summary:" and the summary, or nothing
- `{previous_results_section}` → "Previous results from earlier runs of this action…" and the results, or nothing
- `{library_section}` → "My library:" and the catalog, or nothing
- `{deep_reads_section}`, `{recently_finished_section}`, `{stalled_section}`, `{briefly_started_section}` → their labels above and the lists, or nothing

The raw forms (`{book_text}`, `{full_document}`, `{highlights}`, `{annotations}`, `{notebook}`, `{surrounding_context}`, `{page_text}`, `{xray_cache}`, `{analyze_cache}`, `{summary_cache}`, `{previous_results}`, `{library}`, `{deep_reads}`, `{recently_finished}`, `{stalled}`, `{briefly_started}`) give the content alone, for a prompt that labels it in its own words.

Use the section forms in most cases: a prompt that says "Look at my highlights: {highlights}" with no highlights gives the AI an instruction about content that is not there, while a section form brings its label only when it has content.

**Privacy.** The section forms follow the privacy settings: a data type that is off, or not yet turned on, leaves its placeholder empty and its section form vanishes. `{highlights_section}` is empty unless Allow Highlights is on (or Allow Annotation Notes, which implies highlights). Actions never need changing to match your privacy choices.

**Double-gating in custom actions.** Sensitive data needs both the global privacy setting and the action's own permission flag: with Allow Text Extraction on globally, a new custom action still needs "Allow text extraction" checked to use it. Built-in actions carry the right flags, and copied actions inherit them. The saved-result placeholders need the permissions of their source: `{xray_cache}` needs text extraction, plus highlights if the X-Ray was built with them; `{analyze_cache}` and `{summary_cache}` need text extraction. The full table is on [Privacy and Data](Privacy-and-Data#text-extraction-and-double-gating).

**`{previous_results_section}`** is not privacy-gated because its content is the AI's own earlier output, going back to the provider. It lets a recurring general-context action (a custom "daily news roundup" cloned from an existing action, say) see its last few results so it stops repeating items. It reads the AI's replies from your newest 3 saved general-context chats that ran this same action, so it needs saved chats; with Auto-save All Chats on (the default) that happens on its own. It is a general-context stopgap; book and library history is not covered.

## Utility placeholders

Reusable prompt fragments for any action:

| Placeholder | Expands to | Behaviour |
|---|---|---|
| `{conciseness_nudge}` | "Be direct and concise. Don't restate or over-elaborate." | always present |
| `{hallucination_nudge}` | "If you don't recognize this or the content seems unclear, say so rather than guessing." (a web-aware form adds "search the web to verify" when web search is on) | always present |
| `{text_fallback_nudge}` | "Note: No document text was provided. Use your knowledge of "{title}" to provide the best response you can. If you don't recognize this work, say so honestly rather than fabricating details." | only when the document text is empty; nothing when text is present |
| `{spoiler_free_nudge}` | "The reader is currently at {reading_progress} of this book. IMPORTANT: Do not reveal…" with a known position, or "The reader has not finished this book. Do not reveal plot twists, endings…" without one | only while spoiler protection is active |
| `{quiz_instructions}` | the chapter-quiz instructions and the JSON shape the Quiz action asks for | only for quiz requests |
| `{highlight_analysis_nudge}` | an instruction to also report which passages you highlighted, in a fixed JSON shape | only when highlights are present; no built-in action uses it any more, it is kept for custom actions |

Why they exist: the conciseness nudge counters verbose models and sits in around 20 built-in actions (Explain, Summarize, ELI5, the context-aware analysis actions); the hallucination nudge stops the AI inventing a book or author it does not know, with the web form encouraging a search first, and sits in many built-ins (About, Find Similar, Connect, Historical Context, every library action); the text fallback nudge gives graceful degradation to actions that use document text, guiding the AI to its own knowledge when extraction is off or empty and expanding to nothing when text is present (Explain in Context, Analyze in Context, Thematic Connection, Recap, Key Arguments, Discussion Questions, Quiz, Extract Key Insights, Reading Guide, Counterarguments, and for actions with source selection whenever "AI knowledge only" is chosen; X-Ray, Document Analysis and Document Summary block instead of degrading); the spoiler nudge tells the AI the reader's exact position and forbids anything beyond it, web-search results included, with the generic form when the position is unknown, and for every covered request it is added at send time and re-checked on each reply, so only a custom action that wants to control where the instruction sits needs the placeholder (AI Wiki, Reviews and About carry it inline) ([Spoiler Protection](Spoiler-Protection)).

Put these at the end of a prompt where they fit; they are replaced at run time, and the plain text works just as well if you prefer to write it out. `{text_fallback_nudge}` belongs in any custom action that uses `{full_document_section}` or `{book_text_section}`, so it still answers when extraction is off.

## Update-prompt placeholders

`{cached_result}`, `{cached_progress}`, `{incremental_book_text}`, `{incremental_book_text_section}` and `{entity_index}` fill in only inside an action's update prompt, the prompt used when an existing saved result is updated instead of regenerated: the result you already have, how far it covers, and only the newly read text. In an ordinary prompt they stay as written. See [Artifacts and Caching](Artifacts-and-Caching).

## Related

- [Actions and Menus](Actions-and-Menus): creating and editing the actions these go into.
- [Privacy and Data](Privacy-and-Data): the settings that fill or empty them.
- [Prompts, Behaviors and Domains](Prompts-Behaviors-and-Domains): the system prompt around the action's prompt.
