#!/bin/bash
# Electron Detector / MacNative — MIT licensed. Compatible with macOS Bash 3.2.
# No network calls during scanning. Never modifies application bundles.
VERSION="2.0.0"
export LC_ALL=en_US.UTF-8
json=false quiet=false interactive=false share=false custom=false demo=false
roots=() apps=() names=() sizes=() versions=() evidence=()
count=0 total_kb=0 unknown_sizes=0 skipped=0
usage() {
    cat <<HELP
Electron Detector $VERSION — a little detective for your Mac.
Usage: bash electron-detector.sh [options]
  --path DIRECTORY  Scan a custom folder (repeatable; replaces defaults)
  -u, --user        Include ~/Applications (already included by default)
  -j, --json        JSON report; app names but no personal folder paths
  -q, --quiet       Results without the mascot or promotion
  -i, --interactive Offer actions after the report (requires a terminal)
  --share          Print a shareable summary without app names or paths
  --demo           Preview fictional results; does not scan your apps
  --no-color       Disable terminal colors (also respects NO_COLOR)
  -v, --version    Print version
  -h, --help       Show help
Default folders: /Applications and ~/Applications, including subfolders.
Nothing is installed, deleted, launched, or uploaded during a scan.
HELP
}
while [ "$#" -gt 0 ]; do
    case "$1" in
        --path) [ "$#" -ge 2 ] && [ -d "$2" ] || { printf 'Expected an existing directory after --path\n' >&2; exit 2; }; custom=true; roots+=("$2"); shift 2 ;;
        -u|--user) shift ;;
        -j|--json) json=true; shift ;;
        -q|--quiet) quiet=true; shift ;;
        -i|--interactive) interactive=true; shift ;;
        --share) share=true; shift ;;
        --demo) demo=true; shift ;;
        --no-color) NO_COLOR=1; shift ;;
        -v|--version) printf '%s\n' "$VERSION"; exit 0 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; exit 2 ;;
    esac
done
if $json && $share; then printf 'Choose either --json or --share.\n' >&2; exit 2; fi
if $demo && { $json || $custom; }; then printf '--demo cannot be combined with --json or --path.\n' >&2; exit 2; fi
if [ "$(uname -s)" != Darwin ]; then printf 'This detective needs macOS.\n' >&2; exit 2; fi
if $interactive && { $json || $share || [ ! -t 0 ] || [ ! -t 1 ]; }; then
    printf -- '--interactive requires a terminal and cannot be combined with --json or --share.\n' >&2; exit 2
fi
if ! $custom; then
    roots=(/Applications)
    [ ! -d "$HOME/Applications" ] || roots+=("$HOME/Applications")
fi
mint='' dim='' reset='' animate=false
if [ -t 1 ] && [ "${TERM:-dumb}" != dumb ]; then animate=true; fi
if [ -t 1 ] && [ -z "${NO_COLOR+x}" ] && [ "${TERM:-dumb}" != dumb ]; then
    mint=$'\033[1;36m'; dim=$'\033[2m'; reset=$'\033[0m'
fi
# JSON string escaping includes every control byte; never interpolate names as code.
json_string() {
    local value="$1" char n i
    local LC_ALL=C
    printf '"'
    for ((i=0; i<${#value}; i++)); do
        char="${value:i:1}"
        case "$char" in
            '"') printf '\\"' ;; \\) printf '\\\\' ;;
            *) printf -v n '%d' "'$char"
               n=$((n & 255))
               if [ "$n" -lt 32 ]; then printf '\\u%04x' "$n"; else printf '%s' "$char"; fi ;;
        esac
    done
    printf '"'
}
safe_text() { printf '%s' "$1" | tr '[:cntrl:]' '?'; }
pretty_size() {
    if [ "$1" -lt 0 ]; then printf 'unknown';
    elif [ "$1" -ge 1048576 ]; then awk -v n="$1" 'BEGIN {printf "%.1f GiB",n/1048576}';
    else awk -v n="$1" 'BEGIN {printf "%.1f MiB",n/1024}'; fi
}
if ! $json && ! $quiet && ! $share; then
    printf '\n%s  .--------.\n  |  o  o  |   ELECTRON DETECTOR\n  |   __   |   A little detective for your Mac.\n  \x27--------\x27%s\n\n' "$mint" "$reset"
    if $demo; then printf '  DEMO / fictional apps and sizes. Nothing scanned.\n\n';
    else printf '  Looking inside app bundles. All detective work stays here.\n\n'; fi
fi
if $demo; then
    count=42; total_kb=1572864
    names=("Example Editor" "Example Chat" "Example Notes")
    sizes=(786432 524288 262144)
    versions=("1.2.0" "4.0.1" "2.3.0")
    evidence=("Electron Framework.framework" "Electron Framework.framework" "Contents/MacOS/Electron")
else
# Use NUL-delimited paths and prune bundles, so helpers are not counted as apps.
work=$(mktemp -d "${TMPDIR:-/tmp}/electron-detector.XXXXXX") || exit 1
trap 'rm -rf "$work"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
# Prefix relative roots so find never treats a directory name as an expression.
for ((r=0;r<${#roots[@]};r++)); do
    case "${roots[$r]}" in /*) ;; *) roots[$r]="./${roots[$r]}" ;; esac
done
find -L "${roots[@]}" -type d -name '*.app' -prune -print0 > "$work/apps" 2> "$work/errors"
if [ -s "$work/errors" ]; then
    skipped=$(wc -l < "$work/errors" | tr -d ' ')
    printf 'Some folders could not be read (%s traversal warnings). Results may be incomplete.\n' "$skipped" >&2
fi
while IFS= read -r -d '' app; do
    canonical=$(cd "$app" 2>/dev/null && pwd -P) || { skipped=$((skipped+1)); continue; }
    duplicate=false
    for seen in "${apps[@]}"; do [ "$seen" != "$canonical" ] || { duplicate=true; break; }; done
    $duplicate && continue
    apps+=("$canonical")
    if [ ! -r "$app/Contents" ] || [ ! -x "$app/Contents" ]; then skipped=$((skipped+1)); continue; fi
    count=$((count+1))
    if ! $json && ! $quiet && ! $share && $animate; then printf '\r  Inspecting app %d…' "$count"; fi
    signal=''
    if [ -d "$app/Contents/Frameworks/Electron Framework.framework" ]; then signal='Electron Framework.framework';
    elif [ -f "$app/Contents/MacOS/Electron" ]; then signal='Contents/MacOS/Electron'; fi
    [ -n "$signal" ] || continue
    name=${app##*/}; name=${name%.app}
    version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist" 2>/dev/null) || version='Unknown'
    size=$(du -sk "$canonical" 2>/dev/null) && size=${size%%[[:space:]]*} || size=-1
    case "$size" in ''|*[!0-9-]*) size=-1 ;; esac
    if [ "$size" -lt 0 ]; then unknown_sizes=$((unknown_sizes+1)); else total_kb=$((total_kb+size)); fi
    # Insertion order: largest bundles first. Parallel arrays preserve arbitrary names.
    pos=${#names[@]}
    while [ "$pos" -gt 0 ] && [ "${sizes[$((pos-1))]}" -lt "$size" ]; do
        names[$pos]=${names[$((pos-1))]}; sizes[$pos]=${sizes[$((pos-1))]}
        versions[$pos]=${versions[$((pos-1))]}; evidence[$pos]=${evidence[$((pos-1))]}
        pos=$((pos-1))
    done
    names[$pos]=$name; sizes[$pos]=$size; versions[$pos]=$version; evidence[$pos]=$signal
done < "$work/apps"
fi
found=${#names[@]}
app_label=apps; [ "$found" -ne 1 ] || app_label=app
percent=0; [ "$count" -eq 0 ] || percent=$((found*100/count))
summary() {
    if $demo; then printf 'DEMO / fictional results; nothing scanned.\n'; fi
    printf 'My Mac app census: %d of %d inspected apps have Electron markers (%d%%).\n' "$found" "$count" "$percent"
    printf 'Detected bundles: %s on disk' "$(pretty_size "$total_kb")"
    [ "$unknown_sizes" -eq 0 ] || printf ' + %d unmeasured' "$unknown_sizes"
    printf '. Not a RAM or battery benchmark.\n'
    [ "$skipped" -eq 0 ] || printf 'Partial scan: %d warnings.\n' "$skipped"
    printf 'No marker found does not prove an app is native.\n'
    printf 'Try it: https://github.com/macnative/electron-detector\n'
    if ! $quiet; then printf 'Explore native alternatives: https://macnative.io/categories\n'; fi
}
if $json; then
    printf '{"schema_version":2,"detector_version":"%s","total_apps":%d,"electron_count":%d,"total_size_kb":%d,"unknown_sizes":%d,"scan_warnings":%d,"electron_apps":[' "$VERSION" "$count" "$found" "$total_kb" "$unknown_sizes" "$skipped"
    for ((i=0;i<found;i++)); do
        [ "$i" -eq 0 ] || printf ','
        printf '{"name":'; json_string "${names[$i]}"
        printf ',"size_kb":'; if [ "${sizes[$i]}" -lt 0 ]; then printf null; else printf '%d' "${sizes[$i]}"; fi
        printf ',"version":'; json_string "${versions[$i]}"
        printf ',"evidence":'; json_string "${evidence[$i]}"; printf '}'
    done
    printf ']}\n'
elif $share; then summary
else
    if $animate && ! $quiet; then printf '\r\033[K'; fi
    printf '%s  YOUR MAC APP CENSUS / %d Electron %s found.%s\n' "$mint" "$found" "$app_label" "$reset"
    printf '  %d apps inspected · %d%% with Electron markers\n' "$count" "$percent"
    if ! $quiet && [ "$count" -gt 0 ]; then
        printf '  %s[' "$mint"
        for ((b=0;b<20;b++)); do
            if [ "$b" -lt "$((found*20/count))" ]; then printf '#'; else printf '.'; fi
        done
        printf ']%s  %d matched / %d without a marker\n' "$reset" "$found" "$((count-found))"
    fi
    printf '\n'
    if [ "$found" -gt 0 ]; then printf '  THE LINEUP / largest bundles first\n\n'; fi
    if [ "$count" -eq 0 ]; then printf '  No readable app bundles found in the selected folders.\n';
    elif [ "$found" -eq 0 ]; then printf '  No Electron markers spotted. A quiet day at the agency.\n'; fi
    for ((i=0;i<found;i++)); do
        printf '  %2d. %s  (%s)\n' "$((i+1))" "$(safe_text "${names[$i]}")" "$(pretty_size "${sizes[$i]}")"
        printf '      v%s · %s\n' "$(safe_text "${versions[$i]}")" "${evidence[$i]}"
    done
    printf '\n  Bundle footprint: %s' "$(pretty_size "$total_kb")"
    [ "$unknown_sizes" -eq 0 ] || printf ' + %d unmeasured' "$unknown_sizes"
    printf '\n  This is disk usage, not RAM usage or potential savings.\n'
    printf '  No marker found does not prove an app is native.\n'
    [ "$skipped" -eq 0 ] || printf '  Partial scan: %d warnings (unreadable folders or bundles).\n' "$skipped"
    if ! $quiet; then
        printf '\n%s  Keep the apps you love. Get curious about the rest.%s\n' "$mint" "$reset"
        printf '  Explore native Mac apps → https://macnative.io/categories\n'
        printf '%s  Tip: --json exports a report; --share leaves out app names.%s\n\n' "$dim" "$reset"
    fi
fi
if $interactive; then
    while true; do
        printf '\n  [s] Share text  [c] Copy summary  [e] Explain findings\n'
        printf '  [a] Native alternatives  [q] Done\n  > '
        IFS= read -r choice || break
        case "$choice" in
            s|S) printf '\n'; summary ;;
            c|C) if summary | pbcopy; then printf '  Copied. App names and paths are left out.\n';
                 else printf '  Clipboard unavailable. Choose s to print the summary.\n'; fi ;;
            e|E) printf '\n  The clues: an Electron framework or executable in a bundle.\n'
                 printf '  A match means the app contains a runtime marker.\n'
                 printf '  No match does not establish which framework it uses.\n'
                 printf '  Sizes cover whole app bundles, excluding user data and caches.\n'
                 printf '  For RAM and CPU use, inspect running apps in Activity Monitor.\n' ;;
            a|A) open 'https://macnative.io/categories' || printf '  Visit https://macnative.io/categories in your browser.\n' ;;
            q|Q|'') break ;;
            *) printf '  Choose s, c, e, a, or q (Enter finishes).\n' ;;
        esac
    done
fi
