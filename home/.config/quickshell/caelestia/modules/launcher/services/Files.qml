pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

// Fast on-demand filename search. The two fd processes let the result row
// distinguish files from directories without doing synchronous filesystem IO.
Singleton {
    id: root

    property var results: []
    property string query: ""
    property string runningQuery: ""
    property bool searching: false
    property string error: ""
    property bool filesFinished: true
    property bool directoriesFinished: true
    property var fileResults: []
    property var directoryResults: []
    property int fileExitCode: 0
    property int directoryExitCode: 0
    property var pendingItem: null

    readonly property var excluded: [
        ".cache", ".git", ".local/share/Trash", "node_modules", "target",
        ".venv", "venv", ".npm", ".cargo", ".rustup", ".gradle", ".var/app"
    ]

    function search(value: string): void {
        root.query = String(value ?? "").trim();
        root.error = "";
        root.results = [];

        if (!root.query) {
            root.searching = false;
            timer.stop();
            return;
        }

        root.searching = true;
        timer.restart();
    }

    function makeCommand(type: string, query: string): list<string> {
        const command = [
            "fd", "--absolute-path", "--hidden", "--no-ignore", "--ignore-case",
            "--fixed-strings", "--full-path", "--print0", "--max-results", "90", "--type", type
        ];
        for (const path of root.excluded)
            command.push("--exclude", path);
        command.push("--", query, Paths.home);
        return command;
    }

    function parseResults(output: string, isDirectory: bool): list<var> {
        return String(output ?? "").split("\u0000").filter(path => path.length > 0).map(path => ({
            name: path.slice(path.lastIndexOf("/") + 1),
            path,
            isDirectory
        }));
    }

    function finishSearch(type: string, exitCode: int, output: string): void {
        if (type === "file") {
            root.filesFinished = true;
            root.fileExitCode = exitCode;
            root.fileResults = exitCode <= 1 ? root.parseResults(output, false) : [];
        } else {
            root.directoriesFinished = true;
            root.directoryExitCode = exitCode;
            root.directoryResults = exitCode <= 1 ? root.parseResults(output, true) : [];
        }

        if (!root.filesFinished || !root.directoriesFinished)
            return;

        if (root.runningQuery !== root.query) {
            timer.restart();
            return;
        }

        const needle = root.runningQuery.toLocaleLowerCase();
        const combined = [...root.fileResults, ...root.directoryResults];
        combined.sort((a, b) => {
            const aName = a.name.toLocaleLowerCase();
            const bName = b.name.toLocaleLowerCase();
            const rank = (name, path) => name === needle ? 0 : name.startsWith(needle) ? 1 : name.includes(needle) ? 2 : path.toLocaleLowerCase().includes(needle) ? 3 : 4;
            return rank(aName, a.path) - rank(bName, b.path) || a.path.localeCompare(b.path) || aName.localeCompare(bName);
        });

        root.results = combined.slice(0, 90);
        root.error = root.fileExitCode > 1 || root.directoryExitCode > 1 ? qsTr("File search failed. Install fd and try again.") : "";
        root.searching = false;
    }

    function runSearch(): void {
        if (!root.query)
            return;
        if (files.running || directories.running) {
            timer.restart();
            return;
        }

        root.runningQuery = root.query;
        root.fileResults = [];
        root.directoryResults = [];
        root.filesFinished = false;
        root.directoriesFinished = false;

        files.command = root.makeCommand("file", root.runningQuery);
        directories.command = root.makeCommand("directory", root.runningQuery);
        files.running = true;
        directories.running = true;
    }

    function fileUri(path: string): string {
        return "file://" + path.split("/").map(part => encodeURIComponent(part).replace(/'/g, "%27")).join("/");
    }

    function open(item: var): void {
        if (!item?.path)
            return;
        root.pendingItem = item;
        // Thunar registers FileManager1 when its daemon starts. Give it a
        // moment before asking it to reveal the selected file or folder.
        Quickshell.execDetached(["thunar", "--daemon"]);
        openTimer.restart();
    }

    function revealPendingItem(): void {
        const item = root.pendingItem;
        if (!item?.path)
            return;
        const uriArray = `['${root.fileUri(item.path)}']`;
        const method = item.isDirectory ? "ShowFolders" : "ShowItems";
        Quickshell.execDetached([
            "gdbus", "call", "--session", "--dest", "org.freedesktop.FileManager1",
            "--object-path", "/org/freedesktop/FileManager1", "--method",
            `org.freedesktop.FileManager1.${method}`, uriArray, ""
        ]);
    }

    Timer {
        id: timer
        interval: 160
        repeat: false
        onTriggered: root.runSearch()
    }

    Timer {
        id: openTimer
        interval: 250
        repeat: false
        onTriggered: root.revealPendingItem()
    }

    Process {
        id: files

        stdout: StdioCollector { id: fileOutput }
        onExited: (code, status) => root.finishSearch("file", code, fileOutput.text)
    }

    Process {
        id: directories

        stdout: StdioCollector { id: directoryOutput }
        onExited: (code, status) => root.finishSearch("directory", code, directoryOutput.text)
    }
}
