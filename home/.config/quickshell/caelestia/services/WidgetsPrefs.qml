pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

// Desktop widgets list, stored in its own JSON (~/.config/caelestia/widgets.json). Kept out of
// shell.json because a JsonObject `list<var>` of objects doesn't round-trip reliably here.
Singleton {
    id: root

    property var widgets: [
        {
            type: "arch",
            enabled: true,
            position: "middle-center",
            scale: 1.0,
            background: false
        },
        {
            type: "clock",
            enabled: true,
            position: "top-center",
            scale: 1.0,
            background: true
        },
        {
            type: "media",
            enabled: true,
            position: "bottom-left",
            scale: 1.0,
            background: true
        },
        {
            type: "weather",
            enabled: false,
            position: "top-right",
            scale: 1.0,
            background: true
        }
    ]

    function persist(): void {
        storage.setText(JSON.stringify(root.widgets, null, 2));
    }

    function mutate(fn: var): void {
        const w = (root.widgets || []).map(x => Object.assign({}, x));
        fn(w);
        root.widgets = w;
        persist();
    }

    function setField(i: int, k: string, v: var): void {
        mutate(w => {
            if (w[i])
                w[i][k] = v;
        });
    }

    function add(): void {
        mutate(w => w.push({
            type: "media",
            enabled: true,
            position: "bottom-right",
            scale: 1.0,
            background: true
        }));
    }

    function remove(i: int): void {
        mutate(w => w.splice(i, 1));
    }

    // dir = -1 (up) or +1 (down): reorder, which also reorders the on-screen stack
    function move(i: int, dir: int): void {
        mutate(w => {
            const j = i + dir;
            if (j < 0 || j >= w.length)
                return;
            const t = w[i];
            w[i] = w[j];
            w[j] = t;
        });
    }

    FileView {
        id: storage

        printErrors: false
        path: `${Paths.config}/widgets.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const d = JSON.parse(text());
                if (Array.isArray(d))
                    root.widgets = d;
            } catch (e) {}
        }
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                Qt.callLater(root.persist);
        }
    }
}
