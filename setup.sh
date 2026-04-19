#!/usr/bin/env bash
# setup.sh — Create symlinks for Emacs configuration
#   ~/.emacs.d -> this repo folder (contains init.el)
#   ~/yuleshow-emacs-backup  (create if missing)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- ~/.emacs.d -> this folder ----
if [ -L "$HOME/.emacs.d" ]; then
    echo "~/.emacs.d is already a symlink -> $(readlink "$HOME/.emacs.d")"
    echo "  Removing old symlink..."
    rm "$HOME/.emacs.d"
elif [ -d "$HOME/.emacs.d" ]; then
    echo "~/.emacs.d exists as a directory. Backing up to ~/.emacs.d.bak"
    mv "$HOME/.emacs.d" "$HOME/.emacs.d.bak"
fi
ln -s "$SCRIPT_DIR" "$HOME/.emacs.d"
echo "Created symlink: ~/.emacs.d -> $SCRIPT_DIR"

# ---- Backup directory ----
mkdir -p "$HOME/yuleshow-emacs-backup/backups"
mkdir -p "$HOME/yuleshow-emacs-backup/auto-save"
mkdir -p "$HOME/yuleshow-emacs-backup/auto-save-list"
echo "Ensured ~/yuleshow-emacs-backup/ exists"

echo ""
echo "Done! Start Emacs to use your new configuration."
