#!/bin/bash

# source function run_script, install
source "$(dirname "$(realpath "$0")")/inc/ubuntu.sh"

CONFIG_FILE="/etc/ssh/sshd_config"
PRIVATE_KEY_DST="$HOME/.ssh/id_ed25519"
PUBLIC_KEY_DST="$HOME/.ssh/id_ed25519.pub"
AUTHORIZED_KEYS_DST="$HOME/.ssh/authorized_keys"

PRIVATE_KEY_SRC="$SCRIPT_DIR/files/id_ed25519"
AUTHORIZED_KEYS_SRC="$SCRIPT_DIR/files/authorized_keys"
PRIVATE=false

source "$SCRIPT_DIR/inc/args.sh"

# Process options
while true; do
	case "$1" in
		--private|-p)
			PRIVATE=true
			SSH_ID_FILE="$SCRIPT_DIR/.private/id_ed25519"
			SSH_AUTHORIZED_KEYS="$SCRIPT_DIR/.private/authorized_keys"
			shift
			;;
		--identity|-i)
			PRIVATE_KEY_SRC="$2"
			if [ -f "$PRIVATE_KEY_SRC" ]; then
				echo "Missing private key file"
				exit 1
			fi
			shift 2
			;;
		--authorized-keys|-a)
			PRIVATE_KEY_SRC="$2"
			if [ -f "$AUTHORIZED_KEYS_SRC" ]; then
				echo "Missing authorized_keys file"
				exit 1
			fi
			shift 2
			;;
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

# Create the .ssh directory if it doesn't exist
mkdir -p "$HOME/.ssh"

# Copy private key
cp "$PRIVATE_KEY_SRC" "$PRIVATE_KEY_DST"
chmod 0600 "$PRIVATE_KEY_DST"

# Generate public key from private key
ssh-keygen -f "$PRIVATE_KEY_DST" -y > "$PUBLIC_KEY_DST" || {
	echo "Failed to generate public key"
	return 1
}

# Copy authorized_keys
cp "$AUTHORIZED_KEYS_SRC" "$AUTHORIZED_KEYS_DST"
chmod 0600 "$AUTHORIZED_KEYS_DST"

# Update SSH configuration
printf "Editing %s ... " "$CONFIG_FILE"
tempfile=$(mktemp)
awk '
	/[[:space:]]*Port[[:space:]]/ { print "#", $0; next }
	/[[:space:]]*PubkeyAuthentication[[:space:]]/ { print "#" $0; next }
	/[[:space:]]*PasswordAuthentication[[:space:]]/ { print "#" $0; next }
	{ print }
	END {
		print "# approovia settings";
		print "# added by pproovia configuration script";
		print "PubkeyAuthentication yes";
		print "PasswordAuthentication no";
		print "Port 22";
		print "Port 8022";
	}
' "$CONFIG_FILE" > "$tempfile" && sudo mv "$tempfile" "$CONFIG_FILE"
printf "Done.\n"

# Restart SSH service
printf "restarting the ssh service ... "
sudo systemctl restart ssh.service || { echo "Failed to restart SSH service"; return 1; }
printf "Done.\n"

echo "SSH configuration updated successfully."
