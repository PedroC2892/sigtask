# sigtask

Send Unix signals to running apps straight from the taskbar.
Right-click an app, open **Send Signal**, pick a signal:

`SIGTERM`, `SIGKILL`, `SIGINT`, `SIGHUP`, `SIGQUIT`, `SIGSTOP`, `SIGCONT`, `SIGUSR1`, `SIGUSR2`

## Supported desktops

| Desktop | How it works | Status |
|---|---|---|
| KDE Plasma 6 | Copies the system task manager widget to `~/.local/share/plasma/plasmoids/` and patches its context menu. The user copy overrides the system one. | Tested on Plasma 6.3 (X11) |
| GNOME 45+ | Shell extension that adds the submenu to the app menu used by the dash, Dash to Dock and Dash to Panel. | Not yet tested |

## Install

```sh
git clone <repo-url> sigtask
cd sigtask
./install.sh
```

The script picks the right backend from `$XDG_CURRENT_DESKTOP`.
On GNOME, log out and back in if the extension does not show up right away.

## Uninstall

```sh
./install.sh --uninstall
```

## Updating Plasma

The KDE backend works on a copy of the system widget. After a `plasma-desktop`
upgrade, run `./install.sh` again so the copy matches the new version.

## Notes

- Signals are sent with `kill` as your user, so only your own processes are affected.
- `SIGSTOP` freezes the app until it gets `SIGCONT`. Do not stop `plasmashell`,
  `kwin` or `gnome-shell`: if you do, switch to a TTY (Ctrl+Alt+F3) and run
  `kill -CONT <pid>`.
- On GNOME, apps with several processes get the signal sent to all of them.

## License

GPL-2.0-or-later. The KDE backend patches code from KDE's `plasma-desktop`.
