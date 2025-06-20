#!/bin/bash

USERID=$( id -u )

test_user() {
	if [ "$USERID" -ne "0" ]; then
		echo "Execute como root."
		exit 1
	fi
}

test_user
