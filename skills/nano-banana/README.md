# nano-banana

Generate and edit images using the Gemini API (Nano Banana models) directly from Claude Code. Supports blog heroes, thumbnails, icons, diagrams, illustrations, photos, and any visual content. Arbitrary aspect ratios, multiple resolutions, and three model tiers.

## Install

```
npx skills add allixsenos/claude-plugins --skill nano-banana
```

Or via the plugin marketplace (installs all plugins and skills):

```
/plugin marketplace add allixsenos/claude-plugins
```

## Requirements

- `GEMINI_API_KEY` environment variable set

## Usage

Just ask Claude to create an image:

- "generate a hero image for my blog post about database security"
- "create a dark tech diagram showing a proxy architecture"
- "edit this image to remove the background"
