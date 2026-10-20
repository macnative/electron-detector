"""Render the README's SVG from actual, explicitly fictional CLI output.
Run on macOS with Python 3. No third-party dependencies.
"""
import html
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
output = subprocess.check_output(
    ['/bin/bash', str(root / 'electron-detector.sh'), '--demo', '--no-color'], text=True
)
lines = output.strip('\n').splitlines()
height = 80 + len(lines) * 24
svg = [
    f'<svg xmlns="http://www.w3.org/2000/svg" width="1100" height="{height}" viewBox="0 0 1100 {height}">',
    f'<rect width="1100" height="{height}" rx="20" fill="#14251e"/>',
    '<circle cx="28" cy="28" r="6" fill="#ed978e"/><circle cx="48" cy="28" r="6" fill="#e5ca83"/><circle cx="68" cy="28" r="6" fill="#a3c6a4"/>',
    '<text x="550" y="33" text-anchor="middle" fill="#a5b6aa" font-family="monospace" font-size="13">electron-detector.sh --demo</text>',
]
for i, line in enumerate(lines):
    color = '#bce6ad' if any(t in line for t in [
        'ELECTRON DETECTOR', 'YOUR MAC', 'THE LINEUP', 'Bundle footprint', 'Keep the apps', '[#'
    ]) else '#dce5dc'
    if 'DEMO /' in line:
        color = '#e5ca83'
    svg.append(f'<text x="24" y="{77 + i * 24}" xml:space="preserve" fill="{color}" font-family="Menlo,Consolas,monospace" font-size="16">{html.escape(line)}</text>')
svg.append('</svg>')
(root / '.github/preview.svg').write_text('\n'.join(svg))
