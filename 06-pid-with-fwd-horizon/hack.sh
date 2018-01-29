#!/bin/bash
source ~/.bashrc
export LD_LIBRARY_PATH=''
echo "$@"
gnome-terminal --command="\"$@\""