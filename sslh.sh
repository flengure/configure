#!/bin/bash

# source function run_script, install
source "$(dirname "$(realpath "$0")")/inc/ubuntu.sh"

daemon_opts='--user sslh --listen 0.0.0.0:443 --ssh 127.0.0.1:22 --tls 127.0.0.1:443 --pidfile'

is_direct_execution
case $? in
    0)
        install --update sslh
        ;;
    1)
        install sslh
        ;;
    *)
        echo "Error: Unexpected exit status from is_direct_execution."
        exit 1
        ;;
esac

config_file="/etc/default/sslh"
options_regex=$(sed 's/-/\\-/g' <<< "$daemon_opts")

# Configure sslh
if ! grep -q "$options_regex" "$config_file"; then

	sudo sed -Ei 's/(DAEMON_OPTS=")(.*pidfile)(.*)/\1'"$daemon_opts"'\3/' "$config_file" || {
		echo "Failed to update sslh configuration"
		return 1
	}
	sudo systemctl restart sslh || { 
		echo "Failed to restart sslh service"
		return 1
	}

	echo "sslh configuration updated and service restarted."
else
	echo "sslh is already configured with the specified options."
fi

