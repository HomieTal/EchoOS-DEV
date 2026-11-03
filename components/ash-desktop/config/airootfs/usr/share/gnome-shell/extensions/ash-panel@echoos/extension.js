/*
 * Ash Panel — Echo OS top panel background.
 *
 * The pinned-top-panel behaviour itself is stock GNOME Shell: the panel
 * never auto-hides, reserves struts so maximized windows stop below it,
 * and stays in place across workspace switches and screen lock. This
 * extension only restyles the panel background (see stylesheet.css, which
 * GNOME Shell loads and unloads together with the extension) and toggles
 * the "maximized" emphasis class when a maximized window has focus.
 *
 * The stylesheet is scoped to #panel.ash-panel, so removing the class
 * (or disabling the extension) restores the stock theme exactly.
 */
import GLib from 'gi://GLib';
import Meta from 'gi://Meta';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

const PANEL_CLASS = 'ash-panel';
const MAXIMIZED_CLASS = 'ash-panel-maximized';

export default class AshPanelExtension {
    enable() {
        Main.panel.add_style_class_name(PANEL_CLASS);

        this._overviewChangedId = Main.overview.connect('showing',
            () => this._update());
        this._overviewHiddenId = Main.overview.connect('hidden',
            () => this._update());
        // Maximized windows sit directly under the panel; a slightly
        // higher background alpha keeps the panel readable there.
        this._focusChangedId = global.display.connect('notify::focus-window',
            () => this._update());
        // Maximizing in place does not change the focus window, so also
        // watch window geometry changes.
        this._sizeChangedId = global.window_manager.connect('size-change',
            () => this._scheduleUpdate());

        this._update();
    }

    disable() {
        if (this._overviewChangedId) {
            Main.overview.disconnect(this._overviewChangedId);
            this._overviewChangedId = 0;
        }
        if (this._overviewHiddenId) {
            Main.overview.disconnect(this._overviewHiddenId);
            this._overviewHiddenId = 0;
        }
        if (this._focusChangedId) {
            global.display.disconnect(this._focusChangedId);
            this._focusChangedId = 0;
        }
        if (this._sizeChangedId) {
            global.window_manager.disconnect(this._sizeChangedId);
            this._sizeChangedId = 0;
        }
        if (this._idleId) {
            GLib.source_remove(this._idleId);
            this._idleId = 0;
        }
        Main.panel.remove_style_class_name(MAXIMIZED_CLASS);
        Main.panel.remove_style_class_name(PANEL_CLASS);
    }

    _scheduleUpdate() {
        // Defer one idle cycle so the window's maximize flags are settled.
        if (this._idleId)
            return;
        this._idleId = GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
            this._idleId = 0;
            this._update();
            return GLib.SOURCE_REMOVE;
        });
    }

    _update() {
        // Overview keeps the normal 70% look; the stronger alpha only
        // applies when a maximized window is focused on the desktop.
        const emphasize = !Main.overview.visible && this._focusWindowMaximized();
        if (emphasize) {
            Main.panel.add_style_class_name(MAXIMIZED_CLASS);
        } else {
            Main.panel.remove_style_class_name(MAXIMIZED_CLASS);
        }
    }

    _focusWindowMaximized() {
        const focus = global.display.focus_window;
        if (!focus)
            return false;
        try {
            // Meta.Window exposes maximize state as boolean GObject
            // properties (stable across shell versions). The flag-based
            // accessors were removed in newer shells, so prefer those.
            if (typeof focus.maximized_vertically === 'boolean')
                return focus.maximized_vertically && focus.maximized_horizontally;
            const flags = typeof focus.get_maximized_flags === 'function'
                ? focus.get_maximized_flags()
                : focus.get_maximized();
            const MAXIMIZED = Meta.MaximizeFlags.VERTICAL | Meta.MaximizeFlags.HORIZONTAL;
            return (flags & MAXIMIZED) === MAXIMIZED;
        } catch {
            return false;
        }
    }
}
