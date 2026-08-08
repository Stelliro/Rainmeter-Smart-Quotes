# Smart Quotes

**Interactive quote manager for Rainmeter** — rotate inspiration from a local ZenQuotes cache, save favorites, and curate your own library without leaving the desktop.

Built as a heavily expanded successor to [Static Quotes](https://github.com/alestrunda/static-quotes) by [alestrunda](https://github.com/alestrunda).

<img src="https://img.shields.io/badge/version-1.2.1-blue" alt="Version"> <img src="https://img.shields.io/badge/Rainmeter-4.5%2B-green" alt="Rainmeter"> <img src="https://img.shields.io/badge/license-CC%20BY--NC--SA%203.0-lightgrey" alt="License"> <img src="https://img.shields.io/badge/platform-Windows-0078D6" alt="Windows"> <img src="https://img.shields.io/badge/API-ZenQuotes-informational" alt="ZenQuotes">

## Gallery

<p align="center">
  <img src="Screenshots/Screenshot.png" width="100%" alt="Smart Quotes on the desktop">
</p>
<p align="center"><b>Desktop context</b> — the widget blends into a full Rainmeter setup.</p>

<p align="center">
  <img src="Screenshots/Quote.png" width="45%" alt="Main quote display">
  <img src="Screenshots/Settings.png" width="45%" alt="Settings and favorites library">
</p>
<p align="center"><b>Left:</b> main quote display &nbsp;·&nbsp; <b>Right:</b> settings &amp; favorites library</p>

## Features

### Smart quote engine (rate-limit safe)
- Uses the [ZenQuotes](https://zenquotes.io/) **batch** endpoint (`/api/quotes`, ~50 quotes) instead of `/api/random` on every change
- Free tier is **5 requests / 30 seconds / IP** — double-click and the timer rotate **from local cache**, not the network
- Ships with a seed **`QuotesCache.txt`** so the skin works immediately offline / before the first successful refresh
- Background re-fetch only when the cache is empty or older than `CacheTtl` (default 45 min), gated by `MinApiInterval` (default 10s)
- **Favorite rate** — inject a saved quote every *N* rotations (`1` = always favorites, `0` = cache only)
- Cleans API noise (HTML entities, line breaks, wrapping issues)

### Favorites library
- Heart icon saves or removes the current quote
- Gold star when the on-screen quote is already saved
- Search, scroll, and delete entries in the settings menu
- Optional direct edit of `Favorites.txt` in Notepad

### Custom quotes & research
- **+** opens a quote + author form
- Globe control searches Google for quotes by author/topic
- Sample favorites ship with the skin so the library is never empty on first run

### Look & feel
- Dynamic scale controls (clamped ~0.4–1.6)
- Refresh interval in minutes, edited in-place
- Menu open/closed state persists across refreshes
- **Double-click** the quote (or author / background) for the next line — single-click does nothing
- Hover hit targets on heart, gear, zoom, and list actions

## Requirements

- Windows
- [Rainmeter](https://www.rainmeter.net/) 4.5 or newer (InputText plugin is built-in)
- Network access optional (for cache refresh and web search); local cache + favorites work offline

## Installation

1. Install [Rainmeter](https://www.rainmeter.net/) if you have not already.
2. Download the latest **Release** ZIP (or clone this repository).
3. Copy the `Smart-Quotes` folder into your skins directory, typically:

   `Documents\Rainmeter\Skins\Smart-Quotes\`

4. In Rainmeter **Manage** → **Skins** → **Smart-Quotes** → load **`SmartQuotes.ini`**.

> The active skin file is **`SmartQuotes.ini`** (not the legacy `StaticQuote.ini` name).

## Controls

| Action | What it does |
|--------|----------------|
| **Heart** | Toggle favorite for the current quote |
| **Gear** | Open settings & library |
| **Double-click quote / author / background** | Show the next quote from the local cache (or favorites per recycle rate) |
| **Refresh (min)** | Set auto-rotate interval (minutes) |
| **Favorite rate** | `1` = always favorites; `N` = favorite every *N*th rotation; `0` = cache only |
| **Scale − / +** | Resize the whole UI (about 0.4–1.6) |
| **Search bar** | Filter the favorites list |
| **Globe** | Type an author/topic → Google “quotes by …” |
| **+** | Add a custom quote and author |
| **✕** on a row | Delete that favorite |
| **Edit .txt File** | Open `Favorites.txt` in Notepad |
| **Scroll wheel** (over menu) | Scroll the favorites list |

## Files

| File | Role |
|------|------|
| `SmartQuotes.ini` | Skin layout, measures, UI |
| `logic.lua` | Cache, favorites, WebParser, menu logic |
| `QuotesCache.txt` | Local pool of online quotes (~50); refreshed in the background |
| `Favorites.txt` | Your saved quotes (one `"quote" - Author` per line) |
| `Screenshots/` | README gallery images |
| `LICENSE` | CC BY-NC-SA 3.0 |

Runtime-only (not required to ship): `debug.log` when diagnosing fetches (`DebugMode=1`).

## Favorites / cache format

```text
"Be the change that you want to see in the world." - Mahatma Gandhi
"Good judgment comes from experience, and experience comes from bad judgment." - Rita Mae Brown
```

Use a straight double-quoted quote, then ` - ` (space-hyphen-space), then the author. The **last** ` - ` on the line is the separator so quote text may contain hyphens.

## Configuration notes

Defaults live under `[Variables]` in `SmartQuotes.ini`:

| Variable | Default | Meaning |
|----------|---------|---------|
| `Scale` | `0.8` | UI scale factor |
| `CurrentTimer` | `900` | Auto-rotate interval in **seconds** (15 min); uses local cache |
| `RecycleFrequency` | `16` | Show a favorite every N rotations (`0` = cache only) |
| `URL` | `https://zenquotes.io/api/quotes` | Batch API (preferred over `/api/random`) |
| `MinApiInterval` | `10` | Min seconds between API calls (stay under 5 / 30s) |
| `CacheTtl` | `2700` | Seconds before a batch may re-fetch (45 min) |
| `DebugMode` | `0` | `1` = log fetch details to Rainmeter About → Log and `debug.log` |

### ZenQuotes free-tier policy (built-in)

Per [ZenQuotes docs](https://docs.zenquotes.io/zenquotes-documentation/#use-limits):

- **5 requests / 30 seconds / IP** without an API key  
- Prefer caching `/api/quotes` over calling `/api/random` repeatedly  
- Attribution required for free use — see Credits below  

This skin stays under that budget by rotating from `QuotesCache.txt` and only refreshing the batch when empty or past `CacheTtl`.

## Credits

- **Original concept:** [Static Quotes](https://github.com/alestrunda/static-quotes) by [alestrunda](https://github.com/alestrunda)
- **Quotes API:** [ZenQuotes.io](https://zenquotes.io/) — inspirational quotes provided by [ZenQuotes API](https://zenquotes.io/)
- **Maintainer:** [Stelliro](https://github.com/Stelliro)

## License

[Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported (CC BY-NC-SA 3.0)](https://creativecommons.org/licenses/by-nc-sa/3.0/)

You may share and adapt the work with attribution, for non-commercial use, under the same license. See [LICENSE](LICENSE) for the full legal text.

## Changelog

### 1.2.1
- Fixed author split (first letter no longer dropped, e.g. Stelliro)
- Prefer online cache over favorites; favorites only on recycle cadence
- Seed `QuotesCache.txt` (~50 quotes) for instant offline rotation
- Hardened WebParser batch fetch (less hang / rate-limit thrash)
- README, description, and topics refresh for cache + rate-limit model

### 1.2.0
- ZenQuotes free-tier safe: batch `/api/quotes` + local `QuotesCache.txt` instead of `/api/random` per change
- Rate gate (`MinApiInterval`, default 10s) and cache TTL (`CacheTtl`, default 45 min)
- Double-click rotates instantly from cache; never stuck on "Fetching..."
- Respects documented limit of **5 requests / 30 seconds** per IP

### 1.1.0
- Renamed skin entrypoint to `SmartQuotes.ini`
- Restored add-quote panel, web-search globe, and favorites list wiring after redesign
- Fixed numeric InputText anchors, heart favorite tint, timer minutes display, scale clamping
- Removed unused legacy `changeQuote.lua`
- README, metadata, topics, and release packaging refresh
