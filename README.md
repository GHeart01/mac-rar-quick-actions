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

The installer does four things:

1. Downloads RARLAB's official command-line `rar` and `unrar` (about 700 KB) for your Mac's CPU from [rarlab.com](https://www.rarlab.com/download.htm). It puts them in `~/Library/Application Support/RarQuickActions/bin`.
2. Copies the helper scripts to the same place, and a small Automator action to `~/Library/Automator`.
3. Installs the two Quick Actions into `~/Library/Services`.
4. Turns on automatic updates (see below).

You don't need Homebrew, Xcode or admin rights.

### Progress in the menu bar (one-time setting)

While a job runs, the ⚙️ gear in the menu bar shows its real percentage ("45% completed"), and its **✕** cancels it. For that, macOS has to be allowed to run the small Automator action this tool installs:

1. Open **Automator** (in Applications).
2. In the menu bar at the top of the screen, choose **Automator ▸ Third Party Automator Actions…** and allow them.
3. Run `./install.sh` again.

If you skip this, everything still works, but the gear stays at "0% completed" until the job is done. The installer checks the setting and tells you which mode you got.

If the items don't appear, open **System Settings ▸ General ▸ Login Items & Extensions ▸ Finder** (or **Extensions ▸ Finder**) and tick both. Running `killall Finder` can also help.

### Options

```bash
AUTO_UPDATE=0 ./install.sh    # no automatic updates
RAR_VERSION=723 ./install.sh   # choose a specific RARLAB release (default 723 = 7.23)
SKIP_RAR=1 ./install.sh        # don't download rar; extract only, using `brew install unar`
```

## Automatic updates

The installer adds a LaunchAgent that checks this repo's [latest GitHub release](https://github.com/GHeart01/mac-rar-quick-actions/releases/latest) at login and once a day. When there's a newer version, it downloads that release and installs it quietly, then shows an "Updated to version X" notification.

- **Releases only:** it only installs tagged releases (`vX.Y.Z`), never work-in-progress commits.
- **Kept as is:** your `rar` download stays put unless a release moves to a newer RARLAB version.
- **Update now:** `~/Library/Application\ Support/RarQuickActions/update.sh --verbose`
- **Turn off:** run `AUTO_UPDATE=0 ./install.sh`, or `./uninstall.sh` to remove everything.
- **Log:** checks and updates are logged in `~/Library/Logs/RarQuickActions.log`.

## Behaviour

### Extract

- **Where it goes:** files are extracted beside the archive.
  - If the archive holds a single top-level item, that item goes straight into the folder.
  - Otherwise everything goes into a new folder named after the archive.
  - Nothing is overwritten: you get `Name 2`, `Name 3`, and so on instead.
- **Multi-volume sets** (`Game.part1.rar`, `Game.part2.rar`, …) are extracted once, whichever volume or volumes you selected.
- **Password-protected archives** bring up a password dialog, and you're asked again if the password is wrong.
- **Progress:** the ⚙️ gear shows the overall percentage (across all selected archives). Its **✕** cancels and removes the half-extracted files. A notification appears when it's done.

### Compress

- **Format:** RAR5 at normal compression. Symlinks are stored as links, and `.DS_Store` and `._*` files are left out.
- **Progress:** the ⚙️ gear shows the percentage. Cancelling with its **✕** deletes the unfinished `.rar`.

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
workflows/*.workflow          Quick Actions using the RarQuickActions action (live % in the gear)
workflows-basic/*.workflow    Same, using Apple's Run Shell Script (when third-party actions are off)
action/RarQuickAction.m       The Automator action: runs rartool.sh, passes its % to the gear,
                              and sends it SIGTERM when you click ✕ (action/build.sh rebuilds it)
scripts/rartool.sh            Does the work: calls rar/unrar, dialogs, notifications, cleanup on cancel
scripts/update.sh             Installs newer GitHub releases (run by the LaunchAgent)
tools/build_workflows.py      Regenerates the .workflow bundles
install.sh / uninstall.sh
```

The compiled action is committed (universal, ad-hoc signed) so installing doesn't need Xcode.

The Quick Actions only accept Finder items. **Extract RAR** is limited to the `com.rarlab.rar-archive` file type, so it only shows up when you right-click a `.rar` file.

## License

MIT for the scripts in this repository. See [LICENSE](LICENSE). RAR and UnRAR are covered by RARLAB's own licence.
