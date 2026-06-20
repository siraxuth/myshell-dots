function paruforce --description "AUR install overwriting conflicting files"
    paru -S --overwrite '*' $argv
end
