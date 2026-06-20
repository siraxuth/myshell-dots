function network --description 'toggle VPN interfaces (wg0, tailscale0) for FlashPrint scan'
    switch "$argv[1]"
        case down
            sudo ip link set tailscale0 down
            sudo ip link set wg0 down
            echo "VPN down — FlashPrint scan ready"
        case up
            sudo ip link set wg0 up
            sudo ip link set tailscale0 up
            echo "VPN up"
        case '*'
            echo "usage: network up | network down"
    end
end
