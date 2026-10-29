# sigtask — Progress

Last updated: 2026-10-29

## Goal

Right-click an app in the taskbar, choose **Send Signal**, and pick a Unix signal
(TERM, KILL, INT, HUP, QUIT, STOP, CONT, USR1, USR2). Installable on several
desktop environments.

## Branches

| Branch | State |
|---|---|
| `main` | First working version (`5ec8d2e`) |
| `hardening` | Security and interoperability fixes (`101709a`). Waiting for a manual test before merging into `main` |

## Done

### KDE Plasma 6 (`kde/patch_contextmenu.py`)
- [x] Patches a user copy of the system task manager `ContextMenu.qml`
- [x] Idempotent; refuses unknown file layouts (Plasma 5, future changes)
- [x] Atomic write (temp file + rename)
- [x] Fixed: empty submenu caused by `ReferenceError: signalMenu is not defined`

### GNOME 45+ (`gnome/sigtask@pedroafonsocruz.github.io/`)
- [x] Extension injects a submenu into `AppMenu` (dash, Dash to Dock, Dash to Panel)
- [x] Submenu built once per menu; PIDs re-read at click time
- [x] `disable()` removes the items it added

### Installer (`install.sh`)
- [x] Picks the backend from `XDG_CURRENT_DESKTOP` (colon-separated list)
- [x] Finds the Plasma widget through `XDG_DATA_DIRS`
- [x] Never overwrites a task manager override it did not create
- [x] Patches in a staging directory; failure leaves nothing behind
- [x] Restarts plasmashell through systemd, or `kquitapp6` + `kstart` as fallback
- [x] `--uninstall`

### Security review
- [x] No command injection: signal from a fixed list, PID checked as an integer > 1
- [x] Signals sent as the current user only; no privilege escalation
- [x] Known limits documented in the README (X11 `_NET_WM_PID` can be set by the app; Flatpak PID is `bwrap`)

### Tests
- [x] `tests/test_patch.py` passes against the installed Plasma 6.3.6
- [x] `install.sh` checked in a sandboxed `XDG_DATA_HOME`: reinstall, uninstall, foreign override refused, failed patch cleanup, `ubuntu:GNOME`, unsupported desktop

## Pending

- [ ] Manual test of the `hardening` branch on KDE (right-click, then **Send Signal**)
- [ ] Merge `hardening` into `main`
- [ ] Test the GNOME extension on a real GNOME session (only syntax-checked so far)
- [ ] Optional: confirmation dialog before `SIGKILL`
- [ ] Optional: support for XFCE, Cinnamon, MATE
- [ ] Optional: publish to GitHub and extensions.gnome.org

## Notes

- After a `plasma-desktop` upgrade, run `./install.sh` again so the patched copy matches the new version.
- Never send `SIGSTOP` to `plasmashell`, `kwin` or `gnome-shell`. To recover, open a TTY (Ctrl+Alt+F3) and run `kill -CONT <pid>`.
