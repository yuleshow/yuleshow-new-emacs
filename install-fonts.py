#!/usr/bin/env python3
"""Install the bundled fonts used by this Emacs configuration."""

import ctypes
import os
import platform
import shutil
import subprocess
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


FONT_FILES = (
    "chinese/NotoSansTC-VariableFont_wght.ttf",
    "chinese/NotoSerifTC-VariableFont_wght.ttf",
    "chinese/TW-Kai-98_1.ttf",
    "chinese/TW-Sung-98_1.ttf",
    "chinese/WenQuanYi Bitmap Song 16px.ttf",
    "chinese/mingliu.ttc",
    "chinese/匯文明朝體.otf",
    "chinese/漢儀新蒂文徵明體.ttf",
    "english/Courier New.ttf",
    "english/EBGaramond-VariableFont_wght.ttf",
    "english/FiraCode-VariableFont_wght.ttf",
    "english/Georgia Bold Italic.ttf",
    "english/Georgia Bold.ttf",
    "english/Georgia Italic.ttf",
    "english/Georgia.ttf",
    "english/HackNerdFont-Regular.ttf",
    "english/Menlo.ttc",
    "english/Monaco.ttf",
    "english/SourceCodePro-VariableFont_wght.ttf",
    "english/Times New Roman Bold Italic.ttf",
    "english/Times New Roman Bold.ttf",
    "english/Times New Roman Italic.ttf",
    "english/Times New Roman.ttf",
)
FONT_BASE_URL = (
    "https://raw.githubusercontent.com/yuleshow/yuleshow-new-emacs/main/"
    "emacs-fonts/"
)


def font_directory():
    system = platform.system()
    if system == "Windows":
        local_app_data = os.environ.get("LOCALAPPDATA")
        if not local_app_data:
            raise RuntimeError(
                "LOCALAPPDATA is not set; cannot find the user font directory."
            )
        return Path(local_app_data) / "Microsoft" / "Windows" / "Fonts"
    if system == "Darwin":
        return Path.home() / "Library" / "Fonts"
    if system == "Linux":
        return Path.home() / ".local" / "share" / "fonts" / "yuleshow"
    raise RuntimeError(f"Unsupported operating system: {system}")


def download_font(relative_path, destination):
    encoded_path = urllib.parse.quote(relative_path, safe="/")
    request = urllib.request.Request(
        FONT_BASE_URL + encoded_path,
        headers={"User-Agent": "yuleshow-emacs-font-installer"},
    )
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                with destination.open("wb") as output:
                    shutil.copyfileobj(response, output)
            return
        except (OSError, urllib.error.URLError) as error:
            if attempt == 2:
                raise RuntimeError(
                    f"Could not download font {relative_path}: {error}"
                ) from error
            time.sleep(attempt + 1)


def validate_font(path):
    with path.open("rb") as font_file:
        signature = font_file.read(4)
    if signature not in (b"\x00\x01\x00\x00", b"OTTO", b"ttcf"):
        raise RuntimeError(
            f"Downloaded file is not a TrueType/OpenType font: {path.name}"
        )


def register_windows_fonts(directory, font_paths):
    import winreg

    registry_path = r"Software\Microsoft\Windows NT\CurrentVersion\Fonts"
    with winreg.CreateKeyEx(
        winreg.HKEY_CURRENT_USER, registry_path, 0, winreg.KEY_SET_VALUE
    ) as key:
        for font_path in font_paths:
            value_name = f"{font_path.stem} (TrueType)"
            winreg.SetValueEx(
                key, value_name, 0, winreg.REG_SZ, str(directory / font_path.name)
            )

    result = ctypes.c_size_t()
    if not ctypes.windll.user32.SendMessageTimeoutW(
        0xFFFF, 0x001D, 0, 0, 0x0002, 5000, ctypes.byref(result)
    ):
        raise OSError("Windows did not refresh its installed-font list.")


def main():
    system = platform.system()
    source_directory = Path(__file__).resolve().parent / "emacs-fonts"
    destination = font_directory()

    with tempfile.TemporaryDirectory(prefix="yuleshow-fonts-") as temporary:
        staging = Path(temporary)
        staged_fonts = []

        for relative_path in FONT_FILES:
            relative = Path(relative_path)
            staged_path = staging / relative.name
            bundled_path = source_directory / relative
            if bundled_path.is_file():
                shutil.copyfile(bundled_path, staged_path)
            else:
                download_font(relative_path, staged_path)
            validate_font(staged_path)
            staged_fonts.append(staged_path)

        destination.mkdir(parents=True, exist_ok=True)
        installed_fonts = []
        for staged_path in staged_fonts:
            target = destination / staged_path.name
            if target.exists():
                print(f"Already present, leaving unchanged: {target.name}")
            else:
                shutil.copy2(staged_path, target)
                print(f"Installed {target.name}")
            installed_fonts.append(target)

    if system == "Windows":
        register_windows_fonts(destination, installed_fonts)
    elif system == "Linux":
        fc_cache = shutil.which("fc-cache")
        if fc_cache:
            try:
                subprocess.run([fc_cache, "-f", str(destination)], check=True)
            except subprocess.CalledProcessError as error:
                raise RuntimeError(
                    f"fc-cache failed with exit status {error.returncode}."
                ) from error
        else:
            print("Note: fc-cache was not found; restart your session to refresh fonts.")

    print(f"Fonts installed for the current user in: {destination}")
    print("Restart Emacs to use the newly installed fonts.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError) as error:
        raise SystemExit(f"Font installation failed: {error}") from error
