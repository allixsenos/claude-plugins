# openrouter-imagegen

Generate and edit images using OpenRouter's unified API. Supports Google Nano Banana, OpenAI GPT-5 Image, FLUX.2, Sourceful Riverflow, and any future image models OpenRouter adds. Discovers available models at runtime.

## Install

```
npx skills add allixsenos/claude-plugins --skill openrouter-imagegen
```

Or via the plugin marketplace (installs all plugins and skills):

```
/plugin marketplace add allixsenos/claude-plugins
```

## Requirements

- `OPENROUTER_API_KEY` environment variable set

## Usage

Just ask Claude to create an image:

- "generate an image of a mountain landscape using FLUX"
- "create a logo using GPT-5 Image"
- "what image models are available on OpenRouter?"
