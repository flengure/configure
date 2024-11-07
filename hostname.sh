#!/bin/bash

# Get the directory where the script is located
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
SCRIPT_NAME="$(basename "$(realpath "$0")")"

source "$SCRIPT_DIR/inc/args.sh"

# Process options
while true; do
	case "$1" in
		--)
			shift
			break
			;;
		*)
			if is_direct_execution; then
				echo "Unexpected option: $1"
				usage
				exit 1
			else
				shift
			fi
			;;
	esac
done

# Set default configuration type to 'client' if not provided
HOST="${1:-client}"
if [[ ! "$HOST" =~ ^(server|client|vps[1-9]|vps10)$ ]]; then
  echo "Invalid HOST: $HOST for $SCRIPT_NAME"
  echo "Allowed values are: server, client, vps1, vps2, ..., vps10"
  exit 1
fi

HOSTS_FILE="/etc/hosts"
HOSTNAME_FILE="/etc/hostname"
DOMAIN="apv.lan"
LOOPBACK="127.0.10.10"

# Escape dots for regex
D=$(sed 's/\./\\./g' <<< "$DOMAIN")
L=$(sed 's/\./\\./g' <<< "$LOOPBACK")

# Use grep to check if the pattern exists
if ! grep -qE "^[[:space:]]*${L}[[:space:]]+${HOST}\.${D}[[:space:]]+${HOST}" "$HOSTS_FILE"; then
    echo "Pattern not found in $HOSTS_FILE. Updating file..."

    # Remove any existing lines with the same loopback address
    if sudo sed -i "/^[[:space:]]*${L}[[:space:]]/d" "$HOSTS_FILE"; then
        echo "Removed existing lines with loopback address."
    else
        echo "Failed to remove existing lines. Exiting."
        exit 1
    fi

    # Append the new entry to the hosts file
    if printf "%s\t%s.%s %s\n" "$LOOPBACK" "$HOST" "$DOMAIN" "$HOST" | sudo tee -a "$HOSTS_FILE" > /dev/null; then
        echo "Added new entry to $HOSTS_FILE."
    else
        echo "Failed to append new entry. Exiting."
        exit 1
    fi
else
    echo "Pattern already exists in $HOSTS_FILE. No changes made."
fi

sudo /usr/bin/hostnamectl set-hostname "$HOST"

#if printf "%s\n" "$HOST" | sudo tee "$HOSTNAME_FILE" > /dev/null; then
#        echo "Updated $HOSTNAME_FILE."
#else
#        echo "Failed to update $HOSTNAME_FILE. Exiting."
#        exit 1
#fi

