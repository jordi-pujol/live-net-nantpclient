#!/bin/sh

_e() {
	echo "$@"
}
_e "a" $'\n'"b c"
