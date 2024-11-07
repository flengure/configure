#!/bin/bash

# Get the script path, directory and name
SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
SCRIPT_NAME="$(basename "$SCRIPT_PATH")"

if command -v docker >/dev/null 2>&1; then
    printf "%s\n" "Docker is already installed"
    exit 0
fi

# download and install docker keyring
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
	sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Register docker official repositories
printf "%s %s %s" \
	"deb [arch=$(dpkg --print-architecture)" \
	"signed-by=/usr/share/keyrings/docker-archive-keyring.gpg]" \
	"https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
	sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# get updated package lists from repositories
sudo apt -y update

# Download & install docker requirements
sudo DEBIAN_FRONTEND=noninteractive \
	apt install -y apt-transport-https ca-certificates curl software-properties-common

# Download & install docker
sudo DEBIAN_FRONTEND=noninteractive \
	apt -y install docker-ce docker-ce-cli containerd.io

