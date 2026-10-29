// Adds a "Send Signal" submenu to the app context menu (dash, Dash to Dock, Dash to Panel).
import Gio from 'gi://Gio';

import {Extension, InjectionManager} from 'resource:///org/gnome/shell/extensions/extension.js';
import {AppMenu} from 'resource:///org/gnome/shell/ui/appMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';

const SIGNALS = [
    ['TERM', 'Terminate (SIGTERM)'],
    ['KILL', 'Kill (SIGKILL)'],
    ['INT', 'Interrupt (SIGINT)'],
    ['HUP', 'Hang up (SIGHUP)'],
    ['QUIT', 'Quit (SIGQUIT)'],
    ['STOP', 'Stop / Pause (SIGSTOP)'],
    ['CONT', 'Continue (SIGCONT)'],
    ['USR1', 'User 1 (SIGUSR1)'],
    ['USR2', 'User 2 (SIGUSR2)'],
];

function sendSignal(sig, pids) {
    // pids come from Shell.App and are validated as integers > 1; sig comes from SIGNALS
    const safePids = pids.filter(pid => Number.isInteger(pid) && pid > 1).map(String);
    if (safePids.length === 0)
        return;
    try {
        Gio.Subprocess.new(['kill', '-s', sig, '--', ...safePids], Gio.SubprocessFlags.NONE);
    } catch (e) {
        logError(e, `sigtask: failed to send SIG${sig}`);
    }
}

export default class SigtaskExtension extends Extension {
    enable() {
        this._injections = new InjectionManager();
        this._injections.overrideMethod(AppMenu.prototype, 'open', original => function (...args) {
            this._sigtaskItem?.destroy();
            this._sigtaskItem = null;

            const pids = this._app?.get_pids() ?? [];
            if (pids.length > 0) {
                const label = pids.length === 1 ? `Send Signal (PID ${pids[0]})` : `Send Signal (${pids.length} processes)`;
                const item = new PopupMenu.PopupSubMenuMenuItem(label);
                for (const [sig, text] of SIGNALS)
                    item.menu.addAction(text, () => sendSignal(sig, pids));
                this.addMenuItem(item);
                this._sigtaskItem = item;
            }
            return original.call(this, ...args);
        });
    }

    disable() {
        this._injections.clear();
        this._injections = null;
    }
}
