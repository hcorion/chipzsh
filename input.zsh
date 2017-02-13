#! /usr/bin/env zsh

trap ctrl_c INT

function ctrl_c() {
        echo "Ok, closing down, just let me cleanup."
        rm input.txt
        exit
}


rm input.txt
echo "" > input.txt
while true
do
    read -k 1 input
    case $input in
    # Row #1 |1|2|3|4| -> |1|2|3|C|
    (1)
        echo "1" > input.txt
    ;;
    (2)
        echo "2" > input.txt
    ;;
    (3)
        echo "3" > input.txt
    ;;
    (4)
        echo "12" > input.txt
    ;;
    # Row #2 |Q|W|E|R| -> |4|5|6|D|
    (q)
        echo "4" > input.txt
    ;;
    (w)
        echo "5" > input.txt
    ;;
    (e)
        echo "6" > input.txt
    ;;
    (r)
        echo "13" > input.txt
    ;;
    # Row #3 |A|S|D|F| -> |7|8|9|E|
    (a)
        echo "7" > input.txt
    ;;
    (s)
        echo "8" > input.txt
    ;;
    (d)
        echo "9" > input.txt
    ;;
    (f)
        echo "14" > input.txt
    ;;
    # Row #4 |Z|X|C|V| -> |A|0|B|F|
    (z)
        echo "10" > input.txt
    ;;
    (x)
        echo "0" > input.txt
    ;;
    (c)
        echo "11" > input.txt
    ;;
    (v)
        echo "15" > input.txt
    ;;
    *)
        echo "Unsupported input, keys you can press are: "
        echo "|1|2|3|4|"
        echo "|q|w|e|r|"
        echo "|a|s|d|f|"
        echo "|z|x|c|v|"
    esac
done