#! /usr/bin/env zsh
echo "test"

## I made it easier on myself and used the following shell utilities:
## - od command for reading the binary from the file.

## Developing notes
# Ram size is 4096, 0x1000 in hex
# This seems to be a good solution for input: http://stackoverflow.com/questions/24118224/how-to-make-asynchronous-function-calls-in-shell-scripts
# For converting hex to decimal: echo $((16#FF))


TEMPVAR=""
# Creates an array of size x. Assumes the var is a number.
createNumberArray() 
{
    if [ -z "$1" ]
    then
        echo "You need to provide a parameter when calling createNumberArray."
    else
        declare -a array
        for i in {1.."$1"}
        do
            array+=("0000")
        done
        TEMPVAR=$array
    fi
}

# Reading input from file TODO: Add support for different files.
declare -a inputfile
LC_ALL=C inputfile=($(od -t x1 -An brix.ch8))

# The program counter, it starts at 0x200 in hex, 512 integer.
########################################
## SETTING UP THE VARIABLES           ##
########################################

# The program counter starts at 0x200 (512)
PC=512

# There is also an index register! Hooray!
I=0

# These are unused right now, maybe I'll use them in the future.

# There are 15 general purpose registers.
# There is also a 16th register for carry operations.
declare -a reg
for i in {1..16}
do
    reg+=0
done

echo "registers: ${#reg[@]}"

########################################
## SETTING UP THE RAM                 ##
########################################

declare -a ram

# I read somewhere that the data from 0x0 to 0x200 (512) is reserved for things.
for i in {1..511}
do
    ram+=0
done
# The ROM information is copied to the RAM starting at 0x200 (512)
for i in {1..${#inputfile[@]}}
do
    ram+=${inputfile[$i]}
done
# 
for i in {1..$(expr 3584 - ${#inputfile[@]})}
do
    ram+=0
done

echo $ram
echo "RAM LENGTH: ${#ram[@]} (should be 4096)"
# I figured that it would be best if we unset tempvar.
TEMPVAR=""



#Delete variable
inputfile=""

########################################
## MAIN LOOP                          ##
########################################

# I don't think bash does booleans properly, so 0 is not done and 1 is done.
done=0
while [ $done -eq 0 ]
do
    echo "PC = $PC"
    address=$ram[${PC}]
    echo "We're currently at register: $address"
    case ${address:0:1} in
        (0)
            echo "Moving PC to: ${address:1:3}"
            echo "DUDE!"
        ;;
        (1)
            # Format: 1NNN
            # Jumps to address NNN.
            PC=$((16#${address:1:2}${ram[`expr $PC + 1`]:0:2}))
            echo "PC now set to: $PC"
            ;;
        (a)
            # Format: ANNN
            # Sets I to the address NNN.
            I=$((16#${address:1:2}${ram[`expr $PC + 1`]:0:2}))
            echo "I now set to: $I"
            ((PC+=2))
            ;;
        (d)
            # Format: DXYN
            # Pixel drawing. TODO
            echo "Drawing pixels is not yet implemented."
            ((PC+=2))
            ;;
        (2)
            echo "Calling subroutines not implemented yet. Skipping."
            ((PC+=2))
            ;;
        (6)
            # Format: 6XNN
            # Sets data register X to NN.
            nextAddress=${ram[`expr $PC + 1`]:0:2}
            echo "Making data register ${address:1:2} set to $nextAddress"
            reg[`expr $((16#${address:1:2})) + 1`]=$((16#${nextAddress}))
            ((PC+=2))
            ;;
        (rm -rf*) echo "I just dodged a bullet";;
        *)
            echo "Looks like an unknown operation: ${address:0:1}"
            done=1
  ;;
    esac


    if [ $PC -ge 614 ]
    then
        done=1
    fi
done