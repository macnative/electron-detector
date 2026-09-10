#!/bin/bash
#
# Electron Detector — find Electron-based apps on macOS
# https://github.com/macnative/electron-detector
# https://macnative.io
#
# Licensed under the MIT License (see LICENSE).

VERSION="1.0.0"

# ---------------------------------------------------------------------------
# Colors (disabled automatically when not attached to a terminal, or when
# NO_COLOR is set — see https://no-color.org)
# ---------------------------------------------------------------------------
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    PURPLE='\033[0;35m'
    CYAN='\033[0;36m'
    WHITE='\033[1;37m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; PURPLE=''; CYAN=''; WHITE=''; BOLD=''; NC=''
fi

ELECTRON="⚡"
NATIVE="✨"
SCAN="🔍"
WARN="⚠️"
CHECK="✓"
ROCKET="🚀"
PACKAGE="📦"

SCAN_PATHS=("/Applications")
JSON_OUTPUT=false
QUIET=false

usage() {
    cat <<EOF
Electron Detector v${VERSION}
Find which apps on your Mac are secretly built with Electron.

Usage:
  electron-detector.sh [options]

Options:
  -u, --user     Also scan ~/Applications
  -j, --json     Output machine-readable JSON instead of the report
  -q, --quiet    Suppress the banner and tips, print results only
  -v, --version  Print the version number
  -h, --help     Show this help message

Examples:
  electron-detector.sh
  electron-detector.sh --user
  electron-detector.sh --json | jq '.electron_apps'

Project home: https://github.com/macnative/electron-detector
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -u|--user)
            SCAN_PATHS+=("$HOME/Applications")
            shift
            ;;
        -j|--json)
            JSON_OUTPUT=true
            shift
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        -v|--version)
            echo "electron-detector ${VERSION}"
            exit 0
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

# Function to check if app is Electron
is_electron() {
    local app_path="$1"

    # Most reliable signal: the Electron Framework bundled inside the app
    if [ -d "$app_path/Contents/Frameworks/Electron Framework.framework" ]; then
        return 0
    fi

    # Fallback: an "Electron" binary sitting in the MacOS folder
    if [ -f "$app_path/Contents/MacOS/Electron" ]; then
        return 0
    fi

    return 1
}

get_app_size() {
    du -sh "$1" 2>/dev/null | cut -f1
}

get_app_version() {
    defaults read "$1/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "Unknown"
}

if [[ "$JSON_OUTPUT" != true && "$QUIET" != true ]]; then
    clear
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${ELECTRON}  ${BOLD}${WHITE}Electron Detector for macOS${NC}${CYAN}                    ║${NC}"
    echo -e "${CYAN}║${NC}     Find which apps are secretly Electron-based           ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
fi

apps=()
while IFS= read -r -d '' app; do
    apps+=("$app")
done < <(find "${SCAN_PATHS[@]}" -maxdepth 2 -name "*.app" -print0 2>/dev/null)

total_app_count=${#apps[@]}

if [ "$total_app_count" -eq 0 ]; then
    if [[ "$JSON_OUTPUT" == true ]]; then
        echo '{"error":"no applications found","scanned_paths":[]}'
    else
        echo -e "${RED}No applications found in: ${SCAN_PATHS[*]}${NC}"
    fi
    exit 1
fi

if [[ "$JSON_OUTPUT" != true && "$QUIET" != true ]]; then
    echo -e "${SCAN} ${BOLD}Scanning ${SCAN_PATHS[*]}...${NC}"
    echo ""
fi

electron_apps=()
electron_count=0
current=0
bar_length=50

for app in "${apps[@]}"; do
    ((current++))

    if [[ "$JSON_OUTPUT" != true && "$QUIET" != true ]]; then
        percent=$((current * 100 / total_app_count))
        filled=$((current * bar_length / total_app_count))
        printf "\r${BLUE}["
        for ((i=0; i<filled; i++)); do printf "▓"; done
        for ((i=filled; i<bar_length; i++)); do printf "░"; done
        printf "] %3d%% (%d/%d)${NC}" "$percent" "$current" "$total_app_count"
    fi

    if is_electron "$app"; then
        app_name=$(basename "$app" .app)
        app_size=$(get_app_size "$app")
        app_version=$(get_app_version "$app")
        electron_apps+=("$app_name|$app_size|$app_version")
        ((electron_count++))
    fi
done

if [[ "$JSON_OUTPUT" != true && "$QUIET" != true ]]; then
    printf "\r${BLUE}["
    for ((i=0; i<bar_length; i++)); do printf "▓"; done
    printf "] ${GREEN}Done!${NC}\n"
    echo ""
fi

# ---------------------------------------------------------------------------
# JSON output
# ---------------------------------------------------------------------------
if [[ "$JSON_OUTPUT" == true ]]; then
    printf '{"total_apps":%d,"electron_count":%d,"electron_apps":[' "$total_app_count" "$electron_count"
    first=true
    for app_info in "${electron_apps[@]}"; do
        IFS='|' read -r name size version <<< "$app_info"
        $first || printf ','
        first=false
        printf '{"name":"%s","size":"%s","version":"%s"}' \
            "${name//\"/\\\"}" "${size//\"/\\\"}" "${version//\"/\\\"}"
    done
    printf ']}\n'
    exit 0
fi

# ---------------------------------------------------------------------------
# Human-readable report
# ---------------------------------------------------------------------------
echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
echo ""

if [ "$electron_count" -eq 0 ]; then
    echo -e "${GREEN}${CHECK} ${BOLD}Congratulations!${NC}"
    echo -e "${GREEN}No Electron apps detected on your Mac!${NC}"
    echo ""
    echo -e "${NATIVE} Your Mac is running pure native apps! ${NATIVE}"
else
    echo -e "${RED}${WARN} ${BOLD}Found $electron_count Electron app(s) out of $total_app_count total apps${NC}"
    echo ""
    echo -e "${YELLOW}${ELECTRON} Electron Apps Detected:${NC}"
    echo ""

    printf "${BOLD}%-40s %-12s %-12s${NC}\n" "App Name" "Size" "Version"
    echo -e "${CYAN}────────────────────────────────────────────────────────────────${NC}"

    for app_info in "${electron_apps[@]}"; do
        IFS='|' read -r name size version <<< "$app_info"
        printf "${RED}%-40s${NC} ${YELLOW}%-12s${NC} ${PURPLE}%-12s${NC}\n" "$name" "$size" "$version"
    done

    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${PACKAGE} ${BOLD}Resource Impact:${NC}"
    echo ""

    if [ "$electron_count" -ge 5 ]; then
        echo -e "${RED}${WARN} High Electron count detected!${NC}"
        echo -e "   Each Electron app runs a full Chromium browser"
    elif [ "$electron_count" -ge 3 ]; then
        echo -e "${YELLOW}${WARN} Moderate Electron usage${NC}"
        echo -e "   These apps may impact battery life and performance"
    else
        echo -e "${GREEN}${CHECK} Low Electron usage${NC}"
        echo -e "   Your Mac is mostly running native apps!"
    fi
fi

if [[ "$QUIET" != true ]]; then
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${ROCKET} ${BOLD}Want native alternatives?${NC}"
    echo -e "   Check out: ${CYAN}https://macnative.io${NC}"
    echo ""
    echo -e "${GREEN}${CHECK} Native apps are:${NC}"
    echo -e "   • Faster and more responsive"
    echo -e "   • Use less RAM and battery"
    echo -e "   • Better macOS integration"
    echo -e "   • Smaller app size"
    echo ""

    if [ "$electron_count" -gt 0 ]; then
        echo -e "${BLUE}💡 Fun Fact:${NC}"
        echo -e "   Electron apps can use 100-300MB RAM even when idle"
        echo -e "   Native apps often use less than 50MB"
        echo ""
    fi

    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
    echo ""
fi
