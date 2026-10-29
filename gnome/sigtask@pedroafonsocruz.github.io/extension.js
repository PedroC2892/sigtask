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
        const menus = this._menus = new Set();
        this._injections.overrideMethod(AppMenu.prototype, 'open', original => function (...args) {
            const pids = this._app?.get_pids() ?? [];
            if (!this._sigtaskItem) {
                // Built once per menu. PIDs are re-read on click instead of cached at open,
                // so an app that exited meanwhile is not signalled through a stale PID.
                this._sigtaskItem = new PopupMenu.PopupSubMenuMenuItem('');
                for (const [sig, text] of SIGNALS)
                    this._sigtaskItem.menu.addAction(text, () => sendSignal(sig, this._app?.get_pids() ?? []));
                this.addMenuItem(this._sigtaskItem);
                menus.add(this);
                this.connect('destroy', () => menus.delete(this));
            }
            this._sigtaskItem.visible = pids.length > 0;
            this._sigtaskItem.label.text = pids.length === 1
                ? `Send Signal (PID ${pids[0]})`
                : `Send Signal (${pids.length} processes)`;
            return original.call(this, ...args);
        });
    }

    disable() {
        this._injections.clear();
        this._injections = null;
        // Menus outlive the extension, so remove the items added to them.
        for (const menu of this._menus) {
            menu._sigtaskItem.destroy();
            delete menu._sigtaskItem;
        }
        this._menus = null;
    }
}
