#!/bin/bash
# Installs the "Open in Linear" keyboard shortcut.
#
#   ./install.sh                                         # walks you through setup
#   ./install.sh --workspace acme                        # skip the questions (a linear.app URL works too)
#   ./install.sh --workspace acme --shortcut ctrl+shift+k
#
# Shortcuts are modifiers plus one key, joined with +: cmd, opt (alt), ctrl, shift.
# The default is ctrl+opt+cmd+l (⌃⌥⌘L). Re-run any time to change your settings.

set -euo pipefail
cd "$(dirname "$0")"

NAME="Open in Linear"
DEST="$HOME/Library/Services/$NAME.workflow"
PBS_KEY="(null) - $NAME - runWorkflowAsService"
DEFAULT_SHORTCUT="@~^l"   # ⌃⌥⌘L, in macOS notation: @ = ⌘, ~ = ⌥, ^ = ⌃, $ = ⇧

WORKSPACE=""
SHORTCUT_INPUT=""

# "ctrl+opt+cmd+l" -> "@~^l". Prints nothing if it can't parse it.
parse_shortcut() {
  local input mods="" key="" part
  input="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d ' ')"
  input="${input//⌘/cmd+}"; input="${input//⌥/opt+}"; input="${input//⌃/ctrl+}"; input="${input//⇧/shift+}"
  local IFS="+"
  for part in $input; do
    case "$part" in
      "") ;;
      cmd|command) mods="$mods@" ;;
      opt|option|alt) mods="$mods~" ;;
      ctrl|control) mods="$mods^" ;;
      shift) mods="$mods\$" ;;
      [a-z0-9]) [[ -n "$key" ]] && return; key="$part" ;;
      *) return ;;
    esac
  done
  [[ -n "$mods" && -n "$key" ]] && printf '%s%s' "$mods" "$key"
}

# "@~^l" -> "⌃⌥⌘L" (Apple's modifier order)
pretty_shortcut() {
  local k="$1" out=""
  [[ "$k" == *"^"* ]] && out="$out⌃"
  [[ "$k" == *"~"* ]] && out="$out⌥"
  [[ "$k" == *"\$"* ]] && out="$out⇧"
  [[ "$k" == *"@"* ]] && out="$out⌘"
  printf '%s%s' "$out" "$(printf '%s' "${k: -1}" | tr '[:lower:]' '[:upper:]')"
}

# Opens a little window that records the next shortcut pressed; falls back to typing it.
ask_custom_shortcut() {
  local recorded typed
  echo "  A small window will open. Press the shortcut you want (Esc to cancel)." >&2
  recorded="$(osascript -l JavaScript record-shortcut.js 2>/dev/null || true)"
  if [[ -n "$recorded" ]]; then
    echo "  Got $(pretty_shortcut "$recorded")" >&2
    printf '%s' "$recorded"
    return
  fi
  echo "  Nothing recorded. You can type it instead, like ctrl+shift+k." >&2
  while :; do
    read -r -p "  Shortcut: " typed
    recorded="$(parse_shortcut "$typed" || true)"
    [[ -n "$recorded" ]] && { printf '%s' "$recorded"; return; }
    echo "  Couldn't read that. Use modifiers plus a letter or number, like ctrl+shift+k" >&2
  done
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --workspace) WORKSPACE="${2:-}"; shift 2 ;;
    --shortcut) SHORTCUT_INPUT="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# What's installed now, so re-running defaults to your current settings
current_workspace="$(plutil -extract actions.0.action.ActionParameters.COMMAND_STRING raw "$DEST/Contents/document.wflow" 2>/dev/null |
  sed -nE 's/^workspace="([A-Za-z0-9_-]+)".*/\1/p' || true)"
current_shortcut="$(defaults export pbs - 2>/dev/null |
  plutil -extract "NSServicesStatus.$PBS_KEY.key_equivalent" raw - 2>/dev/null || true)"
[[ -d "$DEST" && -n "$current_shortcut" ]] || current_shortcut="$DEFAULT_SHORTCUT"

SHORTCUT=""
if [[ -n "$SHORTCUT_INPUT" ]]; then
  [[ "$SHORTCUT_INPUT" == "default" ]] && SHORTCUT_INPUT="ctrl+opt+cmd+l"
  SHORTCUT="$(parse_shortcut "$SHORTCUT_INPUT" || true)"
  if [[ -z "$SHORTCUT" ]]; then
    echo "Couldn't read shortcut '$SHORTCUT_INPUT'. Try something like ctrl+shift+k" >&2
    exit 1
  fi
fi

if [[ -t 0 && ( -z "$WORKSPACE" || -z "$SHORTCUT" ) ]]; then
  echo
  echo "  Open in Linear: setup"
  echo "  ---------------------"

  if [[ -z "$WORKSPACE" ]]; then
    echo
    echo "  Which Linear workspace? It's the bit after linear.app/ in your URLs,"
    echo "  e.g. acme for https://linear.app/acme/... (pasting a Linear URL works too)"
    if [[ -n "$current_workspace" ]]; then
      read -r -p "  Workspace [$current_workspace]: " WORKSPACE
      WORKSPACE="${WORKSPACE:-$current_workspace}"
    else
      read -r -p "  Workspace: " WORKSPACE
    fi
  fi

  if [[ -z "$SHORTCUT" ]]; then
    echo
    echo "  Keyboard shortcut?"
    if [[ "$current_shortcut" != "$DEFAULT_SHORTCUT" ]]; then
      echo "    1) Keep $(pretty_shortcut "$current_shortcut") (current)"
      echo "    2) $(pretty_shortcut "$DEFAULT_SHORTCUT") (default)"
      echo "    3) Custom: press your own"
      read -r -p "  Choose [1]: " choice
      case "${choice:-1}" in
        2) SHORTCUT="$DEFAULT_SHORTCUT" ;;
        3) SHORTCUT="$(ask_custom_shortcut)" ;;
        *) SHORTCUT="$current_shortcut" ;;
      esac
    else
      echo "    1) $(pretty_shortcut "$DEFAULT_SHORTCUT") (default)"
      echo "    2) Custom: press your own"
      read -r -p "  Choose [1]: " choice
      case "${choice:-1}" in
        2) SHORTCUT="$(ask_custom_shortcut)" ;;
        *) SHORTCUT="$DEFAULT_SHORTCUT" ;;
      esac
    fi
  fi
  echo
fi
SHORTCUT="${SHORTCUT:-$current_shortcut}"

# Accept a pasted URL: https://linear.app/acme/issue/ENG-1 -> acme
WORKSPACE="${WORKSPACE#*linear.app/}"
WORKSPACE="${WORKSPACE%%/*}"
if [[ ! "$WORKSPACE" =~ ^[A-Za-z0-9_-]+$ ]]; then
  echo "Need a workspace slug like 'acme' (the part after linear.app/). Try: ./install.sh --workspace acme" >&2
  exit 1
fi

script="$(sed -E "s/^workspace=.*/workspace=\"$WORKSPACE\"/" open-in-linear.sh)"

rm -rf "$DEST"
mkdir -p "$DEST/Contents"
cp template/Info.plist template/document.wflow "$DEST/Contents/"
plutil -replace actions.0.action.ActionParameters.COMMAND_STRING -string "$script" "$DEST/Contents/document.wflow"

# Shortcut on, right-click menu off. macOS only runs service shortcuts for services
# shown in the Services menu, so that one stays on.
defaults write pbs NSServicesStatus -dict-add "\"$PBS_KEY\"" \
  "{ enabled_context_menu = 0; enabled_services_menu = 1; key_equivalent = \"$SHORTCUT\"; presentation_modes = { ContextMenu = 0; ServicesMenu = 1; }; }"

/System/Library/CoreServices/pbs -update

echo "Installed. Highlight some text anywhere and press $(pretty_shortcut "$SHORTCUT") to open it in linear.app/$WORKSPACE"
echo "Apps that were already open may need a restart to notice."
