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
    property var directoryStack: []
    property var selectedCategory: null
    property var selectedApp: null
    property string selectedMount: "/"
    property string fileQuery: ""
    property string sortMode: "largest"
    property int visibleLimit: 100
    property string appPackage: ""
    property string errorText: ""
    property bool scanning: false
    property bool refreshing: false
    property bool listingFiles: false
    property bool deleting: false
    property bool clearingCache: false
    property bool inspectingApp: false
    property bool confirmDelete: false
    property bool confirmCacheClear: false
    property bool confirmUninstall: false

    readonly property var activeDisk: disks.find(disk => disk.mount === selectedMount) ?? disks[0] ?? null
    readonly property real usedRatio: activeDisk?.total > 0 ? Math.min(1, activeDisk.used / activeDisk.total) : 0
    readonly property var visibleFiles: {
        const query = root.fileQuery.trim().toLocaleLowerCase();
        const matches = root.files.filter(file => !query || `${file.name} ${file.path}`.toLocaleLowerCase().includes(query));
        return matches.slice().sort((a, b) => root.isPrograms || root.sortMode === "name" ? a.name.localeCompare(b.name) : b.size - a.size);
    }
    readonly property var shownFiles: root.visibleFiles.slice(0, root.visibleLimit)
    readonly property var selectedItems: root.files.filter(file => root.selectedPaths.includes(file.path))
    readonly property string selectedSummary: {
        const names = root.selectedItems.slice(0, 3).map(file => file.name);
        const remaining = root.selectedItems.length - names.length;
        return names.join(", ") + (remaining > 0 ? qsTr(" and %1 more").arg(remaining) : "");
    }
    readonly property bool isPrograms: root.selectedCategory?.name === "Programs"
    readonly property string currentDirectory: root.directoryStack.length > 0 ? root.directoryStack[root.directoryStack.length - 1] : ""

    function formatBytes(value: real): string {
        if (!value || value <= 0)
            return "0 B";
        const units = ["B", "KB", "MB", "GB", "TB", "PB"];
        const unit = Math.min(Math.floor(Math.log(value) / Math.log(1024)), units.length - 1);
        return `${(value / Math.pow(1024, unit)).toFixed(unit > 0 ? 1 : 0)} ${units[unit]}`;
    }

    function refresh(): void {
        if (diskProcess.running)
            return;
        root.errorText = "";
        root.refreshing = true;
        diskProcess.exec({ command: ["df", "-P", "-B1", "-x", "tmpfs", "-x", "devtmpfs", "-x", "squashfs"] });
    }

    function scanCategories(): void {
        if (!root.activeDisk || categoryProcess.running)
            return;
        root.scanning = true;
        categoryProcess.exec({ command: ["ionice", "-c", "3", "nice", "-n", "19", "python3", "-c", categoryScanner, root.activeDisk.mount] });
    }

    function openCategory(category: var): void {
        if (fileProcess.running)
            return;
        root.selectedCategory = category;
        root.directoryStack = [];
        root.files = [];
        root.selectedPaths = [];
        root.confirmDelete = false;
        root.errorText = "";
        root.fileQuery = "";
        root.visibleLimit = 100;
        root.reloadFiles();
    }

    function openDirectory(path: string): void {
        if (!root.selectedCategory || root.isPrograms || fileProcess.running)
            return;
        const allowed = root.selectedCategory.paths.some(base => path.startsWith(`${base}/`));
        const directory = root.files.find(file => file.path === path && file.isDir);
        if (!allowed || !directory)
            return;
        root.directoryStack = [...root.directoryStack, path];
        root.selectedPaths = [];
        root.confirmDelete = false;
        root.errorText = "";
        root.fileQuery = "";
        root.visibleLimit = 100;
        root.reloadFiles();
    }

    function goUpDirectory(): void {
        if (root.directoryStack.length === 0)
            return;
        root.directoryStack = root.directoryStack.slice(0, -1);
        root.selectedPaths = [];
        root.confirmDelete = false;
        root.errorText = "";
        root.fileQuery = "";
        root.reloadFiles();
    }

    function reloadFiles(): void {
        if (!root.selectedCategory || fileProcess.running)
            return;
        root.files = [];
        root.listingFiles = true;
        const paths = root.currentDirectory ? [root.currentDirectory] : root.selectedCategory.paths;
        fileProcess.exec({ command: ["ionice", "-c", "3", "nice", "-n", "19", "python3", "-c", fileScanner, JSON.stringify(paths), root.isPrograms ? "1" : "0"] });
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

    function toggleVisibleSelection(): void {
        const visiblePaths = root.shownFiles.filter(file => !file.isApp).map(file => file.path);
        if (visiblePaths.length > 0 && visiblePaths.every(path => root.isSelected(path))) {
            root.selectedPaths = root.selectedPaths.filter(path => !visiblePaths.includes(path));
        } else {
            const selected = new Set(root.selectedPaths);
            for (const path of visiblePaths)
                selected.add(path);
            root.selectedPaths = Array.from(selected);
        }
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
        root.deleting = true;
        deleteProcess.exec({ command: ["gio", "trash", "--", ...safeTargets] });
    }

    function inspectApp(app: var): void {
        root.selectedApp = app;
        root.appPackage = "";
        root.inspectingApp = true;
        root.confirmUninstall = false;
        ownerProcess.exec({ command: ["pacman", "-Qqo", "--", app.path] });
    }

    function launchApp(): void {
        if (!root.selectedApp?.desktopId)
            return;
        launchProcess.exec({ command: ["gtk-launch", root.selectedApp.desktopId] });
        root.selectedApp = null;
    }

    function openAppLocation(): void {
        if (!root.selectedApp?.path)
            return;
        const slash = root.selectedApp.path.lastIndexOf("/");
        locationProcess.exec({ command: ["xdg-open", slash > 0 ? root.selectedApp.path.slice(0, slash) : "/"] });
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
        root.clearingCache = true;
        cacheProcess.exec({ command: ["ionice", "-c", "3", "nice", "-n", "19", "python3", "-c", "import os,shutil; p=os.path.expanduser('~/.cache'); [shutil.rmtree(os.path.join(p,n),ignore_errors=True) if os.path.isdir(os.path.join(p,n)) and not os.path.islink(os.path.join(p,n)) else os.unlink(os.path.join(p,n)) for n in os.listdir(p)] if os.path.isdir(p) and not os.path.islink(p) else None"] });
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
    ('Desktop', 'desktop_windows', [xdg('DESKTOP', '~/Desktop')]),
    ('Videos', 'movie', [xdg('VIDEOS', '~/Videos')]),
    ('Pictures', 'image', [xdg('PICTURES', '~/Pictures')]),
    ('Music', 'music_note', [xdg('MUSIC', '~/Music')]),
    ('Documents', 'description', [xdg('DOCUMENTS', '~/Documents')]),
    ('App data', 'data_object', [os.path.expanduser('~/.local/share'), os.path.expanduser('~/.var/app')]),
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
result.sort(key=lambda category: category['size'], reverse=True)
print(json.dumps(result))`

    readonly property string fileScanner: `import json, os, subprocess, sys
paths = json.loads(sys.argv[1])
is_programs = sys.argv[2] == '1'
items = []
directories = []
trash_path = os.path.abspath(os.path.expanduser('~/.local/share/Trash'))
for base in paths:
    if not os.path.isdir(base): continue
    try:
        with os.scandir(base) as entries:
            for entry in entries:
                try:
                    if os.path.abspath(entry.path) == trash_path: continue
                    if is_programs and (not entry.is_file(follow_symlinks=False) or not entry.name.endswith('.desktop')): continue
                    if entry.is_symlink(): continue
                    path = entry.path
                    is_dir = entry.is_dir(follow_symlinks=False)
                    record = {'name': entry.name, 'path': path, 'size': entry.stat(follow_symlinks=False).st_size if not is_dir else 0, 'isDir': is_dir, 'isApp': False}
                    if is_dir: directories.append(path)
                    if is_programs:
                        name, exec_line, icon = entry.name[:-8], '', 'apps'
                        hidden = False
                        no_display = False
                        in_desktop_entry = False
                        with open(path, 'r', errors='ignore') as stream:
                            for line in stream:
                                if line.startswith('['):
                                    in_desktop_entry = line.strip() == '[Desktop Entry]'
                                    continue
                                if not in_desktop_entry: continue
                                if line.startswith('Name='): name = line.split('=', 1)[1].strip()
                                elif line.startswith('Exec='): exec_line = line.split('=', 1)[1].strip()
                                elif line.startswith('Icon='): icon = line.split('=', 1)[1].strip()
                                elif line.startswith('Hidden=true'): hidden = True
                                elif line.startswith('NoDisplay=true'): no_display = True
                        if hidden or no_display: continue
                        record.update({'name': name, 'exec': exec_line, 'icon': icon, 'desktopId': entry.name[:-8], 'isApp': True})
                    items.append(record)
                except Exception: pass
    except Exception: pass
if is_programs:
    unique = {}
    for item in items: unique[item['desktopId']] = item
    items = list(unique.values())
if directories:
    try:
        sizes = {}
        for offset in range(0, len(directories), 100):
            chunk = directories[offset:offset + 100]
            done = subprocess.run(['ionice', '-c', '3', 'nice', '-n', '19', 'du', '-sx', '-B1', '--null', '--', *chunk], capture_output=True, text=True, timeout=120)
            if done.returncode != 0: continue
            for row in done.stdout.split('\\0'):
                fields = row.split('\\t', 1)
                if len(fields) == 2:
                    try: sizes[fields[1]] = int(fields[0])
                    except ValueError: pass
        for item in items:
            if item['isDir']: item['size'] = sizes.get(item['path'], 0)
    except Exception: pass
items.sort(key=lambda item: item['size'], reverse=True)
print(json.dumps(items))`

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
                root.refreshing = false;
                if (!parsed.some(disk => disk.mount === root.selectedMount))
                    root.selectedMount = parsed.find(disk => disk.mount === "/")?.mount ?? parsed[0]?.mount ?? "/";
                if (parsed.length > 0)
                    root.scanCategories();
                else
                    root.errorText = qsTr("No mounted storage devices were found.");
            }
        }
        onExited: (code, status) => {
            root.refreshing = false;
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
            root.deleting = false;
            if (code !== 0)
                root.errorText = qsTr("Some selected items could not be moved to Trash.");
            root.selectedPaths = [];
            root.reloadFiles();
            root.scanCategories();
        }
    }

    Process {
        id: cacheProcess
        onExited: (code, status) => {
            root.clearingCache = false;
            root.errorText = code === 0 ? qsTr("Cache cleared.") : qsTr("Could not clear the cache.");
            root.scanCategories();
        }
    }

    Process {
        id: ownerProcess
        stdout: StdioCollector {
            onStreamFinished: {
                root.appPackage = text.trim().split("\n")[0] ?? "";
                root.inspectingApp = false;
            }
        }
        onExited: (code, status) => root.inspectingApp = false
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
                        title: root.selectedCategory ? root.selectedCategory.name : qsTr("Storage")
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: root.errorText.length > 0
                    StyledText {
                        Layout.fillWidth: true
                        text: root.errorText
                        color: root.errorText === qsTr("Cache cleared.") ? Colours.palette.m3primary : Colours.palette.m3error
                        wrapMode: Text.Wrap
                    }
                    TextButton {
                        visible: root.errorText !== qsTr("Cache cleared.")
                        text: qsTr("Retry")
                        type: TextButton.Tonal
                        onClicked: {
                            if (root.selectedCategory)
                                root.reloadFiles();
                            else if (root.activeDisk)
                                root.scanCategories();
                            else
                                root.refresh();
                        }
                    }
                }

                ColumnLayout {
                    visible: !root.selectedCategory
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.normal

                    SectionHeader {
                        title: qsTr("Your drives")
                        description: qsTr("Choose a mounted drive to see what's using its space.")
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        Repeater {
                            model: root.disks
                            TextButton {
                                required property var modelData
                                text: `${modelData.mount} · ${root.formatBytes(modelData.total)}`
                                type: root.selectedMount === modelData.mount ? TextButton.Filled : TextButton.Tonal
                                enabled: !root.refreshing && !root.scanning
                                onClicked: {
                                    root.selectedMount = modelData.mount;
                                    root.errorText = "";
                                    root.scanCategories();
                                }
                            }
                        }

                        TextButton {
                            text: qsTr("Refresh")
                            type: TextButton.Tonal
                            enabled: !root.refreshing
                            onClicked: root.refresh()
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: root.refreshing || root.scanning
                        BusyIndicator {
                            running: parent.visible
                        }
                        StyledText {
                            text: root.refreshing ? qsTr("Reading mounted drives…") : qsTr("Checking folder sizes…")
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: !root.refreshing && root.disks.length === 0 && !root.errorText
                        text: qsTr("No mounted drives were found. Connect or mount a drive, then refresh this page.")
                        color: Colours.palette.m3onSurfaceVariant
                        wrapMode: Text.Wrap
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
                                        text: root.activeDisk?.mount ?? qsTr("Drive unavailable")
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
                                    color: root.activeDisk?.percent >= 90 ? Colours.palette.m3error : root.activeDisk?.percent >= 75 ? Colours.palette.m3tertiary : Colours.palette.m3primary
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: root.activeDisk ? qsTr("%1 used of %2 (%3%)").arg(root.formatBytes(root.activeDisk.used)).arg(root.formatBytes(root.activeDisk.total)).arg(root.activeDisk.percent) : qsTr("Drive capacity is unavailable.")
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
                            description: qsTr("Open a category to inspect its largest items and clean up space.")
                        }
                        BusyIndicator {
                            running: root.scanning
                            visible: running
                        }
                        TextButton {
                            text: qsTr("Clear cache")
                            type: TextButton.Tonal
                            enabled: !root.clearingCache
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
                                    disabled: root.scanning || root.listingFiles
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

                    StyledText {
                        Layout.fillWidth: true
                        visible: !root.scanning && root.categories.length === 0 && !root.errorText && root.activeDisk !== null
                        text: qsTr("No common folders were found on this drive. You can still browse another mounted drive or refresh the scan.")
                        color: Colours.palette.m3onSurfaceVariant
                        wrapMode: Text.Wrap
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: root.clearingCache
                        text: qsTr("Clearing the application cache…")
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }

                ColumnLayout {
                    visible: Boolean(root.selectedCategory)
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    RowLayout {
                        Layout.fillWidth: true
                        TextButton {
                            text: root.currentDirectory ? qsTr("Up one folder") : qsTr("Back to storage")
                            type: TextButton.Tonal
                            onClicked: {
                                if (root.currentDirectory) {
                                    root.goUpDirectory();
                                    return;
                                }
                                root.confirmDelete = false;
                                root.selectedCategory = null;
                                root.selectedPaths = [];
                                root.directoryStack = [];
                                root.fileQuery = "";
                            }
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: root.currentDirectory || root.selectedCategory?.name || ""
                            color: Colours.palette.m3onSurfaceVariant
                            elide: Text.ElideMiddle
                        }
                        Item { Layout.fillWidth: true }
                        TextButton {
                            text: qsTr("Refresh")
                            type: TextButton.Tonal
                            enabled: !root.listingFiles
                            onClicked: { root.errorText = ""; root.reloadFiles(); }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        StyledRect {
                            Layout.fillWidth: true
                            implicitHeight: searchRow.implicitHeight + Tokens.padding.small * 2
                            radius: Tokens.rounding.normal
                            color: Colours.palette.m3surfaceContainerLowest
                            border.width: 1
                            border.color: fileSearch.activeFocus ? Colours.palette.m3primary : Colours.palette.m3outlineVariant

                            RowLayout {
                                id: searchRow
                                anchors.fill: parent
                                anchors.leftMargin: Tokens.padding.normal
                                anchors.rightMargin: Tokens.padding.normal
                                spacing: Tokens.spacing.small

                                MaterialIcon {
                                    text: "search"
                                    color: Colours.palette.m3onSurfaceVariant
                                    font.pointSize: Tokens.font.size.normal
                                }

                                StyledTextField {
                                    id: fileSearch
                                    Layout.fillWidth: true
                                    placeholderText: root.isPrograms ? qsTr("Search applications") : qsTr("Search files and folders")
                                    selectByMouse: true
                                    Binding {
                                        target: fileSearch
                                        property: "text"
                                        value: root.fileQuery
                                    }
                                    onTextEdited: {
                                        root.fileQuery = text;
                                        root.visibleLimit = 100;
                                    }
                                }

                                IconButton {
                                    visible: root.fileQuery.length > 0
                                    icon: "close"
                                    Accessible.name: qsTr("Clear search")
                                    onClicked: root.fileQuery = ""
                                }
                            }
                        }

                        RowLayout {
                            visible: !root.isPrograms && root.visibleFiles.some(file => !file.isApp)
                            spacing: Tokens.spacing.small
                            TextButton {
                                text: qsTr("Largest first")
                                type: root.sortMode === "largest" ? TextButton.Filled : TextButton.Tonal
                                onClicked: { root.sortMode = "largest"; root.visibleLimit = 100; }
                            }
                            TextButton {
                                text: qsTr("Name A–Z")
                                type: root.sortMode === "name" ? TextButton.Filled : TextButton.Tonal
                                onClicked: { root.sortMode = "name"; root.visibleLimit = 100; }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: !root.isPrograms && root.files.length > 0
                        StyledText {
                            Layout.fillWidth: true
                            text: root.selectedPaths.length > 0
                                ? qsTr("%1 selected").arg(root.selectedPaths.length)
                                : qsTr("%1 matches · showing %2").arg(root.visibleFiles.length).arg(root.shownFiles.length)
                            color: Colours.palette.m3onSurfaceVariant
                            font.pointSize: Tokens.font.size.small
                        }
                        TextButton {
                            visible: root.visibleFiles.some(file => !file.isApp)
                            text: root.shownFiles.length > 0 && root.shownFiles.filter(file => !file.isApp).every(file => root.isSelected(file.path)) ? qsTr("Deselect shown") : qsTr("Select shown")
                            type: TextButton.Tonal
                            onClicked: root.toggleVisibleSelection()
                        }
                        TextButton {
                            visible: root.selectedPaths.length > 0
                            text: qsTr("Clear selection")
                            type: TextButton.Tonal
                            onClicked: root.selectedPaths = []
                        }
                        TextButton {
                            visible: root.selectedPaths.length > 0
                            text: qsTr("Move to Trash (%1)").arg(root.selectedPaths.length)
                            type: TextButton.Filled
                            onClicked: root.confirmDelete = true
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: root.listingFiles || root.deleting
                        BusyIndicator { running: parent.visible }
                        StyledText {
                            text: root.deleting ? qsTr("Deleting selected items…") : qsTr("Reading this folder…")
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }

                    SectionContainer {
                        Layout.fillWidth: true
                        visible: root.confirmDelete
                        RowLayout {
                            Layout.fillWidth: true
                            StyledText {
                                Layout.fillWidth: true
                                text: qsTr("Move %1 to Trash?").arg(root.selectedSummary)
                                color: Colours.palette.m3error
                                wrapMode: Text.Wrap
                            }
                            TextButton {
                                text: qsTr("Cancel")
                                type: TextButton.Tonal
                                onClicked: root.confirmDelete = false
                            }
                            TextButton {
                                text: qsTr("Move to Trash")
                                type: TextButton.Filled
                                enabled: !root.deleting
                                onClicked: root.deleteTargets()
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: !root.listingFiles && root.files.length === 0 && !root.errorText
                        text: root.isPrograms
                            ? qsTr("No installed applications were found in the standard application folders.")
                            : qsTr("This category is empty. New items in this folder will appear here after refresh.")
                        color: Colours.palette.m3onSurfaceVariant
                        wrapMode: Text.Wrap
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: !root.listingFiles && root.files.length > 0 && root.visibleFiles.length === 0
                        text: qsTr("No items match “%1”. Clear the search to see everything.").arg(root.fileQuery)
                        color: Colours.palette.m3onSurfaceVariant
                        wrapMode: Text.Wrap
                    }

                    Repeater {
                        model: root.shownFiles
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
                                    Accessible.name: root.isSelected(fileCard.modelData.path)
                                        ? qsTr("Deselect %1").arg(fileCard.modelData.name)
                                        : qsTr("Select %1").arg(fileCard.modelData.name)
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
                                    visible: fileCard.modelData.isDir && !root.isPrograms
                                    text: qsTr("Open")
                                    type: TextButton.Tonal
                                    onClicked: root.openDirectory(fileCard.modelData.path)
                                }

                                TextButton {
                                    visible: fileCard.modelData.isApp
                                    text: qsTr("Inspect")
                                    type: TextButton.Tonal
                                    enabled: !root.inspectingApp
                                    onClicked: root.inspectApp(fileCard.modelData)
                                }

                                IconButton {
                                    visible: !fileCard.modelData.isApp
                                    icon: "delete"
                                    Accessible.name: qsTr("Move %1 to Trash").arg(fileCard.modelData.name)
                                    onClicked: {
                                        root.selectedPaths = [fileCard.modelData.path];
                                        root.confirmDelete = true;
                                    }
                                }
                            }
                        }
                    }

                    TextButton {
                        Layout.alignment: Qt.AlignHCenter
                        visible: root.shownFiles.length < root.visibleFiles.length
                        text: qsTr("Show 100 more (%1 remaining)").arg(root.visibleFiles.length - root.shownFiles.length)
                        type: TextButton.Tonal
                        onClicked: root.visibleLimit += 100
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
                    text: root.selectedApp ? `${root.selectedApp.path}\n${root.inspectingApp ? qsTr("Checking package ownership…") : root.appPackage ? qsTr("Installed by %1").arg(root.appPackage) : qsTr("Package ownership unavailable")}` : ""
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Tokens.font.size.small
                    wrapMode: Text.Wrap
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: root.confirmCacheClear || root.confirmUninstall
                    horizontalAlignment: Text.AlignHCenter
                    text: root.confirmCacheClear ? qsTr("This permanently removes items inside ~/.cache. Open applications may need to rebuild their cache afterward.") : qsTr("The package manager opens in a terminal where you can review the package removal before confirming it.")
                    color: Colours.palette.m3onSurfaceVariant
                    wrapMode: Text.Wrap
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Tokens.spacing.small
                    visible: !root.confirmCacheClear && !root.confirmUninstall
                    TextButton { text: qsTr("Launch"); type: TextButton.Tonal; enabled: Boolean(root.selectedApp?.desktopId); onClicked: root.launchApp() }
                    TextButton { text: qsTr("Open location"); type: TextButton.Tonal; enabled: Boolean(root.selectedApp?.path); onClicked: root.openAppLocation() }
                    TextButton { text: qsTr("Uninstall"); type: TextButton.Tonal; enabled: root.appPackage.length > 0; onClicked: root.confirmUninstall = true }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Tokens.spacing.small
                    visible: root.confirmCacheClear || root.confirmUninstall
                    TextButton {
                        text: qsTr("Cancel")
                        type: TextButton.Tonal
                        onClicked: { root.confirmCacheClear = false; root.confirmUninstall = false; }
                    }
                    TextButton {
                        text: root.clearingCache ? qsTr("Clearing…") : root.confirmCacheClear ? qsTr("Clear cache") : qsTr("Open package manager")
                        type: TextButton.Filled
                        enabled: !root.clearingCache
                        onClicked: root.confirmCacheClear ? root.clearCache() : root.uninstallApp()
                    }
                }
                TextButton {
                    Layout.alignment: Qt.AlignHCenter
                    visible: !root.confirmCacheClear && !root.confirmUninstall
                    text: qsTr("Close")
                    type: TextButton.Text
                    onClicked: root.selectedApp = null
                }
            }
        }
    }
}
