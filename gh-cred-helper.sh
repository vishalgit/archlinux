#!/usr/bin/env zsh

set -e

PAT_FILE="$HOME/.secrets/gh.gpg"
USERNAME="vishalgit"

case "$1" in
	get) 
		echo "username=$USERNAME"
		echo "password=$(gpg --quiet --decrypt "$PAT_FILE")"
		;;
	store|erase)
		exit 0
		;;
esac
