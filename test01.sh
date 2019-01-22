#!/bin/sh

# print NTP date-time
date --date @$((0x`printf 'c%47s' | tr ' ' '\000' | netcat -uw1 livenet 123 | xxd -s40 -l4 -p`-2208988800))

date --date @$((0x`printf '%-48s' $'\x63' | netcat -uw1 livenet 123 | xxd -s40 -l4 -p`-2208988800))

date --date @$((0x`printf '%-48s' $'\x63' | netcat -uw1 livenet 123 | od -j 40 -N 4 -A n -v -t x1 | tr -d ' '`-2208988800))

printf '%-48s' $'\x63' | netcat -uw1 livenet 123 | od -j 40 -N 4 -A n -v -t x1 | tr -d ' '
