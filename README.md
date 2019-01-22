A non accurate NTP client

Sets the computer date-time getting data from an NTP server.

This script is to be ran once at computer boot after the network
has been started.

Will query an NTP server and set local date.

Gets date-time from one NTP server, then computes time
with a precision of one second and sets the local time.
It's not much accurate but is enough for most desktop computers
that don't require a very exact date-time.
Uses only the first response that receives from an NTP server.
Can configure an unlimited list of servers.
Also can discover NTP servers via DHCP.

The shell script, works in:
- busybox ash or bash
- Doesn't work in dash.

Requires: netcat

Recommends:
- nmap # to discover NTP servers via DHCP
- iproute2 # to list IPs of the gateways
