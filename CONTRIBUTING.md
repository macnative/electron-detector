# Contributing

Keep the scanner compatible with macOS `/bin/bash` 3.2 and system utilities. See [the technical reference](docs/reference.md) for the JSON contract and test commands. Add regression fixtures for detection, path handling, and output changes. Avoid performance claims that the scanner cannot measure, and keep all scan data local. A missing Electron marker is never proof of native architecture.

When reporting issues, include macOS and script versions and the detection marker you expected. Review reports before posting: app names may reveal personal information.

After changing the terminal output, run `python3 scripts/render-preview.py` on macOS to regenerate the README preview from `--demo`. Keep the example label visible. Never use a real user's installed apps in promotional assets.
