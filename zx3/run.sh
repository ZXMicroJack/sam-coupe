#!/bin/bash
file=./samcoupe.runs/impl_1/samcoupezx3.bit
if [ "$1" != "" ]; then file=$1; fi
cat << EOF | /opt/urjtag_artix/bin/jtag
cable usbblaster
detect
pld load ${file}
EOF

