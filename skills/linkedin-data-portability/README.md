# linkedin-data-portability

Export LinkedIn member data (connections, profile, posts, messages, job applications, and 50+ other data domains) via the EU DMA Data Portability API.

## Install

```
npx skills add allixsenos/claude-plugins --skill linkedin-data-portability
```

Or via the plugin marketplace (installs all plugins and skills):

```
/plugin marketplace add allixsenos/claude-plugins
```

## Requirements

- LinkedIn account located in the EEA or Switzerland (DMA regulation)
- LinkedIn Developer Application with **Member Data Portability API (Member)** access
- `LINKEDIN_DMA_TOKEN` environment variable set with a valid OAuth access token

## Setup

1. Create a dev app at https://developer.linkedin.com/ using the [default company page](https://www.linkedin.com/company/member-data-portability-member-default-company)
2. Request access to **Member Data Portability API (Member)** in the Products tab
3. Generate an access token via **Docs and tools > OAuth Token Tools** with scope `r_dma_portability_self_serve`
4. Set `LINKEDIN_DMA_TOKEN` in your environment

## Usage

Ask Claude to work with your LinkedIn data:

- "pull my LinkedIn connections"
- "export my LinkedIn profile"
- "download my LinkedIn messages"
- "analyze my LinkedIn network by company and role"

## Available data

50+ domains including: connections, profile, positions, education, skills, inbox, posts, comments, reactions, job applications, endorsements, recommendations, and more. See [references/snapshot-domains.md](references/snapshot-domains.md) for the full list.
