<p align="center">
  <img src=".github/banner.svg" alt="Electron Detector — A little detective for your Mac." width="880">
</p>

<p align="center">
  <a href="https://github.com/macnative/electron-detector/actions/workflows/shellcheck.yml">ShellCheck</a> ·
  <a href="#try-it">Quick start</a> ·
  <a href="#what-a-detection-means">How detection works</a> ·
  <a href="LICENSE">MIT license</a>
</p>

# What's inside your Mac apps?

A tiny shell script that finds Electron runtime markers in your installed apps. See the lineup, inspect the evidence, and find out how much disk space those **whole app bundles** occupy.

**One file. Runs with the Bash your Mac already has. No Homebrew, account, or admin password.**

<p align="center">
  <img src=".github/preview.svg" alt="Demo report: 3 of 42 example apps contain Electron markers, using 1.5 GiB of bundle disk space. Results show names, versions and detection evidence, largest first." width="880">
</p>

*Fictional apps, real output. Reproduce this preview with `bash electron-detector.sh --demo`.*

## Try it

Open **Terminal** (⌘ Space → Terminal), download the script, then inspect it in your editor:

```sh
curl -fL https://raw.githubusercontent.com/macnative/electron-detector/main/electron-detector.sh -o electron-detector.sh
```

Read [the source](electron-detector.sh), then run:

```sh
bash electron-detector.sh --interactive
```

The scan checks `/Applications` and `~/Applications`, including subfolders. Apps don't need to be running. At the end, you can print or copy an anonymous summary, learn what the findings mean, or open MacNative to explore alternatives.

Prefer a plain report? Run `bash electron-detector.sh`. Curious about the look before scanning? Add `--demo --interactive`.

Downloading needs internet. **Scanning works offline.** The script reads bundles and uses a temporary workspace that it removes on exit. It never edits, deletes, or launches your apps. The menu changes the clipboard only when you choose **c**, and opens a website only when you choose **a**. Don't use `sudo`.

## A census, with a little personality

- **Useful at a glance.** Largest detected bundles first, with app versions and the exact marker found.
- **A small Mac companion.** A friendly face, a count of matches, and a compact report that stays in your scrollback.
- **Something to share.** `--share` leaves out app names and folder paths. The interactive menu can copy that summary for you.
- **Built for real folders.** Subfolders, spaces, Unicode, symlinked apps, and overlapping scan roots; nested helper apps aren't counted again.
- **Comfortable in a terminal or a pipeline.** JSON output, quiet mode, `NO_COLOR`, and no surprise prompts.

No purity score. No invented RAM savings. Keep the apps you like.

## Share your census

```sh
bash electron-detector.sh --share
```

```text
My Mac app census: 3 of 42 inspected apps have Electron markers (7%).
Detected bundles: 1.5 GiB on disk. Not a RAM or battery benchmark.
No marker found does not prove an app is native.
Try it: https://github.com/macnative/electron-detector
Explore native alternatives: https://macnative.io/categories
```

*Example numbers.* App names and paths are omitted, but your counts and sizes are still in the summary. Nothing is posted automatically. Full reports and screenshots include app names; review those before sharing.

## Curious about alternatives?

I also make **[MacNative](https://macnative.io)**, a directory for discovering Mac apps. If a result makes you curious, [browse by category](https://macnative.io/categories) and look for a native app that fits how you work.

That's the connection: this tool shows you what's installed; MacNative helps you explore what else is out there. It doesn't guarantee a replacement for every match. There are no network requests during a scan and no per-app referral links. Use `--quiet` to omit the mascot and MacNative promotion.

## Make it yours

| Option | What it does |
| --- | --- |
| `-i`, `--interactive` | Offers share, clipboard, explanation, and alternatives actions after scanning |
| `--path DIRECTORY` | Scans a custom folder; repeat for multiple folders; replaces the defaults |
| `-j`, `--json` | Emits structured data, with app names but no personal folder paths |
| `--share` | Prints a summary without app names or paths |
| `--demo` | Shows fictional results without scanning; works with the interactive menu |
| `-q`, `--quiet` | Omits the mascot, tips, and MacNative promotion |
| `--no-color` | Disables colors; `NO_COLOR` is also respected |
| `-u`, `--user` | Compatibility flag; user apps are now included by default |
| `-v`, `--version` | Prints the version |
| `-h`, `--help` | Shows help |

```sh
# Scan another app folder
bash electron-detector.sh --path '/Volumes/Work/Applications'

# Save a report for your own tools
bash electron-detector.sh --json > electron-report.json

# Just the findings
bash electron-detector.sh --quiet --no-color
```

`--interactive` needs terminal input and output. Use it after downloading, rather than piping the script into Bash. `--json` and `--share` are mutually exclusive; `--demo` cannot be combined with `--json` or `--path`.

## Questions that come up

**Does this tell me which apps are running right now?**  
No. It inspects installed bundles. Use Activity Monitor for running processes, CPU, and memory.

**Is the disk total space I can save?**  
No. It's the measured size of the detected bundles, including the apps themselves. Replacement apps also use space, and user data is outside this measurement.

**It missed an app.**  
Try `--path` if it's outside the default folders. Renamed or relocated Electron internals can be missed. [Open an issue](https://github.com/macnative/electron-detector/issues) with the app version and expected marker; please leave personal paths out.

**I see a partial-scan warning.**  
Some folders or bundles couldn't be read. The results describe what was accessible. Try a smaller folder you can read; no admin access is required.

**Can I remove it afterward?**  
Yes. Delete the downloaded script and any report files you saved. There's no installer, background service, or auto-updater.

## What a detection means

The detector checks for either:

- `Contents/Frameworks/Electron Framework.framework`
- `Contents/MacOS/Electron`

These are runtime markers, not a benchmark or an executable signature check. Renamed or relocated frameworks can be missed, and a coincidentally named file can be a false positive. A bundle may include Electron for only part of its functionality. Other web wrappers are outside this tool's scope. **No Electron marker does not mean native.**

Sizes are allocated bundle disk usage from `du -sk`, in KiB (displayed as MiB/GiB). They exclude user data and caches. APFS cloning, compression, and shared files can complicate totals. The report does not estimate RAM, battery life, speed, or space you would save by switching. Apps changing during a scan may yield partial measurements. Inaccessible folders are reported as warnings; an empty folder yields a valid zero-app report. Symlink cycles may also cause traversal warnings.

Electron is a useful cross-platform framework. Keep apps that work for you. If you want software with a more native Mac feel, [browse MacNative by category](https://macnative.io/categories). A native app is not necessarily a feature-for-feature replacement.

## JSON schema v2

```json
{
  "schema_version": 2,
  "detector_version": "2.0.0",
  "total_apps": 1,
  "electron_count": 1,
  "total_size_kb": 409600,
  "unknown_sizes": 0,
  "scan_warnings": 0,
  "electron_apps": [
    { "name": "Example", "size_kb": 409600, "version": "1.0", "evidence": "Electron Framework.framework" }
  ]
}
```

`size_kb` is `null` when measurement fails. `total_size_kb` sums known sizes only. `total_apps` counts bundles with accessible Contents directories. `scan_warnings` counts traversal diagnostics and inaccessible bundles; it is not a count of missed apps. Version 2 replaces v1's string `size` with numeric `size_kb` and includes the user Applications folder by default. Errors go to stderr; JSON stdout stays machine-readable. The demo cannot export JSON, so fictional data cannot be mistaken for a real scan. Exit 0 means the scan completed (inspect warnings); 2 means invalid arguments or an unsupported platform; 1 means temporary workspace creation failed.

## Contributing & tests

Use macOS and `/bin/bash`, not just a newer Homebrew Bash. Runtime dependencies must ship with macOS. Dev tests use Python 3; ShellCheck is optional locally and runs in CI.

```sh
/bin/bash -n electron-detector.sh
python3 tests/test_detector.py
shellcheck electron-detector.sh
```

New detection rules need fixtures for both true and false positives. Don't add telemetry or unmeasured performance claims. Please remove personal information before attaching reports to issues.

[MIT license](LICENSE).
