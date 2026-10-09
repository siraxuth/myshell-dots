import Quickshell
pragma Singleton

Singleton {
    function resolvedPosition(raw: string) : string {
        const position = (raw ?? "left").trim().toLowerCase();
        return ["left", "top", "bottom"].includes(position) ? position : "left";
    }

    function isHorizontal(position: string) : bool {
        return position === "top" || position === "bottom";
    }

    function isLeft(position: string) : bool {
        return position === "left";
    }

    function isTop(position: string) : bool {
        return position === "top";
    }

    function isRight(position: string) : bool {
        return position === "right";
    }

    function isBottom(position: string) : bool {
        return position === "bottom";
    }

}
