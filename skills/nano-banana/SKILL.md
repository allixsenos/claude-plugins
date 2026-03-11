---
name: nano-banana
description: >
  Generate and edit images using the Gemini API (Nano Banana models) directly
  from Claude Code. Supports blog heroes, thumbnails, icons, diagrams,
  illustrations, photos, and any visual content. Arbitrary aspect ratios,
  multiple resolutions, and three model tiers. Use this skill whenever the user
  asks to create, generate, make, draw, design, or edit any image or visual
  content.
allowed-tools:
  - Bash(curl:*)
  - Bash(python3:*)
  - Bash(open:*)
  - Bash(xdg-open:*)
  - Read
---

# Nano Banana — Direct Gemini API Image Generation

Generate and edit images by calling the Gemini API directly via curl.

## Setup

Set your Gemini API key in your shell environment:

```bash
# Add to your shell profile (~/.zshrc, ~/.bashrc, ~/.config/fish/config.fish)
export GEMINI_API_KEY="your-api-key-here"
```

The skill reads `GEMINI_API_KEY` directly from the environment. Get a key at
https://aistudio.google.com/apikey

## Available Models

| Model ID | Display Name | Strengths | Cost |
|----------|-------------|-----------|------|
| `gemini-2.5-flash-image` | Nano Banana | Fast, cheap, good for drafts | ~$0.04/image |
| `gemini-3-pro-image-preview` | Nano Banana Pro | High quality, better reasoning, larger output | ~$0.10/image |
| `gemini-3.1-flash-image-preview` | Nano Banana 2 | Latest flash, supports 512px size | ~$0.04/image |

Default to **Nano Banana Pro** (`gemini-3-pro-image-preview`) unless the user asks for
speed/cost optimization or drafts.

> **Note:** Gemini preview model IDs may change. Check
> https://ai.google.dev/gemini-api/docs/models for current model availability.

## Supported Aspect Ratios

`1:1`, `1:4`, `1:8`, `2:3`, `3:2`, `3:4`, `4:1`, `4:3`, `4:5`, `5:4`, `8:1`, `9:16`, `16:9`, `21:9`

Common use cases:

| Use Case | Aspect Ratio |
|----------|-------------|
| Blog hero / Substack featured | `16:9` |
| Open Graph / social preview | `3:2` or `16:9` |
| YouTube thumbnail | `16:9` |
| Instagram post | `1:1` or `4:5` |
| Instagram/TikTok story | `9:16` |
| Twitter/X header | `21:9` |
| Ultrawide banner | `21:9` |
| Portrait photo | `2:3` or `3:4` |

Default to **16:9** unless the user specifies otherwise.

## Supported Image Sizes

| Size | Notes |
|------|-------|
| `1K` | ~1024px on long edge. Fast, good for previews. |
| `2K` | ~2048px on long edge. Good default for web use. |
| `4K` | ~4096px on long edge. High-res, slower. |
| `512px` | Only available on Nano Banana 2 (3.1 Flash). |

Default to **2K** unless the user requests otherwise.

## Generate an Image

```bash
curl -s \
  "https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${GEMINI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "contents": [{"parts": [{"text": "Generate an image: PROMPT_HERE"}]}],
    "generationConfig": {
      "responseModalities": ["TEXT", "IMAGE"],
      "imageConfig": {
        "aspectRatio": "RATIO_HERE",
        "imageSize": "SIZE_HERE"
      }
    }
  }' | python3 -c "
import sys, json, base64, os
data = json.load(sys.stdin)
if 'error' in data:
    print(f'API Error: {data[\"error\"][\"message\"]}')
    sys.exit(1)
for part in data.get('candidates', [{}])[0].get('content', {}).get('parts', []):
    if 'inlineData' in part:
        img = base64.b64decode(part['inlineData']['data'])
        # Detect actual format from magic bytes, not MIME (some providers lie)
        if img[:4] == b'RIFF': ext = 'webp'
        elif img[:4] == b'\x89PNG': ext = 'png'
        elif img[:2] == b'\xff\xd8': ext = 'jpg'
        else: ext = 'png'
        path = 'OUTPUT_PATH_HERE'
        with open(path, 'wb') as f:
            f.write(img)
        print(f'Saved: {path} ({len(img)} bytes)')
    elif 'text' in part:
        print(f'Model: {part[\"text\"][:300]}')
"
```

Replace:
- `${MODEL}` — model ID from table above
- `PROMPT_HERE` — the image prompt
- `RATIO_HERE` — aspect ratio
- `SIZE_HERE` — image size
- `OUTPUT_PATH_HERE` — full output file path

## Edit an Existing Image

To modify an existing image, include it as base64 inline data alongside the text instruction:

```bash
python3 -c "
import base64, json, subprocess, sys, os

# Read and encode the source image
with open('INPUT_IMAGE_PATH', 'rb') as f:
    img_b64 = base64.b64encode(f.read()).decode()

# Detect mime type
path = 'INPUT_IMAGE_PATH'
mime = 'image/png' if path.endswith('.png') else 'image/jpeg'

payload = {
    'contents': [{'parts': [
        {'inlineData': {'mimeType': mime, 'data': img_b64}},
        {'text': 'EDIT_INSTRUCTION_HERE'}
    ]}],
    'generationConfig': {
        'responseModalities': ['TEXT', 'IMAGE'],
        'imageConfig': {
            'aspectRatio': 'RATIO_HERE',
            'imageSize': 'SIZE_HERE'
        }
    }
}

result = subprocess.run(
    ['curl', '-s',
     'https://generativelanguage.googleapis.com/v1beta/models/MODEL_HERE:generateContent?key=' + os.environ['GEMINI_API_KEY'],
     '-H', 'Content-Type: application/json',
     '-d', json.dumps(payload)],
    capture_output=True, text=True, env={**__import__('os').environ}
)

data = json.loads(result.stdout)
if 'error' in data:
    print(f'API Error: {data[\"error\"][\"message\"]}')
    sys.exit(1)
for part in data.get('candidates', [{}])[0].get('content', {}).get('parts', []):
    if 'inlineData' in part:
        img = base64.b64decode(part['inlineData']['data'])
        # Detect actual format from magic bytes, not MIME (some providers lie)
        if img[:4] == b'RIFF': ext = 'webp'
        elif img[:4] == b'\\x89PNG': ext = 'png'
        elif img[:2] == b'\\xff\\xd8': ext = 'jpg'
        else: ext = 'png'
        path = f'OUTPUT_PATH_HERE.{ext}'
        with open(path, 'wb') as f:
            f.write(img)
        print(f'Saved: {path} ({len(img)} bytes)')
    elif 'text' in part:
        print(f'Model: {part[\"text\"][:300]}')
"
```

Replace:
- `INPUT_IMAGE_PATH` — path to the image to edit
- `EDIT_INSTRUCTION_HERE` — what to change (e.g., "remove the background", "make it more blue")
- `MODEL_HERE` — model ID (Pro recommended for edits)
- `RATIO_HERE`, `SIZE_HERE`, `OUTPUT_PATH_HERE` — same as generation

## Generate Multiple Variations

To generate N variations, make N parallel curl calls (up to 4 concurrent). Each call
produces a different result from the same prompt due to model randomness.

```bash
# Run 3 variations in parallel
for i in 1 2 3; do
  (curl -s ... | python3 -c "..." ) &
done
wait
```

Vary the output filename per iteration (e.g., `hero-v1.png`, `hero-v2.png`, `hero-v3.png`).

## Verify Dimensions

After generation, verify the output dimensions:

```bash
python3 -c "
import struct
with open('output.png', 'rb') as f:
    f.read(16)
    w, h = struct.unpack('>II', f.read(8))
    print(f'{w}x{h}')
"
```

## Preview

To open the image in the default viewer:

```bash
# macOS
open output.png
# Linux
xdg-open output.png
```

## Output Location

Save generated images to the location the user specifies. If no location is given,
use the current working directory. Use short, descriptive filenames (e.g., `hero.png`,
`diagram-auth-flow.png`).

**NEVER overwrite existing files.** Before writing, check if the target path exists.
If it does, append a version suffix: `hero.jpg` → `hero-v2.jpg` → `hero-v3.jpg`, etc.
Scan for existing versions to pick the next number. This applies to all generation and
edit operations — every API call produces a new file.

## Prompt Recording (MANDATORY)

**ALWAYS save the prompt alongside every generated image.** For every image
saved as `filename.png`, also save `filename.txt` containing:

```
model: <model ID used>
aspect_ratio: <ratio>
image_size: <size>

<the exact prompt text sent to the API>
```

This is non-negotiable. Every image must have a corresponding prompt file so
generations can be reproduced or iterated on later.

## Error Handling

| Error | Cause | Fix |
|-------|-------|-----|
| `RESOURCE_EXHAUSTED` | Quota limit hit | Wait or switch to a cheaper model |
| `INVALID_ARGUMENT` | Bad aspect ratio or size | Check supported values |
| `SAFETY` block | Content policy violation | Simplify the prompt |
| Empty response / no image | Model returned text only | Retry, or rephrase prompt to be more explicit ("Generate an image:") |

## Prompt Tips

1. **Start with "Generate an image:"** to make intent clear to the model
2. **Be specific about composition**: left/right/center, foreground/background
3. **Specify text explicitly**: wrap exact text in quotes within the prompt
4. **Add "no text"** if you don't want text rendered in the image
5. **Reference styles**: "editorial photography", "flat illustration", "3D render", "watercolor", "cinematic"
6. **For text-heavy images**: Nano Banana Pro handles text rendering better than Flash
