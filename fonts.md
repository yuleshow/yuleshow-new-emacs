# Fonts used by the Emacs configuration

The font choices are defined in [`init.el`](./init.el), with additional uses in
[`yuleshow-nov.el`](./yuleshow-nov.el) and
[`yuleshow-org.el`](./yuleshow-org.el). The bundled files are in
[`emacs-fonts/`](./emacs-fonts/), organized into
[`English`](./emacs-fonts/english/) and
[`Chinese`](./emacs-fonts/chinese/) folders.

## Emacs font-selection shortcuts

The shortcuts change the font for the current buffer. In Emacs key notation,
`C-` means hold **Ctrl** and `M-` means hold **Meta** (usually **Alt**; on
macOS, Meta is mapped to **Command** in this configuration).

### Chinese / CJK font

| Shortcut | Font |
|---|---|
| `C-1` | MingLiU |
| `C-2` | Noto Serif TC |
| `C-3` | Noto Sans TC |
| `C-4` | TW-Sung |
| `C-5` | TW-Kai |
| `C-6` | Huiwen-mincho |
| `C-7` | SentyWen |
| `C-8` | WenQuanYi Bitmap Song 16px |

### English font

| Shortcut | Font |
|---|---|
| `M-1` | EB Garamond |
| `M-2` | Source Code Pro |
| `M-3` | Times New Roman |
| `M-4` | Georgia |
| `M-5` | Fira Code |
| `M-6` | Courier New |
| `M-0` | Menlo |
| `M-9` | Monaco |

Programming buffers use Hack Nerd Font. To select a font by name instead, run
`M-x yuleshow-set-chinese-font` or `M-x yuleshow-set-english-font`.

## Bundled fonts

`install-fonts.py` installs all the fonts below for the current user. Times New
Roman and Georgia include regular, bold, italic, and bold-italic faces. Variable
fonts provide multiple weights in one file.

### English fonts

| Font | Bundled files |
|---|---|
| Courier New | `Courier New.ttf` (regular) |
| EB Garamond | `EBGaramond-VariableFont_wght.ttf` (variable weights) |
| Fira Code | `FiraCode-VariableFont_wght.ttf` (variable weights) |
| Georgia | `Georgia.ttf`, `Georgia Bold.ttf`, `Georgia Italic.ttf`, `Georgia Bold Italic.ttf` |
| Hack Nerd Font | `HackNerdFont-Regular.ttf` |
| Menlo | `Menlo.ttc` (regular, bold, italic, bold italic) |
| Monaco | `Monaco.ttf` (regular) |
| Source Code Pro | `SourceCodePro-VariableFont_wght.ttf` (variable weights) |
| Times New Roman | `Times New Roman.ttf`, `Times New Roman Bold.ttf`, `Times New Roman Italic.ttf`, `Times New Roman Bold Italic.ttf` |

### Chinese / CJK fonts

| Font | Bundled file |
|---|---|
| Huiwen-mincho | `匯文明朝體.otf` |
| MingLiU | `mingliu.ttc` |
| Noto Sans TC | `NotoSansTC-VariableFont_wght.ttf` (variable weights) |
| Noto Serif TC | `NotoSerifTC-VariableFont_wght.ttf` (variable weights) |
| SentyWen | `漢儀新蒂文徵明體.ttf` |
| TW-Kai | `TW-Kai-98_1.ttf` |
| TW-Sung | `TW-Sung-98_1.ttf` |
| WenQuanYi Bitmap Song 16px | `WenQuanYi Bitmap Song 16px.ttf` |

Run the installer with Python 3:

- **macOS / Linux:** `python3 install-fonts.py`
- **Windows:** `py -3 install-fonts.py`

The installer copies the bundled font files to the current user's font
directory. If run as a standalone download without the `emacs-fonts/` folder,
it downloads the font files from this repository. On Windows it registers them
for the current user; on Linux it refreshes the font cache when `fc-cache` is
available. Restart Emacs after installation.
