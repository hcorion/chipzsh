#! /usr/bin/env zsh
echo "test"

## I made it easier on myself and used the following shell utilities:
## - od command for reading the binary from the file.

## Developing notes
# Ram size is 4096, 0x1000 in hex
# All ram values should be stored in hex
# The PC, I, Stack, Stack Pointer, screen and registers should be stored as integers.
# This seems to be a good solution for input: http://stackoverflow.com/questions/24118224/how-to-make-asynchronous-function-calls-in-shell-scripts
# For converting hex to decimal: echo $((16#FF))


# Reading input from file TODO: Add support for different files.
declare -a inputfile
LC_ALL=C inputfile=($(od -t x1 -An brix.ch8))

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

delayTimer=0
speed=1

########################################
## SETTING UP THE RAM                 ##
########################################

declare -a fonts

fonts=(
        f0 90 90 90 f0 # 0
        20 60 20 20 70 # 1
        f0 10 f0 80 f0 # 2
        f0 10 f0 10 f0 # 3
        90 90 f0 10 10 # 4
        f0 80 f0 10 f0 # 5
        f0 80 f0 90 f0 # 6
        f0 10 20 40 40 # 7
        f0 90 f0 90 f0 # 8
        f0 90 f0 10 f0 # 9
        f0 90 f0 90 90 # A
        e0 90 e0 90 e0 # B
        f0 80 80 80 f0 # C
        e0 90 90 90 e0 # D
        f0 80 f0 80 f0 # E
        f0 80 f0 80 80 # F
)

declare -a ram

#Add the fonts to the ram. Exactly 80 characters (0x50)

for i in {1..${#fonts[@]}}
do
    echo $fonts[$i]
    ram+=$fonts[$i]
done

# data from 0x0 to 0x200 (512) is reserved for things. and we already added the font values (512-80=0x50). 
for i in {1..431}
do
    ram+=0
done
# The ROM information is copied to the RAM starting at 0x200 (512)
for i in {1..${#inputfile[@]}}
do
    ram+=${inputfile[$i]}
done

# Fill up the rest of the rom.
for i in {1..$(expr 3584 - ${#inputfile[@]})}
do
    ram+=0
done

echo $ram
echo "RAM LENGTH: ${#ram[@]} (should be 4096)"

#Delete variable
inputfile=""

########################################
## MAIN LOOP                          ##
########################################

# I don't think bash does booleans properly, so 0 is not done and 1 is done.
done=0
cycles=0
draw=0
pause=0
while [ $done -eq 0 ]
do
    ((PC+=2))
    echo "PC: $PC"
    # Drawing the screen.
    if [ $draw -eq 1 ]
    then
        for i in {0..63}; do fmt+="%s"; done; fmt+="\n"; printf "$fmt" "${screen[@]}"
        fmt=""
        draw=0
        echo "-----------------------------------------------------"
    fi

    ((cycles+=1))
    if [ $cycles -gt 999999999999999999 ]
    then
        done=1
    fi
    
    if [ $cycles -ge $speed ]
    then
        cycles=0
        if [ $delayTimer -gt 0 ]
        then
            ((delayTimer-=1))
        fi
    fi
    

    if [ $pause -eq 1 ]
    then
        pause=0
        echo "Press enter when your ready to proceed."
        #read
    fi

    address=$ram[${PC}]
    echo "Opcode: ${address}${ram[`expr $PC + 1`]:0:2}"
    echo "delayTimer: $delayTimer"

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
                    #((PC+=2))
                    ;;
                *)
                    echo "YOUR NOT SUPPOSED TO TRIGGER"
                    echo "Opcode: ${address}${ram[`expr $PC + 1`]:0:2}"
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
            #((PC+=2))
            ;;
        (d)
            # Format: DXYN
            # Pixel drawing. TODO
            # I have no idea how this works (yet) and it doesn't work properly (yet)
            nextAddress=$ram[`expr $PC + 1`]
            height=$((16#${nextAddress:1:2}))
            x=$((16#${address:1:2}))
            y=$((16#${nextAddress:0:1}))
            reg[16]=0
            #echo $height
            #for (( row=0; row<$height; row++ ))
            #do
            #    echo "Number= `expr $I + $row`"
            #    sprite=$((16#$ram[`expr $I + $row`]))
            #    echo "row = $row"
            #    echo "Sprite = $sprite"
            #done
            #done=1
            
            #echo "X = $x y=$y height=$height and the opcode was ${address}${nextAddress}"
            
            for (( row=0; row<$height; row++ ))
            do
                sprite=$((16#$ram[`expr $I + $row`]))
                for col in {0..7}
                do
                    test=$((${sprite} & 128))
                    #echo "$sprite and 120 = $test"
                    if [ $test -gt 0 ]
                    then

                        # Set pixels:
                        xpos=$(($register[$x] + col))
                        ypos=$(($register[$y] + row))
                        #echo "Setting pixel at X $xpos Y $ypos"
                        if [ $ypos -gt 32 ]
                        then
                            done=1
                            echo "Error! ypos is greater than 32, and is $ypos"
                        fi
                        if [ $xpos -gt 64 ]
                        then
                            done=1
                            echo "Error! xpos is greater than 64, and is $xpos"
                        fi
                        location=$(($xpos + $ypos * 64 + 1))
                        #echo "Location: $location"
                        #echo $screen[$location]
                        screen[location]=$(($screen[$location] ^ 1))
                        if [ $screen[$location] -eq 0 ]
                        then
                            reg[16]=1
                        fi
                    fi
                    sprite=$(($sprite << 1))
                done
                
            done
            
            #done=1
            draw=1
            #((PC+=2))
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
                ((PC+=2))
            fi
            #else
            #    ((PC+=2))
            #fi
            ;;
        (6)
            # Format: 6XNN
            # Sets data register X to NN.
            nextAddress=${ram[`expr $PC + 1`]:0:2}
            #echo "Making data register ${address:1:2} set to $nextAddress"
            reg[`expr $((16#${address:1:2})) + 1`]=$((16#${nextAddress}))
            #((PC+=2))
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
            #((PC+=2))
            ;;
        (f)
            # The opcode to rule them all!
            case ${ram[`expr $PC + 1`]:0:2} in
                (07)
                    # Format: FX07
                    # Sets register X to delayTimer
                    reg[`expr $((16#${address:1:2})) + 1`]=$delayTimer
                    ;;
                (15)
                    # Format: FX15
                    # Sets delayTimer to register X
                    delayTimer=$reg[`expr $((16#${address:1:2})) + 1`]
                    ;;
                (29)
                    # Format: FX29
                    # Sets I to the location of the sprite for the character in VX. Characters 0-F (in hexadecimal) are represented by a 4x5 font.
                    data=`expr $((16#${address:1:2})) + 1`
                    
                    I=$(($reg[$data] * 5))
                    if [ $I -gt 255 ]
                    then
                        echo "I is really (too) big."
                        done=1 
                    fi
                    #((PC+=2))
                    ;;
                (33)
                    # Look up this one, I just copied a pre-made solution.
                    number=$reg[`expr $((16#${address:1:2})) + 1`]
                    
                    for i in {3..1}
                    do
                        #echo "$i"
                        printf -v hex "%x" $(( $number % 10 ))
                        #printf '%x\n' $((0x`expr $number % 10`))
                        #ram[((`expr $I + $i` + 1))]=$((0x`expr $number % 10`))
                        ram[((`expr $I + $i` + 1))]=$hex
                        number=`expr $number / 10`
                    done
                    
                    # A check to make sure everything is working.

                    if [ $number -gt 0 ]
                    then
                        done=1
                        echo "Exciting stuff!"
                        echo "hex: $hex"
                        echo "number: $number"
                        echo "I: $I"
                    fi
                    #((PC+=2))
                    ;;
                (65)
                    # Format: FX65
                    # Fills data register 0 to X (including X) with values from memory starting at address I.
                    #echo "reg before" $reg
                    for i in {1..`expr $((16#${address:1:2})) + 1`}
                    do
                        reg[$i]=$((16#$ram[`expr $I + $i - 1`]))
                    done
                    #echo "reg after" $reg
                    #((PC+=2))
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

echo "Stats: "
echo "We went through $cycles cycles."