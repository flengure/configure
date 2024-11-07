#!/bin/bash

dpkg -l \
	| awk '/^ii.*linux-(headers|image|modules|modules-extra)-[0-9]/{print $2}' \
	| grep -v $(uname -r | sed 's/-[^0-9]*$//') \
	| xargs sudo apt-get -y autoremove --purge


