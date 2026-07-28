#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPLY_THEME=0
INSTALL_CACHYOS_FISH=0
INSTALL_FIREFOX_USER_JS=1
FIREFOX_PROFILE_NAME="${FIREFOX_PROFILE_NAME:-}"
FIREFOX_PROFILE_NAME_EXPLICIT=0
FIREFOX_PROFILE_DEFAULT_NAME="default-release"

if [[ -n "$FIREFOX_PROFILE_NAME" ]]; then
  FIREFOX_PROFILE_NAME_EXPLICIT=1
fi

WALLPAPER_PATH="${HOME}/Pictures/Wallpapers/nord_cachyos.png"
CACHYOS_FISH_SOURCE="${SCRIPT_DIR}/.config/fish/config.fish"
CACHYOS_FISH_TARGET="/usr/share/cachyos-fish-config/cachyos-config.fish"
FIREFOX_USER_JS_SOURCE="${SCRIPT_DIR}/firefox/user.js"
LAUNCHER_ICON_SOURCE="${SCRIPT_DIR}/assets/app-launcher-logo/cachyos-minimal.svg"
PAPIRUS_ICON_PACKAGE="papirus-icon-theme"
PAPIRUS_SYSTEM_DIR="/usr/share/icons"
CUSTOM_ICON_THEME_NAME="Papirus-Dark-Nordic"
CUSTOM_ICON_THEME_DIR="/usr/local/share/icons/${CUSTOM_ICON_THEME_NAME}"

INSTALL_MAP=(
  ".config/btop:.config/btop"
  ".config/fastfetch:.config/fastfetch"
  ".config/fish:.config/fish"
  ".config/psd/psd.conf:.config/psd/psd.conf"
  ".local/share/aurorae/themes/Nordic:.local/share/aurorae/themes/Nordic"
  ".local/share/color-schemes/nordic-blue.colors:.local/share/color-schemes/nordic-blue.colors"
  ".local/share/icons/capitaine-cursors-nord:.local/share/icons/capitaine-cursors-nord"
  ".local/share/konsole/Nord.profile:.local/share/konsole/Nord.profile"
  ".local/share/konsole/nord.colorscheme:.local/share/konsole/nord.colorscheme"
  ".local/share/plasma/desktoptheme/polar-gleam:.local/share/plasma/desktoptheme/polar-gleam"
  "assets/wallpapers/nord_cachyos.png:Pictures/Wallpapers/nord_cachyos.png"
)

usage() {
  cat <<'EOF'
Usage: ./install.sh [--apply-theme] [--install-cachyos-fish] [--firefox-profile NAME] [--skip-firefox]
EOF
}

list_firefox_profiles() {
  local root="$1" profiles_ini="${root}/profiles.ini"
  local name="" path="" is_relative="1" line candidate

  [[ -f "$profiles_ini" ]] || return 0

  emit_profile() {
    if [[ -z "$path" ]]; then
      return 0
    fi

    if [[ "$is_relative" == "1" ]]; then
      candidate="${root}/${path}"
    else
      candidate="$path"
    fi

    [[ -d "$candidate" ]] && printf '%s\t%s\n' "${name:-${path##*/}}" "$candidate"
  }

  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      "[Profile"*)
        emit_profile
        name=""
        path=""
        is_relative="1"
        ;;
      Name=*)
        name="${line#Name=}"
        ;;
      Path=*)
        path="${line#Path=}"
        ;;
      IsRelative=*)
        is_relative="${line#IsRelative=}"
        ;;
    esac
  done < "$profiles_ini"

  emit_profile
}

profile_matches_name() {
  local profile_name="$1" display_name="$2" profile_dir="$3" path_base="${profile_dir##*/}"

  [[ "$display_name" == "$profile_name" || "$display_name" == *"$profile_name"* || "$path_base" == *"$profile_name"* ]]
}

install_firefox_user_js() {
  local config_home="${XDG_CONFIG_HOME:-${HOME}/.config}"
  local root display_name profile_dir index choice default_index=""
  local -a firefox_roots profile_names profile_dirs

  [[ -f "$FIREFOX_USER_JS_SOURCE" ]] || { echo "Missing Firefox user.js at ${FIREFOX_USER_JS_SOURCE}"; exit 1; }
  command -v install >/dev/null 2>&1 || { echo "Missing required command: install"; exit 1; }

  firefox_roots=(
    "${config_home}/mozilla/firefox"
    "${HOME}/.mozilla/firefox"
  )

  for root in "${firefox_roots[@]}"; do
    [[ -d "$root" ]] || continue

    while IFS=$'\t' read -r display_name profile_dir; do
      profile_names+=("$display_name")
      profile_dirs+=("$profile_dir")
    done < <(list_firefox_profiles "$root")
  done

  if ((${#profile_dirs[@]} == 0)); then
    echo "No Firefox profiles were found. Skipping Betterfox user.js."
    return 0
  fi

  if (( FIREFOX_PROFILE_NAME_EXPLICIT )); then
    for index in "${!profile_dirs[@]}"; do
      if profile_matches_name "$FIREFOX_PROFILE_NAME" "${profile_names[$index]}" "${profile_dirs[$index]}"; then
        profile_dir="${profile_dirs[$index]}"
        echo "Installing Betterfox user.js to ${profile_dir}/user.js"
        install -Dm644 "$FIREFOX_USER_JS_SOURCE" "${profile_dir}/user.js"
        return 0
      fi
    done

    echo "Firefox profile matching '${FIREFOX_PROFILE_NAME}' was not found. Skipping Betterfox user.js."
    return 0
  fi

  for index in "${!profile_dirs[@]}"; do
    if profile_matches_name "$FIREFOX_PROFILE_DEFAULT_NAME" "${profile_names[$index]}" "${profile_dirs[$index]}"; then
      default_index="$index"
      break
    fi
  done

  if [[ -t 0 && -t 1 ]]; then
    echo "Select the Firefox profile to receive Betterfox user.js:"
    for index in "${!profile_dirs[@]}"; do
      printf '  %d) %s (%s)' "$((index + 1))" "${profile_names[$index]}" "${profile_dirs[$index]}"
      if [[ "$index" == "$default_index" ]]; then
        printf ' [default]'
      fi
      printf '\n'
    done
    echo "  s) Skip Firefox user.js"

    while true; do
      read -r -p "Profile number${default_index:+ [$((default_index + 1))]}: " choice
      if [[ -z "$choice" && -n "$default_index" ]]; then
        choice="$((default_index + 1))"
      fi
      if [[ "$choice" == "s" || "$choice" == "S" ]]; then
        echo "Skipping Betterfox user.js."
        return 0
      fi
      if [[ "$choice" =~ ^[0-9]+$ && "$choice" -ge 1 && "$choice" -le "${#profile_dirs[@]}" ]]; then
        profile_dir="${profile_dirs[$((choice - 1))]}"
        echo "Installing Betterfox user.js to ${profile_dir}/user.js"
        install -Dm644 "$FIREFOX_USER_JS_SOURCE" "${profile_dir}/user.js"
        return 0
      fi
      echo "Invalid selection."
    done
  fi

  if [[ -n "$default_index" ]]; then
    profile_dir="${profile_dirs[$default_index]}"
    echo "Non-interactive shell detected. Installing Betterfox user.js to Firefox default-release profile ${profile_dir}/user.js"
    install -Dm644 "$FIREFOX_USER_JS_SOURCE" "${profile_dir}/user.js"
    return 0
  fi

  echo "Non-interactive shell detected and no default-release profile was found. Skipping Betterfox user.js."
  echo "Use --firefox-profile NAME or FIREFOX_PROFILE_NAME=NAME to choose a profile."
}

install_cachyos_fish_config() {
  [[ -f "$CACHYOS_FISH_SOURCE" ]] || { echo "Missing fish config at ${CACHYOS_FISH_SOURCE}"; exit 1; }
  command -v sudo >/dev/null 2>&1 || { echo "Missing required command: sudo"; exit 1; }
  command -v install >/dev/null 2>&1 || { echo "Missing required command: install"; exit 1; }

  echo "Installing CachyOS fish config to ${CACHYOS_FISH_TARGET}"
  sudo install -Dm644 "$CACHYOS_FISH_SOURCE" "$CACHYOS_FISH_TARGET"
}

install_papirus_icon_theme() {
  command -v sudo >/dev/null 2>&1 || { echo "Missing required command: sudo"; exit 1; }
  command -v pacman >/dev/null 2>&1 || { echo "Missing required command: pacman"; exit 1; }

  echo "Installing ${PAPIRUS_ICON_PACKAGE} from the system repositories"
  sudo pacman -S --needed --noconfirm "${PAPIRUS_ICON_PACKAGE}"
}

install_global_nordic_icon_theme() {
  local temp_dir source_dir target_dir source_icon target_icon size rel_dir rel_target directories_csv
  local -a directories

  [[ -d "${PAPIRUS_SYSTEM_DIR}/Papirus-Dark" ]] || { echo "Papirus Dark theme not found at ${PAPIRUS_SYSTEM_DIR}/Papirus-Dark"; exit 1; }
  [[ -f "$LAUNCHER_ICON_SOURCE" ]] || { echo "Missing launcher icon at ${LAUNCHER_ICON_SOURCE}"; exit 1; }
  command -v sudo >/dev/null 2>&1 || { echo "Missing required command: sudo"; exit 1; }
  command -v find >/dev/null 2>&1 || { echo "Missing required command: find"; exit 1; }
  command -v ln >/dev/null 2>&1 || { echo "Missing required command: ln"; exit 1; }
  command -v install >/dev/null 2>&1 || { echo "Missing required command: install"; exit 1; }
  command -v mktemp >/dev/null 2>&1 || { echo "Missing required command: mktemp"; exit 1; }

  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' RETURN

  echo "Building ${CUSTOM_ICON_THEME_NAME}"

  while IFS= read -r source_icon; do
    source_dir="$(dirname "$source_icon")"
    rel_dir="${source_dir#${PAPIRUS_SYSTEM_DIR}/Papirus-Dark/}"
    target_dir="${temp_dir}/${rel_dir}"
    target_icon="${target_dir}/$(basename "$source_icon" | sed 's/^folder-nordic/folder/')"

    mkdir -p "$target_dir"
    ln -sfn "$source_icon" "$target_icon"
  done < <(find "${PAPIRUS_SYSTEM_DIR}/Papirus-Dark" -path '*/places/folder-nordic*.svg' | sort)

  for size in 32 48 64; do
    target_icon="${temp_dir}/${size}x${size}/apps/start-here-kde-plasma.svg"
    install -Dm644 "$LAUNCHER_ICON_SOURCE" "$target_icon"
  done

  while IFS= read -r rel_target; do
    directories+=("$rel_target")
  done < <(find "$temp_dir" -mindepth 1 -type d -printf '%P\n' | sort)

  directories_csv="$(printf '%s\n' "${directories[@]}" | paste -sd, -)"

  {
    echo "[Icon Theme]"
    echo "Name=${CUSTOM_ICON_THEME_NAME}"
    echo "Comment=Papirus Dark with Nordic folder overrides"
    echo "Inherits=Papirus-Dark"
    echo "Directories=${directories_csv}"
    echo

    for rel_dir in "${directories[@]}"; do
      size="${rel_dir%%/*}"
      size="${size%%x*}"

      echo "[${rel_dir}]"
      if [[ "$rel_dir" == */places ]]; then
        echo "Context=Places"
      else
        echo "Context=Applications"
      fi
      echo "Size=${size}"
      echo "Type=Fixed"
      echo
    done
  } > "${temp_dir}/index.theme"

  echo "Installing ${CUSTOM_ICON_THEME_NAME} to ${CUSTOM_ICON_THEME_DIR}"
  sudo rm -rf "${CUSTOM_ICON_THEME_DIR}"
  sudo install -d "$(dirname "${CUSTOM_ICON_THEME_DIR}")"
  sudo cp -a "$temp_dir" "${CUSTOM_ICON_THEME_DIR}"
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
  kwriteconfig6 --file kdeglobals --group Icons --key Theme "${CUSTOM_ICON_THEME_NAME}"
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
    --firefox-profile)
      [[ $# -ge 2 ]] || { echo "Missing value for --firefox-profile"; usage; exit 1; }
      FIREFOX_PROFILE_NAME="$2"
      FIREFOX_PROFILE_NAME_EXPLICIT=1
      shift
      ;;
    --skip-firefox)
      INSTALL_FIREFOX_USER_JS=0
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

install_papirus_icon_theme
install_global_nordic_icon_theme

if (( INSTALL_FIREFOX_USER_JS )); then
  install_firefox_user_js
fi

if (( APPLY_THEME )); then
  apply_theme_settings
fi

if (( INSTALL_CACHYOS_FISH )); then
  install_cachyos_fish_config
fi

echo "Install complete."
