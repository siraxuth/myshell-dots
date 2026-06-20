function cpp --description "Compile a C++ source to ./out then run it"
    if test (count $argv) -eq 0
        echo "Usage: cpp <file.cpp> [args...]" >&2
        return 1
    end

    set -l src $argv[1]
    set -l rest $argv[2..-1]

    if not test -f $src
        echo "cpp: file not found: $src" >&2
        return 1
    end

    g++ -std=c++20 -O2 -Wall -Wextra -pipe -o out $src
    or return $status

    ./out $rest
end
