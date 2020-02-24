#!/bin/bash

# A non accurate NTP client
#
# Sets the computer date-time getting data from an NTP server.
# This script is to be ran once at computer boot after the network
# has been started.
#   Will query an NTP server and set local date.
#     Gets date-time from one NTP server, then computes time
#     with a precision of one second and sets the local time.
#     It's not much accurate but is enough for most desktop computers
#     that don't require a very exact date-time.
#   Uses only the first response that receives from an NTP server.
#   Can configure an unlimited list of servers.
#   Also can discover NTP servers via DHCP.

# Shell script, works in:
#  busybox ash or bash
# Doesn't work in dash.

# Requires: netcat
# Recommends: nmap # to discover NTP servers via DHCP
#             iproute2 # to list IPs of the gateways

_ps_children() {
	local p
	for p in $(pgrep -P "${1}"); do
		echo "${p}"
		_ps_children "${p}"
	done
}

_exit() {
	trap - EXIT HUP
	pids="$(_ps_children "${PidDaemon}")"
	[ -z "${pids}" ] || \
		kill -TERM ${pids} > /dev/null 2>&1 &
	wait || :
}

_sleep() {
	sleep ${Interval} &
	wait $((PidSleep=${!})) || :
	PidSleep=""
}

TimeScan() {
	[ -z "${PidSleep}" ] || \
		kill -TERM "${PidSleep}" || :
}

LoadConfig() {
	# Configuration parameters
	ntpserver_1="*gateway *dhcp"
	#ntpport_1="123"
	ntpserver_2="0.pool.ntp.org 1.pool.ntp.org 2.pool.ntp.org 3.pool.ntp.org"
	#ntpport_2="123"
	ntpserver_3=""
	#ntpport_3="123"

	Interval=20

	[ -f  "/etc/${NAME}.conf" ] && \
		. "/etc/${NAME}.conf" || :

	TimeScan
}

Gateways() {
	if [ -n "$(which ip)" ]; then
		ip -4 route show default | \
		awk '$1 == "default" && $NF != "linkdown" {print $3}'
	else
		route -n -A inet | \
		awk '$2 ~ "^([[:digit:]]+[.]){3}[[:digit:]]+" && \
		$2 != "0.0.0.0" {print $2}'
	fi | \
	sort -u
}

AddNTPServer() {
	! echo "${NTPServers}" | grep -qsxF "${srvr}" || \
		return 1
	[ -z "${NTPServers}" ] && \
		NTPServers="${srvr}" || \
		NTPServers="${NTPServers}"$'\n'"${srvr}"
}

SetLocalTime() {
	local ntpserver srvr ntpport ntpdate
	local i=0 NTPServers=""
	while [ $((i++)) ]; do
		eval ntpserver=\"\${ntpserver_${i}:-}\" && \
		[ -n "${ntpserver}" ] || \
			return 1
		eval ntpport=\"\${ntpport_${i}:-"123"}\"
		for srvr in $(echo "${ntpserver}" | tr -s '\n ,' ' '); do
			if [ "${srvr}" = "*dhcp" ]; then
				AddNTPServer || \
					continue
				srvr="$(which nmap)" && \
				srvr="$(nmap --script broadcast-dhcp-discover | \
				sed -nre '\|.*NTP Servers: (.+)| s||\1|p' | \
				tr -s '\n ,' '\n' | sort -u)" > /dev/null 2>&1 && \
				[ -n "${srvr}" ] || \
					continue
				echo "DHCP advertised NTP servers '$(echo ${srvr})'" >&2
			elif [ "${srvr}" = "*gateway" ]; then
				AddNTPServer || \
					continue
				srvr="$(Gateways)"
				[ -n "${srvr}" ] || \
					continue
				echo "Gateway NTP servers '$(echo ${srvr})'" >&2
			fi
			for srvr in ${srvr}; do
				AddNTPServer || \
					continue
				echo "Requesting time to NTP server '${srvr}'" >&2
				ntpdate="$(printf '%-48s' $'\x63' | \
				netcat -u -w 1 "${srvr}" "${ntpport}" | \
				od -j 40 -N 4 -A n -v -t x1 | tr -d ' ')" && \
				[ -n "${ntpdate}" ] && \
				date --set @$((0x${ntpdate}-2208988800)) >&2 && \
					return 0 || \
					echo "No answer from server" >&2
			done
		done
	done
	return 1
}

set -o errexit -o nounset -o noglob -o pipefail

NAME="$(basename "${0}" '.sh')"

#exec > /tmp/${NAME}.txt 2>&1
#set -x

case "${1:-}" in
start)
	PidDaemon="${$}"
	trap '_exit' EXIT
	PidSleep=""
	LoadConfig
	trap 'LoadConfig' HUP
	for t in 1 2 3; do
		_sleep
		! SetLocalTime || \
			exit 0
	done
	echo "Error: Can't get date/time from any NTP server" >&2
	exit 1
	;;
*)
	echo "Wrong arguments" >&2
	exit 1
	;;
esac
