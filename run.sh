#!/bin/bash

# source functions
# ubuntu:install
# ubuntu:tools:run_script
source "$(dirname "$(realpath "$0")")/inc/ubuntu.sh"

HOST="${1:-client}"

install --update tree tmux byobu jq sslh docker dnsmasq wireguard haproxy

run_script sslh
run_script ssh "$@"
run_script dnsmasq "$@"
run_script wireguard --save "$@"

sudo DEBIAN_FRONTEND=noninteractive apt-get -qq -y -o Dpkg::Options::="--force-confold" full-upgrade

run_script ufw
run_script hostname "$@"
cleanup_old_kernels_on_next_reboot
