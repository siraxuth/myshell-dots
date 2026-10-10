pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property ShellScreen screen
    property var selectedIds: []
    property var widgetLayout: WidgetsPrefs.layoutFor(screen?.name ?? "")
    property bool gridSnap: false
    property bool aspectLock: false
    // Logical desktop coordinates, independent of the embedding pane and scale.
    property real desktopX: 0
    property real desktopY: 0
    property real viewScale: 1
    property real guideX: -1
    property real guideY: -1
    signal activated

    function nudge(dx: real, dy: real): void {
        const hosts = [];
        for (let i = 0; i < widgetRepeater.count; i++) {
            const host = widgetRepeater.itemAt(i);
            if (host && isSelected(host.modelData.wId))
                hosts.push(host);
        }
        if (!hosts.length)
            return;
        const moveX = clamp(dx, Math.max(...hosts.map(h => -h.x)), Math.max(0, Math.min(...hosts.map(h => width - h.width - h.x))));
        const moveY = clamp(dy, Math.max(...hosts.map(h => -h.y)), Math.max(0, Math.min(...hosts.map(h => height - h.height - h.y))));
        geometryCommitted(hosts.map(h => ({
                    id: String(h.modelData.wId),
                    x: h.x + moveX + desktopX,
                    y: h.y + moveY + desktopY,
                    width: h.width,
                    height: h.height
                })));
    }

    MouseArea {
        anchors.fill: parent
        onPressed: {
            root.activated();
            root.selectedIds = [];
            root.selectionChanged([], "");
        }
    }
    Rectangle {
        x: root.guideX
        width: 1 / root.viewScale
        height: parent.height
        visible: root.guideX >= 0
        color: Colours.palette.m3primary
        z: 2
    }
    Rectangle {
        y: root.guideY
        height: 1 / root.viewScale
        width: parent.width
        visible: root.guideY >= 0
        color: Colours.palette.m3primary
        z: 2
    }
    readonly property int gridSize: 20

    signal selectionChanged(var ids, string activeId)
    signal geometryCommitted(var geometry)

    clip: true

    function isSelected(id: string): bool {
        return selectedIds.includes(String(id));
    }

    function clamp(value: real, low: real, high: real): real {
        return Math.max(low, Math.min(value, high));
    }

    function snap(value: real): real {
        return gridSnap ? Math.round(value / gridSize) * gridSize : value;
    }

    function clampX(value: real, itemWidth: real): real {
        return clamp(value, 0, Math.max(0, width - itemWidth));
    }

    function clampY(value: real, itemHeight: real): real {
        return clamp(value, 0, Math.max(0, height - itemHeight));
    }

    function select(id: string, additive: bool): void {
        const key = String(id);
        let ids = additive ? selectedIds.slice() : [];
        const currentIndex = ids.indexOf(key);
        if (additive && currentIndex >= 0)
            ids.splice(currentIndex, 1);
        else
            ids.push(key);
        selectedIds = ids;
        selectionChanged(ids, ids.length ? ids[ids.length - 1] : "");
    }

    function selectAll(): void {
        const ids = root.widgetLayout.map(item => String(item.wId));
        selectedIds = ids;
        selectionChanged(ids, ids.length ? ids[ids.length - 1] : "");
    }

    function commitHosts(hosts: var): void {
        geometryCommitted(hosts.map(host => ({
                    id: String(host.modelData.wId),
                    x: host.x + root.desktopX,
                    y: host.y + root.desktopY,
                    width: host.width,
                    height: host.height
                })));
    }

    function alignPosition(host: Item, x: real, y: real): var {
        let resultX = gridSnap ? snap(x) : x;
        let resultY = gridSnap ? snap(y) : y;
        const threshold = gridSnap ? 0 : 8 / Math.max(0.01, viewScale);
        guideX = -1;
        guideY = -1;
        let bestX = threshold;
        let bestY = threshold;
        const ownX = [resultX, resultX + host.width / 2, resultX + host.width];
        const ownY = [resultY, resultY + host.height / 2, resultY + host.height];
        const centerX = root.width / 2;
        const centerY = root.height / 2;
        if (!gridSnap) {
            const dx = centerX - (resultX + host.width / 2);
            const dy = centerY - (resultY + host.height / 2);
            if (Math.abs(dx) < bestX) {
                bestX = Math.abs(dx);
                resultX += dx;
                guideX = centerX;
            }
            if (Math.abs(dy) < bestY) {
                bestY = Math.abs(dy);
                resultY += dy;
                guideY = centerY;
            }
            for (let i = 0; i < widgetRepeater.count; i++) {
                const other = widgetRepeater.itemAt(i);
                if (!other || other === host)
                    continue;
                const otherX = [other.x, other.x + other.width / 2, other.x + other.width];
                const otherY = [other.y, other.y + other.height / 2, other.y + other.height];
                for (const edge of ownX)
                    for (const target of otherX) {
                        const delta = target - edge;
                        if (Math.abs(delta) < bestX) {
                            bestX = Math.abs(delta);
                            resultX = x + delta;
                            guideX = target;
                        }
                    }
                for (const edge of ownY)
                    for (const target of otherY) {
                        const delta = target - edge;
                        if (Math.abs(delta) < bestY) {
                            bestY = Math.abs(delta);
                            resultY = y + delta;
                            guideY = target;
                        }
                    }
            }
        }
        return {
            x: clampX(resultX, host.width),
            y: clampY(resultY, host.height)
        };
    }

    function arrange(mode: string): void {
        if (mode === "selectAll") {
            selectAll();
            return;
        }
        if (mode === "clearSelection") {
            selectedIds = [];
            selectionChanged([], "");
            return;
        }
        const selected = selectedIds.length ? selectedIds : root.widgetLayout.map(item => String(item.wId));
        const hosts = [];
        for (let i = 0; i < widgetRepeater.count; i++) {
            const host = widgetRepeater.itemAt(i);
            if (host && selected.includes(String(host.modelData.wId)))
                hosts.push(host);
        }
        if (!hosts.length)
            return;
        const gap = Math.min(Tokens.spacing.large, Math.min(width, height) / Math.max(2, hosts.length));
        const area = {
            x: 0,
            y: 0,
            width: Math.max(1, width),
            height: Math.max(1, height)
        };
        const geometry = hosts.map(host => ({
                    id: String(host.modelData.wId),
                    x: host.x,
                    y: host.y,
                    width: host.width,
                    height: host.height
                }));
        if (["grid", "row", "column"].includes(mode)) {
            if (mode === "row" || mode === "column") {
                const isRow = mode === "row";
                const extent = isRow ? area.width : area.height;
                const total = geometry.reduce((sum, item) => sum + (isRow ? item.width : item.height), 0) + gap * (geometry.length - 1);
                const scale = Math.min(1, extent / Math.max(1, total));
                let cursor = (isRow ? area.x : area.y) + (extent - total * scale) / 2;
                for (const item of geometry) {
                    item.width *= scale;
                    item.height *= scale;
                    if (isRow) {
                        item.x = cursor;
                        item.y = area.y + (area.height - item.height) / 2;
                        cursor += item.width + gap * scale;
                    } else {
                        item.x = area.x + (area.width - item.width) / 2;
                        item.y = cursor;
                        cursor += item.height + gap * scale;
                    }
                }
            } else {
                const columns = Math.max(1, Math.ceil(Math.sqrt(geometry.length * area.width / area.height)));
                const rows = Math.ceil(geometry.length / columns);
                const cellWidth = (area.width - gap * (columns - 1)) / columns;
                const cellHeight = (area.height - gap * (rows - 1)) / rows;
                geometry.forEach((item, index) => {
                    const scale = Math.min(1, cellWidth / item.width, cellHeight / item.height);
                    item.width *= scale;
                    item.height *= scale;
                    const column = index % columns;
                    const row = Math.floor(index / columns);
                    item.x = area.x + column * (cellWidth + gap) + (cellWidth - item.width) / 2;
                    item.y = area.y + row * (cellHeight + gap) + (cellHeight - item.height) / 2;
                });
            }
            geometryCommitted(geometry.map(item => ({
                        id: item.id,
                        x: item.x + root.desktopX,
                        y: item.y + root.desktopY,
                        width: item.width,
                        height: item.height
                    })));
            return;
        }
        if (geometry.length < 2)
            return;
        const left = Math.min(...geometry.map(item => item.x));
        const top = Math.min(...geometry.map(item => item.y));
        const right = Math.max(...geometry.map(item => item.x + item.width));
        const bottom = Math.max(...geometry.map(item => item.y + item.height));
        if (mode === "alignLeft")
            geometry.forEach(item => item.x = left);
        else if (mode === "alignCenter")
            geometry.forEach(item => item.x = (left + right - item.width) / 2);
        else if (mode === "alignRight")
            geometry.forEach(item => item.x = right - item.width);
        else if (mode === "alignTop")
            geometry.forEach(item => item.y = top);
        else if (mode === "alignMiddle")
            geometry.forEach(item => item.y = (top + bottom - item.height) / 2);
        else if (mode === "alignBottom")
            geometry.forEach(item => item.y = bottom - item.height);
        else if (mode === "distributeHorizontal") {
            geometry.sort((a, b) => a.x - b.x);
            const spacing = Math.max(0, right - left - geometry.reduce((sum, item) => sum + item.width, 0)) / (geometry.length - 1);
            let cursor = left;
            for (const item of geometry) {
                item.x = cursor;
                cursor += item.width + spacing;
            }
        } else if (mode === "distributeVertical") {
            geometry.sort((a, b) => a.y - b.y);
            const spacing = Math.max(0, bottom - top - geometry.reduce((sum, item) => sum + item.height, 0)) / (geometry.length - 1);
            let cursor = top;
            for (const item of geometry) {
                item.y = cursor;
                cursor += item.height + spacing;
            }
        }
        geometryCommitted(geometry.map(item => ({
                    id: item.id,
                    x: item.x + root.desktopX,
                    y: item.y + root.desktopY,
                    width: item.width,
                    height: item.height
                })));
    }

    Repeater {
        id: widgetRepeater
        model: root.widgetLayout

        Item {
            id: host
            required property var modelData
            required property int index
            readonly property var size: WidgetRegistry.sizeFor(modelData, root.screen.width, root.screen.height)
            readonly property var screenPosition: WidgetRegistry.positionFor(modelData, root.screen.width, root.screen.height)
            property real previewX: screenPosition.x - root.desktopX
            property real previewY: screenPosition.y - root.desktopY
            property real previewWidth: size.width
            property real previewHeight: size.height
            property bool moving: false
            property bool resizing: false

            x: moving ? previewX : screenPosition.x - root.desktopX
            y: moving ? previewY : screenPosition.y - root.desktopY
            width: resizing ? previewWidth : modelData.wProps?.stretchWidth || modelData.wStretchWidth || modelData.stretchWidth ? Math.max(100, root.width - x) : size.width
            height: resizing ? previewHeight : modelData.wProps?.stretchHeight || modelData.wStretchHeight || modelData.stretchHeight ? root.height : size.height
            z: root.isSelected(modelData.wId) ? widgetRepeater.count + index + 3 : index + 3
            opacity: modelData.enabled === false ? 0.35 : 1

            Widget {
                anchors.fill: parent
                widget: host.modelData
                screen: root.screen
                preview: true
                enabled: false
            }

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                visible: root.isSelected(host.modelData.wId) || dragArea.containsMouse
                border.width: (root.isSelected(host.modelData.wId) ? 2 : 1) / root.viewScale
                border.color: root.isSelected(host.modelData.wId) ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3outline, 0.55)
            }

            MouseArea {
                id: dragArea
                anchors.fill: parent
                hoverEnabled: true
                preventStealing: true
                cursorShape: Qt.SizeAllCursor
                acceptedButtons: Qt.LeftButton
                property real pointerX
                property real pointerY
                property var group: []
                property var starts: []
                property bool changed: false

                function finish(): void {
                    if (group.length && changed)
                        root.commitHosts(group);
                    group.forEach(item => item.moving = false);
                    group = [];
                    starts = [];
                    changed = false;
                    root.guideX = -1;
                    root.guideY = -1;
                }

                onPressed: mouse => {
                    root.activated();
                    const id = String(host.modelData.wId);
                    const additive = !!(mouse.modifiers & Qt.ControlModifier);
                    const preserveGroup = !additive && root.selectedIds.length > 1 && root.selectedIds.includes(id);
                    if (!preserveGroup)
                        root.select(id, additive);
                    if (additive && !root.isSelected(id)) {
                        group = [];
                        starts = [];
                        return;
                    }
                    group = preserveGroup ? root.selectedIds.map(selectedId => {
                        for (let i = 0; i < widgetRepeater.count; i++) {
                            const entry = widgetRepeater.itemAt(i);
                            if (entry && String(entry.modelData.wId) === selectedId)
                                return entry;
                        }
                        return null;
                    }).filter(Boolean) : [host];
                    starts = group.map(item => ({
                                x: item.x,
                                y: item.y
                            }));
                    group.forEach((item, index) => {
                        item.previewX = starts[index].x;
                        item.previewY = starts[index].y;
                        item.moving = true;
                    });
                    const point = mapToItem(root, mouse.x, mouse.y);
                    pointerX = point.x;
                    pointerY = point.y;
                    changed = false;
                }

                onPositionChanged: mouse => {
                    if (!pressed)
                        return;
                    const point = mapToItem(root, mouse.x, mouse.y);
                    const dx = point.x - pointerX;
                    const dy = point.y - pointerY;
                    if (Math.abs(dx) > 0.5 || Math.abs(dy) > 0.5)
                        changed = true;
                    if (group.length > 1) {
                        let moveX = root.gridSnap ? root.snap(starts[0].x + dx) - starts[0].x : dx;
                        let moveY = root.gridSnap ? root.snap(starts[0].y + dy) - starts[0].y : dy;
                        const minX = Math.max(...starts.map(start => -start.x));
                        const maxX = Math.min(...starts.map((start, i) => root.width - group[i].width - start.x));
                        const minY = Math.max(...starts.map(start => -start.y));
                        const maxY = Math.min(...starts.map((start, i) => root.height - group[i].height - start.y));
                        moveX = root.clamp(moveX, minX, Math.max(minX, maxX));
                        moveY = root.clamp(moveY, minY, Math.max(minY, maxY));
                        group.forEach((item, index) => {
                            item.previewX = starts[index].x + moveX;
                            item.previewY = starts[index].y + moveY;
                        });
                    } else {
                        const aligned = root.alignPosition(host, starts[0].x + dx, starts[0].y + dy);
                        host.previewX = aligned.x;
                        host.previewY = aligned.y;
                    }
                }
                onReleased: finish()
                onCanceled: {
                    group.forEach(item => item.moving = false);
                    group = [];
                    starts = [];
                    root.guideX = -1;
                    root.guideY = -1;
                }
            }

            Repeater {
                model: root.isSelected(host.modelData.wId) ? 8 : 0
                Rectangle {
                    id: handle
                    required property int index
                    readonly property bool onLeft: [0, 6, 7].includes(index)
                    readonly property bool onRight: [2, 3, 4].includes(index)
                    readonly property bool onTop: [0, 1, 2].includes(index)
                    readonly property bool onBottom: [4, 5, 6].includes(index)
                    readonly property real handleSize: 9 / Math.max(0.01, root.viewScale)
                    x: onLeft ? -handleSize / 2 : onRight ? host.width - handleSize / 2 : (host.width - handleSize) / 2
                    y: onTop ? -handleSize / 2 : onBottom ? host.height - handleSize / 2 : (host.height - handleSize) / 2
                    width: handleSize
                    height: handleSize
                    radius: 3
                    color: Colours.palette.m3primary
                    z: 3

                    MouseArea {
                        anchors.fill: parent
                        preventStealing: true
                        cursorShape: handle.onLeft && handle.onTop || handle.onRight && handle.onBottom ? Qt.SizeFDiagCursor : handle.onRight && handle.onTop || handle.onLeft && handle.onBottom ? Qt.SizeBDiagCursor : handle.onLeft || handle.onRight ? Qt.SizeHorCursor : Qt.SizeVerCursor
                        property real pointerX
                        property real pointerY
                        property real startX
                        property real startY
                        property real startWidth
                        property real startHeight

                        onPressed: mouse => {
                            root.select(host.modelData.wId, false);
                            const point = mapToItem(root, mouse.x, mouse.y);
                            pointerX = point.x;
                            pointerY = point.y;
                            startX = host.x;
                            startY = host.y;
                            startWidth = host.width;
                            startHeight = host.height;
                            host.previewX = startX;
                            host.previewY = startY;
                            host.previewWidth = startWidth;
                            host.previewHeight = startHeight;
                            host.resizing = true;
                            host.moving = true;
                        }
                        onPositionChanged: mouse => {
                            if (!pressed)
                                return;
                            const point = mapToItem(root, mouse.x, mouse.y);
                            const dx = point.x - pointerX;
                            const dy = point.y - pointerY;
                            let w = startWidth + (handle.onRight ? dx : handle.onLeft ? -dx : 0);
                            let h = startHeight + (handle.onBottom ? dy : handle.onTop ? -dy : 0);
                            if (root.aspectLock || ["round", "analog", "materialAnalog", "lumen"].includes(host.modelData.wVariant)) {
                                const aspect = startWidth / Math.max(1, startHeight);
                                if (Math.abs(dx) >= Math.abs(dy))
                                    h = w / aspect;
                                else
                                    w = h * aspect;
                            }
                            const constrained = WidgetRegistry.constrainSize(host.modelData.wType, host.modelData.wVariant, w, h, false);
                            w = root.gridSnap ? root.snap(constrained.w) : constrained.w;
                            h = root.gridSnap ? root.snap(constrained.h) : constrained.h;
                            const finalSize = WidgetRegistry.constrainSize(host.modelData.wType, host.modelData.wVariant, w, h, false);
                            const fit = Math.min(1, root.width / finalSize.w, root.height / finalSize.h);
                            w = Math.max(1, Math.round(finalSize.w * fit));
                            h = Math.max(1, Math.round(finalSize.h * fit));
                            host.previewWidth = w;
                            host.previewHeight = h;
                            host.previewX = root.clampX(handle.onLeft ? startX + startWidth - w : startX, w);
                            host.previewY = root.clampY(handle.onTop ? startY + startHeight - h : startY, h);
                        }
                        onReleased: {
                            root.commitHosts([host]);
                            host.resizing = false;
                            host.moving = false;
                        }
                        onCanceled: {
                            host.resizing = false;
                            host.moving = false;
                        }
                    }
                }
            }
        }
    }
}
