# Image Generation

KOAssistant can turn a passage you highlight, or an entry of a book's X-Ray, into an AI-generated image: a character, a described setting, a diagram, a scene straight from the text. It is a paid feature that uses your own provider key, like chat; each image costs what the provider charges per image, which is separate from and usually more than text, so use it deliberately.

## Generating an image

1. Highlight a passage of any length.
2. In the highlight menu, tap **Generate Image (KOA)**. Long-press it for **Generate with a note…**: type what the picture should show, or how ("from behind", "at night, one lit window"). In the highlight input dialog, whatever you typed is the note.
3. By default your chat provider's fast model first writes the image prompt from the passage and what surrounds it ([the prompt writer](#the-prompt-writer), below); the progress window shows "Writing the prompt with … / …", then "Generating image with … / …", with an elapsed-seconds counter. **Stop** cancels whichever request is in flight.
4. The finished image opens full screen in KOReader's image viewer, and is saved (below). Its caption (the triangle in the title bar) starts with who wrote the prompt and from what, then the prompt itself. If the provider refuses the prompt or the request fails, an error message shows instead and nothing is saved. A refusal says why when the provider gives a reason: Google's safety filter and the reason it names, or OpenAI's moderation and whether it refused the prompt or the picture.

The button appears when the image provider in effect can generate images and has an API key. If Provider is Follow main provider and your chat provider cannot make images (Anthropic, DeepSeek and the other text providers), it appears when any image provider has a key: the first tap asks which one makes your images, listing only those you have a key for, and saves the answer as **Provider** (below). Cancel leaves it unset, so the next tap asks again. With no image provider key at all, the button is hidden.

## Providers and models

Four providers offer image generation, each with its own models (the first is the default):

| Provider | Models | Notes |
|---|---|---|
| **OpenAI** | `gpt-image-2.5-flare` (default: fast, about 11 s at Draft), `gpt-image-2.5-sunburst` (finest detail, slower), `gpt-image-2`, `gpt-image-1-mini` | the 2.5 models draw your screen's exact proportions under Fit my screen (1152x1536 on most e-readers), the others the nearest of 1024x1024, 1536x1024 and 1024x1536; Detail sets the quality |
| **xAI (Grok)** | `grok-imagine-image` (default: fast, about 7 s, the cheapest), `grok-imagine-image-2.0` (better pictures, about twice the price) | Detail applies to `grok-imagine-image-2.0` only |
| **Gemini** | `gemini-nano-banana-2.1` (default: Nano Banana 2.1, Google's everyday image model), `gemini-3.1-flash-lite-image` (the fastest and cheapest, a few seconds), `gemini-3-pro-image` (Nano Banana Pro: finest detail, slower) | Flash Lite draws at one size, so Detail does not apply to it; requests follow **Settings → Advanced → Provider Settings → Gemini Content Filter**, as chat does |
| **OpenRouter** | `openai/gpt-image-2.5-flare` (default: about half a cent at Draft), `google/gemini-nano-banana-2.1`, `black-forest-labs/flux-3-image` (FLUX 3, about 5 cents), `bytedance-seed/seedream-5-0-flash` (Seedream 5.0 Flash, about 2 cents), `recraft/recraft-v4.1-flash` (Recraft v4.1 Flash, under a cent, leans to illustration); **More models…** lists the rest of OpenRouter's image catalog | many makers' models through one OpenRouter key; Shape and Detail become what each model takes (its proportions, and a quality or a resolution: 1K, Best 2K), and Detail is grayed out for a model that takes neither (Recraft) |

A model you picked that has left this list keeps working (`gpt-image-1.5`, `gpt-image-1`, `chatgpt-image-latest`, `gemini-3.1-flash-image`). xAI retires `grok-imagine-image-quality` on November 2, 2026, so a pick of it goes out as `grok-imagine-image-2.0`, the model xAI answers it with.

KOAssistant generates images only through these four; Anthropic (Claude), DeepSeek, OpenAI Subscription and the other chat providers are not used for images (they write the prompt: see below). With one of them as your main provider, the first tap of Generate Image asks which image provider to use, or pick one yourself under Provider below (OpenAI there needs an OpenAI API key: the subscription sign-in does not cover images).

## The prompt writer

Image models draw what a prompt describes, and a passage from the middle of a book often names people and places the model knows nothing about. So, unless you turn **Write the prompt with AI** off, a fast text model writes the prompt first, from material it is told where each piece comes from:

- the passage (the picture shows it),
- your note, when you add one (it is followed),
- the text around the passage, cut the way chat's context is,
- the entries of this book's X-Ray that the passage names, up to five, with their descriptions as of the X-Ray you have installed (so nothing from further ahead than it), found by the same matching the X-Ray marks use,
- the book's title and author, as far as Book Info in Chat allows,
- the book's Background (Book Settings), and
- the Style and the Shape below; on a black-and-white screen it is also told the picture is for e-ink (clear shapes, strong contrast).

The writer describes people by how they look, never by name, adds nothing from its own knowledge of the book, and keeps text, titles and captions out of the picture; with [spoiler protection](Spoiler-Protection) on, it is told to show nothing later in the story than the passage. The model is your chat provider's fast model (a global tier pin for Fast is honored, and with **Settings → Advanced → Faster Models for Quick Actions** off, your chat model), with reasoning off: a few seconds and a fraction of a cent per picture.

What goes where: the material goes to your chat provider; the image provider receives only the prompt the writer wrote. The text around the passage and the X-Ray descriptions are your data under [Privacy and Data](Privacy-and-Data), so each must be allowed for both providers, and when one is on Ask, one question names both ("Generate Image will send to Anthropic, to write the prompt, and to OpenAI, to draw it"). **Continue without** makes this picture without them and changes no setting; a kind set to Never is left out, and the caption says so.

If the writer fails (an error, an empty answer, or one far too long for a prompt), the picture is drawn from the passage framed as before, and the progress window and the caption say the writer failed and why. With the writer off, the passage goes to the image model framed with the title and author and the text around it, the style and your note as lines at the end.

## Illustrate from X-Ray

An entry of a book's X-Ray can be drawn too: open the entry (from the X-Ray browser, or by tapping a marked name and its card), then **More… → Illustrate…**. A short dialog takes an optional note; **Illustrate** starts. The entry's description is the subject, with the book's title and author, its Background, the Style and the Shape; an abstract entry (an idea, an argument) gets a scene that carries it. It works for every entry of the book's own installed X-Ray, not for carried entries, other books' entries or upcoming entries, and only while an image provider is available. The description is your stored data: it is sent only where the kinds the X-Ray was made from are allowed (book text, and your highlights if it used them).

## Choosing the provider and model

Image generation has its own provider and model, independent of your chat provider, so you can chat with Claude and draw with OpenAI. The rows are under **Settings → Advanced → Image Generation**:

- **Provider**: Follow main provider (the default: your current chat provider, when it can generate images) or OpenAI, xAI (Grok), Gemini or OpenRouter. An explicit pick works whatever chat provider is active, with that provider's own key.
- **OpenAI model**, **xAI model**, **Gemini model**, **OpenRouter model**: a model per provider, each defaulting to Default (the provider's first, recommended model). OpenRouter's row also has **More models…**, which fetches OpenRouter's image catalog (dozens of models, with a filter) and remembers what the model you pick can draw, so Shape and Detail fit it.
- **Shape**, for every provider: **Fit my screen** (the default: your screen's proportions as you hold it, so the picture fills an e-reader's page), **Portrait**, **Landscape**, **Square**, or **Let the model choose** (the provider decides, and often draws a square or a wide picture). Each model gets the nearest proportions it can draw.
- **Detail**, for every provider: **Draft** (the default: the fastest and cheapest), **Standard** or **Best** (the slowest and costs the most). It sets OpenAI's quality (low, medium, high; xhigh on the 2.5 models), the quality and size of `grok-imagine-image-2.0` (low quality at Draft, medium above it, and twice the size at Best), Gemini's size (2K at Best, 1K otherwise; at Draft, Nano Banana 2.1 and Pro are also told to think as little as they can before drawing: Nano Banana 2.1 drew in about 9 seconds instead of 13 to 23, with pictures as good) and, on OpenRouter, the quality or the resolution the model takes (1K, 2K at Best). It is grayed out while the model in use has a single setting: `grok-imagine-image`, Gemini Flash Lite, and OpenRouter models that take neither.
- **Write the prompt with AI** (on by default): [the prompt writer](#the-prompt-writer) above. Off sends the framed passage straight to the image model.
- **Style**, for every provider: **Book illustration** (the default), **Watercolor**, **Ink drawing**, **Pencil sketch**, **Woodcut**, **Photographic**, **Comic**, **Map or diagram**, or **Custom…** (your own words, such as "a 1920s travel poster"). The writer works it into the prompt; with the writer off, a style other than Book illustration is a line at the end of the prompt.
- **Include book title/author in prompt** and **Include surrounding text in prompt** (both on by default): whether the prompt is framed with the book's title and author and a short slice of the surrounding text, so illustrations match the work's setting and era. A framed prompt also tells the model to put no text, titles or captions in the image. Turn both off for a prompt that is just your selection. The frame follows the same rules as chat: the title and author go only as far as **Settings → Chat & Export Settings → Book Info in Chat** (or the book's own value in Book Settings) allows, so None sends neither and Title only sends the title; and the text after your selection is cut the way chat's context is, by **Settings → Highlight Settings → Context Direction** and, while [spoiler protection](Spoiler-Protection) is on, **Context Under Spoiler Protection**.
- **Prompt template…**: what goes to the models with your current settings: the writer's instructions and the material it reads (with the writer on), then the framed prompt (the writer's fallback, or the prompt itself with the writer off).
- **Generated images…**: opens the gallery.

A provider's model row can be changed while that provider makes the images: the one **Provider** names, or your chat provider under Follow main provider. The other providers' model rows are grayed out, and the models they hold apply when that provider is used. Shape and Detail apply to whichever provider makes the images.

## Where images are stored

Generated images are kept, not temporary, in `koassistant_images` under KOReader's data folder (for example `~/.config/koreader/koassistant_images` on a Linux desktop). Each file is named with its creation date and time plus the start of the selected text, so the folder is self-describing, and carries the type of its contents: `.jpg` for most new images (KOAssistant asks OpenAI for JPEG, a fraction of a PNG's size and quicker to open, and Gemini and xAI send JPEG), `.webp` or `.png` for some of OpenRouter's models, `.png` for images made by earlier versions. A `thumbnails` folder beside them holds a small preview of each (made once, so the gallery never has to open the full pictures). They are your data: preserved across plugin updates, and no reset or uninstall removes them. They are not part of KOAssistant backups; copy the folder yourself when moving to another device ([Backups and Updates](Backups-and-Updates)).

## The gallery

Open it from **Settings → Advanced → Image Generation → Generated images…**, or from any View Artifacts surface (below), which opens the book's own images. When your images come from more than one book, the gallery first lists **All images**, then each book (the one with the newest image first), then **Without a book** (images made outside a book, or whose book was deleted), each with its count; tap one to see its images.

The images show as thumbnails, newest first, nine to a page (eight with the reader held sideways), with the start of the selected text (or the X-Ray entry's name) under each. Turn pages with a swipe, the arrows at the bottom or the page keys; swipe down to close. Images made before this version get their thumbnail the first time a page shows them, after a short "Making previews…" note.

- **Tap** an image to view it full screen; the triangle in its title bar shows the prompt.
- **Hold** an image to read who drew it (the provider and model), who wrote the prompt and from what, then the full prompt that was sent, with three buttons:
  - **Regenerate** draws the same prompt again with the image provider, model, Shape and Detail now in effect (no prompt writer this time: the prompt is used as it stands). The new image is saved beside the old one, which stays until you delete it, and shows first in the gallery.
  - **Edit prompt…** opens the prompt in an editor; **Regenerate** there draws your edited text the same way.
  - **Delete image…** deletes it after a confirmation.

  An image with no recorded prompt (made by a version before the prompt was kept) goes straight to the delete confirmation.
- The **menu button** in the title bar deletes every image shown after a confirmation: all of them, or just one book's.

A prompt drawn again goes to the image provider in effect with what it carries: a prompt made from the text around the passage or from X-Ray descriptions asks the same privacy question a new image does when that data is on Ask, and is refused when it is set to Never. It has no **Continue without**, since what a written prompt took from them cannot be taken out ([Privacy and Data](Privacy-and-Data)). On a device without a touchscreen the gallery is a list of names with the same tap and hold.

## Per-book association

An image generated while reading is recorded as that book's, in a small index inside the images folder. That gives you a per-book gallery filtered to the book's images, and a **Generated Images (N)** entry on every View Artifacts surface: the file browser's long-press menu, the open book's artifact viewer, the input dialog's View Artifacts, the Book Hub, the chat window's Artifacts switcher, the X-Ray browser's Other Artifacts, and the cross-book artifact browser, where a book that only has images still shows up ([Artifacts and Caching](Artifacts-and-Caching)).

Images follow their book: moving the book in the file manager moves its associations; deleting the book keeps the images and their prompts, which then appear under **Without a book**. Deleting an image from the gallery removes its thumbnail and keeps the index in step.

## Showing or hiding the button

Generate Image is an ordinary highlight action, on by default. Toggle it and move it among the other buttons under **Settings → Menus & Buttons → Highlight Menu Actions** ([Actions and Menus](Actions-and-Menus)). A change applies the next time the highlight menu opens, and the button hides itself whenever no image provider with a key is available, or with the other action buttons when **Settings → Menus & Buttons → Show quick actions** is off. Like other highlight actions, it can also be added to the dictionary popup (**Settings → Menus & Buttons → Dictionary Popup Actions**) or the highlight input dialog (**Settings → Menus & Buttons → Input Dialog Actions**), where the same provider rule applies; gestures cannot run it.

## Related

- [Providers and Models](Providers-and-Models): the keys the image providers use.
- [Artifacts and Caching](Artifacts-and-Caching): the View Artifacts surfaces the gallery sits on.
- [Actions and Menus](Actions-and-Menus): the highlight menu's buttons.
