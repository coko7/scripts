#!/usr/bin/env bash
#
# appimg-install.sh — integrate an AppImage into your desktop
#
# Usage:   appimg-install.sh /path/to/MyApp.AppImage [CustomName]
#
# What it does:
#   1. Moves the AppImage to ~/.local/bin (renamed to lowercase, no spaces)
#   2. Extracts the app icon from the AppImage into ~/.local/share/icons
#   3. Reads the embedded .desktop file (if any) for Name/Categories/etc.
#   4. Creates a desktop entry in ~/.local/share/applications
#   5. Refreshes the desktop database so it shows up in your launcher

set -euo pipefail

# ---------- helpers ----------
err() {
  printf '\033[1;31merror:\033[0m %s\n' "$*" >&2
  exit 1
}
info() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }

# ---------- args ----------
[[ $# -ge 1 ]] || err "usage: $(basename "$0") /path/to/App.AppImage [CustomName]"

APPIMAGE_SRC="$1"
CUSTOM_NAME="${2:-}"

[[ -f "$APPIMAGE_SRC" ]] || err "file not found: $APPIMAGE_SRC"

# ---------- paths ----------
BIN_DIR="$HOME/.local/bin"
ICON_DIR="$HOME/.local/share/icons"
DESKTOP_DIR="$HOME/.local/share/applications"

mkdir -p "$BIN_DIR" "$ICON_DIR" "$DESKTOP_DIR"

# Derive a clean, launcher-friendly base name: "My App-1.2.3-x86_64.AppImage" -> "my-app"
BASENAME="$(basename "$APPIMAGE_SRC")"
CLEAN_NAME="$(echo "${BASENAME%.[Aa]pp[Ii]mage}" |
  sed -E 's/[-_.]?(v?[0-9]+(\.[0-9]+)*)//g; s/(x86_64|amd64|aarch64|arm64|i386)//gI' |
  sed -E 's/[^A-Za-z0-9]+/-/g; s/^-+|-+$//g' |
  tr '[:upper:]' '[:lower:]')"
[[ -n "$CLEAN_NAME" ]] || CLEAN_NAME="$(echo "${BASENAME%.*}" | tr '[:upper:]' '[:lower:]')"

TARGET="$BIN_DIR/$CLEAN_NAME.AppImage"

# ---------- 1. install the AppImage ----------
info "Installing AppImage to $TARGET"
if [[ "$(realpath "$APPIMAGE_SRC")" != "$(realpath -m "$TARGET")" ]]; then
  mv -i "$APPIMAGE_SRC" "$TARGET"
fi
chmod +x "$TARGET"

# ---------- 2. extract icon + embedded desktop file ----------
TMPDIR_EXTRACT="$(mktemp -d)"
cleanup() { rm -rf "$TMPDIR_EXTRACT"; }
trap cleanup EXIT

info "Extracting AppImage contents (icon + metadata)..."
(
  cd "$TMPDIR_EXTRACT"
  "$TARGET" --appimage-extract >/dev/null 2>&1
) || err "extraction failed — this AppImage may not support --appimage-extract"

SQUASH="$TMPDIR_EXTRACT/squashfs-root"
[[ -d "$SQUASH" ]] || err "extraction produced no squashfs-root directory"

# --- find the icon ---
# Priority: .DirIcon (resolving symlinks) -> top-level png/svg -> biggest icon in usr/share/icons
ICON_SRC=""
if [[ -e "$SQUASH/.DirIcon" ]]; then
  ICON_SRC="$(realpath "$SQUASH/.DirIcon" 2>/dev/null || true)"
fi
if [[ -z "$ICON_SRC" || ! -s "$ICON_SRC" ]]; then
  ICON_SRC="$(find "$SQUASH" -maxdepth 1 -type f \( -name '*.png' -o -name '*.svg' \) | head -n1 || true)"
fi
if [[ -z "$ICON_SRC" ]]; then
  # pick the largest png in the icon theme dirs (usually the highest resolution)
  ICON_SRC="$(find "$SQUASH/usr/share/icons" -type f -name '*.png' -printf '%s %p\n' 2>/dev/null |
    sort -rn | head -n1 | cut -d' ' -f2- || true)"
fi
if [[ -z "$ICON_SRC" ]]; then
  ICON_SRC="$(find "$SQUASH" -type f -name '*.svg' 2>/dev/null | head -n1 || true)"
fi

ICON_PATH=""
if [[ -n "$ICON_SRC" && -s "$ICON_SRC" ]]; then
  EXT="${ICON_SRC##*.}"
  case "$EXT" in png | svg | xpm) ;; *) EXT="png" ;; esac
  ICON_PATH="$ICON_DIR/$CLEAN_NAME.$EXT"
  cp "$ICON_SRC" "$ICON_PATH"
  info "Icon installed: $ICON_PATH"
else
  info "No icon found inside the AppImage — the entry will use a generic icon."
fi

# --- read the embedded .desktop file for metadata ---
EMBEDDED_DESKTOP="$(find "$SQUASH" -maxdepth 1 -name '*.desktop' -type f | head -n1 || true)"

get_key() { # get_key <key> <file>
  grep -m1 "^$1=" "$2" 2>/dev/null | cut -d= -f2- || true
}

APP_NAME=""
CATEGORIES=""
COMMENT=""
MIMETYPE=""
TERMINAL="false"
if [[ -n "$EMBEDDED_DESKTOP" ]]; then
  APP_NAME="$(get_key Name "$EMBEDDED_DESKTOP")"
  CATEGORIES="$(get_key Categories "$EMBEDDED_DESKTOP")"
  COMMENT="$(get_key Comment "$EMBEDDED_DESKTOP")"
  MIMETYPE="$(get_key MimeType "$EMBEDDED_DESKTOP")"
  TERMINAL="$(get_key Terminal "$EMBEDDED_DESKTOP")"
fi

# overrides / fallbacks
[[ -n "$CUSTOM_NAME" ]] && APP_NAME="$CUSTOM_NAME"
[[ -n "$APP_NAME" ]] || APP_NAME="$CLEAN_NAME"
[[ -n "$CATEGORIES" ]] || CATEGORIES="Utility;"
[[ "$CATEGORIES" == *\; ]] || CATEGORIES="$CATEGORIES;"
[[ "$TERMINAL" == "true" ]] || TERMINAL="false"

# ---------- 3. write the desktop entry ----------
DESKTOP_FILE="$DESKTOP_DIR/$CLEAN_NAME.desktop"
info "Creating desktop entry: $DESKTOP_FILE"

{
  echo "[Desktop Entry]"
  echo "Type=Application"
  echo "Name=$APP_NAME"
  [[ -n "$COMMENT" ]] && echo "Comment=$COMMENT"
  echo "Exec=\"$TARGET\" %U"
  [[ -n "$ICON_PATH" ]] && echo "Icon=$ICON_PATH"
  echo "Terminal=$TERMINAL"
  echo "Categories=$CATEGORIES"
  [[ -n "$MIMETYPE" ]] && echo "MimeType=$MIMETYPE"
  echo "X-AppImage-Path=$TARGET"
} >"$DESKTOP_FILE"

chmod 644 "$DESKTOP_FILE"

# ---------- 4. refresh caches ----------
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -q "$ICON_DIR" 2>/dev/null || true
fi

info "Done! '$APP_NAME' should now appear in your application launcher."
echo
echo "  Binary : $TARGET"
echo "  Desktop: $DESKTOP_FILE"
[[ -n "$ICON_PATH" ]] && echo "  Icon   : $ICON_PATH"
echo
echo "To uninstall:  rm '$TARGET' '$DESKTOP_FILE'${ICON_PATH:+ '$ICON_PATH'}"
