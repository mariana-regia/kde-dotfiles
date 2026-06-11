#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPLY_THEME=0
INSTALL_CACHYOS_FISH=0

WALLPAPER_PATH="${HOME}/Pictures/Wallpapers/nord_cachyos.png"
CACHYOS_FISH_SOURCE="${SCRIPT_DIR}/.config/fish/config.fish"
CACHYOS_FISH_TARGET="/usr/share/cachyos-fish-config/cachyos-config.fish"
LAUNCHER_ICON_SOURCE="${SCRIPT_DIR}/assets/app-launcher-logo/cachyos-minimal.svg"

INSTALL_MAP=(
  ".config/btop:.config/btop"
  ".config/fastfetch:.config/fastfetch"
  ".config/fish:.config/fish"
  ".local/share/aurorae/themes/Nordic:.local/share/aurorae/themes/Nordic"
  ".local/share/color-schemes/nordic-blue.colors:.local/share/color-schemes/nordic-blue.colors"
  ".local/share/icons/Papirus:.local/share/icons/Papirus"
  ".local/share/icons/Papirus-Dark:.local/share/icons/Papirus-Dark"
  ".local/share/icons/Papirus-Light:.local/share/icons/Papirus-Light"
  ".local/share/icons/capitaine-cursors-nord:.local/share/icons/capitaine-cursors-nord"
  ".local/share/konsole/Nord.profile:.local/share/konsole/Nord.profile"
  ".local/share/konsole/nord.colorscheme:.local/share/konsole/nord.colorscheme"
  ".local/share/plasma/desktoptheme/polar-gleam:.local/share/plasma/desktoptheme/polar-gleam"
  "assets/wallpapers/nord_cachyos.png:Pictures/Wallpapers/nord_cachyos.png"
)

usage() {
  cat <<'EOF'
Usage: ./install.sh [--apply-theme] [--install-cachyos-fish]
EOF
}

install_cachyos_fish_config() {
  [[ -f "$CACHYOS_FISH_SOURCE" ]] || { echo "Missing fish config at ${CACHYOS_FISH_SOURCE}"; exit 1; }
  command -v sudo >/dev/null 2>&1 || { echo "Missing required command: sudo"; exit 1; }
  command -v install >/dev/null 2>&1 || { echo "Missing required command: install"; exit 1; }

  echo "Installing CachyOS fish config to ${CACHYOS_FISH_TARGET}"
  sudo install -Dm644 "$CACHYOS_FISH_SOURCE" "$CACHYOS_FISH_TARGET"
}

install_launcher_icon_override() {
  local target

  [[ -f "$LAUNCHER_ICON_SOURCE" ]] || { echo "Missing launcher icon at ${LAUNCHER_ICON_SOURCE}"; exit 1; }
  command -v install >/dev/null 2>&1 || { echo "Missing required command: install"; exit 1; }

  for size in 32 48 64; do
    target="${HOME}/.local/share/icons/Papirus-Dark/${size}x${size}/apps/start-here-kde-plasma.svg"
    install -Dm644 "$LAUNCHER_ICON_SOURCE" "$target"
  done
}

apply_desktop_wallpaper() {
  local script

  read -r -d '' script <<EOF || true
const wallpaper = "file://${WALLPAPER_PATH}";
for (const desktop of desktops()) {
  desktop.wallpaperPlugin = "org.kde.image";
  desktop.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
  desktop.writeConfig("Image", wallpaper);
}
EOF

  if qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$script" >/dev/null 2>&1; then
    return 0
  fi

  if qdbus6 org.kde.PlasmaShell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$script" >/dev/null 2>&1; then
    return 0
  fi

  echo "Failed to apply the desktop wallpaper through Plasma D-Bus. The files were installed, but you may need to set the desktop wallpaper manually."
  return 1
}

refresh_plasma() {
  echo "Refreshing Plasma"
  kbuildsycoca6 >/dev/null 2>&1 || true
  qdbus6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
  kquitapp6 plasmashell >/dev/null 2>&1 || true
  (plasmashell >/dev/null 2>&1 &) || true
}

apply_theme_settings() {
  command -v kwriteconfig6 >/dev/null 2>&1 || { echo "Missing required command: kwriteconfig6"; exit 1; }
  command -v plasma-apply-colorscheme >/dev/null 2>&1 || { echo "Missing required command: plasma-apply-colorscheme"; exit 1; }
  command -v plasma-apply-cursortheme >/dev/null 2>&1 || { echo "Missing required command: plasma-apply-cursortheme"; exit 1; }
  command -v plasma-apply-desktoptheme >/dev/null 2>&1 || { echo "Missing required command: plasma-apply-desktoptheme"; exit 1; }
  command -v qdbus6 >/dev/null 2>&1 || { echo "Missing required command: qdbus6"; exit 1; }
  [[ -x /usr/lib/plasma-apply-aurorae ]] || { echo "Missing required command: /usr/lib/plasma-apply-aurorae"; exit 1; }

  [[ -e "$WALLPAPER_PATH" ]] || { echo "Wallpaper not found at ${WALLPAPER_PATH}"; exit 1; }

  echo "Applying KDE settings"
  plasma-apply-colorscheme "Nordic Blue" >/dev/null 2>&1
  plasma-apply-desktoptheme polar-gleam >/dev/null 2>&1
  /usr/lib/plasma-apply-aurorae __aurorae__svg__Nordic >/dev/null 2>&1
  kwriteconfig6 --file kdeglobals --group Icons --key Theme Papirus-Dark
  kwriteconfig6 --file kcminputrc --group Mouse --key cursorTheme "capitaine-cursors-nord"
  kwriteconfig6 --file kcminputrc --group Mouse --key cursorSize 32
  plasma-apply-cursortheme "breeze_cursors" >/dev/null 2>&1 || true
  plasma-apply-cursortheme "capitaine-cursors-nord" >/dev/null 2>&1 || echo "Failed to apply the cursor theme automatically. You may need to switch it once in System Settings."
  kwriteconfig6 --file konsolerc --group Desktop Entry --key DefaultProfile Nord.profile
  apply_desktop_wallpaper
  kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key Image "${WALLPAPER_PATH}"
  refresh_plasma
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply-theme)
      APPLY_THEME=1
      ;;
    --install-cachyos-fish)
      INSTALL_CACHYOS_FISH=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

echo "Installing dotfiles into ${HOME}"

for entry in "${INSTALL_MAP[@]}"; do
  source="${SCRIPT_DIR}/${entry%%:*}"
  target="${HOME}/${entry#*:}"

  if [[ ! -e "$source" && ! -L "$source" ]]; then
    echo "Skipping missing source ${source}"
    continue
  fi

  if [[ -e "$target" || -L "$target" ]]; then
    echo "Removing ${target}"
    rm -rf "$target"
  fi

  mkdir -p "$(dirname "$target")"

  echo "Copying ${source} -> ${target}"
  cp -a "$source" "$target"
done

install_launcher_icon_override

if (( APPLY_THEME )); then
  apply_theme_settings
fi

if (( INSTALL_CACHYOS_FISH )); then
  install_cachyos_fish_config
fi

echo "Install complete."
