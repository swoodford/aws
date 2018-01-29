#!/bin/bash
# This script will install the AWS CLI
# Requires Homebrew, Python, pip

read -rp "Install and Configure AWS CLI? (y/n) " INSTALL
if [[ $INSTALL =~ ^([yY][eE][sS]|[yY])$ ]]; then

	# Test if pip is installed
	command -v pip >/dev/null 2>&1 || {
		brew install python

		echo "Installing pip"
		sudo easy_install pip
	}

	# Test if AWS CLI is installed
	command -v aws >/dev/null 2>&1 || {
		pip install awscli --upgrade --user

		aws configure
		complete -C '/usr/local/bin/aws_completer' aws
	}
	echo "Completed."
fi
