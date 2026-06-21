function appinstall --description "Install all myshell apps (pacman + AUR). Usage: appinstall [--no-aur] [--damx]"
    # Repo (pacman) apps + tool deps
    set -l pac foot thunar thunar-volman thunar-archive-plugin tumbler \
        playerctl mpv cava brightnessctl grim slurp wl-clipboard \
        imagemagick python-pillow libsixel toilet figlet \
        fish starship btop fastfetch jq

    # AUR apps
    set -l aur caelestia-shell-git caelestia-cli-git mpvpaper \
        visual-studio-code-bin zen-browser-bin zed

    if contains -- -h $argv; or contains -- --help $argv
        echo "appinstall — install myshell apps"
        echo "  appinstall            pacman + AUR apps"
        echo "  appinstall --no-aur   pacman apps only"
        echo "  appinstall --damx     also install DAMX (Acer fan/perf, github.com/PXDiv/Div-Acer-Manager-Max)"
        echo ""
        echo "pacman: $pac"
        echo "aur:    $aur"
        return 0
    end

    if not command -q pacman
        echo "appinstall: not an Arch-based system (no pacman). See README for other distros." >&2
        return 1
    end

    echo ":: Installing pacman apps…"
    sudo pacman -S --needed --noconfirm $pac; or echo "appinstall: some pacman apps failed — continuing." >&2

    if not contains -- --no-aur $argv
        set -l helper (command -v yay; or command -v paru)
        if test -z "$helper"
            echo ":: No AUR helper found — bootstrapping yay…"
            sudo pacman -S --needed --noconfirm git base-devel
            set -l tmp (mktemp -d)
            git clone https://aur.archlinux.org/yay.git $tmp/yay
            and pushd $tmp/yay; and makepkg -si --noconfirm; and popd
            set helper (command -v yay)
        end
        if test -n "$helper"
            echo ":: Installing AUR apps with "(basename $helper)"…"
            $helper -S --needed --noconfirm $aur; or echo "appinstall: some AUR apps failed." >&2
        end
    end

    if contains -- --damx $argv
        echo ":: Installing DAMX (Acer)…"
        set -l t (mktemp -d)
        git clone --depth 1 https://github.com/PXDiv/Div-Acer-Manager-Max.git $t/damx
        and pushd $t/damx; and bash ./install.sh; and popd
        or echo "appinstall: DAMX failed — grab a release from github.com/PXDiv/Div-Acer-Manager-Max/releases" >&2
    end

    echo ":: appinstall done."
end
