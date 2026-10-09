pragma ComponentBehavior: Bound

import ".."
import "../components"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    required property Session session

    property var disks: []
    property var categories: []
    property var files: []
    property var selectedPaths: []
    property var selectedCategory: null
    property var selectedApp: null
    property string selectedMount: "/"
    property string appPackage: ""
    property string errorText: ""
    property bool scanning: false
    property bool listingFiles: false
    property bool confirmDelete: false
    property bool confirmCacheClear: false
    property bool confirmUninstall: false

    readonly property var activeDisk: disks.find(disk => disk.mount === selectedMount) ?? disks[0] ?? null
    readonly property real usedRatio: activeDisk?.total > 0 ? Math.min(1, activeDisk.used / activeDisk.total) : 0

    function formatBytes(value: real): string {
        if (!value || value <= 0)
            return "0 B";
        const units = ["B", "KB", "MB", "GB", "TB", "PB"];
        const unit = Math.min(Math.floor(Math.log(value) / Math.log(1024)), units.length - 1);
        return `${(value / Math.pow(1024, unit)).toFixed(unit > 0 ? 1 : 0)} ${units[unit]}`;
    }

    function refresh(): void {
        root.errorText = "";
        diskProcess.exec(["df", "-P", "-B1", "-x", "tmpfs", "-x", "devtmpfs", "-x", "squashfs"]);
    }

    function scanCategories(): void {
        if (!root.activeDisk)
            return;
        root.scanning = true;
        categoryProcess.exec(["python3", "-c", categoryScanner, root.activeDisk.mount]);
    }

    function openCategory(category: var): void {
        root.selectedCategory = category;
        root.files = [];
        root.selectedPaths = [];
        root.confirmDelete = false;
        root.listingFiles = true;
        fileProcess.exec(["python3", "-c", fileScanner, JSON.stringify(category.paths), category.name === "Programs" ? "1" : "0"]);
    }

    function isSelected(path: string): bool {
        return root.selectedPaths.includes(path);
    }

    function toggleSelected(path: string): void {
        const next = root.selectedPaths.slice();
        const index = next.indexOf(path);
        if (index < 0)
            next.push(path);
        else
            next.splice(index, 1);
        root.selectedPaths = next;
    }

    function deleteTargets(): void {
        if (!root.selectedCategory || root.selectedPaths.length === 0)
            return;

        // Only delete direct entries returned by the active category scan.
        const listed = new Set(root.files.map(file => file.path));
        const safeTargets = root.selectedPaths.filter(path => listed.has(path) && root.selectedCategory.paths.some(base => path.startsWith(`${base}/`)));
        if (safeTargets.length === 0) {
            root.errorText = qsTr("No safe files were selected.");
            return;
        }

        root.confirmDelete = false;
        deleteProcess.exec(["rm", "-rf", "--", ...safeTargets]);
    }

    function inspectApp(app: var): void {
        root.selectedApp = app;
        root.appPackage = "";
        root.confirmUninstall = false;
        ownerProcess.exec(["pacman", "-Qqo", "--", app.path]);
    }

    function launchApp(): void {
        if (!root.selectedApp?.desktopId)
            return;
        launchProcess.exec(["gtk-launch", root.selectedApp.desktopId]);
        root.selectedApp = null;
    }

    function openAppLocation(): void {
        if (!root.selectedApp?.path)
            return;
        const slash = root.selectedApp.path.lastIndexOf("/");
        locationProcess.exec(["xdg-open", slash > 0 ? root.selectedApp.path.slice(0, slash) : "/"]);
    }

    function uninstallApp(): void {
        if (!root.appPackage)
            return;
        root.confirmUninstall = false;
        root.selectedApp = null;
        Quickshell.execDetached(["foot", "-e", "sudo", "pacman", "-Rns", root.appPackage]);
    }

    function clearCache(): void {
        root.confirmCacheClear = false;
        cacheProcess.exec(["python3", "-c", "import os,shutil; p=os.path.expanduser('~/.cache'); [shutil.rmtree(os.path.join(p,n),ignore_errors=True) if os.path.isdir(os.path.join(p,n)) and not os.path.islink(os.path.join(p,n)) else os.unlink(os.path.join(p,n)) for n in os.listdir(p)] if os.path.isdir(p) else None"]);
    }

    readonly property string categoryScanner: `import json, os, subprocess, sys
mount = sys.argv[1]
try:
    mount_dev = os.stat(mount).st_dev
except OSError:
    mount_dev = None
def xdg(key, fallback):
    try:
        value = subprocess.run(['xdg-user-dir', key], capture_output=True, text=True, timeout=2).stdout.strip()
        if value and os.path.isdir(value): return value
    except Exception: pass
    return os.path.expanduser(fallback)
defs = [
    ('Programs', 'apps', ['/usr/share/applications', os.path.expanduser('~/.local/share/applications')]),
    ('Downloads', 'download', [xdg('DOWNLOAD', '~/Downloads')]),
    ('Videos', 'movie', [xdg('VIDEOS', '~/Videos')]),
    ('Pictures', 'image', [xdg('PICTURES', '~/Pictures')]),
    ('Music', 'music_note', [xdg('MUSIC', '~/Music')]),
    ('Documents', 'description', [xdg('DOCUMENTS', '~/Documents')]),
    ('Cache & Temp', 'cleaning_services', [os.path.expanduser('~/.cache')]),
]
result = []
for name, icon, candidates in defs:
    paths = []
    size = 0
    for path in candidates:
        if not os.path.exists(path): continue
        try:
            if mount_dev is not None and os.stat(path).st_dev != mount_dev: continue
            paths.append(path)
            cmd = ['ionice', '-c', '3', 'nice', '-n', '19', 'du', '-sx', '-B1', '--', path]
            done = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
            if done.returncode == 0:
                size += int(done.stdout.split()[0])
        except Exception: pass
    if paths: result.append({'name': name, 'icon': icon, 'paths': paths, 'size': size})
print(json.dumps(result))`

    readonly property string fileScanner: `import json, os, subprocess, sys
paths = json.loads(sys.argv[1])
is_programs = sys.argv[2] == '1'
items = []
def size_of(path):
    try:
        if os.path.isfile(path): return os.path.getsize(path)
        done = subprocess.run(['ionice', '-c', '3', 'nice', '-n', '19', 'du', '-sx', '-B1', '--', path], capture_output=True, text=True, timeout=30)
        return int(done.stdout.split()[0]) if done.returncode == 0 else 0
    except Exception: return 0
for base in paths:
    if not os.path.isdir(base): continue
    try:
        with os.scandir(base) as entries:
            for entry in entries:
                try:
                    if is_programs and (not entry.is_file(follow_symlinks=False) or not entry.name.endswith('.desktop')): continue
                    if entry.is_symlink(): continue
                    path = entry.path
                    is_dir = entry.is_dir(follow_symlinks=False)
                    record = {'name': entry.name, 'path': path, 'size': entry.stat(follow_symlinks=False).st_size if is_dir else size_of(path), 'isDir': is_dir, 'isApp': False}
                    if is_programs:
                        name, exec_line, icon = entry.name[:-8], '', 'apps'
                        with open(path, 'r', errors='ignore') as stream:
                            for line in stream:
                                if line.startswith('Name=') and name == entry.name[:-8]: name = line.split('=', 1)[1].strip()
                                elif line.startswith('Exec='): exec_line = line.split('=', 1)[1].strip()
                                elif line.startswith('Icon='): icon = line.split('=', 1)[1].strip()
                        record.update({'name': name, 'exec': exec_line, 'icon': icon, 'desktopId': entry.name[:-8], 'isApp': True})
                    items.append(record)
                except Exception: pass
    except Exception: pass
items.sort(key=lambda item: item['size'], reverse=True)
print(json.dumps(items[:200]))`

    Component.onCompleted: root.refresh()

    Process {
        id: diskProcess
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").slice(1);
                const parsed = [];
                for (const line of lines) {
                    const fields = line.trim().split(/\s+/);
                    if (fields.length < 6) continue;
                    const mount = fields[fields.length - 1].replace(/\\040/g, " ").replace(/\\011/g, "\t").replace(/\\134/g, "\\");
                    const disk = {
                        device: fields[0],
                        total: Number(fields[1]),
                        used: Number(fields[2]),
                        free: Number(fields[3]),
                        percent: parseInt(fields[4], 10) || 0,
                        mount: mount
                    };
                    if (mount.startsWith("/") && disk.total > 0 && !parsed.some(item => item.mount === mount))
                        parsed.push(disk);
                }
                parsed.sort((a, b) => a.mount === "/" ? -1 : b.mount === "/" ? 1 : a.mount.localeCompare(b.mount));
                root.disks = parsed;
                if (!parsed.some(disk => disk.mount === root.selectedMount))
                    root.selectedMount = parsed.find(disk => disk.mount === "/")?.mount ?? parsed[0]?.mount ?? "/";
                root.scanCategories();
            }
        }
        onExited: (code, status) => {
            if (code !== 0)
                root.errorText = qsTr("Could not read disk information.");
        }
    }

    Process {
        id: categoryProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.categories = JSON.parse(text.trim());
                    root.errorText = "";
                } catch (error) {
                    root.categories = [];
                    root.errorText = qsTr("Could not scan storage categories.");
                }
                root.scanning = false;
            }
        }
        onExited: (code, status) => {
            if (code !== 0) {
                root.scanning = false;
                root.errorText = qsTr("Storage scan failed.");
            }
        }
    }

    Process {
        id: fileProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.files = JSON.parse(text.trim());
                } catch (error) {
                    root.files = [];
                    root.errorText = qsTr("Could not read this category.");
                }
                root.listingFiles = false;
            }
        }
        onExited: (code, status) => {
            if (code !== 0) {
                root.listingFiles = false;
                root.errorText = qsTr("Could not read this category.");
            }
        }
    }

    Process {
        id: deleteProcess
        onExited: (code, status) => {
            if (code !== 0)
                root.errorText = qsTr("Some selected items could not be deleted.");
            root.selectedPaths = [];
            root.openCategory(root.selectedCategory);
            root.scanCategories();
        }
    }

    Process {
        id: cacheProcess
        onExited: (code, status) => {
            root.errorText = code === 0 ? qsTr("Cache cleared.") : qsTr("Could not clear the cache.");
            root.scanCategories();
        }
    }

    Process {
        id: ownerProcess
        stdout: StdioCollector {
            onStreamFinished: root.appPackage = text.trim().split("\n")[0] ?? ""
        }
    }

    Process { id: launchProcess }
    Process { id: locationProcess }

    PaneFrame {
        anchors.fill: parent

        Flickable {
            anchors.fill: parent
            contentHeight: layout.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: layout
                width: parent.width
                spacing: Tokens.spacing.normal

                SettingsHeader {
                    icon: "hard_drive"
                    title: root.selectedCategory ? root.selectedCategory.name : qsTr("Storage & Disk Usage")
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.errorText.length > 0
                    text: root.errorText
                    color: root.errorText === qsTr("Cache cleared.") ? Colours.palette.m3primary : Colours.palette.m3error
                    wrapMode: Text.Wrap
                }

                ColumnLayout {
                    visible: !root.selectedCategory
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.normal

                    SectionHeader {
                        title: qsTr("Storage devices")
                        description: qsTr("Select a mounted drive to view its capacity.")
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        Repeater {
                            model: root.disks
                            TextButton {
                                required property var modelData
                                text: `${modelData.mount} · ${root.formatBytes(modelData.free)} ${qsTr("free")}`
                                type: root.selectedMount === modelData.mount ? ButtonBase.Filled : ButtonBase.Tonal
                                isRound: true
                                onClicked: {
                                    root.selectedMount = modelData.mount;
                                    root.scanCategories();
                                }
                            }
                        }

                        TextButton {
                            text: qsTr("Refresh")
                            type: ButtonBase.Tonal
                            isRound: true
                            onClicked: root.refresh()
                        }
                    }

                    SectionContainer {
                        Layout.fillWidth: true

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.small

                            RowLayout {
                                Layout.fillWidth: true
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: Tokens.spacing.smaller
                                    StyledText {
                                        text: root.activeDisk?.mount ?? qsTr("No mounted drive found")
                                        font.pointSize: Tokens.font.size.large
                                        font.weight: 600
                                        color: Colours.palette.m3primary
                                    }
                                    StyledText {
                                        text: root.activeDisk ? root.activeDisk.device : qsTr("Disk capacity unavailable")
                                        color: Colours.palette.m3onSurfaceVariant
                                        font.pointSize: Tokens.font.size.small
                                    }
                                }
                                ColumnLayout {
                                    Layout.alignment: Qt.AlignRight
                                    StyledText {
                                        Layout.alignment: Qt.AlignRight
                                        text: root.activeDisk ? root.formatBytes(root.activeDisk.free) : "—"
                                        font.pointSize: Tokens.font.size.large
                                        font.weight: 600
                                        color: Colours.palette.m3primary
                                    }
                                    StyledText {
                                        Layout.alignment: Qt.AlignRight
                                        text: qsTr("free")
                                        color: Colours.palette.m3onSurfaceVariant
                                        font.pointSize: Tokens.font.size.small
                                    }
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                implicitHeight: 12
                                StyledRect {
                                    anchors.fill: parent
                                    radius: Tokens.rounding.full
                                    color: Qt.alpha(Colours.palette.m3outline, 0.2)
                                }
                                StyledRect {
                                    width: parent.width * root.usedRatio
                                    height: parent.height
                                    radius: Tokens.rounding.full
                                    color: Colours.palette.m3primary
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: root.activeDisk ? qsTr("%1 used of %2 · %3%").arg(root.formatBytes(root.activeDisk.used)).arg(root.formatBytes(root.activeDisk.total)).arg(root.activeDisk.percent) : ""
                                color: Colours.palette.m3onSurfaceVariant
                                font.pointSize: Tokens.font.size.small
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        SectionHeader {
                            Layout.fillWidth: true
                            title: qsTr("Category breakdown")
                            description: qsTr("Folder sizes are scanned on demand and may take a moment.")
                        }
                        BusyIndicator {
                            running: root.scanning
                            visible: running
                        }
                        TextButton {
                            text: qsTr("Clear cache")
                            type: ButtonBase.Tonal
                            isRound: true
                            onClicked: root.confirmCacheClear = true
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: width >= 700 ? 2 : 1
                        rowSpacing: Tokens.spacing.small
                        columnSpacing: Tokens.spacing.small

                        Repeater {
                            model: root.categories
                            delegate: StyledRect {
                                id: categoryCard
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: 78
                                radius: Tokens.rounding.normal
                                color: Colours.tPalette.m3surfaceContainer

                                StateLayer {
                                    radius: Tokens.rounding.normal
                                    onClicked: root.openCategory(categoryCard.modelData)
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: Tokens.padding.normal
                                    spacing: Tokens.spacing.normal
                                    MaterialIcon {
                                        text: categoryCard.modelData.icon
                                        color: Colours.palette.m3primary
                                        font.pointSize: Tokens.font.size.large
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: Tokens.spacing.smaller
                                        StyledText {
                                            Layout.fillWidth: true
                                            text: categoryCard.modelData.name
                                            font.weight: 600
                                        }
                                        StyledText {
                                            Layout.fillWidth: true
                                            text: root.formatBytes(categoryCard.modelData.size)
                                            color: Colours.palette.m3onSurfaceVariant
                                            font.pointSize: Tokens.font.size.small
                                        }
                                    }
                                    MaterialIcon {
                                        text: "chevron_right"
                                        color: Colours.palette.m3outline
                                    }
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    visible: Boolean(root.selectedCategory)
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    RowLayout {
                        Layout.fillWidth: true
                        TextButton {
                            text: qsTr("Back to storage")
                            type: ButtonBase.Tonal
                            isRound: true
                            onClicked: {
                                root.confirmDelete = false;
                                root.selectedCategory = null;
                                root.selectedPaths = [];
                            }
                        }
                        Item { Layout.fillWidth: true }
                        TextButton {
                            visible: root.files.length > 0 && root.selectedCategory?.name !== "Programs"
                            text: root.selectedPaths.length === root.files.length ? qsTr("Deselect all") : qsTr("Select all")
                            type: ButtonBase.Tonal
                            isRound: true
                            onClicked: root.selectedPaths.length === root.files.length ? root.selectedPaths = [] : root.selectedPaths = root.files.map(file => file.path)
                        }
                        TextButton {
                            visible: root.selectedPaths.length > 0
                            text: qsTr("Delete selected (%1)").arg(root.selectedPaths.length)
                            type: ButtonBase.Filled
                            isRound: true
                            onClicked: root.confirmDelete = true
                        }
                        TextButton {
                            text: qsTr("Refresh")
                            type: ButtonBase.Tonal
                            isRound: true
                            onClicked: root.openCategory(root.selectedCategory)
                        }
                    }

                    SectionContainer {
                        Layout.fillWidth: true
                        visible: root.confirmDelete
                        RowLayout {
                            Layout.fillWidth: true
                            StyledText {
                                Layout.fillWidth: true
                                text: qsTr("Permanently delete %1 selected item(s)?").arg(root.selectedPaths.length)
                                color: Colours.palette.m3error
                                wrapMode: Text.Wrap
                            }
                            TextButton {
                                text: qsTr("Cancel")
                                type: ButtonBase.Tonal
                                isRound: true
                                onClicked: root.confirmDelete = false
                            }
                            TextButton {
                                text: qsTr("Delete permanently")
                                type: ButtonBase.Filled
                                isRound: true
                                onClicked: root.deleteTargets()
                            }
                        }
                    }

                    StyledText {
                        visible: root.listingFiles
                        text: qsTr("Scanning…")
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    Repeater {
                        model: root.files
                        delegate: SectionContainer {
                            id: fileCard
                            required property var modelData
                            Layout.fillWidth: true
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Tokens.spacing.normal

                                IconButton {
                                    visible: !fileCard.modelData.isApp
                                    icon: root.isSelected(fileCard.modelData.path) ? "check_box" : "check_box_outline_blank"
                                    onClicked: root.toggleSelected(fileCard.modelData.path)
                                }

                                MaterialIcon {
                                    text: fileCard.modelData.isApp ? "apps" : fileCard.modelData.isDir ? "folder" : "description"
                                    color: Colours.palette.m3primary
                                    font.pointSize: Tokens.font.size.large
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: Tokens.spacing.smaller
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: fileCard.modelData.name
                                        elide: Text.ElideRight
                                    }
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: `${fileCard.modelData.path} · ${root.formatBytes(fileCard.modelData.size)}`
                                        color: Colours.palette.m3onSurfaceVariant
                                        font.pointSize: Tokens.font.size.small
                                        elide: Text.ElideMiddle
                                    }
                                }

                                TextButton {
                                    visible: fileCard.modelData.isApp
                                    text: qsTr("Inspect")
                                    type: ButtonBase.Tonal
                                    isRound: true
                                    onClicked: root.inspectApp(fileCard.modelData)
                                }

                                IconButton {
                                    visible: !fileCard.modelData.isApp
                                    icon: "delete"
                                    onClicked: {
                                        root.selectedPaths = [fileCard.modelData.path];
                                        root.confirmDelete = true;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        z: 20
        visible: root.selectedApp !== null || root.confirmCacheClear
        Rectangle {
            anchors.fill: parent
            color: Qt.alpha(Colours.palette.m3scrim, 0.62)
            MouseArea { anchors.fill: parent; onClicked: { root.selectedApp = null; root.confirmCacheClear = false; root.confirmUninstall = false; } }
        }
        StyledRect {
            anchors.centerIn: parent
            width: Math.min(parent.width - Tokens.padding.large * 2, 480)
            implicitHeight: modalContent.implicitHeight + Tokens.padding.large * 2
            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainer

            ColumnLayout {
                id: modalContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.normal

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.confirmCacheClear ? "cleaning_services" : "apps"
                    color: Colours.palette.m3primary
                    font.pointSize: Tokens.font.size.extraLarge * 2
                }
                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.confirmCacheClear ? qsTr("Clear application cache?") : root.confirmUninstall ? qsTr("Uninstall %1?").arg(root.appPackage) : (root.selectedApp?.name ?? "")
                    font.pointSize: Tokens.font.size.large
                    font.weight: 600
                    wrapMode: Text.Wrap
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: !root.confirmCacheClear && !root.confirmUninstall
                    horizontalAlignment: Text.AlignHCenter
                    text: root.selectedApp ? `${root.selectedApp.path}\n${root.appPackage ? qsTr("Installed by %1").arg(root.appPackage) : qsTr("Package ownership unavailable")}` : ""
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Tokens.font.size.small
                    wrapMode: Text.Wrap
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: root.confirmCacheClear || root.confirmUninstall
                    horizontalAlignment: Text.AlignHCenter
                    text: root.confirmCacheClear ? qsTr("This removes the contents of ~/.cache. Applications can recreate these temporary files.") : qsTr("The package manager will open in a terminal so you can review and confirm the removal.")
                    color: Colours.palette.m3onSurfaceVariant
                    wrapMode: Text.Wrap
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Tokens.spacing.small
                    visible: !root.confirmCacheClear && !root.confirmUninstall
                    TextButton { text: qsTr("Launch"); type: ButtonBase.Tonal; isRound: true; enabled: Boolean(root.selectedApp?.desktopId); onClicked: root.launchApp() }
                    TextButton { text: qsTr("Open location"); type: ButtonBase.Tonal; isRound: true; enabled: Boolean(root.selectedApp?.path); onClicked: root.openAppLocation() }
                    TextButton { text: qsTr("Uninstall"); type: ButtonBase.Tonal; isRound: true; enabled: root.appPackage.length > 0; onClicked: root.confirmUninstall = true }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Tokens.spacing.small
                    visible: root.confirmCacheClear || root.confirmUninstall
                    TextButton {
                        text: qsTr("Cancel")
                        type: ButtonBase.Tonal
                        isRound: true
                        onClicked: { root.confirmCacheClear = false; root.confirmUninstall = false; }
                    }
                    TextButton {
                        text: root.confirmCacheClear ? qsTr("Clear cache") : qsTr("Open package manager")
                        type: ButtonBase.Filled
                        isRound: true
                        onClicked: root.confirmCacheClear ? root.clearCache() : root.uninstallApp()
                    }
                }
                TextButton {
                    Layout.alignment: Qt.AlignHCenter
                    visible: !root.confirmCacheClear && !root.confirmUninstall
                    text: qsTr("Close")
                    type: ButtonBase.Text
                    isRound: true
                    onClicked: root.selectedApp = null
                }
            }
        }
    }
}
