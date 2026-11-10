#!/usr/bin/env bash
# Install the Emacs configuration on macOS and Linux.

set -euo pipefail

REPOSITORY_ARCHIVE="https://github.com/yuleshow/yuleshow-new-emacs/archive/refs/heads/main.tar.gz"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CONFIG_DIR="$HOME/.emacs.d"
INSTALL_DIR="$HOME/.local/share/yuleshow-emacs"
SOURCE_DIR=""

if [ -f "$SCRIPT_DIR/init.el" ]; then
    SOURCE_DIR="$SCRIPT_DIR"
elif [ -f "$INSTALL_DIR/init.el" ]; then
    SOURCE_DIR="$INSTALL_DIR"
else
    command -v curl >/dev/null 2>&1 || {
        echo "Error: curl is required to download the configuration." >&2
        exit 1
    }
    command -v tar >/dev/null 2>&1 || {
        echo "Error: tar is required to unpack the configuration." >&2
        exit 1
    }
    temp_dir="$(mktemp -d)"
    trap 'rm -rf "$temp_dir"' EXIT

    echo "Downloading Emacs configuration..."
    curl --fail --location --silent --show-error "$REPOSITORY_ARCHIVE" -o "$temp_dir/repository.tar.gz"
    tar -xzf "$temp_dir/repository.tar.gz" -C "$temp_dir"
    downloaded_dir="$temp_dir/yuleshow-new-emacs-main"
    if [ ! -f "$downloaded_dir/init.el" ]; then
        echo "Error: downloaded archive does not contain init.el." >&2
        exit 1
    fi

    mkdir -p "$(dirname "$INSTALL_DIR")"
    mv "$downloaded_dir" "$INSTALL_DIR"
    SOURCE_DIR="$INSTALL_DIR"
fi
SOURCE_DIR="$(cd -P "$SOURCE_DIR" && pwd -P)"

if [ -L "$CONFIG_DIR" ] && [ "$(cd -P "$CONFIG_DIR" 2>/dev/null && pwd)" = "$SOURCE_DIR" ]; then
    echo "$CONFIG_DIR already points to $SOURCE_DIR"
else
    if [ -e "$CONFIG_DIR" ] || [ -L "$CONFIG_DIR" ]; then
        backup_dir="$CONFIG_DIR.bak"
        suffix=1
        while [ -e "$backup_dir" ] || [ -L "$backup_dir" ]; do
            backup_dir="$CONFIG_DIR.bak.$suffix"
            suffix=$((suffix + 1))
        done
        mv "$CONFIG_DIR" "$backup_dir"
        echo "Backed up existing $CONFIG_DIR to $backup_dir"
    fi

    ln -s "$SOURCE_DIR" "$CONFIG_DIR"
    echo "Created symlink: $CONFIG_DIR -> $SOURCE_DIR"
fi

mkdir -p "$HOME/yuleshow-emacs-backup/backups" \
         "$HOME/yuleshow-emacs-backup/auto-save" \
         "$HOME/yuleshow-emacs-backup/auto-save-list"
echo "Ensured $HOME/yuleshow-emacs-backup/ exists"

echo ""
echo "Done! Start Emacs to use your new configuration."
