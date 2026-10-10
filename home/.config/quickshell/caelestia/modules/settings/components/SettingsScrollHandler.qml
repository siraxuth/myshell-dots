import QtQuick

// Deliberately scoped to settings viewports, rather than the shell's base types.
WheelHandler {
    id: root

    required property Flickable flickable
    property real scrollSpeed: 1.8

    parent: flickable
    target: null
    orientation: Qt.Vertical
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    acceptedModifiers: Qt.NoModifier
    enabled: flickable && flickable.visible && flickable.interactive

    onWheel: event => handleWheel(event)

    function handleWheel(event: var): void {
        // A horizontal gesture belongs to its horizontal viewport.
        if (Math.abs(event.pixelDelta.x) > Math.abs(event.pixelDelta.y)
                || (event.pixelDelta.x === 0 && event.pixelDelta.y === 0
                    && Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y))) {
            event.accepted = false;
            return;
        }

        // Let nested controls which explicitly enable wheel editing own it.
        const viewportPoint = flickable.mapFromItem(parent, event.x, event.y);
        let item = flickable.childAt(viewportPoint.x, viewportPoint.y);
        while (item) {
            if ("wheelEnabled" in item && item.wheelEnabled) {
                event.accepted = false;
                return;
            }
            const point = item.mapFromItem(flickable, viewportPoint.x, viewportPoint.y);
            item = item.childAt(point.x, point.y);
        }

        // Never quantize high-resolution wheel events or animate behind the finger.
        // Native momentum events take this same path, without a second inertia tail.
        const delta = event.pixelDelta.y !== 0
            ? event.pixelDelta.y
            : event.angleDelta.y / 120 * 64;
        const minimum = flickable.originY;
        const maximum = minimum + Math.max(0, flickable.contentHeight - flickable.height);
        flickable.cancelFlick();
        flickable.contentY = Math.max(minimum, Math.min(maximum,
            flickable.contentY - delta * scrollSpeed));
        event.accepted = true;
    }
}
