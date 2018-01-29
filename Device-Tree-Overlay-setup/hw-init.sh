#!/bin/bash

# set -x # echo cmds
set -e # bail if fail

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root. Plz sudo su and re-run" 1>&2
   exit 1
fi

# get aliases I like
. /root/.profile

# Load DTOs

echo "Verify nothing weird in dmesg before I clear it:"

dmesg | tail

dmesg --clear

echo "Loading jppprugpio device tree overlay..."

echo jppprugpio > /sys/devices/bone_capemgr.9/slots

echo "Look ok?"

dmesg 

dmesg --clear

echo "Loading EQEP device tree overlay..."

echo bone_eqep1 > /sys/devices/bone_capemgr.9/slots

echo "Look ok?"

dmesg 

dmesg --clear

echo "Should now see those in the SLOTS:"

cat /sys/devices/bone_capemgr.9/slots

echo "Should look like this:"

echo '
"""
root@beaglebone:/home/debian# cat $SLOTS
 0: 54:PF--- 
 1: 55:PF--- 
 2: 56:PF--- 
 3: 57:PF--- 
 4: ff:P-O-L Bone-LT-eMMC-2G,00A0,Texas Instrument,BB-BONE-EMMC-2G
 5: ff:P-O-- Bone-Black-HDMI,00A0,Texas Instrument,BB-BONELT-HDMI
 6: ff:P-O-- Bone-Black-HDMIN,00A0,Texas Instrument,BB-BONELT-HDMIN
 8: ff:P-O-L Override Board Name,00A0,Override Manuf,BB-ADC
 9: ff:P-O-L Override Board Name,00A0,Override Manuf,bone_pwm_P8_34
10: ff:P-O-L Override Board Name,00A0,Override Manuf,am33xx_pwm
11: ff:P-O-L Override Board Name,00A0,Override Manuf,jppprugpio
12: ff:P-O-L Override Board Name,00A0,Override Manuf,bone_eqep1
"""
'
