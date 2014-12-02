#!/bin/bash
# This script downloads s3cmd from the git repo, installs and starts setup

# Test if already installed
command -v s3cmd >/dev/null 2>&1 || {
	cd ~
	git clone https://github.com/s3tools/s3cmd.git
	cd s3cmd
	sudo python setup.py install
	read -rp "Configure s3cmd? (y/n) " CONFIGURE
		if [[ $CONFIGURE =~ ^([yY][eE][sS]|[yY])$ ]]; then
			s3cmd --configure
		fi
}

echo " "
echo "s3cmd installed"