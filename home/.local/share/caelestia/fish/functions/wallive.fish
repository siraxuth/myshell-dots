function wallive --description "Video wallpaper control via mpvpaper"
    set -l default_video /home/siraxuth/Downloads/monochrome-daydreams.3840x2160.mp4
    set -l state_dir $HOME/.config/wallive
    set -l path_file $state_dir/path
    set -l autostart_file $state_dir/autostart
    set -l mpv_opts "no-audio --loop --hwdec=vaapi --vo=gpu-next --cache=no --demuxer-max-bytes=20MiB"

    mkdir -p $state_dir

    switch "$argv[1]"
        case stop
            pkill -x mpvpaper
            echo "wallive: Stopped."

        case -s
            touch $autostart_file
            echo "wallive: Autostart is enabled. (will run the episode login)"

        case -ns
            rm -f $autostart_file
            echo "wallive: Autostart is turned off."

        case autostart
            # ถูกเรียกตอน Hyprland start เท่านั้น
            test -f $autostart_file; and wallive
        case -h --help help
            echo "wallive — video wallpaper control via mpvpaper"
            echo ""
            echo "Usage:"
            echo "  wallive             Play wallpaper (last used path, or default if none)"
            echo "  wallive <path>      Play the given video and remember it"
            echo "  wallive stop        Stop / kill mpvpaper"
            echo "  wallive -s          Enable autostart on login"
            echo "  wallive -ns         Disable autostart on login"
            echo "  wallive -h          Show this help"
            echo ""
            echo "  wallive autostart   (internal) used by Hyprland exec-once"
            echo ""
            if test -f $autostart_file
                echo "Autostart : enabled"
            else
                echo "Autostart : disabled"
            end
            echo "Default   : $default_video"
            echo "State dir : $state_dir"
        case '*'
            set -l video
            if test -n "$argv[1]"
                set video $argv[1]
            else if test -f $path_file
                set video (cat $path_file)
            else
                set video $default_video
            end

            if not test -f "$video"
                echo "wallive: File not found -> $video" >&2
                return 1
            end

            echo $video >$path_file # จำ path ไว้ใช้ตอน autostart
            pkill -x mpvpaper
            sleep 0.3
            # -l background: lowest layer. While live wp is active the shell sets
            # wallpaperEnabled=false, so caelestia's bg window drops to the Bottom layer
            # (transparent) and holds the visualiser + desktop widgets — those must stay ABOVE
            # the video, so mpvpaper goes on the layer below them.
            mpvpaper -fp -l background -o "$mpv_opts" ALL $video
            echo "wallive: Playing $video"
    end
end
