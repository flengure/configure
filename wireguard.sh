#!/bin/bash

# Get the script path, directory, and name
SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
SCRIPT_NAME="$(basename "$SCRIPT_PATH")"

# Source functions
#   is_not_run_from_another_script
#   install
#   copy_content
#   run_script
source "$SCRIPT_DIR/inc/ubuntu.sh"

install wireguard jq

# Initialize default values
HOST="client2"
NETWORK=
PREFIX_LENGTH=
PRIVATE=false
SAVE=false
TYPE=client
WG_CONFIG=
WG_CONFIG_FILE="/etc/wireguard/wg0.conf"
WG_ENDPOINT=
WG_INDEX="${HOST##*[a-zA-Z]}"
WG_KEYS="$SCRIPT_DIR/files/keys"
WG_LABEL="client${WG_INDEX}"
WG_LISTEN_PORT=
WG_PEER_COUNT=32
WG_PEERS="$SCRIPT_DIR/files/peers"
WG_PREFIX="${HOST%%[0-9]*}"
WG_PRESHARED_KEY=
WG_PRIVATE_KEY=
WG_PUBLIC_KEY=
WG_TYPE=client
WG_PRESHARED_KEY_FILE="/etc/wireguard/preshared.key"
WG_PRIVATE_KEY_FILE="/etc/wireguard/private.key"
WG_PUBLIC_KEY_FILE="/etc/wireguard/public.key"

# Debugging function
debug_vars() {
    fmt="%-16s : %s\n"
    printf "$fmt" SCRIPT_PATH "$SCRIPT_PATH"
    printf "$fmt" SCRIPT_DIR "$SCRIPT_DIR"
    printf "$fmt" SCRIPT_NAME "$SCRIPT_NAME"
    printf "$fmt" HOST "$HOST"
    printf "$fmt" NETWORK "$NETWORK"
    printf "$fmt" PREFIX_LENGTH "$PREFIX_LENGTH"
    printf "$fmt" PRIVATE "$PRIVATE"
    printf "$fmt" SAVE "$SAVE"
    printf "$fmt" TYPE "$TYPE"
    printf "$fmt" WG_ENDPOINT "$WG_ENDPOINT"
    printf "$fmt" WG_INDEX "$WG_INDEX"
    printf "$fmt" WG_KEYS "$WG_KEYS"
    printf "$fmt" WG_LABEL "$WG_LABEL"
    printf "$fmt" WG_LISTEN_PORT "$WG_LISTEN_PORT"
    printf "$fmt" WG_PEER_COUNT "$WG_PEER_COUNT"
    printf "$fmt" WG_PEERS "$WG_PEERS"
    printf "$fmt" WG_PREFIX "$WG_PREFIX"
    printf "$fmt" WG_PRESHARED_KEY "$WG_PRESHARED_KEY"
    printf "$fmt" WG_PRIVATE_KEY "$WG_PRIVATE_KEY"
    printf "$fmt" WG_PUBLIC_KEY "$WG_PUBLIC_KEY"
	printf "$fmt" WG_TYPE "$WG_TYPE"
}

# Function to display usage instructions
usage() {
    echo "Usage: $0 [options] [host]"
    echo
    echo "Options:"
    echo "  -t, --config-type TYPE         Configuration type: server or client"
    echo "  -c, --peer-count COUNT         Number of peers (1-252)"
    echo "  -p, --private                  Use alternative private file location"
    echo "  -n, --network NETWORK          Network CIDR (e.g., 192.168.0.0/24)"
    echo "  -e, --endpoint ENDPOINT        WireGuard endpoint (e.g., 192.168.0.1:51820)"
    echo "  --preshared-key KEY            Preshared key"
    echo "  --private-key KEY              Private key"
    echo "  --public-key KEY               Public key"
    echo "  -s, --save                     Save changes"
    return 1
}

source "$SCRIPT_DIR/inc/args.sh"

# Process options
while true; do
	case "$1" in
		--type|-t)
			TYPE="${2,,}"
			DNS_TYPE="$TYPE"
			WG_TYPE="$TYPE"
			if [[ ! "$TYPE" =~ ^(server|client)$ ]]; then
				echo "Invalid type: $2"
				echo "Should be either server or client"
				exit 1
			fi
			shift 2
			;;
		--peer-count|-c)
			WG_PEER_COUNT="$2"
			if [[ "$WG_PEER_COUNT" -lt 1 || "$WG_PEER_COUNT" -gt 252 ]]; then
				echo "Peer count must be between 1 and 252"
				exit 1
			fi
			shift 2
			;;
		--private|-p)
			PRIVATE=true
			WG_KEYS="$SCRIPT_DIR/.private/keys"
			WG_PEERS="$SCRIPT_DIR/.private/peers"
			SSH_ID_FILE="$SCRIPT_DIR/.private/id_ed25519"
			#SSH_AUTHORIZED_KEYS="$SCRIPT_DIR/.private/authorized_keys"
			shift
			;;
		--network|-n)
			NETWORK="$2"
			if ! validate_ipv4_cidr "$NETWORK"; then
				echo "Invalid IPv4 CIDR network address: $2"
				echo "Should be of the form --network <ip address>/<prefix length>"
				exit 1
			fi
			shift 2
			;;
		--endpoint|-e)
			WG_ENDPOINT="$2"
			if ! validate_ipv4_endpoint "$WG_ENDPOINT"; then
				echo "Invalid IPv4 endpoint supplied: $2"
				echo "Should be of the form --endpoint <ip address>:<port>"
				exit 1
			fi
			shift 2
			;;
		--preshared-key)
			WG_PRESHARED_KEY="$2"
			if [ -z "$WG_PRESHARED_KEY" ]; then
				echo "Missing preshared key"
				exit 1
			fi
			shift 2
			;;
		--private-key)
			WG_PRIVATE_KEY="$2"
			if [ -z "$WG_PRIVATE_KEY" ]; then
				echo "Missing private key"
				exit 1
			fi
			shift 2
			;;
		--public-key)
			WG_PUBLIC_KEY="$2"
			if [ -z "$WG_PUBLIC_KEY" ]; then
				echo "Missing public key"
				exit 1
			fi
			shift 2
			;;
		--save|-s)
			SAVE=true
			shift
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

# Parse positional arguments
	if [[ "${1,,}" =~ ^[a-z]+[0-9]+$ ]]; then
		HOST="${1,,}"
		WG_PREFIX="${HOST%%[0-9]*}"
		WG_INDEX="${HOST##*[a-zA-Z]}"
		if [[ ! "$HOST" =~ ^[a-z]+(0?[2-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-4])$ ]]; then
			printf "Invalid host specification: %s\n" "$HOST"
			printf "Valid values: %s2, %s3.., %s254\n" "$WG_PREFIX" "$WG_PREFIX" "$WG_PREFIX"
			exit 1
		fi
		shift
	elif [[ "${1,,}" =~ ^[a-z]+$ ]] && [[ "$2" =~ ^[0-9]+$ ]]; then
		WG_PREFIX="${1,,}"
		WG_INDEX="$2"
		HOST="${WG_PREFIX}${WG_INDEX}"
		if [[ ! "$HOST" =~ ^[a-z]+(0?[2-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-4])$ ]]; then
			printf "Invalid host specification: %s\n" "$HOST"
			printf "Valid values: %s2, %s3.., %s254\n" "$WG_PREFIX" "$WG_PREFIX" "$WG_PREFIX"
			exit 1
		fi
		shift 2
	elif [[ "$1" =~ ^[0-9]+$ ]]; then
		WG_INDEX="$1"
		if [[ ! "$WG_INDEX" =~ ^(0?[2-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-4])$ ]]; then
			printf "Index can only be from 2 to 254\n"
			exit 1
		fi
		if [[ "$HOST" == "client2" ]]; then
			WG_PREFIX="client"
			HOST="${WG_PREFIX}${WG_INDEX}"
			shift
		else
			printf "Unexpected argument: %s\n" "$WG_INDEX"
			exit 1
		fi
	fi
	if [[ "${1,,}" == "save" ]]; then
		SAVE=true
		shift
	fi

wg_prefix_from_key_file=$(jq -r '.ClientPrefix' "$WG_KEYS")

if [[ "$TYPE" == "server" ]]; then
	HOST="server"
	if [[ -n "$wg_prefix_from_key_file" ]]; then
		WG_PREFIX="$wg_prefix_from_key_file"
	else
		WG_PREFIX="client"
	fi
	WG_LABEL="server"
else
	WG_PREFIX="${HOST%%[0-9]*}"
	WG_INDEX="${HOST##*[a-zA-Z]}"
	WG_LABEL="client${WG_INDEX}"
	if [[ "$WG_PREFIX" == "client" ]] && [[ -n "$wg_prefix_from_key_file" ]] ; then
		WG_PREFIX="$wg_prefix_from_key_file"
		HOST="${WG_PREFIX}${WG_INDEX}"
	fi
fi

# Check for inconsistencies
if [[ "$TYPE" == "server" ]] && [[ -n "$WG_PUBLIC_KEY" ]]; then
    printf "You cannot specify both PublicKey and config-type server\n"
    printf "Invalid options --config-type server --public-key %s\n" "$WG_PUBLIC_KEY"
    exit 1
fi

[[ -z "$WG_PRESHARED_KEY" ]] && WG_PRESHARED_KEY=$(jq -r '.PresharedKey' "$WG_KEYS")
[[ -z "$NETWORK"          ]] && NETWORK=$(jq -r '.Network' "$WG_KEYS")
[[ -z "$WG_ENDPOINT"      ]] && WG_ENDPOINT=$(jq -r '.Endpoint' "$WG_KEYS")
WG_LISTEN_PORT="${WG_ENDPOINT##*:}"
PREFIX_LENGTH="${NETWORK##*/}"
[[ -z "$WG_PUBLIC_KEY"    ]] && WG_PUBLIC_KEY=$( jq -r '.server.PrivateKey' "$WG_KEYS" | wg pubkey)
[[ -z "$WG_PRIVATE_KEY"   ]] && WG_PRIVATE_KEY=$(jq -r --arg lbl "$WG_LABEL" '.[$lbl].PrivateKey' "$WG_KEYS")
[[ -z "$WG_ADDRESS"       ]] && WG_ADDRESS=$(jq -r --arg lbl "$WG_LABEL" '.[$lbl].Address' "$WG_KEYS")

# debug_vars

config_server() {

	section3=$(sed -e '1{/^[[:space:]]*$/d;}' -e '${/^[[:space:]]*$/d;}' "$WG_PEERS")

	section2=$(while read -r vps prv ipa
		do
			pub=$(printf "%s" "$prv"|wg pubkey)
			index=$(sed -E 's/[^0-9]+//g' <<< "${vps,,}")

			printf "\n[Peer]\n"
			printf "# %s%s\n" "$WG_PREFIX" "$index"
			printf "%-13s = %s\n" PublicKey "$pub"
			printf "%-13s = %s\n" PresharedKey "$WG_PRESHARED_KEY"
			printf "%-13s = %s\n" AllowedIPs "$ipa"
#			printf "PersistentKeepalive = 25\n"
		done <<< "$(jq -c 'to_entries[]' "$WG_KEYS" \
		| awk -F'[:,{}"]+' \
		-v peers="$WG_PEER_COUNT" \
			'$3 ~ /^client/ && $3 != "client1" {
				if (NR > peers) exit;
				print $3,$6,$8
			}'
		)"
	)

	section1=$(
#		pk=$(jq -r '.server.PrivateKey' "$WG_KEYS")
#		ip=$(jq -r '.server.Address' "$WG_KEYS")
		printf "[Interface]\n"
		printf "# server\n"
		printf "%-13s = %s\n"    "ListenPort" "$WG_LISTEN_PORT"
		printf "%-13s = %s\n"    "PrivateKey" "$WG_PRIVATE_KEY"
		printf "%-13s = %s/%s\n" "Address"    "$WG_ADDRESS" "$PREFIX_LENGTH"
	)

	printf "%s\n%s\n\n%s\n" "$section1" "$section2" "$section3"
}

config_client() {
	printf "[Interface]\n"
	printf "# %s\n" "$HOST"
	printf "%-13s = %s\n"    "PrivateKey"   "$WG_PRIVATE_KEY"
	printf "%-13s = %s/%s\n" "Address"      "$WG_ADDRESS" "$PREFIX_LENGTH"
	printf "\n"
	printf "[Peer]\n"
	printf "%-13s = %s\n"    "Endpoint"     "$WG_ENDPOINT"
	printf "%-13s = %s\n"    "PublicKey"    "$WG_PUBLIC_KEY"
	printf "%-13s = %s\n"    "PresharedKey" "$WG_PRESHARED_KEY"
	printf "%-13s = %s\n"    "AllowedIPs"   "$NETWORK"
	printf "PersistentKeepalive = 25\n"
}

[[ "$TYPE" == "client" ]] && WG_CONFIG=$(config_client) || WG_CONFIG=$(config_server)

WG_PUBLIC_KEY=$(wg pubkey <<< "$WG_PRIVATE_KEY")

if [[ "$SAVE" == "true" ]]; then

	copy_content  "$WG_CONFIG"        "$WG_CONFIG_FILE"        sudo
#	copy_content  "$WG_PRIVATE_KEY"   "$WG_PRIVATE_KEY_FILE"   sudo
#	copy_content  "$WG_PUBLIC_KEY"    "$WG_PUBLIC_KEY_FILE"    sudo
#	copy_content  "$WG_PRESHARED_KEY" "$WG_PRESHARED_KEY_FILE" sudo

	sudo systemctl enable wg-quick@wg0.service
	sudo systemctl restart wg-quick@wg0.service
else
	printf "%s\n" "$WG_CONFIG"
fi
