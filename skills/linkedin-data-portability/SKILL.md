---
name: linkedin-data-portability
description: |
  Fetch LinkedIn member data (connections, profile, posts, messages, jobs, etc.) via the
  Member Data Portability API (DMA). Use when the user wants to export, explore, or analyze
  their LinkedIn data — connections, profile, inbox, job applications, endorsements, etc.
  Requires EEA/Swiss LinkedIn account. Triggers on: "pull my LinkedIn connections",
  "export LinkedIn data", "get my LinkedIn profile", "download LinkedIn messages".
---

# LinkedIn Member Data Portability API

EU Digital Markets Act API that lets LinkedIn members export their own data via REST APIs.

**Constraint:** Only available to members located in the EEA or Switzerland.

## Setup (one-time)

1. Go to https://developer.linkedin.com/ and create a developer application
2. **Use the default company page:** [Member Data Portability (Member) Default Company](https://www.linkedin.com/company/member-data-portability-member-default-company) — do NOT create a new company page
3. In the Products tab, click **Request access** for **Member Data Portability API (Member)**
4. Accept Terms and Conditions — access is granted immediately

### Generate access token

1. Go to **Docs and tools** > **OAuth Token Tools** in the developer portal
2. Click **Create token**
3. Select the app provisioned with Member Data Portability API (Member)
4. Select scope: `r_dma_portability_self_serve`
5. Click **Request access token** — login and consent when redirected
6. Copy the access token

## Member Snapshot API

Point-in-time export of all historical LinkedIn data. This is the primary API for bulk data export.

### Endpoint

```
GET https://api.linkedin.com/rest/memberSnapshotData?q=criteria
```

### Required headers

```
Authorization: Bearer <access_token>
Content-Type: application/json
Linkedin-Version: 202312
```

### Query parameters

| Param | Required | Description |
|-------|----------|-------------|
| `domain` | No | Specific data domain. Omit to get all domains. Case-sensitive. |
| `start` | No | Pagination offset (default 0) |
| `count` | No | Page size (default 10) |

### Example: fetch connections

```bash
curl -s 'https://api.linkedin.com/rest/memberSnapshotData?q=criteria&domain=CONNECTIONS' \
  -H 'Authorization: Bearer TOKEN' \
  -H 'Linkedin-Version: 202312' \
  -H 'Content-Type: application/json'
```

### Response shape

```json
{
  "paging": {
    "start": 0,
    "count": 10,
    "total": 2,
    "links": [
      { "rel": "next", "href": "/rest/memberSnapshotData?count=10&domain=CONNECTIONS&q=criteria&start=1" }
    ]
  },
  "elements": [
    {
      "snapshotDomain": "CONNECTIONS",
      "snapshotData": [
        { "First Name": "Tom", "Last Name": "Cruise", "Position": "...", "Company": "...", "Connected On": "..." }
      ]
    }
  ]
}
```

### Pagination

Response may be paginated. Follow `paging.links` with `rel: "next"` until you get a 404 or error "No data found for this memberId". The `total` field may be inaccurate — always paginate until exhaustion.

### Key domains for common tasks

| Task | Domain |
|------|--------|
| Export connections | `CONNECTIONS` |
| Profile info | `PROFILE` |
| Messages/inbox | `INBOX` |
| Posts/shares | `MEMBER_SHARE_INFO` |
| Comments | `ALL_COMMENTS` |
| Reactions/likes | `ALL_LIKES` |
| Job applications | `JOB_APPLICATIONS` |
| Skills | `SKILLS` |
| Work history | `POSITIONS` |
| Education | `EDUCATION` |
| Articles | `ARTICLES` |
| Endorsements | `ENDORSEMENTS` |
| Recommendations | `RECOMMENDATIONS` |

For the full list of 50+ domains, see [references/snapshot-domains.md](references/snapshot-domains.md).

## Member Changelog API

Tracks member activity (posts, comments, reactions) from the time of consent. Events available for 28 days only.

### Endpoint

```
GET https://api.linkedin.com/rest/memberChangeLogs?q=memberAndApplication
```

### Query parameters

| Param | Required | Description |
|-------|----------|-------------|
| `startTime` | No | Epoch milliseconds (inclusive). Use latest `processedAt` from previous response. Max 28 days back. |
| `count` | No | 1-50, recommended 10 |

### Tips

- Query each member's activities **once per hour max**
- Use `capturedAt` for event timing, not created/lastModified on the activity itself
- `count` > 10 increases latency and can cause timeouts
- Archive: `method`, `resourceName`, `resourceId`, `processedActivity`

### Check if changelog is active

```
GET https://api.linkedin.com/rest/memberAuthorizations?q=memberAndApplication
```

### Manually enable changelog

```
POST https://api.linkedin.com/rest/memberAuthorizations
Body: {}
```

## Error handling

- Fields that fail processing return `"Unable_to_process_this_field."`
- Unprocessed activities in `processedActivity` return `{"message": "Unable to process this event."}`
- Unprocessed URN fields get a sibling key with `!` suffix: `"URN!": {"message": "Unable to process this field."}`

## Workflow: export all connections to CSV

1. Generate access token (see Setup above)
2. Fetch first page: `GET ...?q=criteria&domain=CONNECTIONS&start=0&count=10`
3. Extract `elements[0].snapshotData` array — each entry is one connection
4. Follow `paging.links[rel=next]` until exhausted
5. Flatten all `snapshotData` arrays into a single CSV
