#!/bin/bash

# ubuntu.sh
#
# Description:
# This script contains common functions and utilities specific to Ubuntu systems.
# It includes functions for installing packages, updating package repositories,
# and cleaning up old kernels.
#
# Functions:
# - install: Installs specified packages and handles special cases for Docker, dnsmasq,
#   and sslh. It provides options for updating package repositories and running apt in
#   different modes.
# - update: Updates package repositories.
# - cleanup_old_kernels: Removes old kernel packages that are no longer needed.
#
# Author:
# Tonye George (2024)
#
# Usage:
# Source this script in your shell or other scripts to access the provided functions.
# Example:
#   source /path/to/ubuntu.sh
#   install -u -v package1 package2
#   update -v
#   cleanup_old_kernels

# Common variables & functions

# functions contains_element, remove_element

file="inc/common.sh"
for base_path in \
	"$(dirname "$(realpath "$0")")" \
	"$(dirname "$(realpath "${BASH_SOURCE[0]}")")"; do
    file_path="$base_path/$file"
    if [[ -f "$file_path" ]]; then
        source "$file_path"
        break
    fi
done



#f1="$(dirname "$(realpath "$0")")/$f0"
#f2="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/$f0"
#
#if [[ -f "$f1" ]]; then
#	source "$f1"
#elif [[ -f "$f2" ]]; then
#	source "$f2"
#else
#	printf "%s not found.\n"
#	exit 1
#fi
#
#
#if [[ -f "$(dirname "$(realpath "$0")")/inc/common.sh"
#source "$(dirname "$(realpath "$0")")/inc/common.sh" || {
#	f=$(find -type f -wholename *inc/common.sh)
#	if [[ -z "$f" ]]; then
#		exit 1
#	fi
#	if [[ "$(echo "$f" | wc -l)" -gt 1 ]]; then
#		exit 1
#	fi
#	source "$f"
#}

# Name: install
# Description: This function installs specified packages and manages system dependencies.
# It handles special cases for Docker, dnsmasq, and sslh, including setting up Docker repositories
# and handling systemd-resolved interactions for dnsmasq.
# Options:
#   -u, --update           Update package repositories before installing.
#   -v, --verbose          Run apt with verbose output (removes -qq option).
#   -i, --interactive      Run apt in interactive mode (removes DEBIAN_FRONTEND=noninteractive).
# Packages:
#   A list of packages to install. Special handling is done for "dnsmasq" and "sslh".
# Example Usage:
#   install -u -v package1 package2

install() {
	local script_name=$(basename "$0")
	local function_name="${FUNCNAME[0]}"
	local fn=$(printf "%s:%s:" "$script_name" "$function_name")

	usage() {
		cat <<EOF
Usage: $(basename "$0") [OPTIONS] [PACKAGES...]
Install packages and manage system dependencies.

Options:
  -u, --update           Update package repositories before installing.
  -v, --verbose          Run apt with verbose output.
  -i, --interactive      Run apt in interactive mode.

PACKAGES:
  List of packages to install. If "dnsmasq" is specified and systemd-resolved is running, it will be stopped and disabled.

Example:
  $(basename "$0") -u -v package1 package2
EOF
	}

	local update=false
	local verbose=" -qq"
	local interactive=" DEBIAN_FRONTEND=noninteractive"

	local options
	options=$(getopt -o uvi --long update,verbose,interactive -- "$@") || {
		usage
		return 1
	}
	eval set -- "$options"

	while true; do
		case "$1" in
			--update|-u)
				update=true
				shift
				;;
			--verbose|-v)
				verbose=""
				shift
				;;
			--interactive|-i)
				interactive=""
				shift
				;;
			--)
				shift
				break
				;;
			*)
				printf "%s %s: Unexpected option: %s\n" "$script_name" "$function_name" "$1" >&2
				usage
				return 1
				;;
		esac
	done

	local packages_to_install="$@"

	if [[ -z "$packages_to_install" ]]; then
		printf "%s %s: No packages specified.\n" "$fn" "$script_name"
		usage
		return 1
	fi

	local installed_packages
	installed_packages=$(dpkg -l | awk '/^ii/{print $2}')

	local missing_packages
	missing_packages=$(awk 'NR==FNR { installed[$1]; next } !($1 in installed)' \
		<(echo "$installed_packages") <(echo "$packages_to_install" | tr " " "\n"))

	if [[ -z "$missing_packages" ]]; then
		printf "%s %s: All packages already installed.\n" "$fn" "$packages_to_install"
		return 0
	fi

	local should_install_docker=$(contains_element "docker" "$missing_packages")
	local should_install_dnsmasq=$(contains_element "dnsmasq" "$missing_packages")
	local should_install_sslh=$(contains_element "sslh" "$missing_packages")



	docker_before_update() {

		missing_packages=$(remove_element "docker" "$missing_packages" | tr "\n" " ")

		for pkg in docker-ce docker-ce-cli containerd.io; do
			if [[ "$(contains_element "$pkg" "$missing_packages")" == "false" ]]; then
				missing_packages="$missing_packages $pkg"
			fi
		done

		curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
			| sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

		docker_repo_file="/etc/apt/sources.list.d/docker.list"
		docker_repo=$(printf "%s %s %s" \
			"deb [arch=$(dpkg --print-architecture)" \
			"signed-by=/usr/share/keyrings/docker-archive-keyring.gpg]" \
			"https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
		)

		[[ ! -f "$docker_repo_file" || ! $(grep -qF "$docker_repo" "$docker_repo_file" 2>/dev/null) ]] && {
			printf "%s\n" "$docker_repo" | sudo tee "$docker_repo_file" > /dev/null
			update=true
		}
	}

	docker_after_update() {

		sudo DEBIAN_FRONTEND=noninteractive \
			apt install -y apt-transport-https ca-certificates \
			curl software-properties-common || {
			printf "Failed to install Docker prerequisites.\n"
			return 1
		}

	}

	dnsmasq_after_update() {

		systemctl is-active --quiet systemd-resolved && {
			sudo systemctl stop systemd-resolved
		}

		systemctl is-enabled --quiet systemd-resolved && {
			sudo systemctl disable systemd-resolved
		}

		local resolv_file="/etc/resolv.conf"
		[ -L "$resolv_file" ] && sudo rm "$resolv_file"
		[ -f "$resolv_file" ] && {
			printf "nameserver %s\n" "127.0.0.1" "8.8.8.8" "8.8.4.4" \
			| sudo tee "$resolv_file" > /dev/null
		}
	}

	sslh_after_update() {

		printf "%s Installing sslh...\n" "$fn"

		# Preconfigure options
		echo "sslh sslh/daemon_type select standalone" | sudo debconf-set-selections || {
			echo "Failed to preconfigure sslh"
			return 1
		}

		sudo$interactive apt -y$verbose --no-install-recommends install sslh || {
			printf "%s Failed to install sslh.\n" "$fn"
			return 1
		}

		missing_packages=$(echo "$missing_packages" | grep -v '^sslh$')
	}

	##############

	# run activities before updates
	if [[ "$should_install_docker" == "true" ]]; then docker_before_update; fi

	# update package repositories
	if [[ "$update" == "true" ]]; then update ; fi

	# run activities after updates
	if [[ "$should_install_docker"  == "true" ]]; then docker_after_update ; fi
	if [[ "$should_install_dnsmasq" == "true" ]]; then dnsmasq_after_update; fi
	if [[ "$should_install_sslh"    == "true" ]]; then sslh_after_update   ; fi

	# install all packages not installed seperately
	printf "%s Installing %s ... \n" "$fn" "$missing_packages"
	sudo$interactive apt -y$verbose install $missing_packages || {
		printf "%s Failed to install packages.\n" "$fn"
		return 1
	}
}


update() {
    local script_name=$(basename "$0")
    local function_name="${FUNCNAME[0]}"
    local fn=$(printf "%s:%s:" "$script_name" "$function_name")
	local options

    usage() {
        cat <<EOF
Usage: $function_name [OPTIONS]
Update the system or perform a specific action based on options.

Options:
  -v, --verbose      Enable verbose mode for detailed output.

Example:
  $function_name -v
  $function_name --verbose
EOF
    }

	options=$(getopt -o v --long verbose -- "$@") || {
		usage
		return 1
	}
	eval set -- "$options"

	while true; do
		case "$1" in
			--verbose|-v)
				verbose=""
				shift
				;;
			--)
				shift
				break
				;;
			*)
				printf "%s %s: Unexpected option: %s\n" "$script_name" "$function_name" "$1" >&2
				usage
				return 1
				;;
		esac
	done
	
	printf "%s Updating package repositories...\n" "$fn"

	sudo apt -y$verbose update || {
		printf "%s Failed to update package repositories.\n" "$fn"
		return 1
	}
}

cleanup_old_kernels () {
	
	dpkg -l \
		| awk '/^ii.*linux-(headers|image|modules|modules-extra)-[0-9]/{print $2}' \
		| grep -v `uname -r \
		| sed 's/-[^0-9]*$//'` \
		| xargs sudo apt -y autoremove
}

oneshot() {
    local script_name=$(basename "$0")
    local function_name="${FUNCNAME[0]}"
    local fn=$(printf "%s_%s" "$script_name" "$function_name")
	local options
	local user
	local command
	local name
	local remove="false"

	debug() {
		local fmt="%-13s : %s\n"
		printf "$fmt" "script_name" "$script_name"
		printf "$fmt" "function_name" "$function_name"
		printf "$fmt" "fn" "$fn"
		printf "$fmt" "options" "$options"
		printf "$fmt" "user" "$user"
		printf "$fmt" "command" "$command"
		printf "$fmt" "name" "$name"
		printf "$fmt" "remove" "$remove"
	}

	usage() {
    cat <<EOF
Usage: $function_name [OPTIONS]

Options:
  -c, --command COMMAND  Specify the command to execute.
  -n, --name NAME        Provide a name associated with the command.
  -u, --user USER        Specify the user for the command execution.
  -r, --remove           Remove the systemd oneshot.

Example:
  $function_name -c "deploy" -n "my_app" -u "admin"
EOF
	return 1
	}

	options=$(getopt -o c:n:u:r --long command:,name:,user:,remove -- "$@")

	# Check for errors in getopt parsing
	if [ $? -ne 0 ]; then usage; fi

	# Set the parsed options
	eval set -- "$options"

	while true; do
		case "$1" in
			--user|-u)
				user="$2"
				shift 2
				;;
			--command|-c)
				command="$2"
				shift 2
				;;
			--name|-n)
				name="$2"
				shift 2
				;;
			--remove|-r)
				remove="true"
				shift
				;;
			--)
				shift
				break
				;;
			*)
				printf "%s %s: Unexpected option: %s\n" "$script_name" "$function_name" "$1" >&2
				usage
				return 1
				;;
		esac
	done
	
	user=${user:-root}
	name=${name:-${fn}}

	# Ensure a script to run is provided
	if [ -z "$command" ]; then
		usage
	fi

    # Create a systemd one-shot service
    local service_file="/etc/systemd/system/${name}.service"

	if [[ "$remove" == "true" ]] && [[ -f "$service_file" ]] ; then

		if grep -q "Type=oneshot" "$service_file"; then

			systemctl is-active --quiet "$name" && {
				sudo systemctl stop "$name"
			}

			systemctl is-enabled --quiet "$name" && {
				sudo systemctl disable "$name"
			}

			sudo rm "$service_file"
			return 0

		else

			printf "service file %s, is not a oneshot service\n" "$service_file"
			printf "not deleting it\n"
			return 1

		fi
	fi


    echo "Creating systemd one-shot service..."
    sudo bash -c "cat << EOF > \"$service_file\"
[Unit]
Description=Run script after reboot

[Service]
User=root
Type=oneshot
ExecStart=$command
ExecStart=/usr/bin/systemctl disable $name
ExecStart=rm /etc/systemd/system/$name.service

[Install]
WantedBy=multi-user.target
EOF"

	## Enable the one-shot service to run after reboot
	sudo systemctl daemon-reload
	sudo systemctl enable "$name"

}

# cleanup_old_kernels_on_next_reboot
#
# This function finds a script named "cleanup-old-kernels.sh" in the current
# directory or the directory of the script being executed. It copies this
# script to "/usr/local/bin/" and sets the executable permission. Finally,
# it schedules the script to run on the next reboot using the "oneshot" command.
#
# Usage:
#   cleanup_old_kernels_on_next_reboot
#
# Note:
# - The "oneshot" command or function must be defined elsewhere in your script
#   or environment for this function to work.
# - Ensure that the "realpath" command is available or modify the function to
#   handle environments where it is not present.
#
# Arguments:
#   None
#
# Returns:
#   0  if the script was successfully copied and scheduled
#   1  if there was an error in finding the script, copying it, or scheduling it

cleanup_old_kernels_on_next_reboot() {
    local file="cleanup-old-kernels.sh"
    local dest="/usr/local/bin/cleanup-old-kernels"
    local file_path=""

    # Try to find the script in the given directories
    for base_path in "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" "$(dirname "$(realpath "$0")")"; do
        file_path="$base_path/$file"
        if [[ -f "$file_path" ]]; then
            break
        fi
    done

    # Check if the file was found
    if [[ ! -f "$file_path" ]]; then
        printf "cleanup file not found: %s\n" "$file"
        return 1
    fi

    # Copy the script to the destination
    if ! sudo cp "$file_path" "$dest"; then
        printf "Failed to copy file to %s\n" "$dest"
        return 1
    fi

    # Set executable permissions
    if ! sudo chmod +x "$dest"; then
        printf "Failed to set executable permissions for %s\n" "$dest"
        return 1
    fi

    # Schedule the script to run on the next reboot
    if ! oneshot --command "$dest" --name "cleanup-old-kernels"; then
        printf "Failed to schedule the script to run on reboot\n"
        return 1
    fi

    printf "Cleanup script successfully scheduled to run on next reboot\n"
}

