#!/usr/bin/env bash

# Shared AWS CLI profile argument handling for repository scripts.
# Precedence: --profile flag > AWS_PROFILE env var > legacy first positional arg.

function aws_profile_prepare_args() {
	local explicit_profile=""

	AWS_SCRIPT_LEGACY_ARGS=()

	while [ $# -gt 0 ]; do
		case "$1" in
			--profile)
				shift
				if [ $# -eq 0 ] || [ -z "$1" ]; then
					echo "Failure: Missing value for --profile." >&2
					return 1
				fi
				explicit_profile="$1"
				;;
			--profile=*)
				explicit_profile="${1#--profile=}"
				if [ -z "$explicit_profile" ]; then
					echo "Failure: Missing value for --profile." >&2
					return 1
				fi
				;;
			*)
				AWS_SCRIPT_LEGACY_ARGS+=("$1")
				;;
		esac
		shift
	done

	if [ -n "$explicit_profile" ]; then
		AWS_SCRIPT_PROFILE="$explicit_profile"
		AWS_SCRIPT_LEGACY_ARGS=("$explicit_profile" "${AWS_SCRIPT_LEGACY_ARGS[@]}")
	elif [ -n "${AWS_PROFILE:-}" ]; then
		AWS_SCRIPT_PROFILE="$AWS_PROFILE"
	elif [ ${#AWS_SCRIPT_LEGACY_ARGS[@]} -gt 0 ]; then
		AWS_SCRIPT_PROFILE="${AWS_SCRIPT_LEGACY_ARGS[0]}"
	else
		AWS_SCRIPT_PROFILE=""
	fi
}

function aws() {
	local selected_profile="${AWS_SCRIPT_PROFILE:-${profile:-}}"

	if [ -n "$selected_profile" ]; then
		command aws --profile "$selected_profile" "$@"
	else
		command aws "$@"
	fi
}
