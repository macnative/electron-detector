<p align="center">
  <img src=".github/banner.svg" alt="Electron Detector" width="100%">
</p>

<p align="center">
  <a href="https://github.com/macnative/electron-detector/actions/workflows/shellcheck.yml"><img src="https://github.com/macnative/electron-detector/actions/workflows/shellcheck.yml/badge.svg" alt="ShellCheck"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License"></a>
  <a href="#requirements"><img src="https://img.shields.io/badge/platform-macOS-black?logo=apple" alt="macOS"></a>
  <img src="https://img.shields.io/badge/bash-4%2B-4EAA25?logo=gnu-bash&logoColor=white" alt="Bash 4+">
  <a href="https://github.com/macnative/electron-detector/stargazers"><img src="https://img.shields.io/github/stars/macnative/electron-detector?style=flat&color=yellow" alt="Stars"></a>
  <a href="https://github.com/macnative/electron-detector/pulls"><img src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg" alt="PRs Welcome"></a>
</p>

<h3 align="center">Which of your "native" Mac apps are secretly running a full Chromium browser?</h3>

<p align="center">
  One command tells you. No install, no dependencies, no tracking — just a shell script that reads your <code>/Applications</code> folder.
</p>

<p align="center"><b>
  <code>curl -sL https://raw.githubusercontent.com/macnative/electron-detector/main/electron-detector.sh | bash</code>
</b></p>

---

## Why this exists

[Electron](https://www.electronjs.org/) lets developers ship one app for every platform by bundling a full copy of Chromium and Node.js inside it. That's great for developers — and rough on your Mac. Every Electron app you run is, under the hood, its own private browser tab: its own renderer process, its own ~100–300MB of idle RAM, its own hit to battery life.

Most people have no idea how many of their everyday apps work this way. **Electron Detector** scans your installed apps and tells you, in a few seconds, exactly which ones are Electron — with sizes, versions, and a straight answer on whether it's worth switching to something native.

## Quick start

```bash
curl -sL https://raw.githubusercontent.com/macnative/electron-detector/main/electron-detector.sh | bash
```

That's it — no install, no config, nothing left behind. It's a read-only scan of `/Applications`; it doesn't modify anything on your system.

## Example output

```
╔════════════════════════════════════════════════════════════╗
║  ⚡  Electron Detector for macOS                            ║
║     Find which apps are secretly Electron-based             ║
╚════════════════════════════════════════════════════════════╝

🔍 Scanning /Applications...

[▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓] Done!

════════════════════════════════════════════════════════════

⚠️  Found 5 Electron app(s) out of 47 total apps

⚡ Electron Apps Detected:

App Name                                 Size         Version
────────────────────────────────────────────────────────────────
Slack                                    165M         4.35.0
Discord                                  156M         0.0.290
Visual Studio Code                       387M         1.85.0
Postman                                  312M         10.20.0
Notion                                   198M         2.2.3

════════════════════════════════════════════════════════════

📦 Resource Impact:

⚠️  High Electron count detected!
   Each Electron app runs a full Chromium browser

════════════════════════════════════════════════════════════

🚀 Want native alternatives?
   Check out: https://macnative.io

✓ Native apps are:
   • Faster and more responsive
   • Use less RAM and battery
   • Better macOS integration
   • Smaller app size

💡 Fun Fact:
   Electron apps can use 100-300MB RAM even when idle
   Native apps often use less than 50MB

════════════════════════════════════════════════════════════
```

## Features

- 🔎 Scans `/Applications` (and optionally `~/Applications`) for Electron apps
- ⚡ Detects the Electron runtime via its framework bundle, not just an app name guess
- 📊 Reports app name, disk size, and version for every match
- 🎨 Clean, colorful terminal output — with a real progress bar, not a spinner
- 🤖 `--json` mode for scripting, dashboards, or piping into `jq`
- 🧠 Zero dependencies: pure Bash, nothing to install
- 🔒 Read-only — it only inspects app bundles, it never modifies or deletes anything

## Usage

```bash
electron-detector.sh [options]

Options:
  -u, --user     Also scan ~/Applications
  -j, --json     Output machine-readable JSON instead of the report
  -q, --quiet    Suppress the banner and tips, print results only
  -v, --version  Print the version number
  -h, --help     Show this help message
```

**Scan both system and user app directories:**

```bash
./electron-detector.sh --user
```

**Get JSON for scripting:**

```bash
./electron-detector.sh --json | jq '.electron_apps[].name'
```

## Manual installation

```bash
git clone https://github.com/macnative/electron-detector.git
cd electron-detector
chmod +x electron-detector.sh
./electron-detector.sh
```

## How it works

Electron Detector doesn't guess from an app's name or icon — it looks inside the `.app` bundle for the actual Electron runtime:

1. **Electron Framework** — `Contents/Frameworks/Electron Framework.framework`
2. **Electron binary** — `Contents/MacOS/Electron`

If either is present, the app is running on Electron — full stop. This is the same signal macOS itself uses internally to launch the app, so it's accurate even when an app hides its origins well.

## Why it matters

| | Electron apps | Native apps |
|---|---|---|
| Idle RAM | 100–300MB per app | Often under 50MB |
| Battery impact | Higher — runs a full Chromium instance | Lower — uses native frameworks |
| Launch time | Slower — boots a browser engine | Near-instant |
| Disk footprint | Large (bundles Chromium + Node.js) | Small |
| macOS integration | Approximated | Native |

None of this means Electron apps are *bad* — it's a reasonable trade-off for developers shipping cross-platform software fast. But if you're stacking up a dozen of them, your battery and fans will notice. Once you know which apps are Electron, you can make that call for yourself.

Found some? Browse [**macnative.io**](https://macnative.io) for a curated directory of native macOS replacements.

## Requirements

- macOS with Bash (ships by default)
- Apps installed in `/Applications` or `~/Applications`

## Troubleshooting

**"Permission denied" when running the script directly**
```bash
chmod +x electron-detector.sh
```

**Not finding an app you know is Electron**
Some apps rename or relocate their internals. Open an issue with the app name and version and we'll add a detection rule.

**Apps in unusual locations aren't scanned**
By design, only `/Applications` and (with `--user`) `~/Applications` are scanned. This is deliberate — the script only reads standard, expected locations.

## Contributing

Contributions are very welcome — new detection rules, bug fixes, and general polish all help. See [CONTRIBUTING.md](CONTRIBUTING.md) to get started, or just open an issue or PR.

## Credits

Electron Detector is built and maintained by [**macnative**](https://macnative.io) — a directory of fast, native, non-Electron alternatives to the apps cluttering your Mac. Visit [macnative.io](https://macnative.io) to find one for every Electron app this tool flags.

## License

[MIT](LICENSE) — free to use, modify, and share.

---

<p align="center">Made with ❤️ by <a href="https://github.com/macnative">macnative</a> for people who like their Macs fast and their RAM free.</p>
