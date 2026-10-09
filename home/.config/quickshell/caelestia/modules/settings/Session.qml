import "./state"
import QtQuick
import qs.modules.settings

QtObject {
    readonly property list<string> panes: PaneRegistry.labels

    required property var root
    property string active: "network"
    property int activeIndex: 0
    property bool navExpanded: true

    readonly property BluetoothState bt: BluetoothState {}
    readonly property NetworkState network: NetworkState {}
    readonly property EthernetState ethernet: EthernetState {}
    readonly property LauncherState launcher: LauncherState {}
    readonly property VpnState vpn: VpnState {}

    onActiveChanged: activeIndex = Math.max(0, panes.indexOf(active))
    onActiveIndexChanged: if (panes[activeIndex])
        active = panes[activeIndex]
}
