#!/usr/bin/env python3
"""Add a "Send Signal" submenu to the Plasma 6 task manager context menu.

Usage: patch_contextmenu.py <path to ContextMenu.qml>

The file is patched in place. Running it twice is a no-op.
"""
import os
import sys
import tempfile

MARKER = "// sigtask: send signal submenu"

IMPORT_ANCHOR = "import org.kde.plasma.extras as PlasmaExtras\n"
IMPORT_LINE = "import org.kde.plasma.plasma5support as Plasma5Support\n"

# Insert right before the separator that precedes "Configure Task Manager".
BLOCK_ANCHOR = (
    "    PlasmaExtras.MenuItem { separator: true }\n\n"
    "    PlasmaExtras.MenuItem {\n"
    "        property QtObject configureAction: null"
)

BLOCK = '''    ''' + MARKER + '''
    PlasmaExtras.MenuItem {
        id: sendSignalMenuItem

        readonly property int pid: menu.visualParent ? (menu.get(atm.AppPid) || 0) : 0

        visible: menu.visualParent && !menu.get(atm.IsLauncher) && !menu.get(atm.IsStartup) && pid > 1
        enabled: visible

        text: i18n("Send Signal") + (pid > 0 ? " (PID " + pid + ")" : "")
        icon: "system-run"

        readonly property Plasma5Support.DataSource executable: Plasma5Support.DataSource {
            engine: "executable"
            onNewData: (sourceName, data) => disconnectSource(sourceName)
        }

        readonly property PlasmaExtras.Menu signalMenu: PlasmaExtras.Menu {
            id: signalMenu
            visualParent: sendSignalMenuItem.action

            Component.onCompleted: {
                const signals = [
                    ["TERM", "Terminate (SIGTERM)", "process-stop"],
                    ["KILL", "Kill (SIGKILL)", "edit-delete"],
                    ["INT", "Interrupt (SIGINT)", "dialog-cancel"],
                    ["HUP", "Hang up (SIGHUP)", "view-refresh"],
                    ["QUIT", "Quit (SIGQUIT)", "application-exit"],
                    ["STOP", "Stop / Pause (SIGSTOP)", "media-playback-pause"],
                    ["CONT", "Continue (SIGCONT)", "media-playback-start"],
                    ["USR1", "User 1 (SIGUSR1)", "user-identity"],
                    ["USR2", "User 2 (SIGUSR2)", "user-identity"],
                ];
                for (const [sig, label, iconName] of signals) {
                    const item = menu.newMenuItem(signalMenu);
                    item.text = label;
                    item.icon = iconName;
                    item.clicked.connect(() => {
                        // pid is an int from the tasks model, sig comes from the fixed list above
                        const pid = Math.trunc(Number(sendSignalMenuItem.pid));
                        if (pid > 1) {
                            sendSignalMenuItem.executable.connectSource("kill -s " + sig + " -- " + pid);
                        }
                    });
                    signalMenu.addMenuItem(item);
                }
            }
        }
    }

'''


def patch(source: str) -> str:
    if MARKER in source:
        return source
    if IMPORT_ANCHOR not in source or BLOCK_ANCHOR not in source:
        raise SystemExit("ContextMenu.qml layout not recognised; unsupported Plasma version")
    source = source.replace(IMPORT_ANCHOR, IMPORT_ANCHOR + IMPORT_LINE, 1)
    return source.replace(BLOCK_ANCHOR, BLOCK + BLOCK_ANCHOR, 1)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    path = sys.argv[1]
    with open(path, encoding="utf-8") as f:
        original = f.read()
    patched = patch(original)
    assert patch(patched) == patched, "patch must be idempotent"
    # Write to a temp file and rename so a crash never leaves a half-written QML file.
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(os.path.abspath(path)), suffix=".qml")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(patched)
    os.chmod(tmp, 0o644)
    os.replace(tmp, path)
