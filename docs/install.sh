#!/usr/bin/env bash
set -euo pipefail

repo="nodos-dev/workspace"
api="https://api.github.com/repos/${repo}/releases/latest"

print_banner() {
  cat <<'EOF'
--------------------------------------------
███╗   ██╗ ██████╗ ██████╗  ██████╗ ███████╗
████╗  ██║██╔═══██╗██╔══██╗██╔═══██╗██╔════╝
██╔██╗ ██║██║   ██║██║  ██║██║   ██║███████╗
██║╚██╗██║██║   ██║██║  ██║██║   ██║╚════██║
██║ ╚████║╚██████╔╝██████╔╝╚██████╔╝███████║
╚═╝  ╚═══╝ ╚═════╝ ╚═════╝  ╚═════╝ ╚══════╝
--------------------------------------------
EOF
  echo "Nodos  - Highly Extensible Node-Based Computing Platform"
  echo "nosman - Nodos Workspace & Package Manager"
  echo "Latest nosman release (and optionally, Nodos release) will be downloaded and installed for your platform."
}

prompt_choice() {
  local prompt="$1"
  local default="$2"
  local value
  printf '\n' >&2
  read -r -p "${prompt} [${default}]: " value </dev/tty || true
  if [ -z "$value" ]; then
    value="$default"
  fi
  printf '%s' "$value"
}

prompt_yes_no() {
  local prompt="$1"
  local default="$2"
  local value
  printf '\n' >&2
  read -r -p "${prompt} [${default}] (y/n): " value </dev/tty || true
  if [ -z "$value" ]; then
    value="$default"
  fi
  case "$value" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

download_text() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1"
    return
  fi
  if command -v wget >/dev/null 2>&1; then
    wget -qO- "$1"
    return
  fi
  echo "Error: curl or wget is required." >&2
  exit 1
}

download_file() {
  local url="$1"
  local dest="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fL --progress-bar -o "$dest" "$url"
    return
  fi
  wget --progress=bar:force -O "$dest" "$url"
}

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
    return
  fi
  if command -v sudo >/dev/null 2>&1; then
    sudo "$@"
    return
  fi
  return 1
}

install_git_linux() {
  if command -v apt-get >/dev/null 2>&1; then
    echo "Installing git via apt-get..."
    run_as_root apt-get update || return 1
    run_as_root apt-get install -y git || return 1
    return 0
  fi
  if command -v dnf >/dev/null 2>&1; then
    echo "Installing git via dnf..."
    run_as_root dnf install -y git || return 1
    return 0
  fi
  if command -v yum >/dev/null 2>&1; then
    echo "Installing git via yum..."
    run_as_root yum install -y git || return 1
    return 0
  fi
  if command -v pacman >/dev/null 2>&1; then
    echo "Installing git via pacman..."
    run_as_root pacman -Sy --noconfirm git || return 1
    return 0
  fi
  if command -v zypper >/dev/null 2>&1; then
    echo "Installing git via zypper..."
    run_as_root zypper --non-interactive install git || return 1
    return 0
  fi
  if command -v apk >/dev/null 2>&1; then
    echo "Installing git via apk..."
    run_as_root apk add --no-cache git || return 1
    return 0
  fi
  if command -v brew >/dev/null 2>&1; then
    echo "Installing git via brew..."
    brew install git || return 1
    return 0
  fi
  echo "Error: could not detect a supported package manager to install git automatically." >&2
  return 1
}

offer_git_linux() {
  if command -v git >/dev/null 2>&1; then
    return
  fi
  echo "Git is not needed to run Nodos. The 'nodos dev' commands and publishing use it."
  if prompt_yes_no "Install git now?" "n"; then
    if install_git_linux && command -v git >/dev/null 2>&1; then
      return
    fi
    echo "Warning: automatic git installation failed. Install it manually if you need it later." >&2
  fi
}

install_binary() {
  local src="$1"
  local dest_dir="$2"
  local dest_name="$3"
  local dest_path="${dest_dir}/${dest_name}"

  if [ ! -d "$dest_dir" ]; then
    mkdir -p "$dest_dir" 2>/dev/null || true
  fi

  if [ -w "$dest_dir" ]; then
    install -m 0755 "$src" "$dest_path"
    return
  fi

  if command -v sudo >/dev/null 2>&1; then
    sudo install -m 0755 "$src" "$dest_path"
    return
  fi

  echo "Error: cannot write to ${dest_dir}. Run with sudo or choose a user directory." >&2
  exit 1
}

ensure_path() {
  local dir="$1"
  local scope="$2"
  if printf '%s' "$PATH" | tr ':' '\n' | grep -Fxq "$dir"; then
    return
  fi

  if [ "$scope" = "system" ]; then
    local profile_path="/etc/profile.d/nosman.sh"
    local line="export PATH=\"\$PATH:${dir}\""
    if command -v sudo >/dev/null 2>&1; then
      echo "$line" | sudo tee "$profile_path" >/dev/null
      sudo chmod 0644 "$profile_path"
      return
    fi
    echo "Error: cannot update system PATH. Run with sudo." >&2
    exit 1
  fi

  local shell_name
  shell_name="$(basename "${SHELL:-}")"
  local profile
  case "$shell_name" in
    zsh) profile="$HOME/.zshrc" ;;
    bash) profile="$HOME/.bashrc" ;;
    *) profile="$HOME/.profile" ;;
  esac

  if [ ! -f "$profile" ]; then
    touch "$profile"
  fi

  if ! grep -Fq "$dir" "$profile"; then
    printf '\nexport PATH="$PATH:%s"\n' "$dir" >> "$profile"
  fi
}

find_nodos_exec() {
  local dir="$1"
  local found
  found="$(find "$dir" -type f \( -iname "nodos" -o -iname "nodos.exe" \) 2>/dev/null | head -n 1)"
  if [ -n "$found" ]; then
    printf '%s' "$found"
    return
  fi
  echo "Error: could not locate Nodos executable in ${dir}." >&2
  exit 1
}

write_desktop_entry() {
  local dest="$1"
  local exec_path="$2"
  local work_dir="$3"

  local content
  content="$(
    cat <<EOF
[Desktop Entry]
Type=Application
Name=Nodos
Exec=${exec_path}
Path=${work_dir}
Terminal=false
Categories=Development;
EOF
  )"

  if [ -w "$(dirname "$dest")" ]; then
    printf '%s\n' "$content" > "$dest"
    chmod 0644 "$dest"
    return
  fi

  if command -v sudo >/dev/null 2>&1; then
    printf '%s\n' "$content" | sudo tee "$dest" >/dev/null
    sudo chmod 0644 "$dest"
    return
  fi

  echo "Error: cannot write shortcut to ${dest}." >&2
  exit 1
}

print_banner

install_scope="$(prompt_choice "Install for all users or current user?" "current")"
case "$install_scope" in
  all|system|all-users) install_scope="all" ;;
  current|user|current-user) install_scope="current" ;;
  *)
    echo "Error: choose 'all' or 'current'." >&2
    exit 1
    ;;
esac

if [ "$install_scope" = "all" ]; then
  default_install_dir="/usr/local/bin"
  path_scope="system"
else
  default_install_dir="${HOME}/.local/bin"
  path_scope="user"
fi

install_dir="$(prompt_choice "Install directory" "$default_install_dir")"

add_path=true
if ! prompt_yes_no "Add install directory to PATH" "y"; then
  add_path=false
fi

uname_m="$(uname -m)"
case "$uname_m" in
  x86_64|amd64) arch="x86_64" ;;
  aarch64|arm64) arch="aarch64" ;;
  i386|i686) arch="x86" ;;
  *)
    arch="$uname_m"
    ;;
esac

json="$(download_text "$api")"

download_url="$(
  printf '%s\n' "$json" \
    | grep -Eo '"browser_download_url":\s*"[^"]+"' \
    | sed -E 's/.*"([^"]+)".*/\1/' \
    | grep -i "nosman-linux-${arch}" \
    | head -n 1
)"

if [ -z "$download_url" ]; then
  echo "Error: no matching asset for linux/${arch}." >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
tmp_path="${tmp_dir}/nosman"

echo "Downloading nosman for linux/${arch}..."
download_file "$download_url" "$tmp_path"

install_binary "$tmp_path" "$install_dir" "nosman"
if [ "$add_path" = true ]; then
  ensure_path "$install_dir" "$path_scope"
fi

rm -rf "$tmp_dir"

echo "Installed nosman to ${install_dir}/nosman"
if [ "$add_path" = true ]; then
  echo "If this is a new PATH entry, restart your shell."
fi

install_nodos=true
if ! prompt_yes_no "Install latest Nodos release?" "y"; then
  install_nodos=false
fi

if [ "$install_nodos" = true ]; then
  offer_git_linux

  if [ "$install_scope" = "all" ]; then
    nodos_install_dir="/opt/nodos"
    shortcut_dir="/usr/share/applications"
    desktop_dir=""
  else
    nodos_install_dir="${HOME}/.local/share/nodos"
    shortcut_dir="${HOME}/.local/share/applications"
    desktop_dir="${HOME}/Desktop"
  fi

  nosman_cmd="${install_dir}/nosman"
  if [ ! -x "$nosman_cmd" ]; then
    nosman_cmd="$(command -v nosman 2>/dev/null || true)"
  fi
  if [ -z "$nosman_cmd" ]; then
    echo "Error: nosman not found to install Nodos." >&2
    exit 1
  fi

  if [ "$install_scope" = "all" ] && [ ! -w "$nodos_install_dir" ]; then
    if command -v sudo >/dev/null 2>&1; then
      sudo mkdir -p "$nodos_install_dir"
      echo "Installing latest Nodos release with nosman..."
      sudo bash -c "'$nosman_cmd' --workspace '$nodos_install_dir' get -y"
    else
      echo "Error: cannot write to ${nodos_install_dir}. Run with sudo or choose a user install." >&2
      exit 1
    fi
  else
    mkdir -p "$nodos_install_dir" 2>/dev/null || true
    echo "Installing latest Nodos release with nosman..."
    "$nosman_cmd" --workspace "$nodos_install_dir" get -y
  fi

  nodos_exec="$(find_nodos_exec "$nodos_install_dir")"
  chmod +x "$nodos_exec" 2>/dev/null || true

  mkdir -p "$shortcut_dir" 2>/dev/null || true
  write_desktop_entry "${shortcut_dir}/Nodos.desktop" "$nodos_exec" "$(dirname "$nodos_exec")"

  if [ -n "$desktop_dir" ] && [ -d "$desktop_dir" ]; then
    write_desktop_entry "${desktop_dir}/Nodos.desktop" "$nodos_exec" "$(dirname "$nodos_exec")"
    chmod +x "${desktop_dir}/Nodos.desktop" 2>/dev/null || true
  fi

  echo "Installed Nodos to ${nodos_install_dir}"
  echo "Created shortcuts:"
  echo "  - ${shortcut_dir}/Nodos.desktop"
  if [ -n "$desktop_dir" ] && [ -d "$desktop_dir" ]; then
    echo "  - ${desktop_dir}/Nodos.desktop"
  fi
fi
