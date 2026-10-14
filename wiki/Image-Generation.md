# Image Generation

KOAssistant can turn a passage you highlight into an AI-generated image: a character, a described setting, a diagram, a scene straight from the text. It is a paid feature that uses your own provider key, like chat; each image costs what the provider charges per image, which is separate from and usually more than text, so use it deliberately.

## Generating an image

1. Highlight a passage of any length. By default the plugin frames it with the book's title and author and a slice of the surrounding text before sending it as the image prompt (the framing switches are below); the selected text is always the core of the prompt.
2. In the highlight menu, tap **Generate Image (KOA)**.
3. A progress window shows "Generating image with … / …" with an elapsed-seconds counter; **Stop** cancels a request in flight.
4. The finished image opens full screen in KOReader's image viewer, and is saved (below). If the provider refuses the prompt or the request fails, an error message shows instead and nothing is saved. A refusal says why when the provider gives a reason: Google's safety filter and the reason it names, or OpenAI's moderation and whether it refused the prompt or the picture.

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

KOAssistant generates images only through these four; Anthropic (Claude), DeepSeek, OpenAI Subscription and the other chat providers are not used for images. With one of them as your main provider, the first tap of Generate Image asks which image provider to use, or pick one yourself under Provider below (OpenAI there needs an OpenAI API key: the subscription sign-in does not cover images).

## Choosing the provider and model

Image generation has its own provider and model, independent of your chat provider, so you can chat with Claude and draw with OpenAI. The rows are under **Settings → Advanced → Image Generation**:

- **Provider**: Follow main provider (the default: your current chat provider, when it can generate images) or OpenAI, xAI (Grok), Gemini or OpenRouter. An explicit pick works whatever chat provider is active, with that provider's own key.
- **OpenAI model**, **xAI model**, **Gemini model**, **OpenRouter model**: a model per provider, each defaulting to Default (the provider's first, recommended model). OpenRouter's row also has **More models…**, which fetches OpenRouter's image catalog (dozens of models, with a filter) and remembers what the model you pick can draw, so Shape and Detail fit it.
- **Shape**, for every provider: **Fit my screen** (the default: your screen's proportions as you hold it, so the picture fills an e-reader's page), **Portrait**, **Landscape**, **Square**, or **Let the model choose** (the provider decides, and often draws a square or a wide picture). Each model gets the nearest proportions it can draw.
- **Detail**, for every provider: **Draft** (the default: the fastest and cheapest), **Standard** or **Best** (the slowest and costs the most). It sets OpenAI's quality (low, medium, high; xhigh on the 2.5 models), the quality and size of `grok-imagine-image-2.0` (low quality at Draft, medium above it, and twice the size at Best), Gemini's size (2K at Best, 1K otherwise) and, on OpenRouter, the quality or the resolution the model takes (1K, 2K at Best). It is grayed out while the model in use has a single setting: `grok-imagine-image`, Gemini Flash Lite, and OpenRouter models that take neither.
- **Include book title/author in prompt** and **Include surrounding text in prompt** (both on by default): whether the prompt is framed with the book's title and author and a short slice of the surrounding text, so illustrations match the work's setting and era. A framed prompt also tells the model to put no text, titles or captions in the image. Turn both off for a prompt that is just your selection. The frame follows the same rules as chat: the title and author go only as far as **Settings → Chat & Export Settings → Book Info in Chat** (or the book's own value in Book Settings) allows, so None sends neither and Title only sends the title; and the text after your selection is cut the way chat's context is, by **Settings → Highlight Settings → Context Direction** and, while [spoiler protection](Spoiler-Protection) is on, **Context Under Spoiler Protection**.
- **Prompt template…**: the exact prompt the image API will receive, with your framing switches applied.
- **Generated images…**: opens the gallery.

A provider's model row can be changed while that provider makes the images: the one **Provider** names, or your chat provider under Follow main provider. The other providers' model rows are grayed out, and the models they hold apply when that provider is used. Shape and Detail apply to whichever provider makes the images.

## Where images are stored

Generated images are kept, not temporary, in `koassistant_images` under KOReader's data folder (for example `~/.config/koreader/koassistant_images` on a Linux desktop). Each file is named with its creation date and time plus the start of the selected text, so the folder is self-describing, and carries the type of its contents: `.jpg` for most new images (KOAssistant asks OpenAI for JPEG, a fraction of a PNG's size and quicker to open, and Gemini and xAI send JPEG), `.webp` or `.png` for some of OpenRouter's models, `.png` for images made by earlier versions. They are your data: preserved across plugin updates, and no reset or uninstall removes them. They are not part of KOAssistant backups; copy the folder yourself when moving to another device ([Backups and Updates](Backups-and-Updates)).

## The gallery

Open it from **Settings → Advanced → Image Generation → Generated images…**, or from any View Artifacts surface (below). Images are listed newest first with their file size. Tap an image to view it full screen; hold it to read the full prompt that was sent, with **Delete image…** under it (an image with no recorded prompt goes straight to the delete confirmation). The menu button in the title bar deletes every image after a confirmation, or just the book's in a per-book view.

## Per-book association

An image generated while reading is recorded as that book's, in a small index inside the images folder. That gives you a per-book gallery filtered to the book's images, and a **Generated Images (N)** entry on every View Artifacts surface: the file browser's long-press menu, the open book's artifact viewer, the input dialog's View Artifacts, the Book Hub, the chat window's Artifacts switcher, the X-Ray browser's Other Artifacts, and the cross-book artifact browser, where a book that only has images still shows up ([Artifacts and Caching](Artifacts-and-Caching)).

Images follow their book: moving the book in the file manager moves its associations; deleting the book keeps the images, which then appear only in the full gallery. Deleting an image from a per-book view keeps the index in step.

## Showing or hiding the button

Generate Image is an ordinary highlight action, on by default. Toggle it and move it among the other buttons under **Settings → Menus & Buttons → Highlight Menu Actions** ([Actions and Menus](Actions-and-Menus)). A change applies the next time the highlight menu opens, and the button hides itself whenever no image provider with a key is available, or with the other action buttons when **Settings → Menus & Buttons → Show quick actions** is off. Like other highlight actions, it can also be added to the dictionary popup (**Settings → Menus & Buttons → Dictionary Popup Actions**) or the highlight input dialog (**Settings → Menus & Buttons → Input Dialog Actions**), where the same provider rule applies; gestures cannot run it.

## Related

- [Providers and Models](Providers-and-Models): the keys the image providers use.
- [Artifacts and Caching](Artifacts-and-Caching): the View Artifacts surfaces the gallery sits on.
- [Actions and Menus](Actions-and-Menus): the highlight menu's buttons.
