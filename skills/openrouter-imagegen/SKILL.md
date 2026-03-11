---
name: openrouter-imagegen
description: >
  Generate and edit images using OpenRouter's unified API. Supports Google Nano
  Banana, OpenAI GPT-5 Image, FLUX.2, Sourceful Riverflow, and any future image
  models OpenRouter adds. Discovers available models at runtime. Use this skill
  when the user asks to create, generate, make, draw, design, or edit images
  and wants to use OpenRouter or a specific model available through it.
allowed-tools:
  - Bash(curl:*)
  - Bash(python3:*)
  - Bash(open:*)
  - Bash(xdg-open:*)
  - Read
---

# OpenRouter Image Generation

Generate and edit images via OpenRouter's unified API. One key, many models.

## Setup

Set your OpenRouter API key in your shell environment:

```bash
# fish
set -gx OPENROUTER_API_KEY "sk-or-v1-your-key-here"

# bash/zsh
export OPENROUTER_API_KEY="sk-or-v1-your-key-here"
```

Get a key at https://openrouter.ai/settings/keys

## Discover Available Models

Always check which image models are currently available before generating:

```bash
curl -s "https://openrouter.ai/api/frontend/models" -o /tmp/or_models.json && python3 << 'PYEOF'
import json
with open('/tmp/or_models.json') as f:
    data = json.load(f)
models = [m for m in data.get('data', []) if 'image' in (m.get('output_modalities') or [])]
models = [m for m in models if m.get('slug') != 'openrouter/auto']
for m in sorted(models, key=lambda x: x.get('slug', '')):
    inp = ','.join(m.get('input_modalities') or [])
    out = ','.join(m.get('output_modalities') or [])
    print(f"{m['slug']:55s} in=[{inp}] out=[{out}]")
print(f"\n{len(models)} image models available")
PYEOF
```

Run this at the start of any image generation session so you know what's available.

## Known Model Tiers

These are the models typically available. The discovery command above is the
source of truth — models come and go.

| Provider | Model ID | Strengths |
|----------|----------|-----------|
| Google | `google/gemini-2.5-flash-image` | Fast, cheap, good default |
| Google | `google/gemini-3-pro-image-preview` | Highest quality Gemini |
| Google | `google/gemini-3.1-flash-image-preview` | Latest flash, 512px support |
| OpenAI | `openai/gpt-5-image` | High quality, file input |
| OpenAI | `openai/gpt-5-image-mini` | Cheaper GPT-5, file input |
| FLUX | `black-forest-labs/flux.2-pro` | Image-only, high quality |
| FLUX | `black-forest-labs/flux.2-max` | Image-only, maximum quality |
| FLUX | `black-forest-labs/flux.2-flex` | Image-only, flexible |
| FLUX | `black-forest-labs/flux.2-klein-4b` | Image-only, fast/cheap |
| Sourceful | `sourceful/riverflow-v2-pro` | Custom font support |
| ByteDance | `bytedance-seed/seedream-4.5` | Alternative provider |

Default to **`google/gemini-3-pro-image-preview`** (Nano Banana Pro) unless the
user asks for a specific model, speed optimization, or cost savings.

## Model Categories

Models fall into two categories based on output modalities:

**Text + Image models** (Google, OpenAI): Use `modalities: ["text", "image"]`.
These can describe what they generated and support conversational editing.

**Image-only models** (FLUX, Sourceful, ByteDance): Use `modalities: ["image"]`.
These return only the image with no text description.

Check the discovery output for each model's capabilities before calling.

## Supported Aspect Ratios

`1:1`, `1:4`, `1:8`, `2:3`, `3:2`, `3:4`, `4:1`, `4:3`, `4:5`, `5:4`, `8:1`,
`9:16`, `16:9`, `21:9`

Not all models support all ratios. Google models have the widest support.

| Use Case | Aspect Ratio |
|----------|-------------|
| Blog hero / Substack featured | `16:9` |
| Open Graph / social preview | `3:2` or `16:9` |
| YouTube thumbnail | `16:9` |
| Instagram post | `1:1` or `4:5` |
| Instagram/TikTok story | `9:16` |
| Twitter/X header | `21:9` |
| Portrait photo | `2:3` or `3:4` |

Default to **16:9** unless the user specifies otherwise.

## Supported Image Sizes

| Size | Notes |
|------|-------|
| `1K` | ~1024px on long edge. Fast, good for previews. |
| `2K` | ~2048px on long edge. Good default for web use. |
| `4K` | ~4096px on long edge. High-res, slower. |

Default to **2K** unless the user requests otherwise.

## Generate an Image (Text + Image models)

For models that output both text and image (Google, OpenAI):

```bash
curl -s "https://openrouter.ai/api/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${OPENROUTER_API_KEY}" \
  -d '{
    "model": "MODEL_ID_HERE",
    "messages": [{"role": "user", "content": "Generate an image: PROMPT_HERE"}],
    "modalities": ["text", "image"],
    "image_config": {
      "aspect_ratio": "RATIO_HERE",
      "image_size": "SIZE_HERE"
    }
  }' | python3 -c "
import sys, json, base64
data = json.load(sys.stdin)
if 'error' in data:
    print(f'API Error: {data[\"error\"].get(\"message\", data[\"error\"])}')
    sys.exit(1)
choice = data.get('choices', [{}])[0]
msg = choice.get('message', {})
# Handle text response
content = msg.get('content', '')
if content:
    print(f'Model: {content[:300]}')
# Handle image response
images = msg.get('images', [])
for i, img_obj in enumerate(images):
    url = img_obj if isinstance(img_obj, str) else (img_obj.get('image_url', {}).get('url', '') if isinstance(img_obj.get('image_url'), dict) else img_obj.get('url', img_obj.get('image_url', '')))
    if url.startswith('data:'):
        header, b64data = url.split(',', 1)
        img = base64.b64decode(b64data)
        # Detect actual format from magic bytes, not MIME (some providers lie)
        if img[:4] == b'RIFF': ext = 'webp'
        elif img[:4] == b'\x89PNG': ext = 'png'
        elif img[:2] == b'\xff\xd8': ext = 'jpg'
        else: ext = 'png'
        path = 'OUTPUT_PATH_HERE'
        with open(path, 'wb') as f:
            f.write(img)
        print(f'Saved: {path} ({len(img)} bytes)')
"
```

## Generate an Image (Image-only models)

For FLUX, Sourceful, ByteDance models:

```bash
curl -s "https://openrouter.ai/api/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${OPENROUTER_API_KEY}" \
  -d '{
    "model": "MODEL_ID_HERE",
    "messages": [{"role": "user", "content": "PROMPT_HERE"}],
    "modalities": ["image"],
    "image_config": {
      "aspect_ratio": "RATIO_HERE",
      "image_size": "SIZE_HERE"
    }
  }' | python3 -c "
import sys, json, base64
data = json.load(sys.stdin)
if 'error' in data:
    print(f'API Error: {data[\"error\"].get(\"message\", data[\"error\"])}')
    sys.exit(1)
choice = data.get('choices', [{}])[0]
msg = choice.get('message', {})
images = msg.get('images', [])
for i, img_obj in enumerate(images):
    url = img_obj if isinstance(img_obj, str) else (img_obj.get('image_url', {}).get('url', '') if isinstance(img_obj.get('image_url'), dict) else img_obj.get('url', img_obj.get('image_url', '')))
    if url.startswith('data:'):
        header, b64data = url.split(',', 1)
        img = base64.b64decode(b64data)
        # Detect actual format from magic bytes, not MIME (some providers lie)
        if img[:4] == b'RIFF': ext = 'webp'
        elif img[:4] == b'\x89PNG': ext = 'png'
        elif img[:2] == b'\xff\xd8': ext = 'jpg'
        else: ext = 'png'
        path = 'OUTPUT_PATH_HERE'
        with open(path, 'wb') as f:
            f.write(img)
        print(f'Saved: {path} ({len(img)} bytes)')
if not images:
    # Some models return image data differently
    content = msg.get('content', '')
    if content:
        print(f'Response: {content[:500]}')
"
```

## Edit an Existing Image

For models that accept image input (Google, OpenAI — check `input_modalities`):

```bash
python3 -c "
import base64, json, subprocess, sys, os

with open('INPUT_IMAGE_PATH', 'rb') as f:
    img_b64 = base64.b64encode(f.read()).decode()

path = 'INPUT_IMAGE_PATH'
mime = 'image/png' if path.endswith('.png') else 'image/jpeg'
data_url = f'data:{mime};base64,{img_b64}'

payload = {
    'model': 'MODEL_ID_HERE',
    'messages': [{'role': 'user', 'content': [
        {'type': 'image_url', 'image_url': {'url': data_url}},
        {'type': 'text', 'text': 'EDIT_INSTRUCTION_HERE'}
    ]}],
    'modalities': ['text', 'image'],
    'image_config': {
        'aspect_ratio': 'RATIO_HERE',
        'image_size': 'SIZE_HERE'
    }
}

result = subprocess.run(
    ['curl', '-s', 'https://openrouter.ai/api/v1/chat/completions',
     '-H', 'Content-Type: application/json',
     '-H', f'Authorization: Bearer {os.environ[\"OPENROUTER_API_KEY\"]}',
     '-d', json.dumps(payload)],
    capture_output=True, text=True
)

data = json.loads(result.stdout)
if 'error' in data:
    print(f'API Error: {data[\"error\"].get(\"message\", data[\"error\"])}')
    sys.exit(1)
msg = data.get('choices', [{}])[0].get('message', {})
if msg.get('content'):
    print(f'Model: {msg[\"content\"][:300]}')
for img_obj in msg.get('images', []):
    url = img_obj if isinstance(img_obj, str) else (img_obj.get('image_url', {}).get('url', '') if isinstance(img_obj.get('image_url'), dict) else img_obj.get('url', img_obj.get('image_url', '')))
    if url.startswith('data:'):
        header, b64data = url.split(',', 1)
        img = base64.b64decode(b64data)
        # Detect actual format from magic bytes, not MIME (some providers lie)
        if img[:4] == b'RIFF': ext = 'webp'
        elif img[:4] == b'\x89PNG': ext = 'png'
        elif img[:2] == b'\xff\xd8': ext = 'jpg'
        else: ext = 'png'
        path = f'OUTPUT_PATH_HERE.{ext}'
        with open(path, 'wb') as f:
            f.write(img)
        print(f'Saved: {path} ({len(img)} bytes)')
"
```

Replace:
- `INPUT_IMAGE_PATH` — path to the image to edit
- `EDIT_INSTRUCTION_HERE` — what to change
- `MODEL_ID_HERE` — use a model with image in `input_modalities`
- `RATIO_HERE`, `SIZE_HERE`, `OUTPUT_PATH_HERE` — same as generation

## Generate Multiple Variations

Make N parallel curl calls (up to 4 concurrent):

```bash
for i in 1 2 3; do
  (curl -s ... | python3 -c "..." ) &
done
wait
```

Vary the output filename per iteration (e.g., `hero-v1.jpg`, `hero-v2.jpg`).

## Verify Dimensions

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

```bash
# macOS
open output.png
# Linux
xdg-open output.png
```

## Output Location

Save images where the user specifies. If no location is given, use the current
working directory. Use short, descriptive filenames.

**NEVER overwrite existing files.** Before writing, check if the target path
exists. If it does, append a version suffix: `hero.jpg` -> `hero-v2.jpg` ->
`hero-v3.jpg`. Scan for existing versions to pick the next number.

## Background Generation

When generating images, always run the curl/python commands with `run_in_background: true`
on the Bash tool. This prevents blocking the conversation while waiting for the API response
(which can take 30-120 seconds per image). Save prompt `.txt` files immediately, then check
results when the background task completes.

When generating multiple images, launch all calls in parallel as separate background Bash commands.

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
| 401 Unauthorized | Bad or missing API key | Check `OPENROUTER_API_KEY` |
| 402 Payment Required | Insufficient credits | Add credits at openrouter.ai |
| 429 Rate Limited | Too many requests | Wait and retry |
| Model not found | Model ID changed or removed | Run discovery command |
| Empty images array | Model returned text only | Retry or rephrase prompt |
| No `images` field | Response format differs | Check raw response |

## Prompt Tips

1. **Start with "Generate an image:"** for text+image models
2. **Be specific about composition**: left/right/center, foreground/background
3. **Specify text explicitly**: wrap exact text in quotes within the prompt
4. **Add "no text"** if you don't want text rendered in the image
5. **Reference styles**: "editorial photography", "flat illustration", "3D render", "cinematic"
6. **For text-heavy images**: Nano Banana Pro or GPT-5 Image handle text best

## Choosing a Model

| Priority | Recommended |
|----------|-------------|
| Best quality | `google/gemini-3-pro-image-preview` or `openai/gpt-5-image` |
| Fast + cheap | `google/gemini-2.5-flash-image` |
| Image-only (no chat) | `black-forest-labs/flux.2-pro` |
| Custom fonts | `sourceful/riverflow-v2-pro` |
| Cost sensitive | `openai/gpt-5-image-mini` or FLUX Klein |

When unsure, run the discovery command and default to Nano Banana Pro.
