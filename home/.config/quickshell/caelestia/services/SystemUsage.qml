pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config

Singleton {
    id: root

    // CPU properties
    property string cpuName: ""
    property real cpuPerc
    property real cpuTemp

    // GPU properties
    readonly property string gpuType: GlobalConfig.services.gpuType.toUpperCase() || autoGpuType
    property string autoGpuType: "NONE"
    property string gpuName: ""
    property real gpuPerc
    property real gpuTemp

    // Memory properties
    property real memUsed
    property real memTotal
    readonly property real memPerc: memTotal > 0 ? memUsed / memTotal : 0

    // Storage properties (aggregated)
    readonly property real storagePerc: {
        let totalUsed = 0;
        let totalSize = 0;
        for (const disk of disks) {
            totalUsed += disk.used;
            totalSize += disk.total;
        }
        return totalSize > 0 ? totalUsed / totalSize : 0;
    }

    // Individual disks: Array of { mount, used, total, free, perc }
    property var disks: []

    property real lastCpuIdle
    property real lastCpuTotal

    property int refCount

    function cleanCpuName(name: string): string {
        return name.replace(/\(R\)|\(TM\)|CPU|\d+(?:th|nd|rd|st) Gen |Core |Processor/gi, "").replace(/\s+/g, " ").trim();
    }

    function cleanGpuName(name: string): string {
        return name.replace(/\(R\)|\(TM\)|Graphics/gi, "").replace(/\s+/g, " ").trim();
    }

    function temperaturesFromSensorBlock(block: string): var {
        const temperatures = [];

        for (const line of block.split("\n")) {
            const match = line.match(/^[^:]+:\s+\+?(-?[0-9]+(?:\.[0-9]+)?)(?:°| )C/);
            if (!match)
                continue;

            const temperature = parseFloat(match[1]);
            // Discard disconnected/broken sensors without hiding legitimate laptop temperatures.
            if (Number.isFinite(temperature) && temperature >= 0 && temperature <= 125)
                temperatures.push(temperature);
        }

        return temperatures;
    }

    function average(values: var): real {
        if (values.length === 0)
            return 0;

        return values.reduce((sum, value) => sum + value, 0) / values.length;
    }

    function cpuTemperatureFromSensors(output: string): real {
        const blocks = output.trim().split(/\n\s*\n/);

        // DAMX averages all readings exposed by the CPU hwmon device instead of
        // showing only the hottest package/control reading.
        for (const block of blocks) {
            const chip = block.split("\n", 1)[0].toLowerCase();
            if (!/(^|[-_])(coretemp|k10temp|zenpower|cpu_thermal|x86_pkg_temp)([-_]|$)/.test(chip))
                continue;

            const temperatures = root.temperaturesFromSensorBlock(block);
            if (temperatures.length > 0)
                return root.average(temperatures);
        }

        // Keep the former behaviour as a fallback for uncommon sensor drivers.
        const fallback = output.match(/(?:Package id [0-9]+|Tdie|Tctl):\s+\+?(-?[0-9]+(?:\.[0-9]+)?)(?:°| )C/);
        return fallback ? parseFloat(fallback[1]) : 0;
    }

    function gpuTemperatureFromSensors(output: string): real {
        const blocks = output.trim().split(/\n\s*\n/);

        for (const block of blocks) {
            const chip = block.split("\n", 1)[0].toLowerCase();
            // Only accept a DRM GPU sensor. The previous PCI-wide parser could
            // accidentally report a Wi-Fi or NVMe temperature as the GPU value.
            if (!/(^|[-_])(amdgpu|radeon|nouveau|i915|xe)([-_]|$)/.test(chip))
                continue;

            const temperatures = root.temperaturesFromSensorBlock(block);
            if (temperatures.length > 0)
                return root.average(temperatures);
        }

        return 0;
    }

    function formatKib(kib: real): var {
        const mib = 1024;
        const gib = 1024 ** 2;
        const tib = 1024 ** 3;

        if (kib >= tib)
            return {
                value: kib / tib,
                unit: "TiB"
            };
        if (kib >= gib)
            return {
                value: kib / gib,
                unit: "GiB"
            };
        if (kib >= mib)
            return {
                value: kib / mib,
                unit: "MiB"
            };
        return {
            value: kib,
            unit: "KiB"
        };
    }

    Timer {
        running: root.refCount > 0
        interval: Math.max(5000, GlobalConfig.dashboard.resourceUpdateInterval)
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
            if (root.gpuType === "GENERIC" || root.gpuType === "NVIDIA")
                gpuUsage.running = true;
        }
    }

    // Sensors and lsblk spawn external processes and change slowly; sample them
    // less often than CPU, memory and GPU counters.
    Timer {
        running: root.refCount > 0
        interval: 30000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            storage.running = true;
            sensors.running = true;
        }
    }

    // One-time CPU info detection (name)
    FileView {
        id: cpuinfoInit

        path: "/proc/cpuinfo"
        onLoaded: {
            const nameMatch = text().match(/model name\s*:\s*(.+)/);
            if (nameMatch)
                root.cpuName = root.cleanCpuName(nameMatch[1]);
        }
    }

    FileView {
        id: stat

        path: "/proc/stat"
        onLoaded: {
            const data = text().match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/);
            if (data) {
                const stats = data.slice(1).map(n => parseInt(n, 10));
                const total = stats.reduce((a, b) => a + b, 0);
                const idle = stats[3] + (stats[4] ?? 0);

                const totalDiff = total - root.lastCpuTotal;
                const idleDiff = idle - root.lastCpuIdle;
                root.cpuPerc = totalDiff > 0 ? (1 - idleDiff / totalDiff) : 0;

                root.lastCpuTotal = total;
                root.lastCpuIdle = idle;
            }
        }
    }

    FileView {
        id: meminfo

        path: "/proc/meminfo"
        onLoaded: {
            const data = text();
            root.memTotal = parseInt(data.match(/MemTotal: *(\d+)/)[1], 10) || 1;
            root.memUsed = (root.memTotal - parseInt(data.match(/MemAvailable: *(\d+)/)[1], 10)) || 0;
        }
    }

    Process {
        id: storage

        // Get physical disks with aggregated usage from their partitions
        // -J triggers JSON output. -b triggers bytes.
        command: ["lsblk", "-J", "-b", "-o", "NAME,SIZE,TYPE,FSUSED,FSSIZE,MOUNTPOINT"]

        stdout: StdioCollector {
            onStreamFinished: {
                const data = JSON.parse(text);
                const diskList = [];
                const seenDevices = new Set();

                // Helper to recursively sum usage from children (partitions, crypt, lvm)
                const aggregateUsage = dev => {
                    let used = 0;
                    let size = 0;
                    let isRoot = dev.mountpoint === "/" || (dev.mountpoints && dev.mountpoints.includes("/"));

                    if (!seenDevices.has(dev.name)) {
                        // lsblk returns null for empty/unformatted partitions, which parses to 0 here
                        used = parseInt(dev.fsused) || 0;
                        size = parseInt(dev.fssize) || 0;
                        seenDevices.add(dev.name);
                    }

                    if (dev.children) {
                        for (const child of dev.children) {
                            const stats = aggregateUsage(child);
                            used += stats.used;
                            size += stats.size;
                            if (stats.isRoot)
                                isRoot = true;
                        }
                    }
                    return {
                        used,
                        size,
                        isRoot
                    };
                };

                for (const dev of data.blockdevices) {
                    // Only process physical disks at the top level
                    if (dev.type === "disk" && !dev.name.startsWith("zram")) {
                        const stats = aggregateUsage(dev);

                        if (stats.size === 0) {
                            continue;
                        }

                        const total = stats.size;
                        const used = stats.used;

                        diskList.push({
                            mount: dev.name,
                            used: used / 1024      // KiB
                            ,
                            total: total / 1024    // KiB
                            ,
                            free: (total - used) / 1024,
                            perc: total > 0 ? used / total : 0,
                            hasRoot: stats.isRoot
                        });
                    }
                }

                // Sort by putting the disk with root first, then sort the rest alphabetically
                root.disks = diskList.sort((a, b) => {
                    if (a.hasRoot && !b.hasRoot)
                        return -1;
                    if (!a.hasRoot && b.hasRoot)
                        return 1;
                    return a.mount.localeCompare(b.mount);
                });
            }
        }
    }

    // GPU name detection (one-time)
    Process {
        id: gpuNameDetect

        running: true
        command: ["sh", "-c", "nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || glxinfo -B 2>/dev/null | grep 'Device:' | cut -d':' -f2 | cut -d'(' -f1 || lspci 2>/dev/null | grep -i 'vga\\|3d controller\\|display' | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const output = text.trim();
                if (!output)
                    return;

                // Check if it's from nvidia-smi (clean GPU name)
                if (output.toLowerCase().includes("nvidia") || output.toLowerCase().includes("geforce") || output.toLowerCase().includes("rtx") || output.toLowerCase().includes("gtx")) {
                    root.gpuName = root.cleanGpuName(output);
                } else if (output.toLowerCase().includes("rx")) {
                    root.gpuName = root.cleanGpuName(output);
                } else {
                    // Parse lspci output: extract name from brackets or after colon
                    // Handles cases like [AMD/ATI] Navi 21 [Radeon RX 6800/6800 XT / 6900 XT] (rev c0)
                    const bracketMatch = output.match(/\[([^\]]+)\][^\[]*$/);
                    if (bracketMatch) {
                        root.gpuName = root.cleanGpuName(bracketMatch[1]);
                    } else {
                        const colonMatch = output.match(/:\s*(.+)/);
                        if (colonMatch)
                            root.gpuName = root.cleanGpuName(colonMatch[1]);
                    }
                }
            }
        }
    }

    Process {
        id: gpuTypeCheck

        running: !GlobalConfig.services.gpuType
        command: ["sh", "-c", "if command -v nvidia-smi &>/dev/null && nvidia-smi -L &>/dev/null; then echo NVIDIA; elif ls /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | grep -q .; then echo GENERIC; else echo NONE; fi"]
        stdout: StdioCollector {
            onStreamFinished: root.autoGpuType = text.trim()
        }
    }

    Process {
        id: gpuUsage

        command: root.gpuType === "GENERIC" ? ["sh", "-c", "cat /sys/class/drm/card*/device/gpu_busy_percent"] : root.gpuType === "NVIDIA" ? ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu", "--format=csv,noheader,nounits"] : ["echo"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.gpuType === "GENERIC") {
                    const percs = text.trim().split("\n").map(value => parseInt(value, 10)).filter(value => Number.isFinite(value));
                    root.gpuPerc = percs.length > 0 ? Math.min(1, Math.max(0, root.average(percs) / 100)) : 0;
                } else if (root.gpuType === "NVIDIA") {
                    const [usage, temp] = text.trim().split(",");
                    const usageValue = parseInt(usage, 10);
                    const temperatureValue = parseInt(temp, 10);
                    root.gpuPerc = Number.isFinite(usageValue) ? Math.min(1, Math.max(0, usageValue / 100)) : 0;
                    root.gpuTemp = Number.isFinite(temperatureValue) ? temperatureValue : 0;
                } else {
                    root.gpuPerc = 0;
                    root.gpuTemp = 0;
                }
            }
        }
    }

    Process {
        id: sensors

        command: ["sensors"]
        environment: ({
                LANG: "C.UTF-8",
                LC_ALL: "C.UTF-8"
            })
        stdout: StdioCollector {
            onStreamFinished: {
                root.cpuTemp = root.cpuTemperatureFromSensors(text);

                if (root.gpuType !== "GENERIC")
                    return;

                root.gpuTemp = root.gpuTemperatureFromSensors(text);
            }
        }
    }
}
