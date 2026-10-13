# Image Generation

KOAssistant can turn a passage you highlight into an AI-generated image: a character, a described setting, a diagram, a scene straight from the text. It is a paid feature that uses your own provider key, like chat; each image costs what the provider charges per image, which is separate from and usually more than text, so use it deliberately.

## Generating an image

1. Highlight a passage of any length. By default the plugin frames it with the book's title and author and a slice of the surrounding text before sending it as the image prompt (the framing switches are below); the selected text is always the core of the prompt.
2. In the highlight menu, tap **Generate Image (KOA)**.
3. A progress window shows "Generating image with … / …" with an elapsed-seconds counter; **Stop** cancels a request in flight.
4. The finished image opens full screen in KOReader's image viewer, and is saved (below).

The button appears only when the resolved image provider can generate images and has an API key. With no such provider, it is hidden.

## Providers and models

Three providers offer image generation, each with its own models (the first is the default):

| Provider | Models | Notes |
|---|---|---|
| **OpenAI** | `gpt-image-1-mini` (default, fast, about 15 s, cheapest), `gpt-image-1.5`, `gpt-image-2` (flagship quality, slow, about 60 s), `gpt-image-1`, `chatgpt-image-latest` | size (1024x1024, landscape, portrait) and quality (low / medium / high) settings |
| **xAI (Grok)** | `grok-imagine-image` (default, fast, about 7 s), `grok-imagine-image-quality` (higher quality) | an aspect ratio setting (1:1, 16:9, 9:16, 3:2, 2:3) |
| **Gemini** | `gemini-3.1-flash-image` (default, "Nano Banana"), `gemini-3-pro-image` | no size or quality parameters |

Anthropic (Claude), DeepSeek and the other chat providers have no image API. If Claude is your main provider, pick a dedicated image provider below, or the button stays hidden.

## Choosing the provider and model

Image generation has its own provider and model, independent of your chat provider, so you can chat with Claude and draw with OpenAI. The rows are under **Settings → Advanced → Image Generation**:

- **Provider**: Follow main provider (the default: your current chat provider, when it can generate images) or OpenAI, xAI (Grok) or Gemini. An explicit pick works whatever chat provider is active, with that provider's own key.
- **OpenAI model**, **xAI model**, **Gemini model**: a model per provider, each defaulting to Default (the provider's first, recommended model).
- **OpenAI size** and **OpenAI quality**: dimensions and quality tier, OpenAI only.
- **Aspect ratio**: xAI only.
- **Include book title/author in prompt** and **Include surrounding text in prompt** (both on by default): whether the prompt is framed with the book's title and author and a short slice of the surrounding text, so illustrations match the work's setting and era. Turn either off for a prompt that is just your selection.
- **Prompt template…**: the exact prompt the image API will receive, with your framing switches applied.
- **Generated images…**: opens the gallery.

A parameter left at Default is left out of the request, so the provider decides.

## Where images are stored

Generated images are kept, not temporary, in `koassistant_images` under KOReader's data folder (for example `~/.config/koreader/koassistant_images` on a desktop). Each file is named with its creation date and time plus a snippet of the prompt, so the folder is self-describing. They are your data: preserved across plugin updates, and no reset or uninstall removes them. They are not part of KOAssistant backups; copy the folder yourself when moving to another device ([Backups and Updates](Backups-and-Updates)).

## The gallery

Open it from **Settings → Advanced → Image Generation → Generated images…**, or from any View Artifacts surface (below). Images are listed newest first with their file size. Tap an image to view it full screen; hold it to delete it, with a confirmation; the title-bar menu's **Delete all** clears every image, or just the book's in a per-book view.

## Per-book association

An image generated while reading is recorded as that book's, in a small index inside the images folder. That gives you a per-book gallery filtered to the book's images, and a **Generated Images (N)** entry on every View Artifacts surface: the file browser's long-press menu, the open book's artifact viewer, the input dialog's View Artifacts, the Book Hub, the chat window's Artifacts switcher, the X-Ray browser's Other Artifacts, and the cross-book artifact browser, where a book that only has images still shows up ([Artifacts and Caching](Artifacts-and-Caching)).

Images follow their book: moving the book in the file manager moves its associations; deleting the book keeps the images, which then appear only in the full gallery. Deleting an image from a per-book view keeps the index in step.

## Showing or hiding the button

Generate Image is an ordinary highlight action, on by default. Toggle it and move it among the other buttons under **Settings → Menus & Buttons → Highlight Menu Actions** ([Actions and Menus](Actions-and-Menus)). A change applies the next time the highlight menu opens, and the button hides itself whenever no image provider with a key is available.

## Related

- [Providers and Models](Providers-and-Models): the keys the image providers use.
- [Artifacts and Caching](Artifacts-and-Caching): the View Artifacts surfaces the gallery sits on.
- [Actions and Menus](Actions-and-Menus): the highlight menu's buttons.
