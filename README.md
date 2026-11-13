# RAR Quick Actions for macOS

Right-click a `.rar` in Finder to extract it, or right-click files and folders to compress them to `.rar`.

| Right-click on…          | Menu item                               | Result                                                                   |
| ------------------------ | --------------------------------------- | ------------------------------------------------------------------------ |
| a `.rar` file (or several) | **Quick Actions ▸ Extract RAR**       | Extracted next to the archive                                            |
| any files / folders      | **Quick Actions ▸ Compress to RAR**     | `Name.rar` for one item, `Archive.rar` for several, in the same folder   |

## Install

```bash
git clone https://github.com/GHeart01/mac-rar-quick-actions.git
cd mac-rar-quick-actions
./install.sh
```

The installer does three things:

1. Downloads RARLAB's official command-line `rar` and `unrar` (about 700 KB) for your Mac's CPU from [rarlab.com](https://www.rarlab.com/download.htm). It puts them in `~/Library/Application Support/RarQuickActions/bin`.
2. Copies the helper script `rartool.sh` to the same place.
3. Installs the two Quick Actions into `~/Library/Services`.

You don't need Homebrew, Xcode or admin rights.

If the items don't appear, open **System Settings ▸ General ▸ Login Items & Extensions ▸ Finder** (or **Extensions ▸ Finder**) and tick both. Running `killall Finder` can also help.

### Options

```bash
RAR_VERSION=723 ./install.sh   # choose a specific RARLAB release (default 723 = 7.23)
SKIP_RAR=1 ./install.sh        # don't download rar; extract only, using `brew install unar`
```

## Behaviour

### Extract

- **Where it goes:** files are extracted beside the archive.
  - If the archive holds a single top-level item, that item goes straight into the folder.
  - Otherwise everything goes into a new folder named after the archive.
  - Nothing is overwritten: you get `Name 2`, `Name 3`, and so on instead.
- **Multi-volume sets** (`Game.part1.rar`, `Game.part2.rar`, …) are extracted once, whichever volume or volumes you selected.
- **Password-protected archives** bring up a password dialog, and you're asked again if the password is wrong.
- **Large archives:** a spinning gear shows in the menu bar while it works, and a notification appears when it's done.

### Compress

- **Format:** RAR5 at normal compression. Symlinks are stored as links, and `.DS_Store` and `._*` files are left out.

### Errors and uninstalling

- **Errors** pop up as an alert. Details are written to `~/Library/Logs/RarQuickActions.log`.
- **Uninstall:** `./uninstall.sh`

## About RAR licensing

The RAR format and the `rar` tool belong to RARLAB (Alexander Roshal).

- **Not bundled:** this repo doesn't include them. The installer downloads them from RARLAB's own site.
- **Compressing:** `rar` is shareware with a 40-day trial. After that it keeps working but asks you to buy a licence. To register, put your `rarreg.key` in `~/Library/Application Support/RarQuickActions/bin/`.
- **Extracting:** `unrar` is free.

RARLAB's licence is saved next to the binaries as `license.txt`.

## How it works

```
workflows/Extract RAR.workflow      ┐  Automator Quick Actions (Finder Services).
workflows/Compress to RAR.workflow  ┘  Each runs: rartool.sh extract|compress "$@"
scripts/rartool.sh                     Does the work: calls rar/unrar, shows dialogs and notifications
tools/build_workflows.py               Regenerates the .workflow bundles
install.sh / uninstall.sh
```

The Quick Actions only accept Finder items. **Extract RAR** is limited to the `com.rarlab.rar-archive` file type, so it only shows up when you right-click a `.rar` file.

## License

MIT for the scripts in this repository. See [LICENSE](LICENSE). RAR and UnRAR are covered by RARLAB's own licence.
