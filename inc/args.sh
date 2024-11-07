#!/bin/bash

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [host]

Options:
  -a, --authorized_keys FILE ssh authorized_keys file
  -c, --peer-count COUNT     Number of peers (1-252)
  -d, --domain DOMAIN        Specify the domain name
  -e, --endpoint ENDPOINT    WireGuard endpoint (e.g., 192.168.0.1:51820)
  -i, --identity FILE        ssh identity file
  -p, --private              Use alternative private file location
  -n, --network NETWORK      Network CIDR (e.g., 192.168.0.0/24)
  -s, --save                 Save the configuration
  -t, --type TYPE            Specify the type (e.g., client, server)
  --nameservers NAMESERVERS  Comma-separated list of nameservers
  --preshared-key KEY        Wireguard Preshared key
  --private-key PRIVATE_KEY  Wireguard Private key
  --public-key PUBLIC_KEY    Wireguard Server Public key

Examples:
  $(basename "$0") --type client --peer-count 3 --private --domain example.com fred2
  $(basename "$0") -p vps5

EOF
    exit 1
}

# Function to map aliases to canonical long options
map_aliases() {
    local args=("$@")    # Accept arguments as an array
    local mapped_args=() # Initialize an empty array for mapped arguments

    # Iterate over each argument
    for arg in "${args[@]}"; do
        case "$arg" in
            --authkeys)
                mapped_args+=(--authorized-keys)
                ;;
            --commit)
                mapped_args+=(--save)
                ;;
            --ns)
                mapped_args+=(--nameservers)
                ;;
            --pubkey)
                mapped_args+=(--public-key)
                ;;
            --privkey|--pk)
                mapped_args+=(--private-key)
                ;;
            --psk)
                mapped_args+=(--preshared-key)
                ;;
            *)
                mapped_args+=("$arg")
                ;;
        esac
    done

	echo "${mapped_args[@]}"

}

eval set -- "$(map_aliases "$@")"

# Parse command-line arguments using getopt
OPTIONS=$(
	getopt \
	-o psa:c:d:e:i:n:t: \
	--long type:,peer-count:,private,network:,endpoint:,preshared-key:,private-key:,public-key:,save,domain:,nameservers:,identity:,authorized_keys: \
	-- "$@"
)

# Check for errors in getopt parsing
if [ $? -ne 0 ]; then
	usage
fi

# Set the parsed options
eval set -- "$OPTIONS"

