pragma Singleton
import QtQuick
import qs.services

QtObject {
    function layout(name: string, screen: var): var {
        if (!screen)
            return [];
        const safe = WidgetRegistry.safeArea(screen.width, screen.height, false, false);
        const pad = 32, gap = 20;
        const groups = {
            Calm: [["time", "minimal", 64, 54, 370, 130], ["weather", "compact", 1040, 54, 300, 150], ["calendar", "month", 1040, 224, 300, 350]],
            Studio: [["time", "minimal", 64, 54, 370, 130], ["note", "default", 64, 204, 300, 220], ["music", "full", 720, 340, 620, 240], ["visualizer", "bars", 720, 600, 620, 140]],
            Monitor: [["time", "minimal", 64, 54, 370, 130], ["cpu", "default", 900, 64, 210, 150], ["ram", "default", 1130, 64, 210, 150], ["temp", "default", 900, 234, 210, 150], ["disk", "default", 1130, 234, 210, 150], ["battery", "default", 900, 404, 440, 100]]
        };
        const rows = groups[name] ?? groups.Calm;
        const extentW = Math.max(...rows.map(r => r[2] + r[4]));
        const extentH = Math.max(...rows.map(r => r[3] + r[5]));
        const scale = Math.min(1, (safe.width - pad * 2) / extentW, (safe.height - pad * 2) / extentH);
        const result = rows.map((r, i) => {
            const size = WidgetRegistry.constrainSize(r[0], r[1], r[4] * scale, r[5] * scale, false);
            return {
                wId: `preset_${name}_${i}`,
                wType: r[0],
                wVariant: r[1],
                wX: Math.round(pad + r[2] * scale),
                wY: Math.round(pad + r[3] * scale),
                wWidth: Math.min(size.w, safe.width),
                wHeight: Math.min(size.h, safe.height),
                wOpacity: 1,
                wRotation: 0,
                enabled: true,
                wImagePath: "",
                wProps: {
                    bgRadius: 16,
                    bgOpacity: 0.86,
                    bgBorderWidth: 0,
                    noteText: r[0] === "note" ? qsTr("Write your reminder here.") : undefined
                }
            };
        });
        // Minimum sizes can exceed scaled slots on small displays: reflow then.
        const overlaps = result.some((a, i) => result.some((b, j) => j > i && a.wX < b.wX + b.wWidth + gap && a.wX + a.wWidth + gap > b.wX && a.wY < b.wY + b.wHeight + gap && a.wY + a.wHeight + gap > b.wY));
        if (overlaps) {
            let x = pad, y = pad, rowHeight = 0;
            for (const item of result) {
                if (x + item.wWidth > safe.width - pad) {
                    x = pad;
                    y += rowHeight + gap;
                    rowHeight = 0;
                }
                item.wX = x;
                item.wY = y;
                x += item.wWidth + gap;
                rowHeight = Math.max(rowHeight, item.wHeight);
            }
            const bottom = Math.max(...result.map(w => w.wY + w.wHeight));
            if (bottom > safe.height - pad) {
                const columns = Math.ceil(Math.sqrt(result.length * safe.width / safe.height));
                const rowCount = Math.ceil(result.length / columns);
                const cellW = (safe.width - pad * 2 - gap * (columns - 1)) / columns;
                const cellH = (safe.height - pad * 2 - gap * (rowCount - 1)) / rowCount;
                result.forEach((item, i) => {
                    const fit = Math.min(1, cellW / item.wWidth, cellH / item.wHeight);
                    item.wWidth = Math.max(1, Math.round(item.wWidth * fit));
                    item.wHeight = Math.max(1, Math.round(item.wHeight * fit));
                    item.wX = Math.round(pad + (i % columns) * (cellW + gap));
                    item.wY = Math.round(pad + Math.floor(i / columns) * (cellH + gap));
                });
            }
        }
        result.forEach(w => {
            w.wX = Math.max(0, Math.min(w.wX, safe.width - w.wWidth));
            w.wY = Math.max(0, Math.min(w.wY, safe.height - w.wHeight));
        });
        return result;
    }
}
