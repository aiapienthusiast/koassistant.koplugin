# Book Settings and Book Hub

Book Settings is the per-book screen: every value set there applies to that book only, sticks to it (stored in KOAssistant's own file inside the book's `.sdr` folder, so it comes back every time you open the book), and overrides the global default. The Book Hub is the one page per book that gathers its artifacts, chats, notebook, group and settings.

## Opening Book Settings

A book must be in scope, so from the reader or the file browser:

| Entry point | Where |
|---|---|
| **Quick Actions** | the **Book Settings** utility (reading mode); reorderable and hideable like any panel item |
| **File browser** | long-press a book → **Book Settings (KOA)** |
| **The input dialog** | the gear menu → **Book Settings** (book and highlight chats) |

Several per-book values are also reachable from the input dialog's chips: tap **Domain** for the Domain & Research picker, hold **Web** for web search (with its Search depth row), hold **Tools** for AI Book Tools (with lookup effort and the read-whole size), hold **Spoiler** for spoiler protection, hold **Ctx** (highlight chats) for highlight context; each picker offers a "For this book / Global" target. Book Settings is the full screen; the chip holds are the fast single-setting switches, and both write the same values ([Contexts and Chat](Contexts-and-Chat)).

## What you can set per book

Each row shows its current value: "Follow global (X)" when unset, or "Follow group X (value)" when the book follows one of its [groups](Book-Groups-and-Series) for that setting. Each opens a small picker in which **Follow global** is always a choice, and so is following a group that sets the value. The screen leads with a few headline rows (Domain, Background, Research mode, Spoiler protection, Group) and continues with six sub-screens, each with a badge counting its customized rows: **X-Ray**, **Chat behavior**, **Privacy**, **Identity**, **Quiz settings**, **Languages**.

### Headline rows

| Setting | Choices | Notes |
|---|---|---|
| **Domain** | Follow global / None / a domain | the same per-book domain as the quick picker ([Prompts, Behaviors and Domains](Prompts-Behaviors-and-Domains)) |
| **Background** | free text, up to 2,000 characters | a standing note about this book, sent with behavior and domain in its requests ("I'm reading this critically; flag questionable claims"), so it reaches actions, gestures and chats on its own; actions that leave the domain out, such as Translate and the dictionary actions, leave it out too. There is no privacy switch: writing it is the consent ([Prompts, Behaviors and Domains](Prompts-Behaviors-and-Domains#the-per-book-background)) |
| **Research mode** | Follow global / On / Off | [Research Mode](Research-Mode); Off suppresses it even when a DOI is detected |
| **Spoiler protection** | Follow global / On / Off | [Spoiler Protection](Spoiler-Protection); research mode or a book marked Finished stands it down, and the row says so |
| **Group** | Group Hub / memberships / "Add to group…" | the book's group membership: tap opens its Group Hub (a chooser when it is in several), hold opens the memberships popup |

### Chat behavior

| Setting | Choices | Notes |
|---|---|---|
| **AI Book Tools** | Follow global / On / Off | whether the Tools chip starts on for this book ([Reasoning, Web Search and Book Tools](Reasoning-Web-Search-and-Book-Tools)) |
| **Lookup effort** | Follow global / Quick / Standard / Thorough | how much the book tools may look up per question on this book |
| **Read short texts whole** | Follow global / Off / Small / Medium / Large | how long this book's readable text may be and still go to the AI in one piece instead of being searched (16,000 / 64,000 / 128,000 characters) |
| **Web search** | Follow global / On / Off | the per-book web search default, under the chat's Web chip |
| **Search depth** | Follow global / Light / Standard / Thorough | the web search effort for this book |
| **Quick answer default** | Follow global / On / Off | whether the Quick Answer chip starts on for a new chat on this book; the chip wins once tapped |
| **Book info** | Follow global / None / Title only / Title & author / Title, author & position | how much book context is attached on its own (below) |
| **Highlight context** | Follow global / None / Sentence / Paragraph(s) / Characters | how much surrounding text goes with highlight chats and actions on this book |
| **Dictionary context** | Follow global / None / Sentence / Paragraph(s) / Characters | the same for dictionary lookups on this book |

**Book info** decides the generic context line: **None** sends no "Book: …" line (useful when the metadata clutters the context; explicit `{title}` and `{author}` placeholders in a custom action still resolve, so X-Ray and the other artifacts keep working); **Title only**; **Title & author** (the default, "Book: Title by Author"); **Title, author & position** adds the reading progress, the current chapter and the page, which needs Allow Basic Stats. A chat about a closed book includes its saved position too.

### X-Ray

| Setting | Choices | Notes |
|---|---|---|
| **Automatic X-Ray** | Follow global / On / Off | one switch for background upkeep of this book's X-Ray. On covers the first build too, whatever the global setting, and confirms how many background requests it needs before starting; Off always wins |
| **Build up to** | the whole book / the end of a section (open book) | how far the automatic build goes |
| **Checkpoint spacing** | Recommended / every 2.5% to 50% | how far apart the background checkpoints land |
| **X-Ray updates** | Newest first / Follow my position | whether checkpoint installs may run ahead of your position while spoiler protection is off |
| **Marking & lookup** | nine overrides | passive marking on or off, its density, which entities are marked, tap to open, upcoming entities, what an upcoming entity's card shows first, how much of an entry a card shows, matching selections, and how an exact hit opens (footnote card, popup card, full entry) |
| **New X-Ray preset** | Follow global / Characters only / Characters and story / Reference / Everything / Light companion / Deep study | sets the categories, the status block and the depth in one tap; reads Custom when they match no preset |
| **New X-Ray categories** | Follow global / All categories / a narrower pick, and the **Where things stand** checkbox | the categories (people, places, ideas, terms, events) and the status block for this book's future X-Rays and section X-Rays |
| **New X-Ray depth** | Follow global / Light / Standard / Deep | how much each entry carries in future creates and rebuilds, and in section X-Rays; checkpoints and updates keep the depth the X-Ray started with |
| **New X-Ray type** | Follow global / Auto / Fiction / Nonfiction / Academic | which schema future creates and rebuilds use; Auto lets the AI decide; updates keep the X-Ray's own type; a type unlike the book's X-Ray offers a rebuild |
| **Carried entries** | Follow global / In their categories too / Separate list only | where the entries carried from a group's other books are listed in this book's X-Ray browser; a display choice, nothing is sent |

Everything these rows control is explained on [Using X-Ray](Using-X-Ray).

### Privacy

Four overrides of the global sharing switches, **Highlights sharing**, **Annotations sharing**, **Notebook sharing** and **Text extraction**, each Follow global (On or Off) / On / Off, with a "How overrides work…" row. A per-book Off always wins, even over trusted providers; the rules are on [Privacy and Data](Privacy-and-Data#per-book-overrides).

### Identity

| Setting | Choices | Notes |
|---|---|---|
| **AI title** | Use real metadata / Custom… / Send empty | what the AI is told the book is called |
| **AI author** | Use real metadata / Custom… / Send empty | what the AI is told the author is |

These change only what KOAssistant sends to the AI and shows in its own chat header; KOReader's library metadata is never touched. The override reaches every action, X-Ray and the other artifacts included, through `{title}` and `{author}`. **Custom…** fixes wrong metadata, gives a working title, or uses a name the AI will recognize for a badly tagged file; **Send empty** sends nothing for that field (an anonymous author, a junk title suppressed).

### Quiz settings

Overrides for the chapter-end quiz and the Quiz action on this book, each Follow global by default:

- **Chapter-end quiz:** Follow global, or **Off: never quiz this book**. It can silence the chapter-end prompt for one book but cannot turn it on while the global Quiz on Chapter End is off; the offer's **Not for this book** button sets the same.
- **Question count**, **Difficulty**, **Multiple choice**, **Short answer**, **Discussion:** the same options as the global rows.
- **Chapter level:** which single table-of-contents level counts as a chapter for this book's chapter-end quiz.
- **Min chapter length:** skip the chapter-end prompt for chapters shorter than N pages: No minimum, Follow global, or a page count.
- **Min reading time:** the same for the minutes spent in the chapter.

The global rows and the quiz itself: [Reading Analysis Actions](Reading-Analysis-Actions#chapter-quiz).

### Languages

Four overrides, each Follow global by default: the **AI response language** for every action on this book, the **Translation language**, the **Dictionary language**, and the **Book text language** told to the AI in book-tool sessions. They are explained on [Languages](Languages).

## Resolution and reset

The order is: an action's own override where it declares one, then the per-book value, then the global setting. Follow global means no per-book override. Because per-book values are sticky and silent, the screen shows them: its title reads "Book Settings (N customized)" when the book has overrides, and a **Reset book settings** button clears every per-book override at once, which is the fix when a global change "isn't taking effect" for one book that was customized long ago. A book that follows a group reads the group's value live until it picks its own ([Book Groups and Series](Book-Groups-and-Series)).

## The Book Hub

One full-screen page per book with everything KOAssistant knows about it:

- every artifact with live status, X-Ray first (an open book without one gets a create route); tap a row to view it;
- **Chat/Action**, **Search in book** (open book; hands off to KOReader's full-text search), **Open Book** (closed-book views), **Chat History** with its count, **Notebook** (tap to view, hold to edit), **Group** (tap opens the Group Hub, hold the memberships popup, "Add to group…" when ungrouped), and **Book Settings** ("N customized"); a book in a group also gets a bottom-left up-arrow to its Group Hub;
- rows refresh in place as you generate things;
- the title-bar ☰ menu: **Refresh index**, **Export all artifacts** (to a folder, in your chosen format), **Browse all books** (the cross-book artifact browser) and **Delete all** (with a confirmation naming what it covers).

Open it from a file-browser long-press ("Book Hub (KOA)", switchable under **Settings → Menus & Buttons**), the KOAssistant menu (open book), the Quick Actions panel, a gesture ("KOAssistant: Book Hub"), or the "Book Hub…" row on every View Artifacts surface. A chat started from a closed book's hub while another book is open belongs to the closed book: its title, settings, saved position and chat storage are that book's ([Contexts and Chat](Contexts-and-Chat)).

## Related

- [Book Groups and Series](Book-Groups-and-Series): group settings, which a book can follow.
- [Settings Reference](Settings-Reference): the global rows these override.
- [Using X-Ray](Using-X-Ray): the X-Ray sub-screen's rows explained.
- [Privacy and Data](Privacy-and-Data): the per-book privacy overrides.
- [Artifacts and Caching](Artifacts-and-Caching): the artifacts the hub lists.
