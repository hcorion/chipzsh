## chipzsh

A chip-8 emulator written in Bash

This script was developed in Zsh, and doesn't work with other shells like sh or bash.

Some command line tools that are required are:
- od (for reading the binary of the file)
- env located at /usr/bin/env ( for getting zsh )
- zsh, because the script is run in zsh.

### Notes

- Ram size is 4096, 0x1000 in hex
- In this emulator all ram values are stored in hex
- In this emulator the PC, I, Stack, Stack Pointer, screen and registers are stored as integers.