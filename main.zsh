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

# We also need a stack, hooray!
declare -a stack
# Aaand a stack pointer 
sp=1

# There are 15 general purpose registers.
# There is also a 16th register for carry operations.
declare -a reg
for i in {1..16}
do
    reg+=0
done

echo "registers: ${#reg[@]}"

# The screen is 64x32 pixels (2048)
declare -a screen
for i in {1..2048}
do
    screen+=0
done



########################################
## SETTING UP THE RAM                 ##
########################################

declare -a fonts

#fonts=(240 144 144 144 240 32 96 32 32 112 240 16 240 128 240 240 16 240 16 240 144 144 240 16 16 240 128 240 16 240 240 128 240 144 240 240 16 32 64 64 240 144 240 144 240 240 144 240 16 240 240 144 240 144 144 224 144 224 144 224 240 128 128 128 240 224 144 144 144 224 240 128 240 128 240 240 128 240 128 128)
fonts=(
        F0 90 90 90 F0
        20 60 20 20 70 
        F0 10 F0 80 F0 
        F0 10 F0 10 F0
        90 90 F0 10 10
        F0 80 F0 10 F0
        F0 80 F0 90 F0
        F0 10 20 40 40
        F0 90 F0 90 F0
        F0 90 F0 10 F0
        F0 90 F0 90 90 
        E0 90 E0 90 E0
        F0 80 80 80 F0
        E0 90 90 90 E0 
        F0 80 F0 80 F0
        F0 80 F0 80 80 
)

declare -a ram

#Add the fonts to the ram. Exactly 80 characters (0x50)

for i in {1..${#fonts[@]}}
do
    echo $fonts[$i]
    ram+=$fonts[$i]
done

# I read somewhere that the data from 0x0 to 0x200 (512) is reserved for things.
for i in {1..431}
do
    ram+=0
done
echo "RAM LENGTH: ${#ram[@]} (should be 512)"
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
cycles=0
draw=0
while [ $done -eq 0 ]
do
    ## Draw the screen
    #buffer=""
    #for i in {1..32}
    #do
    #    for d in {1..64}
    #    do
    #        buffer+="$screen[`expr $i + $d - 1`]"
    #    done
    #    buffer+="\n"
    #done
    #printf $buffer
    
    if [ $draw -eq 1 ]
    then
        for i in {0..31}; do fmt+="%s"; done; fmt+="\n"; printf "$fmt" "${screen[@]}"
        draw=0
        echo "-----------------------------------------------------"
    fi
    #
    ((cycles+=1))
    if [ $cycles -gt 999999999999999999 ]
    then
        done=1
    fi
    sleep 1


    #echo "PC = $PC"
    address=$ram[${PC}]
    #echo "We're currently at register: $address"
    case ${address:0:1} in
        (0)
            case ${ram[`expr $PC + 1`]:0:2} in
                (ee)
                    #echo "Returning from subroutine."
                    PC=$stack[`expr $sp - 1`]
                    ;;
                (e0)
                    echo "LOL SUPPOSED TO CLEAR THE SCREEN HERE :P"
                    echo "Drawing pixels is not yet implemented."
                    done=1
                    draw=1
                    ((PC+=2))
                    ;;
                *)
                    echo "YOUR NOT SUPPOSED TO TRIGGER"
                    echo "${ram[`expr $PC + 1`]:0:2}"
                    done=1
                    ;;
            esac

        ;;
        (1)
            # Format: 1NNN
            # Jumps to address NNN.
            PC=$((16#${address:1:2}${ram[`expr $PC + 1`]:0:2}))
            #echo "PC now set to: $PC"
            ;;
        (a)
            # Format: ANNN
            # Sets I to the address NNN.
            I=$((16#${address:1:2}${ram[`expr $PC + 1`]:0:2}))
            #echo "I now set to: $I"
            ((PC+=2))
            ;;
        (d)
            # Format: DXYN
            # Pixel drawing. TODO
            #echo "Drawing pixels is not yet implemented."
            nextAddress=$ram[`expr $PC + 1`]
            height=$((16#${nextAddress:1:2}))
            x=$((16#${address:1:2}))
            y=$((16#${nextAddress:0:1}))
            reg[16]=0
            #echo "X = $x y=$y height=$height and the opcode was ${address}${nextOpcode}"
            width=8
            for row in {0..$height}
            do
                sprite=$((16#$ram[`expr $I + $row`]))
                for col in {0..$width}
                do
                    test=""
                    test=$((${sprite} & 128))
                    #echo "$sprite and 120 = $test"
                    if [ $test -gt 0 ]
                    then
                        temp=`expr $y + $row`
                        index=`expr $col + $x + $temp`
                        six=6
                        index=$(($index << $six))
                        tempster=$screen[$index]
                        #echo "Index at screen $screen[$index]"
                        #echo "index: $index"
                        if [ $index -gt 2048 ]
                        then
                            stop=1
                            echo "PC: $PC"
                            echo "I: $I"
                            echo "Reigsters: $reg"
                            
                            #Draw screen
                            echo "Screen: "
                            #printf '%-8s\n' "${screen[@]}"
                            #printf "%s\n" "${screen[@]}"
                            #for i in {0..31}; do fmt+="%s \n"; done; printf "$fmt" "${screen[@]}"
                            for i in {0..31}; do fmt+="%s "; done; fmt+="\n"; printf "$fmt" "${screen[@]}"
                            #echo "Screen: $screen"
                            #buffer=""
                            #for i in {1..32}
                            #do
                            #    for d in {1..64}
                            #    do
                            #        buffer+="$screen[`expr $i + $d - 1`]"
                            #    done
                            #    buffer+="\n"
                            #done
                            #echo $buffer
                            
                            echo "Index: $index"
                        fi
                        if [ $tempster -eq 0 ]
                        then
                            reg[16]=1
                        fi
                        screen[index]=$(($screen[$index] ^ 1))
                        #echo $screen
                    fi
                    
                    #if []
                    #screen[`expr $col + $x + $tmp << 6`]=
                    #vscreen[(i + x + ((y+e)<<6))]
                    #then
                    #    
                    #fi
                done
            #for (col = 0; col < width; col++) {
            #  if ((sprite & 0x80) > 0) {
            #    if (this.screen.setPixel(this.v[x] + col, this.v[y] + row)) {
            #      this.v[0xF] = 1;
            #    }
            #  }
            #
            #
            #  sprite = sprite << 1;
            #}
            done
            
            #done=1
            draw=1
            ((PC+=2))
            ;;
        (2)
            # Format: 2NNN
            # Calls subroutine at NNN.
            stack[sp]=$PC
            ((sp++))
            PC=$((16#${address:1:2}${ram[`expr $PC + 1`]:0:2}))
            #echo "Calling subroutine at address $PC"
            ;;
        (3)
            # Format: 3XNN
            # Skips the next instruction if data register X is equal to NN. 
            register=$reg[`expr $((16#${address:1:2})) + 1`]

            if [ $register -eq $((16#${ram[`expr $PC + 1`]:0:2})) ]
            then
                ((PC+=4))
            else
                ((PC+=2))
            fi
            ;;
        (6)
            # Format: 6XNN
            # Sets data register X to NN.
            nextAddress=${ram[`expr $PC + 1`]:0:2}
            #echo "Making data register ${address:1:2} set to $nextAddress"
            reg[`expr $((16#${address:1:2})) + 1`]=$((16#${nextAddress}))
            ((PC+=2))
            ;;
        (7)
            # Format: 7XNN
            # Adds NN to data register X.
            toAdd=$((16#${ram[`expr $PC + 1`]:0:2}))
            regAddress=`expr $((16#${address:1:2})) + 1`
            #echo "Adding $toAdd to data register #$regAddress which is $reg[$regAddress]"
            added=`expr $toAdd + $reg[$regAddress]`
            # We need to implement integer overflow.
            if [ `expr $added` -ge 255 ]
            then
                reg[$regAddress]=`expr $added - 255`
            else
                reg[$regAddress]=$added
            fi
            #echo "Register is now: $reg[$regAddress]"
            ((PC+=2))
            ;;
        (f)
            # The opcode to rule them all!
            case ${ram[`expr $PC + 1`]:0:2} in
                (29)
                    # Format: FX29
                    # Sets I to the location of the sprite for the character in VX. Characters 0-F (in hexadecimal) are represented by a 4x5 font.
                    data=`expr $((16#${address:1:2})) + 1`
                    I=`expr $reg[$data] \* 5`
                    ((PC+=2))
                    ;;
                (33)
                    # Look up this one, I just copied a pre-made solution.
                    number=$reg[`expr $((16#${address:1:2})) + 1`]
                    #echo "number = $number"
                    #echo "I = $I"
                    for i in {3..1}
                    do
                        #echo "$i"
                        ram[((`expr $I + $i` + 1))]=$((0x`expr $number % 10`))
                        number=`expr $number / 10`
                    done
                    ((PC+=2))
                    ;;
                (65)
                    # Format: FX65
                    # Fills data register 0 to X (including X) with values from memory starting at address I.
                    #echo "reg before" $reg
                    for i in {1..`expr $((16#${address:1:2})) + 1`}
                    do
                        reg[$i]=$ram[`expr $I + $i - 1`]
                    done
                    #echo "reg after" $reg
                    ((PC+=2))
                    ;;
                *)
                    echo "F is unimplemented. Calling: ${address:1:2}${ram[`expr $PC + 1`]:0:2}"
                    done=1
                    ;;
            esac
            ;;
        *)
            echo "Looks like an unknown operation: ${address:0:1}"
            done=1
            ;;
    esac
done

buffer=""
    for i in {1..32}
    do
        for d in {1..63}
        do
            buffer+="$screen[`expr $i + $d`]"
        done
        buffer+="\n"
    done
    echo $buffer