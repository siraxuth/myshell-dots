pragma ComponentBehavior: Bound

import ".."
import "../components"
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services

ColumnLayout {
    id: root

    required property Session session

    spacing: Tokens.spacing.normal

    SettingsHeader {
        icon: "apps"
        title: qsTr("Launcher Settings")
    }

    SectionHeader {
        Layout.topMargin: Tokens.spacing.large
        title: qsTr("General")
        description: qsTr("General launcher settings")
    }

    SectionContainer {
        ToggleRow {
            label: qsTr("Enabled")
            checked: Config.launcher.enabled
            toggle.onToggled: {
                GlobalConfig.launcher.enabled = checked;
            }
        }

        ToggleRow {
            label: qsTr("Show on hover")
            checked: Config.launcher.showOnHover
            toggle.onToggled: {
                GlobalConfig.launcher.showOnHover = checked;
            }
        }

        SplitButtonRow {
            label: qsTr("Position")
            active: LauncherPrefs.position === "center" ? centerItem : (LauncherPrefs.position === "top" ? topItem : bottomItem)
            menuItems: [
                MenuItem {
                    id: topItem

                    text: qsTr("Top")
                    icon: "vertical_align_top"
                    onClicked: LauncherPrefs.setPosition("top")
                },
                MenuItem {
                    id: bottomItem

                    text: qsTr("Bottom")
                    icon: "vertical_align_bottom"
                    onClicked: LauncherPrefs.setPosition("bottom")
                },
                MenuItem {
                    id: centerItem

                    text: qsTr("Center")
                    icon: "filter_center_focus"
                    onClicked: LauncherPrefs.setPosition("center")
                }
            ]
        }

        SplitButtonRow {
            label: qsTr("Search position")
            active: LauncherPrefs.searchPosition === "top" ? searchTopItem : searchBottomItem
            menuItems: [
                MenuItem {
                    id: searchTopItem

                    text: qsTr("Top")
                    icon: "vertical_align_top"
                    onClicked: LauncherPrefs.setSearchPosition("top")
                },
                MenuItem {
                    id: searchBottomItem

                    text: qsTr("Bottom")
                    icon: "vertical_align_bottom"
                    onClicked: LauncherPrefs.setSearchPosition("bottom")
                }
            ]
        }

        ToggleRow {
            label: qsTr("Vim keybinds")
            checked: GlobalConfig.launcher.vimKeybinds
            toggle.onToggled: {
                GlobalConfig.launcher.vimKeybinds = checked;
            }
        }

        ToggleRow {
            label: qsTr("Enable dangerous actions")
            checked: GlobalConfig.launcher.enableDangerousActions
            toggle.onToggled: {
                GlobalConfig.launcher.enableDangerousActions = checked;
            }
        }
    }

    SectionHeader {
        Layout.topMargin: Tokens.spacing.large
        title: qsTr("Display")
        description: qsTr("Display and appearance settings")
    }

    SectionContainer {
        contentSpacing: Tokens.spacing.small / 2

        PropertyRow {
            label: qsTr("Max shown items")
            value: qsTr("%1").arg(Config.launcher.maxShown)
        }

        PropertyRow {
            showTopMargin: true
            label: qsTr("Max wallpapers")
            value: qsTr("%1").arg(Config.launcher.maxWallpapers)
        }

        PropertyRow {
            showTopMargin: true
            label: qsTr("Drag threshold")
            value: qsTr("%1 px").arg(Config.launcher.dragThreshold)
        }
    }

    SectionHeader {
        Layout.topMargin: Tokens.spacing.large
        title: qsTr("Prefixes")
        description: qsTr("Command prefix settings")
    }

    SectionContainer {
        contentSpacing: Tokens.spacing.small / 2

        PropertyRow {
            label: qsTr("Special prefix")
            value: GlobalConfig.launcher.specialPrefix || qsTr("None")
        }

        PropertyRow {
            showTopMargin: true
            label: qsTr("Action prefix")
            value: GlobalConfig.launcher.actionPrefix || qsTr("None")
        }
    }

    SectionHeader {
        Layout.topMargin: Tokens.spacing.large
        title: qsTr("Fuzzy search")
        description: qsTr("Fuzzy search settings")
    }

    SectionContainer {
        ToggleRow {
            label: qsTr("Apps")
            checked: GlobalConfig.launcher.useFuzzy.apps
            toggle.onToggled: {
                GlobalConfig.launcher.useFuzzy.apps = checked;
            }
        }

        ToggleRow {
            label: qsTr("Actions")
            checked: GlobalConfig.launcher.useFuzzy.actions
            toggle.onToggled: {
                GlobalConfig.launcher.useFuzzy.actions = checked;
            }
        }

        ToggleRow {
            label: qsTr("Schemes")
            checked: GlobalConfig.launcher.useFuzzy.schemes
            toggle.onToggled: {
                GlobalConfig.launcher.useFuzzy.schemes = checked;
            }
        }

        ToggleRow {
            label: qsTr("Variants")
            checked: GlobalConfig.launcher.useFuzzy.variants
            toggle.onToggled: {
                GlobalConfig.launcher.useFuzzy.variants = checked;
            }
        }

        ToggleRow {
            label: qsTr("Wallpapers")
            checked: GlobalConfig.launcher.useFuzzy.wallpapers
            toggle.onToggled: {
                GlobalConfig.launcher.useFuzzy.wallpapers = checked;
            }
        }
    }

    SectionHeader {
        Layout.topMargin: Tokens.spacing.large
        title: qsTr("Sizes")
        description: qsTr("Size settings for launcher items")
    }

    SectionContainer {
        contentSpacing: Tokens.spacing.small / 2

        PropertyRow {
            label: qsTr("Item width")
            value: qsTr("%1 px").arg(Tokens.sizes.launcher.itemWidth)
        }

        PropertyRow {
            showTopMargin: true
            label: qsTr("Item height")
            value: qsTr("%1 px").arg(Tokens.sizes.launcher.itemHeight)
        }

        PropertyRow {
            showTopMargin: true
            label: qsTr("Wallpaper width")
            value: qsTr("%1 px").arg(Tokens.sizes.launcher.wallpaperWidth)
        }

        PropertyRow {
            showTopMargin: true
            label: qsTr("Wallpaper height")
            value: qsTr("%1 px").arg(Tokens.sizes.launcher.wallpaperHeight)
        }
    }

    SectionHeader {
        Layout.topMargin: Tokens.spacing.large
        title: qsTr("Hidden apps")
        description: qsTr("Applications hidden from launcher")
    }

    SectionContainer {
        contentSpacing: Tokens.spacing.small / 2

        PropertyRow {
            label: qsTr("Total hidden")
            value: qsTr("%1").arg(GlobalConfig.launcher.hiddenApps ? GlobalConfig.launcher.hiddenApps.length : 0)
        }
    }
}
