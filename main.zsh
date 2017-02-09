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

function getRandom()
{
    # By setting the internet to 1 it becomes very slow to generate random numbers
    # and requires an internet connection but you get the very best random numbers.
    return 15
    internet=1
    if [ $internet -eq 1 ]
    then
        return $(curl -s "https://www.random.org/integers/?num=1&min=0&max=255&col=1&base=10&format=plain&rnd=new")
    else
        return $(( RANDOM % 255 ))
    fi
}

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
maxCycles=3500
actualCycles=0
rm ./brix-${maxCycles}-mine.txt 
while [ $done -eq 0 ]
do

    
    #echo "PC: $PC"
    
    # Drawing the screen.
    if [ $draw -eq 1 ]
    then
        for i in {0..63}
        do
            fmt+="%s"
        done
        fmt+="\n"
        printf -v new "$fmt" "${screen[@]}"
        new=${new//1/█}
        echo "${new//0/ }"
        #█
        #echo "fmt: $fmt"

        fmt=""
        draw=0
        echo "-----------------------------------------------------"
    fi

    ((cycles+=1))
    ((actualCycles+=1))
    if [ $actualCycles -gt $maxCycles ]
    then
        exit
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
        echo "Press any key when your ready to proceed."
        read -q
    fi

    address=$ram[${PC}]
    

    #echo "Opcode: ${address}${ram[`expr $PC + 1`]:0:2}"
    
    echo "${address}${ram[`expr $PC + 1`]:0:2}" &>> brix-${maxCycles}-mine.txt 
    #echo "delayTimer: $delayTimer"

    case ${address:0:1} in
        (0)
            case ${ram[`expr $PC + 1`]:0:2} in
                (ee)
                    #echo "Returning from subroutine."
                    ((sp-=1))
                    PC=$stack[$sp] # $(($sp - 1))]
                    echo "Returning from subroutine to opcode: ${ram[$PC]:0:2}${ram[`expr $PC + 1`]:0:2}"
                    #$((PC-=2))
                    #echo ""
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
            ((PC-=2))
            #echo "PC now set to: $PC"
            ;;
        (2)
            # Format: 2NNN
            # Calls subroutine at NNN.
            stack[sp]=$PC
            ((sp++))
            PC=$((16#${address:1:2}${ram[`expr $PC + 1`]:0:2}))
            ((PC-=2))
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
        (4)
            # Format: 4XNN
            # Skips the next instruction if data register X is not equal to NN. 
            register=$reg[`expr $((16#${address:1:2})) + 1`]

            if [ $register -ne $((16#${ram[`expr $PC + 1`]:0:2})) ]
            then
                ((PC+=2))
            fi
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
            if [ `expr $added` -gt 255 ]
            then
                reg[$regAddress]=`expr $added - 255`
            else
                reg[$regAddress]=$added
            fi
            #echo "Register is now: $reg[$regAddress]"
            #((PC+=2))
            ;;
        (8)
            # The mega math opcode
            nextAddress=${ram[`expr $PC + 1`]}
            case ${nextAddress:1:2} in
                (0)
                    # Format 8XY0
                    # Sets register X to register Y.
                    x=`expr $((16#${address:1:2})) + 1`
                    y=`expr $((16#${nextAddress:0:1})) + 1`
                    reg[$x]=$reg[$y]
                    ;;
                (2)
                    # Format 8XY2
                    # Sets register X to register X AND register Y. (Bitwise AND operation)
                    x=`expr $((16#${address:1:2})) + 1`
                    y=`expr $((16#${nextAddress:0:1})) + 1`
                    reg[$x]=$(($reg[$x] & $reg[$y]))
                    ;;
                (4)
                    # Format 8XY4
                    # Adds register Y to register X. Register 16 (carry flag) is set to 1 when there's a carry, and to 0 when there isn't.
                    x=`expr $((16#${address:1:2})) + 1`
                    y=`expr $((16#${nextAddress:0:1})) + 1`

                    added=`expr $reg[$x] + $reg[$y]`
                    
                    # We need to implement integer overflow.
                    if [ $added -gt 255 ]
                    then
                        reg[$x]=`expr $added - 256`
                        reg[16]=1
                    else
                        reg[$x]=$added
                        reg[16]=0
                    fi
                    ;;
                (5)
                    # Format 8XY5
                    # register Y is subtracted from register X. register 16 (carry flag) is set to 0 when there's a borrow, and 1 when there isn't.
                    x=`expr $((16#${address:1:2})) + 1`
                    y=`expr $((16#${nextAddress:0:1})) + 1`

                    sub=`expr $reg[$x] - $reg[$y]`
                    
                    # We need to implement integer overflow.
                    if [ $sub -lt 0 ]
                    then
                        reg[$x]=`expr $sub + 256`
                        reg[16]=1
                    else
                        reg[$x]=$sub
                        reg[16]=0
                    fi
                    ;;
                (6)
                    # Format 8XY6
                    # Shifts register X right by one. Register 16 (carry flag) is set to the value of the least significant bit of VX before the shift.
                    x=`expr $((16#${address:1:2})) + 1`
                    y=`expr $((16#${nextAddress:0:1})) + 1`
                    
                    reg[16]=$(($reg[$x] & 1))
                    reg[$x]=$(($reg[$x] >> 1))
                    ;;
                *)
                    done=1
                    echo "ERROR! Unimplemented math opcode called: ${address}${nextAddress}"
                    ;;
            esac

            ;;
        (a)
            # Format: ANNN
            # Sets I to the address NNN.
            I=$((16#${address:1:2}${ram[`expr $PC + 1`]:0:2}))
            #echo "I now set to: $I"
            #((PC+=2))
            ;;
        (c)
            # Format: CXNN
            # Set register X = random byte AND NN.
            getRandom
            random=$?
            nextAddress=$((16#$ram[`expr $PC + 1`]))
            reg[`expr $((16#${address:1:2})) + 1`]=$(($random & $nextAddress))
            ;;
        (d)
            # Format: DXYN
            # Pixel drawing. 
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
                        xpos=$(($reg[$(($x+1))] + col))
                        ypos=$(($reg[$(($y+1))] + row))
                        #echo "Setting pixel at X $xpos Y $ypos"
                        if [ $ypos -gt 32 ]
                        then
                            done=1
                            echo "Error! ypos is greater than 32, and is $ypos"
                        fi
                        
                        columns=64
                        if [ $xpos -ge 64 ]
                        then
                            while [ $xpos -ge $columns ]
                            do
                                ((xpos-=1))
                            done

                        fi
                        location=$(($xpos + ( $ypos * $columns ) + 1))
                        if [ $location -gt 2048 ]
                        then
                            done=1
                            echo "ERROR, ERROR!"
                            echo "location: $location"
                            echo "ypos: $ypos"
                            echo "xpos: $xpos"
                        fi
                        #echo "Location: $location"
                        #echo $screen[$location]
                        previous=$screen[$location]
                        screen[location]=$(($screen[$location] ^ 1))
                        if [[ $previous -eq 1 && $screen[$location] -eq 0 ]]
                        then
                            echo "Sprite collision!"
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
        (e)
            # Format: EX9E or EXA1
            nextAddress=$ram[`expr $PC + 1`]
            if [ "$nextAddress" = "9e" ]
            # Skips the next instruction if the key stored in register X is pressed.
            then
                # TODO: ACTUALLY implement
                #((PC+=2))
                echo "Warning, nothing actually happens here."
                
            elif [ "$nextAddress" = "a1" ]
            # Skips the next instruction if the key stored in register X isn't pressed.
            then
                # TODO: ACTUALLY implement
                echo "Warning, nothing actually happens here."
                ((PC+=2))
            else
                done=1
                echo "Error! Unkown opcode was called: ${address}${nextAddress}"
            fi
            #done=1
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
                (18)
                    # Format: FX18
                    # Something to do with sound
                    # TODO: Actually implement
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
                    # Format FX33
                    # Store BCD representation of register X in memory locations I, I+1, and I+2.
                    # Here is a good explanation: https://github.com/AfBu/haxe-CHIP-8-emulator/wiki/(Super)CHIP-8-Secrets#understanding-of-store-bcd-instruction
                    number=$reg[`expr $((16#${address:1:2})) + 1`]
                    
                    # All values stored in RAM need to be hex, so we need to convert it back into hexadecimal.
                    printf -v hex "%x" $(( $number / 100 ))
                    ram[(($I))]=$hex

                    printf -v hex "%x" $(( $number % 100 /10 ))
                    ram[(($I + 1))]=$hex

                    printf -v hex "%x" $(( $number % 10 ))
                    ram[(($I + 2))]=$hex
                    
                    # A check to make sure everything is working.
                    if [ $number -gt 0 ]
                    then
                        pause=1
                        echo "Exciting stuff!"
                        echo "hex: $hex"
                        echo "number: $number"
                        echo "I: $I"
                        echo "value 1: $ram[$I]"
                        echo "value 2: $ram[(($I + 1))]"
                        echo "value 3: $ram[(($I + 2))]"
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

    ((PC+=2))
done

echo "Stats: "
echo "We went through $cycles cycles."