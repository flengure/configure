#!/bin/bash

###############################################################################
# ip.sh - IP Address Manipulation and Validation Functions
#
# This script contains functions for validating, converting, and manipulating
# IP addresses (both IPv4 and IPv6) and CIDR networks. It is intended to be
# sourced by other scripts to provide IP-related functionality.
#
# Functions:
#   - validate_ipv4: Validates an IPv4 address.
#   - validate_ipv6: Validates an IPv6 address.
#   - validate_ip: Validates an IP address (either IPv4 or IPv6).
#   - ip_to_decimal: Converts an IPv4 address to its decimal representation.
#   - decimal_to_ip: Converts a decimal value to an IPv4 address.
#   - validate_cidr: Validates a CIDR network address.
#   - validate_network_endpoint: Validates a network endpoint (IP address and port).
#   - get_network_address: Calculates the network address of a given CIDR.
#   - calculate_hosts: Calculates the number of usable hosts in a CIDR network.
#   - get_ip_by_index: Retrieves an IP address offset by a given index from the network address in a CIDR network.
#
# Usage:
# Source this script in your script using:
#   source /path/to/ip.sh
#
# Example:
#   source /path/to/ip.sh
#   if validate_ipv4 "192.168.1.1"; then
#     echo "Valid IPv4 address"
#   fi
###############################################################################

# Function to validate an IPv4 address
# Arguments:
#   $1 - The IP address to validate
# Returns:
#   0 if the address is a valid IPv4 address, 1 otherwise
validate_ipv4() {
    local ip="$1"
    local ipv4_regex='^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'
    [[ "$ip" =~ $ipv4_regex ]]
}

# Function to validate an IPv6 address
# Arguments:
#   $1 - The IP address to validate
# Returns:
#   0 if the address is a valid IPv6 address, 1 otherwise
validate_ipv6() {
    local ip="$1"
    local ipv6_regex='^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:(:[0-9a-fA-F]{1,4}){1,7}|::(ffff(:0{1,4}){0,1}:){0,1}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'
    [[ "$ip" =~ $ipv6_regex ]]
}

# Function to validate an IP address (either IPv4 or IPv6)
# Arguments:
#   $1 - The IP address to validate
# Returns:
#   0 if the address is a valid IPv4 or IPv6 address, 1 otherwise
validate_ip() {
    local ip="$1"
    
    if validate_ipv4 "$ip"; then
        echo "Valid IPv4 address"
        return 0
    elif validate_ipv6 "$ip"; then
        echo "Valid IPv6 address"
        return 0
    else
        echo "Invalid IP address format"
        return 1
    fi

}

# Converts an IP address to its decimal representation
# Usage: ip_to_decimal <IP_ADDRESS>
# Example: ip_to_decimal 10.45.37.128
# Output: Decimal representation of the IP address
ip_to_decimal() {
    local ip="$1"
    local IFS=.
    read -r i1 i2 i3 i4 <<< "$ip"
    echo $(( (i1 << 24) + (i2 << 16) + (i3 << 8) + i4 ))
}

# Converts a decimal representation to an IP address
# Usage: decimal_to_ip <DECIMAL_VALUE>
# Example: decimal_to_ip 1742515968
# Output: IP address in dotted-decimal notation
decimal_to_ip() {
    local decimal="$1"
    echo "$(( (decimal >> 24) & 255 )).$(( (decimal >> 16) & 255 )).$(( (decimal >> 8) & 255 )).$(( decimal & 255 ))"
}

# Function to validate an IPv4 CIDR network address
# Usage: validate_ipv4_cidr <CIDR_ADDRESS>
# Example: validate_ipv4_cidr 192.168.10.0/24
validate_ipv4_cidr() {
    local cidr="$1"

    # Check if the CIDR matches the pattern
    if [[ "$cidr" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
        # Extract the IP and prefix length
        local ip="${cidr%/*}"
        local prefix="${cidr##*/}"

        # Validate IP address format
        if validate_ipv4 "$ip"; then
            # Validate prefix length (0-32)
            if [[ "$prefix" -ge 0 && "$prefix" -le 32 ]]; then
                echo "Valid IPv4 CIDR address"
                return 0
            fi
        fi
    fi

    echo "Invalid IPv4 CIDR address"
    return 1
}

# Function to validate an IPv6 CIDR network address
# Usage: validate_ipv6_cidr <CIDR_ADDRESS>
# Example: validate_ipv6_cidr 2001:db8::/32
validate_ipv6_cidr() {
    local cidr="$1"

    # Check if the CIDR matches the pattern
    if [[ "$cidr" =~ ^[0-9a-fA-F:]+\.[0-9a-fA-F:]+/[0-9]+$ ]]; then
        # Extract the IP and prefix length
        local ip="${cidr%/*}"
        local prefix="${cidr##*/}"

        # Validate IP address format
        if validate_ipv6 "$ip"; then
            # Validate prefix length (0-128)
            if [[ "$prefix" -ge 0 && "$prefix" -le 128 ]]; then
                echo "Valid IPv6 CIDR address"
                return 0
            fi
        fi
    fi

    echo "Invalid IPv6 CIDR address"
    return 1
}

# Function to validate a CIDR network address (either IPv4 or IPv6)
# Usage: validate_cidr <CIDR_ADDRESS>
# Example: validate_cidr 192.168.10.0/24
validate_cidr() {
    local cidr="$1"
    
    if validate_ipv4_cidr "$cidr"; then
        echo "Valid CIDR address"
        return 0
    elif validate_ipv6_cidr "$cidr"; then
        echo "Valid CIDR address"
        return 0
    else
        echo "Invalid CIDR address"
        return 1
    fi
}


# Example usage
#validate_cidr "192.168.10.0/24"
#validate_cidr "10.0.0.0/33"   # Invalid example
#!/bin/bash

# Function to validate a network endpoint
# Usage: validate_network_endpoint <ENDPOINT>
# Example: validate_network_endpoint 10.78.65.67:443
validate_network_endpoint() {
    local endpoint="$1"

    # Check if the endpoint matches the pattern
    if [[ "$endpoint" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]{1,5}$ ]]; then
        # Extract the IP address and port number
        local ip="${endpoint%%:*}"
        local port="${endpoint##*:}"

        # Validate IP address format
        if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
            local IFS='.'
            read -r i1 i2 i3 i4 <<< "$ip"
            if [[ "$i1" -le 255 && "$i2" -le 255 && "$i3" -le 255 && "$i4" -le 255 ]]; then
                # Validate port number (1-65535)
                if [[ "$port" -ge 1 && "$port" -le 65535 ]]; then
                    echo "Valid network endpoint"
                    return 0
                fi
            fi
        fi
    fi

    echo "Invalid network endpoint"
    return 1
}

# Example usage
# validate_network_endpoint "10.78.65.67:443"
# validate_network_endpoint "192.168.1.1:70000"   # Invalid example



# Calculates the network address of the given CIDR
# Usage: get_network_address <CIDR_NETWORK>
# Example: get_network_address 10.45.37.128/25
# Output: Network address
get_network_address() {
    local cidr="$1"
    local network="${cidr%/*}"
    local prefix="${cidr##*/}"
    local ip_decimal
    ip_decimal=$(ip_to_decimal "$network")
    local mask_decimal
    mask_decimal=$(( (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF ))
    local network_decimal
    network_decimal=$(( ip_decimal & mask_decimal ))
    decimal_to_ip "$network_decimal"
}

# Calculates the number of usable hosts in a CIDR network
# Usage: calculate_hosts <CIDR_NETWORK>
# Example: calculate_hosts 10.45.37.128/25
# Output: Number of usable hosts (excluding network and broadcast addresses)
calculate_hosts() {
    local cidr="$1"
    
    # Validate CIDR format
    if ! validate_cidr "$cidr"; then
        echo "Invalid CIDR format."
        return 1
    fi

    local prefix="${cidr##*/}"
    local subnet_bits=$((32 - prefix))
    local total_hosts=$((2 ** subnet_bits))
    local usable_hosts=$((total_hosts - 2))
    echo "$total_hosts"
}

# Retrieves an IP address offset by a given index from the network address in a CIDR network
# Usage: get_ip_by_index <CIDR_NETWORK> <INDEX>
# Example: get_ip_by_index 10.45.37.128/25 10
# Output: IP address offset by the index from the network address
get_ip_by_index() {
    local cidr="$1"
    local index="$2"
    
    # Validate CIDR format
    if ! validate_cidr "$cidr"; then
        echo "Invalid CIDR format."
        return 1
    fi

    local network
    network=$(get_network_address "$cidr")
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    local usable_hosts
    usable_hosts=$(calculate_hosts "$cidr")
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    if [[ "$index" -lt 0 || "$index" -ge "$usable_hosts" ]]; then
        echo "Index out of range. Valid range is 0 to $((usable_hosts - 1))."
        return 1
    fi
    
    # Convert network address to decimal
    local network_decimal
    network_decimal=$(ip_to_decimal "$network")
    
    # Calculate the decimal representation of the resulting IP address
    #local ip_decimal=$((network_decimal + index + 1))  # Adding 1 to account for the network address
    local ip_decimal=$((network_decimal + index))

    # Convert the decimal representation back to IP address
    local ip_address
    ip_address=$(decimal_to_ip "$ip_decimal")
    
    echo "$ip_address"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	if [ -n "$2" ]; then
		get_ip_by_index	"$1" "$2"
	elif [ -n "$1" ]; then
		calculate_hosts	"$1"
	fi
fi
# Example usage:
# Uncomment the following lines to test the functions
# echo "Number of usable hosts in 10.45.37.128/25: $(calculate_hosts 10.45.37.128/25)"
# echo "IP address at index 0 in 10.45.37.0/24: $(get_ip_by_index 10.45.37.128/24 0)"

