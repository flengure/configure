#!/bin/bash

# source functions
# ubuntu:install
# ubuntu:tools:run_script
source "$(dirname "$(realpath "$0")")/inc/ubuntu.sh"

HOST="client2"

# Check if inside a byobu session
is_inside_byobu() { [ -n "$TMUX" ] || [ -n "$STY" ] && return 0 || return 1; }


# Script to run
script="$SCRIPT_DIR/run.sh"

# Check if byobu is installed
install byobu

# Convert arguments to a single quoted string
args_quoted=$(printf "%q " "$@")

# Main logic
if is_inside_byobu; then
    # Inside byobu session, just run the main script with all arguments
    echo "Running '$script $args_quoted' in the current byobu session."
    run_script run "$@"
else
    # Check if the default byobu session exists
    if byobu list-sessions | grep -q "default"; then
        # If the default session exists, create a new window (tab)
        echo "Creating a new window in the existing 'default' byobu session."
        byobu new-window -t default:1 -n "RunScript"
        
        # Run the main script in the new window with all arguments
        echo "Sending command to the new window in the 'default' byobu session."
        byobu send-keys -t default:1 "$script $args_quoted" C-m
    else
        # Create a new default byobu session if it does not exist
        echo "Creating new byobu session 'default'..."
        byobu new-session -d -s default
        
        # Run the main script in the new session
        echo "Sending command to the new 'default' byobu session."
        byobu send-keys -t default "$script $args_quoted" C-m
    fi
    if [ -t 1 ]; then
        echo "Attaching to the byobu session."
        byobu attach -t default
    else
        echo "Not attaching to byobu session; not running interactively."
    fi

fi

