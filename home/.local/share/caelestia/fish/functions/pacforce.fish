function pacforce --description "Install package overwriting conflicting files"
    sudo pacman -S --overwrite '*' $argv
end
