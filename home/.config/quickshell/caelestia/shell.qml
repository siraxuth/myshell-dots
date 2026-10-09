//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import Quickshell
import "modules"
import "modules/areapicker"
import "modules/background"
import "modules/drawers"
import "modules/emoji"
import "modules/lock"
import "modules/widgets"
import qs.services

ShellRoot {
    readonly property var eventsService: Events

    settings.watchFiles: false

    Background {
    }

    WidgetLayoutManager {
    }

    WidgetEditor {
    }

    Drawers {
    }

    EmojiPicker {
    }

    AreaPicker {
    }

    Lock {
        id: lock
    }

    ConfigToasts {
    }

    Shortcuts {
    }

    BatteryMonitor {
    }

    IdleMonitors {
        lock: lock
    }

}
