#!/bin/sh
# Author: Christoph Galuschka <tigalch@tigalch.org>
#         Athmane Madjoudj <athmanem@gmail.com>

t_Log "Running $0 - TCPdump test to Default-GW with IPv4"

if [ "$CONTAINERTEST" -eq "1" ]; then
    t_Log "Running in container -> SKIP"
    exit 0
fi

# Grabing Default-Router if NIC
def_gw_out=$(ip route list default|grep "default via"|head -n 1)
def_gw=$(echo $def_gw_out | awk '{print $3}')
eth_int=$(echo $def_gw_out | awk '{print $5}')

t_Log "Found Default-GW - starting tcpdump test"
#Dumping 4 pings via NIC to file
FILE='/var/tmp/nic_test.pcap'
COUNT='4'
tcpdump -i $eth_int -q -n -p -w $FILE &
# If we don't wait a short time, the first paket will be missed by tcpdump
sleep 1
ping -q -c $COUNT -i 0.25 ${def_gw} > /dev/null 2>&1
sleep 1
killall -s SIGINT tcpdump
sleep 1
# reading from file, for each ping we should see at least two pakets
WORKING=$( tcpdump -r $FILE | grep -ci icmp )
if [ $WORKING -lt $[COUNT*2] ]
  then
  t_Log "ping to Default-Gateway did not return the number of pakets we expect. "$WORKING" of "$[COUNT*2]" pakets were dumped to file"
  ret_val=1
else
  t_Log "ping to Default-Gateway looks OK. "$WORKING" of "$[COUNT*2]" pakets were dumped to file"
  ret_val=0
fi
# Remove file afterwards
/bin/rm $FILE

t_CheckExitStatus $ret_val
