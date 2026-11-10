# Yuleshow Emacs configuration

## Installation

Download the installer for your operating system and run it:

- **macOS / Linux:**
  ```sh
  curl -fsSLO https://raw.githubusercontent.com/yuleshow/yuleshow-new-emacs/main/setup.sh
  bash setup.sh
  ```
- **Windows PowerShell:**
  ```powershell
  Set-ExecutionPolicy -Scope Process Bypass
  Invoke-WebRequest https://raw.githubusercontent.com/yuleshow/yuleshow-new-emacs/main/setup.ps1 -OutFile setup.ps1
  .\setup.ps1
  ```

The installer downloads the latest configuration from this repository if it
isn't already available locally, then links it as `~/.emacs.d` (a directory
junction on Windows). It creates the backup and autosave directories under
`~/yuleshow-emacs-backup`. If `~/.emacs.d` already exists, it is moved to the
first available `.emacs.d.bak`, `.emacs.d.bak.1`, etc.

Running the installer requires internet access and `curl` plus `tar` on
macOS/Linux. Windows uses PowerShell's built-in download and ZIP tools. On
Windows, a directory junction is used so administrator privileges and
Developer Mode are not required.

## Fonts

See [fonts.md](./fonts.md) for the font inventory, files, and Emacs shortcuts.
The installer places all bundled fonts in the current user's font directory.
Download the single installer and run it with Python 3:

- **macOS / Linux:**
  ```sh
  curl -fsSLO https://raw.githubusercontent.com/yuleshow/yuleshow-new-emacs/main/install-fonts.py
  python3 install-fonts.py
  ```
- **Windows PowerShell:**
  ```powershell
  Invoke-WebRequest https://raw.githubusercontent.com/yuleshow/yuleshow-new-emacs/main/install-fonts.py -OutFile install-fonts.py
  py -3 install-fonts.py
  ```

If `emacs-fonts/` is beside the script, it installs from that folder; otherwise
it downloads the font files from this repository. The download is about 185 MB.
Windows font registration is per-user and does not require administrator
privileges. Restart Emacs after installation.
