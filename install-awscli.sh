#!/usr/bin/env bash

# This script will install the AWS CLI
# Requires Homebrew, Python, pip

read -rp "Install and Configure AWS CLI? (y/n) " INSTALL
if [[ $INSTALL =~ ^([yY][eE][sS]|[yY])$ ]]; then

	# Test if pip is installed
	command -v pip >/dev/null 2>&1 || {
		brew install python

		echo "Installing Python pip"
		sudo easy_install pip && echo; echo "Installed Python pip."
	}

	# Test if AWS CLI is installed
	command -v aws >/dev/null 2>&1 || {
		echo "Installing awscli"
		pip install awscli --upgrade --user && echo; echo "Installed awscli."

		aws configure
		complete -C '/usr/local/bin/aws_completer' aws
	} && {
		echo "Updating awscli"
		pip install awscli --upgrade --user && echo; echo "Updated awscli."
	}

	echo "Completed."
fi
