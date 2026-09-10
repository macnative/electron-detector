# Contributing

Thanks for considering a contribution to Electron Detector.

## Ways to help

- **New detection rules** — if you know of an app that hides its Electron internals differently, open a PR adding a check to `is_electron()` in `electron-detector.sh`, or open an issue with the app name/version and we'll add it.
- **Bug fixes** — if the script misbehaves on your setup, please include your macOS version and `bash --version`.
- **README / docs** — typo fixes and clarity improvements are always welcome.

## Development

The project is a single dependency-free Bash script, kept that way on purpose.

```bash
git clone https://github.com/macnative/electron-detector.git
cd electron-detector
chmod +x electron-detector.sh
./electron-detector.sh
```

Before opening a PR:

- Run [ShellCheck](https://www.shellcheck.net/) against `electron-detector.sh` (CI runs this automatically on every PR).
- Test both the default and `--json`/`--user`/`--quiet` flag combinations.
- Keep the script POSIX-friendly Bash — no external binaries beyond what macOS ships by default (`find`, `du`, `defaults`, `basename`).

## Reporting an issue

Open a [GitHub issue](https://github.com/macnative/electron-detector/issues) with:

- Your macOS version
- The app you expected to be detected (or misdetected), with its version
- Output of `./electron-detector.sh --json` if relevant

## Code of conduct

Be respectful and constructive. This is a small tool built for fun and utility — let's keep it a pleasant place to contribute.
