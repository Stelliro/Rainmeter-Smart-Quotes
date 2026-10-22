# Smart Quotes

**A quote widget for your Windows desktop.** Smart Quotes shows a new inspirational quote every few minutes, lets you save the ones you like, and lets you add your own — all without leaving the desktop.

It runs on [Rainmeter](https://www.rainmeter.net/), a free desktop customisation tool for Windows. Built as a heavily expanded successor to [Static Quotes](https://github.com/alestrunda/static-quotes) by [alestrunda](https://github.com/alestrunda).

<img src="https://img.shields.io/badge/version-1.3.0-blue" alt="Version"> <img src="https://img.shields.io/badge/Rainmeter-4.5%2B-green" alt="Rainmeter"> <img src="https://img.shields.io/badge/license-CC%20BY--NC--SA%203.0-lightgrey" alt="License"> <img src="https://img.shields.io/badge/platform-Windows-0078D6" alt="Windows"> <img src="https://img.shields.io/badge/API-ZenQuotes-informational" alt="ZenQuotes">

<p align="center">
  <img src="Screenshots/Screenshot.png" width="100%" alt="Smart Quotes on the desktop">
</p>

## Install

### 1. Get Rainmeter (skip if you already have it)

Smart Quotes needs **Rainmeter 4.5 or newer**. Download it from either place — they are the same installer:

- **Official site:** [rainmeter.net](https://www.rainmeter.net/) → **Download**
- **GitHub:** [rainmeter/rainmeter releases](https://github.com/rainmeter/rainmeter/releases/latest) → download the `Rainmeter-x.x.x.exe` file under **Assets**

Run the installer and pick **Standard installation**. If you get stuck, Rainmeter's own guide walks through it step by step: [Installing Rainmeter](https://docs.rainmeter.net/manual/installing-rainmeter/).

### 2. Install Smart Quotes

1. Go to the [latest release](https://github.com/Stelliro/Rainmeter-Smart-Quotes/releases/latest) and download **`Smart-Quotes_1.3.0.rmskin`**.
2. Double-click the file. Rainmeter's installer opens.
3. Click **Install**. The widget appears on your desktop straight away.

That's it. Drag the widget wherever you like.

<details>
<summary><b>Manual install (zip or git clone)</b></summary>

1. Download **`Smart-Quotes_1.3.0.zip`** from the [latest release](https://github.com/Stelliro/Rainmeter-Smart-Quotes/releases/latest), or clone this repository.
2. Put the `Smart-Quotes` folder in your Rainmeter skins folder, usually:

   `Documents\Rainmeter\Skins\Smart-Quotes\`

3. Right-click the Rainmeter icon in the system tray → **Refresh all**.
4. Open **Manage** → **Skins** → **Smart-Quotes** → select **`SmartQuotes.ini`** → **Load**.

More help: [Installing skins](https://docs.rainmeter.net/manual/installing-skins/) in the Rainmeter manual.
</details>

### Updating

Download the new `.rmskin` and install it over the old one. The package includes a sample `Favorites.txt`, so **copy your own `Favorites.txt` somewhere safe first** and put it back after installing. (If you leave **Backup** ticked in the installer, your old folder is also saved to `Documents\Rainmeter\Skins\@Backup\`.)

## How to use it

| Action | What it does |
|--------|--------------|
| **Double-click** the quote | Show the next quote |
| **Heart** | Save or remove the current quote (gold star = already saved) |
| **Gear** | Open settings and your favorites library |
| **+** | Add your own quote and author |
| **Globe** | Search Google for quotes by an author or topic |
| **Search bar** | Filter your favorites |
| **✕** on a row | Delete that favorite |
| **Scroll wheel** (over the menu) | Scroll the favorites list |
| **Scale − / +** | Make the whole widget bigger or smaller |
| **Refresh (min)** | How often it changes quote by itself |
| **Favorite rate** | `1` = only show favorites; `N` = a favorite every *N*th quote; `0` = never |
| **Edit .txt File** | Open your favorites in Notepad |

## Features

- **Works offline.** Ships with ~50 quotes in `QuotesCache.txt`, so it works the moment you load it, even with no internet.
- **Gentle on the quote service.** Fetches quotes from [ZenQuotes](https://zenquotes.io/) in batches of ~50, then rotates locally. It only asks for more when the batch runs out or is over 45 minutes old, and never more than once every 10 seconds, well inside ZenQuotes' free limit of 5 requests per 30 seconds.
- **Favorites library.** Save, search, scroll and delete quotes, or edit `Favorites.txt` directly. Sample favorites are included so the library is never empty.
- **Your own quotes.** Add any quote and author from the **+** form.
- **Scales cleanly.** Resize from about 0.4× to 1.6×; settings and menu state survive refreshes.
- **Tidy text.** Cleans up HTML entities, stray line breaks and wrapping from the API.

## Settings

Most people never need these, but they live under `[Variables]` in `SmartQuotes.ini`:

| Variable | Default | Meaning |
|----------|---------|---------|
| `Scale` | `0.8` | Widget size |
| `CurrentTimer` | `900` | Seconds between automatic quote changes (15 min) |
| `RecycleFrequency` | `16` | Show a favorite every N quotes (`0` = never) |
| `URL` | `https://zenquotes.io/api/quotes` | Batch quote API |
| `MinApiInterval` | `10` | Minimum seconds between API calls |
| `CacheTtl` | `2700` | Seconds before a batch is considered stale (45 min) |
| `DebugMode` | `0` | `1` = write fetch details to `debug.log` and Rainmeter's log |

### Favorites file format

One quote per line: the quote in straight double quotes, then ` - `, then the author. The **last** ` - ` on the line is the separator, so quotes can contain hyphens.

```text
"Be the change that you want to see in the world." - Mahatma Gandhi
"Good judgment comes from experience, and experience comes from bad judgment." - Rita Mae Brown
```

## Files

| File | Role |
|------|------|
| `SmartQuotes.ini` | The skin: layout, measures and UI |
| `logic.lua` | Cache, favorites, fetching and menu logic |
| `QuotesCache.txt` | Local pool of quotes, refreshed in the background |
| `Favorites.txt` | Your saved quotes |
| `Screenshots/` | Images for this README |
| `LICENSE` | CC BY-NC-SA 3.0 |

## Credits

- **Original concept:** [Static Quotes](https://github.com/alestrunda/static-quotes) by [alestrunda](https://github.com/alestrunda)
- **Quotes:** inspirational quotes provided by the [ZenQuotes API](https://zenquotes.io/) (attribution required for free use)
- **Maintainer:** [Stelliro](https://github.com/Stelliro)

## License

[Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported (CC BY-NC-SA 3.0)](https://creativecommons.org/licenses/by-nc-sa/3.0/). You may share and adapt it with attribution, for non-commercial use, under the same license. See [LICENSE](LICENSE) for the full text.

## Changelog

### 1.3.0
- One-click install: releases now include a `.rmskin` package alongside the zip
- README rewritten around a simple install, with links to get Rainmeter from rainmeter.net or GitHub

### 1.2.1
- Fixed author split (first letter no longer dropped, e.g. Stelliro)
- Prefer online cache over favorites; favorites only on recycle cadence
- Seed `QuotesCache.txt` (~50 quotes) for instant offline rotation
- Hardened WebParser batch fetch (less hang / rate-limit thrash)

### 1.2.0
- ZenQuotes free-tier safe: batch `/api/quotes` + local `QuotesCache.txt` instead of `/api/random` per change
- Rate gate (`MinApiInterval`, default 10s) and cache TTL (`CacheTtl`, default 45 min)
- Double-click rotates instantly from cache; never stuck on "Fetching..."

### 1.1.0
- Renamed skin entrypoint to `SmartQuotes.ini`
- Restored add-quote panel, web-search globe, and favorites list wiring after redesign
- Fixed numeric InputText anchors, heart favorite tint, timer minutes display, scale clamping
- Removed unused legacy `changeQuote.lua`
