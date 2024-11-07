#!/bin/bash

wg_keys() {
	# Parse command-line arguments
	local network
	local index

	while [[ $# -gt 0 ]]; do
		if [[ "$1" =~ ^(([0-9]{1,3}\.){3}[0-9]{1,3})\/([0-9]|[1-9][0-9]|3[0-2])$ ]]; then
			network="$1"
			shift
		elif [[ "$1" =~ ^[0-9]+$ ]]; then
			index="$1"
			shift
		else 
			shift
		fi
	done

	if [ -z "$network" ]; then
		printf "Usage: %s <CIDR_NETWORK> [index]\n" "${FUNCNAME[0]}"
		return 1
	fi

	local script_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
	local ip_sources
	if [ -f "$script_dir/ip.sh" ]; then
		ip_sources="$script_dir/ip.sh"
	elif [ ! -f "$script_dir/inc/ip.sh" ]; then
		ip_sources="$script_dir/inc/ip.sh"
	else
		printf "%s\n" "ip.sh source routine file not found.."
		return 1
	fi
	source "$ip_sources"
	
    # Validate CIDR format
    if ! validate_cidr "$network"; then
        echo "Invalid CIDR format."
        return 1
    fi

	local max_hosts=$(calculate_hosts "$network")
	
	local count=1
	
	printf "{\n"
	printf "  \"Network\": \"%s\",\n" "$network"
	printf "  \"PresharedKey\": \"%s\",\n" "$(wg genpsk)"

	# Loop through the number of hosts
	while [ "$count" -le "$index" ] && [ "$count" -le "$max_hosts" ]; do
		# Get the IP address for the current index
		local ip
		ip=$(get_ip_by_index "$network" "$count")

		# printf "ip: %s, index: %s\n" "$ip" "$count"

		# Perform some action with the IP address (e.g., print it)
		printf "  \"vps%s\": {\n" $count
		printf "    \"PrivateKey\": \"%s\",\n" "$(wg genkey)"
		printf "    \"Address\": \"%s\"\n" "$ip"
		printf "  }"
		if [ $count -lt $max_hosts ]; then
			printf ",\n"
		else
			printf "\n"
		fi

		# Increment the count
		count=$((count + 1))
	done
	printf "}\n"
}

#if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	wg_keys "$@"
#fi
