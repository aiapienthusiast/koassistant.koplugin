# Spoiler Protection

Spoiler protection keeps the AI from revealing what lies beyond your current reading position when you chat about a book. It is on by default, and one posture drives both the chat layer and the X-Ray layer: what the AI is told, what AI Book Tools may read, which X-Ray checkpoint is installed, and how far a text scope may reach.

## How it works

When protection is on, a short reminder is added to each request (never to the saved chat) telling the AI your current reading progress ("The reader is currently at 42% of this book") and forbidding anything beyond that point, including anything found in web-search results. It is resolved again at every send, so a chat that is already open follows you as you read and picks up a toggle mid-conversation. When reading progress is unavailable, a generic form is used ("The reader has not finished this book"); the same generic form is used when Basic Stats sharing is off, so your position is never disclosed without consent ([Privacy and Data](Privacy-and-Data)).

Where the position comes from: the live reader for an open book, the saved progress for a book in the file browser, and the generic form when no progress is known (0% or unknown).

## What it covers, and what it leaves alone

Covered:

- freeform chat (the Send button) in book and highlight contexts, and every reply in the same session, resumed chats included: protection follows your live position on each reply;
- book and highlight actions that do not opt out, X-Ray "Chat about this" chats included;
- the scope and source popups: while protection is on they pre-select **Up to current position** instead of Full document whenever that row exists, and deliberately picking a scope that crosses your position asks once before sending ([Contexts and Chat](Contexts-and-Chat)).

Left alone on purpose:

- actions that opt out: the artifact-generating family (X-Ray, Recap, Summary and the rest, which have their own position handling), Translate and the dictionary family, and the plugin's internal merge and duplicate runs;
- artifact chats (discussing a result that already exists);
- library and general chats (no book to spoil).

## Controls

- **Global:** **Settings → Chat & Export Settings → Spoiler Protection**, on by default; the X-Ray settings mirror it.
- **Per chat:** the **Spoiler** chip in the input dialog flips protection for the current chat without touching your saved settings. The chip starts in the state your per-book or global default resolves to. (It replaced the old "Show Spoiler-free Chat Checkbox" setting.)
- **Per book:** the Spoiler protection row in [Book Settings](Book-Settings-and-Book-Hub) (Follow global / On / Off) seeds the chip when you open the book; a long press on the chip opens the same per-book or global picker.
- **Stands down on its own:** marking a book **Finished** in KOReader's own status screen, or turning Research Mode on for it, disables protection for that book without changing your stored setting; un-finishing the book restores it. The Book Settings row says so ("off: book finished", "off: research mode"). Marking a book finished does not change text extraction: the artifact actions keep their own position handling.

## With AI Book Tools

With [AI Book Tools](Reasoning-Web-Search-and-Book-Tools) on, protection also bounds the tools in code, not only in words: on, the tools can read only up to your current page, so the AI cannot read ahead; off, they can read the whole document. The same bound decides how much text "Read Short Texts Whole" may send.

## With X-Ray

Protection steers the X-Ray's checkpoints: on, checkpoint updates install only up to your reading position, so the entries you can open never describe what you have not read; off, or in research mode, the newest built checkpoint installs as soon as it is ready. A single book can be pinned either way with the Book Settings row **X-Ray updates: Newest first / Follow my position**. The X-Ray's own extraction is bounded the same way: by default it reads the book only up to your position ([Using X-Ray](Using-X-Ray)).

In a series, later volumes stay closed: a lookup looks past a book only once that book is read (Finished, or read to its last page) or its own protection is off, and a confirmation opens a later book by name, one at a time ([Book Groups and Series](Book-Groups-and-Series)).

## Context around a selection

While protection is on, the text sent around a highlight or a looked-up word is clamped on the far side: **Settings → Highlight Settings → Context Under Spoiler Protection** sets how far past the selection the context may reach (nothing after the selection, to the end of its sentence, to the end of its paragraph, which is the default, or no limit). A dictionary action started from the input dialog is clamped the same way; a lookup from KOReader's dictionary popup, the bypass or the highlight menu is not clamped yet. Selections made inside the plugin's own windows are not clamped, since they are not the book. See [Contexts and Chat](Contexts-and-Chat) and [Dictionary and Translation](Dictionary-and-Translation).

## In custom actions

For every covered request the instruction is added at send time. A custom action that wants to control where it sits in the prompt can carry `{spoiler_free_nudge}`, which resolves to the instruction while protection is active and to nothing otherwise ([Template Variables](Template-Variables)). A few built-ins carry it inline: AI Wiki, Reviews, About.

## Related

- [Using X-Ray](Using-X-Ray): checkpoints, version history, and what "follow my position" installs.
- [Book Settings and Book Hub](Book-Settings-and-Book-Hub): the per-book row and the X-Ray updates row.
- [Contexts and Chat](Contexts-and-Chat): the chips row and the scope popup.
- [Privacy and Data](Privacy-and-Data): Basic Stats, which the position reminder depends on.
