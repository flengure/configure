#!/bin/bash

# source function run_script, install
source "$(dirname "$(realpath "$0")")/inc/ubuntu.sh"

install dnsmasq

DNS_CONFIG=
DNS_CONFIG_FILE="/etc/dnsmasq.conf"
RESOLVCONF_FILE="/etc/resolv.conf"

DNS_TYPE=client
DOMAIN=
NAMESERVERS=
DNS_KEYS="$SCRIPT_DIR/files/keys"
ADDN_HOSTS="$SCRIPT_DIR/files/addn_hosts"

# Debugging function
debug_vars() {
    fmt="%-16s : %s\n"
    printf "$fmt" SCRIPT_PATH "$SCRIPT_PATH"
    printf "$fmt" SCRIPT_DIR "$SCRIPT_DIR"
    printf "$fmt" SCRIPT_NAME "$SCRIPT_NAME"
	printf "$fmt" DNS_CONFIG_FILE "$DNS_CONFIG_FILE"
	printf "$fmt" DNS_RESOLVCONF_FILE "$DNS_RESOLVCONF_FILE"
	printf "$fmt" DNS_TYPE "$DNS_TYPE"
	printf "$fmt" DOMAIN "$DOMAIN"
	printf "$fmt" NAMESERVERS "$NAMESERVERS"
    printf "$fmt" SAVE "$SAVE"
}

# Function to display usage instructions
usage() {
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  -t, --type TYPE          Specify the type (e.g., 'client' or 'server')"
    echo "  -d, --domain DOMAIN      Specify the domain (e.g., 'example.com')"
    echo "  -n, --nameservers NAMESERVERS"
    echo "                          Specify a comma-separated list of nameservers (e.g., '10.78.16.1,10.78.16.2')"
    echo "  -s, --save               Save changes"
    echo
    exit 1
}

source "$SCRIPT_DIR/inc/args.sh"

# Process options
while true; do
	case "$1" in
		--type|-t)
			DNS_TYPE="${2,,}"
			if [[ ! "$DNS_TYPE" =~ ^(server|client)$ ]]; then
				echo "Invalid type: $2"
				echo "Should be either server or client"
				exit 1
			fi
			shift 2
			;;
		--domain|-d)
			DOMAIN="${2,,}"
			if [[ ! "$DOMAIN" =~ ^.*\..*$ ]]; then
				echo "Invalid Domain: $DOMAIN"
				echo "Should have a dot in it"
				exit 1
			fi
			shift 2
			;;
		--nameservers|-n)
			NAMESERVERS="${2,,}"
			IFS=',' read -r -a ips <<< "$NAMESERVERS"
			for ip in "${ips[@]}"; do
				if ! validate_ip "$ip"; then
					printf "invalid ip address: %s\n" "$ip"
					exit 1
				fi
			done
			shift 2
			;;
		--private|-p)
			PRIVATE=true
			DNS_KEYS="$SCRIPT_DIR/.private/keys"
			ADDN_HOSTS="$SCRIPT_DIR/.private/approovia_hosts"
			shift
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

NAMESERVERS_SAVED=$(jq -r '.Nameservers' "$DNS_KEYS")
DOMAIN_SAVED=$(jq -r '.Domain' "$DNS_KEYS")

[[ -z "$DOMAIN" ]] && [[ -n "$DOMAIN_SAVED" ]] && DOMAIN="$DOMAIN_SAVED"
[[ -z "$NAMESERVERS" ]] && [[ -n "$NAMESERVERS_SAVED" ]] && NAMESERVERS="$NAMESERVERS_SAVED"

if [[ "$DNS_TYPE" == "client" ]]; then
	CONFIG=$(printf "%s\n" "
# Add multiple hosts files
addn-hosts=/etc/hosts
#addn-hosts=\"$ADDN_HOSTS\"

$(
	jq -r '.Nameservers[]' "$DNS_KEYS" | while read -r ip; do
		echo "server=/$DOMAIN/$ip"
	done
)

# Specify DNS servers to forward queries to for other domains
server=8.8.8.8
server=8.8.4.4

# Default domain for unqualified hostnames
expand-hosts
domain=$DOMAIN

# Enable DNS caching for performance
cache-size=1000
"
	)

else
	
	CONFIG=$(printf "%s\n" "
# Set the authoritative domain
local=/$DOMAIN/

# Add multiple hosts files
addn-hosts=/etc/hosts
addn-hosts=/etc/$(basename $ADDN_HOSTS)

# Specify DNS servers to forward queries to for other domains
server=8.8.8.8
server=8.8.4.4

# Default domain for unqualified hostnames
expand-hosts
domain=$DOMAIN

# Enable DNS caching for performance
cache-size=1000
"
	)

fi

RESOLV=$(printf "%s\n" "
search $DOMAIN
$(
    jq -r '.Nameservers[]' "$DNS_KEYS" | while read -r ip; do
        echo "nameserver $ip"
    done
)
"
)

# Update hosts file if necessary
sudo cp "$ADDN_HOSTS" "/etc/$(basename "$ADDN_HOSTS")"
copy_content "$CONFIG" "$DNS_CONFIG_FILE" sudo

# delete existing /etc/resolv.conf
sudo rm -f /etc/resolv.conf

copy_content "$RESOLV" "$RESOLVCONF_FILE" sudo

# stop systemd-resolved if running
if systemctl is-active --quiet systemd-resolved; then
    sudo systemctl stop systemd-resolved
fi

# disable systemd-resolved if enabled
if systemctl is-enabled --quiet systemd-resolved; then
    sudo systemctl disable systemd-resolved
fi

# restart dnsmasq
sudo systemctl restart dnsmasq.service


printf "%s\n" "Finished configuring dnsmasq."

