#!/bin/bash

config_file=$HOME/.config/hypr/UserConfigs/UserDefaults.conf

if [[ ! -f "$config_file" ]]; then
    echo "Error: Configuration file not found!"
    exit 1
fi

get_config() {
    local var_name="$1"
    grep "^\s*\$$var_name\s*=" "$config_file" | sed 's/^.*=//;s/#.*//' | xargs | sed 's/^"//;s/"$//'
}

term=$(get_config "term")
files=$(get_config "files")

[ -z "$term" ] && term="kitty"
[ -z "$files" ] && files="nautilus"

if [[ "$1" == "--btop" ]]; then
    $term --title btop sh -c 'btop'
elif [[ "$1" == "--nvtop" ]]; then
    $term --title nvtop sh -c 'nvtop'
elif [[ "$1" == "--nmtui" ]]; then
    $term nmtui
elif [[ "$1" == "--term" ]]; then
    $term &
elif [[ "$1" == "--files" ]]; then
    $files &
else
    echo "Usage: $0 [--btop | --nvtop | --nmtui | --term]"
    echo "--btop       : Open btop in a new term"
    echo "--nvtop      : Open nvtop in a new term"
    echo "--nmtui      : Open nmtui in a new term"
    echo "--term       : Launch a term window"
    echo "--files      : Launch a file manager"
fi