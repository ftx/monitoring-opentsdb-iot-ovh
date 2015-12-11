#!/bin/bash

#################################################################################################
################        CONFIGURATION
#################################################################################################

CLIENT="MyClient"
NODE="Server1"

PATH_M="/home/ftx/monitoring" # Without end /

DISK_PARTITION="/dev/vda1"

ETH="eth0"

MONIT_LOAD="1"
MONIT_MEMORY="1"
MONIT_DISK="1"
MONIT_TRAFFIC="1"
MONIT_NGINX="1"

#################################################################################################
################	END CONFIGURATION
#################################################################################################

###
## Load Usage
if [ "${MONIT_LOAD}" == "1" ]; then
LOAD=$(uptime | awk '{print $10}' | sed "s/,//g")
python $PATH_M/bin/iot.py "$CLIENT.$NODE.Load" iot metrics "$LOAD"
fi
###
## Memory Usage
if [ "${MONIT_MEMORY}" == "1" ]; then
MEMORY_TOTAL=$(free -m | grep Mem | awk '{print $2}')
MEMORY_USED=$(free -m | grep buffers/ | awk '{print $3}')

python $PATH_M/bin/iot.py "$CLIENT.$NODE.MemoryTotal" iot metrics "$MEMORY_TOTAL"
python $PATH_M/bin/iot.py "$CLIENT.$NODE.MemoryUsed" iot metrics "$MEMORY_USED"
fi

###
## Disk Usage
if [ "${MONIT_DISK}" == "1" ]; then
DISK_TOTAL=$(df -h | grep $DISK_PARTITION | awk '{print $2}' | sed "s/G//g")
DISK_USED=$(df -h | grep $DISK_PARTITION | awk '{print $3}' | sed "s/G//g")

python $PATH_M/bin/iot.py "$CLIENT.$NODE.DiskTotal" iot metrics "$DISK_TOTAL"
python $PATH_M/bin/iot.py "$CLIENT.$NODE.DiskUsed" iot metrics "$DISK_USED"
fi

###
## Traffic Usage
if [ "${MONIT_TRAFFIC}" == "1" ]; then
IN=$(vnstati -i $ETH -tr | grep rx | awk '{print $2}')
OUT=$(vnstat -i $ETH -tr | grep rx | awk '{print $2}')

python $PATH_M/bin/iot.py "$CLIENT.$NODE.Traffic.In" iot metrics "$IN"
python $PATH_M/bin/iot.py "$CLIENT.$NODE.Traffic.Out" iot metrics "$OUT"
fi

###
## Nginx connections
if [ "${MONIT_NGINX}" == "1" ]; then
NGINX_CONNECTIONS=$(php $PATH_M/scripts/nginx_connections.php)
python $PATH_M/bin/iot.py "$CLIENT.$NODE.Nginx.ActiveConnections" iot metrics "$NGINX_CONNECTIONS"
fi
