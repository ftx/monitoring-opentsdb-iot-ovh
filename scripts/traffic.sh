#!/bin/bash

INTERVAL="1"  # update interval in seconds

if [ -z "$1" ]; then
        echo
        echo "example: plugin.sh HOSTNAME system interface_name time warning_mbit/s critical_mbit/s total mbit/s;" 
        echo
        echo "./check_bandwidth.sh localhost linux eth0 15 80 90 100"
        echo "./check_bandwidth.sh switchname cisco GigabitEthernet0/1 15 80 90 100 192.192.192.192 snmp-community"
        exit
fi

name=$1
system=$2
IF=$3
sec=$4
warn=$5
crit=$6
iface_speed=$7
ip=$8
community=$9
current_pid=$$

bin_ps=`which ps`
bin_grep=`which grep`
bin_expr=`which expr`
bin_cat=`which cat`
bin_tac=`which tac`
bin_sort=`which sort`
bin_wc=`which wc`
bin_awk=`which awk`
bin_snmpwalk=`which snmpwalk`
interfaces_oid=1.3.6.1.2.1.2.2.1.2
                                                                                                                                                                        
                                                                                                                                                                        
if [ "$system" = "cisco" ];                                                                                                                                             
    then                                                                                                                                                                
        if_index=`$bin_snmpwalk -c $community -v 2c $ip $interfaces_oid | grep $IF | sed 's/^.*\.//;s/\ .*$//'`
        pidfile=/tmp/"$name"_"$if_index"_check_bandwidth.pid
fi
if [ "$system" = "linux" ];
    then
        pidfile=/tmp/"$name"_"$IF"_check_bandwidth.pid
fi

if [ -f $pidfile ];
    then
        echo "need to reduce the check duration or increase the interval between checks"
        exit 1
    else
        echo $current_pid > $pidfile
fi

if [ "$system" = "linux" ];
    then
        tmpfile_rx=/tmp/"$name"_"$IF"_check_bandwidth_rx.tmp
        tmpfile_tx=/tmp/"$name"_"$IF"_check_bandwidth_tx.tmp
        reverse_tmpfile_rx=/tmp/"$name"_"$IF"_reverse_check_bandwidth_rx.tmp
        reverse_tmpfile_tx=/tmp/"$name"_"$IF"_reverse_check_bandwidth_tx.tmp
        deltafile_rx=/tmp/"$name"_"$IF"_delta_check_bandwidth_rx.tmp
        deltafile_tx=/tmp/"$name"_"$IF"_delta_check_bandwidth_tx.tmp
elif [ "$system" = "cisco" ];
    then
        tmpfile_rx=/tmp/"$name"_"$if_index"_check_bandwidth_rx.tmp
        tmpfile_tx=/tmp/"$name"_"$if_index"_check_bandwidth_tx.tmp
        reverse_tmpfile_rx=/tmp/"$name"_"$if_index"_reverse_check_bandwidth_rx.tmp
        reverse_tmpfile_tx=/tmp/"$name"_"$if_index"_reverse_check_bandwidth_tx.tmp
        deltafile_rx=/tmp/"$name"_"$if_index"_delta_check_bandwidth_rx.tmp
        deltafile_tx=/tmp/"$name"_"$if_index"_delta_check_bandwidth_tx.tmp
        laststate_file=/tmp/"$name"_"$if_index"_laststate.tmp
fi

warn_kbits=`$bin_expr $warn '*' 1000000`
crit_kbits=`$bin_expr $crit '*' 1000000`
iface_speed_kbits=`$bin_expr $iface_speed '*' 1000000`

if [ "$system" = "linux" ];
    then
        START_TIME=`date +%s`
        n=0
        while [ $n -lt $sec ]
            do
                cat /sys/class/net/$3/statistics/rx_bytes >> $tmpfile_rx
                cat /sys/class/net/$3/statistics/tx_bytes >> $tmpfile_tx
                sleep $INTERVAL
                let "n = $n + 1"
            done
        FINISH_TIME=`date +%s`
    $bin_cat $tmpfile_rx | $bin_sort -nr > $reverse_tmpfile_rx
    $bin_cat $tmpfile_tx | $bin_sort -nr > $reverse_tmpfile_tx
    while read line;
        do
            if [ -z "$RBYTES" ];
                then
                    RBYTES=`cat /sys/class/net/$3/statistics/rx_bytes`
                    $bin_expr $RBYTES - $line >> $deltafile_rx;
                else
                    $bin_expr $RBYTES - $line >> $deltafile_rx;
            fi
        RBYTES=$line
        done < $reverse_tmpfile_rx
    while read line;
        do
            if [ -z "$TBYTES" ];
                then
                    TBYTES=`cat /sys/class/net/$3/statistics/tx_bytes`
                    $bin_expr $TBYTES - $line >> $deltafile_tx;
                else
                    $bin_expr $TBYTES - $line >> $deltafile_tx;
            fi
        TBYTES=$line
        done < $reverse_tmpfile_tx
    while read line;
        do
            SUM_RBYTES=`$bin_expr $SUM_RBYTES + $line`
        done < $deltafile_rx
    while read line;
        do
            SUM_TBYTES=`$bin_expr $SUM_TBYTES + $line`
        done < $deltafile_tx
    let "DURATION = $FINISH_TIME - $START_TIME"
    let "RBITS_SEC = ( $SUM_RBYTES * 8 ) / $DURATION"
    let "TBITS_SEC = ( $SUM_TBYTES * 8 ) / $DURATION"
    if [ $RBITS_SEC -lt $warn_kbits  -o  $TBITS_SEC -lt $warn_kbits ]
        then
            data_output_r=`echo "$RBITS_SEC 1000000" | $bin_awk '{ printf ("%.2f", $1/$2); }'`
            data_output_t=`echo "$TBITS_SEC 1000000" | $bin_awk '{ printf ("%.2f", $1/$2); }'`
            percent_output_r=`echo "$RBITS_SEC $iface_speed_kbits 100" | $bin_awk '{ printf ("%.2f", $1/$2*$3); }'`
            percent_output_t=`echo "$TBITS_SEC $iface_speed_kbits 100" | $bin_awk '{ printf ("%.2f", $1/$2*$3); }'`
            nagvis_perfdata_r="InUsage=$percent_output_r%;$warn_kbits;$crit_kbits"
            nagvis_perfdata_t="OutUsage=$percent_output_t%;$warn_kbits;$crit_kbits"
            pnp4nagios_perfdata_r="in=$RBITS_SEC;$warn_kbits;$crit_kbits"
            pnp4nagios_perfdata_t="in=$TBITS_SEC;$warn_kbits;$crit_kbits"
            output="IN $data_output_r Mbit/s OUT $data_output_t Mbit/s - OK, period $DURATION sec | $nagvis_perfdata_r $nagvis_perfdata_t inBandwidth="$data_output_r"Mbs outBandwidth="$data_output_t"Mbs $pnp4nagios_perfdata_r $pnp4nagios_perfdata_t"
            exitstatus=0
    elif [ $RBITS_SEC -ge $warn_kbits  -a  $RBITS_SEC -le $crit_kbits ] || [ $TBITS_SEC -ge $warn_kbits -a $TBITS_SEC -le $crit_kbits ];
        then
            data_output_r=`echo "$RBITS_SEC 1000000" | $bin_awk '{ printf ("%.2f", $1/$2); }'`
            data_output_t=`echo "$TBITS_SEC 1000000" | $bin_awk '{ printf ("%.2f", $1/$2); }'`
            percent_output_r=`echo "$RBITS_SEC $iface_speed_kbits 100" | $bin_awk '{ printf ("%.2f", $1/$2*$3); }'`
            percent_output_t=`echo "$TBITS_SEC $iface_speed_kbits 100" | $bin_awk '{ printf ("%.2f", $1/$2*$3); }'`
            nagvis_perfdata_r="InUsage=$percent_output_r%;$warn_kbits;$crit_kbits"
            nagvis_perfdata_t="OutUsage=$percent_output_t%;$warn_kbits;$crit_kbits"
            pnp4nagios_perfdata_r="in=$RBITS_SEC;$warn_kbits;$crit_kbits"
            pnp4nagios_perfdata_t="in=$TBITS_SEC;$warn_kbits;$crit_kbits"
            output="IN $data_output_r Mbit/s OUT $data_output_t Mbit/s WARNING! period $DURATION sec | $nagvis_perfdata_r $nagvis_perfdata_t inBandwidth="$data_output_r"Mbs outBandwidth="$data_output_t"Mbs $pnp4nagios_perfdata_r $pnp4nagios_perfdata_t"
            exitstatus=1
    elif [ $RBITS_SEC -gt $warn_kbits  -o  $TBITS_SEC -gt $warn_kbits ]
        then
            data_output_r=`echo "$RBITS_SEC 1000000" | $bin_awk '{ printf ("%.2f", $1/$2); }'`
            data_output_t=`echo "$TBITS_SEC 1000000" | $bin_awk '{ printf ("%.2f", $1/$2); }'`
            percent_output_r=`echo "$RBITS_SEC $iface_speed_kbits 100" | $bin_awk '{ printf ("%.2f", $1/$2*$3); }'`
            percent_output_t=`echo "$TBITS_SEC $iface_speed_kbits 100" | $bin_awk '{ printf ("%.2f", $1/$2*$3); }'`
            nagvis_perfdata_r="InUsage=$percent_output_r%;$warn_kbits;$crit_kbits"
            nagvis_perfdata_t="OutUsage=$percent_output_t%;$warn_kbits;$crit_kbits"
            pnp4nagios_perfdata_r="in=$RBITS_SEC;$warn_kbits;$crit_kbits"
            pnp4nagios_perfdata_t="in=$TBITS_SEC;$warn_kbits;$crit_kbits"
            output="IN $data_output_r Mbit/s OUT $data_output_t Mbit/s CRITICAL! period $DURATION sec | $nagvis_perfdata_r $nagvis_perfdata_t inBandwidth="$data_output_r"Mbs outBandwidth="$data_output_t"Mbs $pnp4nagios_perfdata_r $pnp4nagios_perfdata_t"
            exitstatus=2
    else
        output="unknown status"
        exitstatus=3
    fi
elif [ "$system" = "cisco" ];
    then
        START_TIME=`date +%s`
        n=0
        rx_tag=1
        tx_tag=1
        rx_old=0
        tx_old=0
        while [ $n -lt $sec -a $rx_tag -eq 1 -a $tx_tag -eq 1 ];
            do
                rx_now=`$bin_snmpwalk -c $community -v 2c -Oqv $ip 1.3.6.1.2.1.2.2.1.10.$if_index`
                    if [ $rx_now -ge $rx_old ];
                        then 
                        rx_tag=1
                            if [ $rx_now -gt $rx_old ];
                                then
                                    echo $rx_now >> $tmpfile_rx
                            fi
                    else
                        rx_tag=0
                    fi
                rx_old=$rx_now
                tx_now=`$bin_snmpwalk -c $community -v 2c -Oqv $ip 1.3.6.1.2.1.2.2.1.16.$if_index`
                    if [ $tx_now -ge $tx_old ];
                        then 
                        tx_tag=1
                            if [ $tx_now -gt $tx_old ];
                                then
                                    echo $tx_now >> $tmpfile_tx
                            fi
                    else
                        tx_tag=0
                    fi
                tx_old=$tx_now
                sleep $INTERVAL
                let "n = $n + 1"
            done
        FINISH_TIME=`date +%s`
        data_lines_rx=`$bin_cat $tmpfile_rx | $bin_wc -l`
        data_lines_tx=`$bin_cat $tmpfile_tx | $bin_wc -l`
        if [ $data_lines_rx -le 1 -o $data_lines_rx -le 1 ];
            then
                output=`$bin_cat $laststate_file`
                echo $output
                rm -f $tmpfile_rx
                rm -f $tmpfile_tx
                rm -f $pidfile
                exit 0
        fi
        $bin_tac $tmpfile_rx > $reverse_tmpfile_rx
        $bin_tac $tmpfile_tx > $reverse_tmpfile_tx
        while read line;
            do
                if [ -z "$ROCTETS" ];
                    then
                        ROCTETS=$line
                    else
                        $bin_expr $ROCTETS - $line >> $deltafile_rx;
                fi
            ROCTETS=$line
            done < $reverse_tmpfile_rx
        while read line;
            do
                if [ -z "$TOCTETS" ];
                    then
                        TOCTETS=$line
                    else
                        $bin_expr $TOCTETS - $line >> $deltafile_tx;
                fi
            TOCTETS=$line
            done < $reverse_tmpfile_tx
        while read line;
            do
                SUM_ROCTETS=`$bin_expr $SUM_ROCTETS + $line`
            done < $deltafile_rx
        while read line;
            do
                SUM_TOCTETS=`$bin_expr $SUM_TOCTETS + $line`
            done < $deltafile_tx
        let "DURATION = $FINISH_TIME - $START_TIME"
        let "RBITS_SEC = ( $SUM_ROCTETS * 8 ) / $DURATION"
        let "TBITS_SEC = ( $SUM_TOCTETS * 8 ) / $DURATION"
#debug block start
if [ $RBITS_SEC -lt 0 ];
    then
        timestamp=`date +%H%M%S`
        cp $tmpfile_rx "$tmpfile_rx"_"$timestamp"
        cp $reverse_tmpfile_rx "$reverse_tmpfile_rx"_"$timestamp"
        cp $deltafile_rx "$deltafile_rx"_"$timestamp"
fi
if [ $TBITS_SEC -lt 0 ];
    then
        timestamp=`date +%H%M%S`
        cp $tmpfile_tx "$tmpfile_tx"_"$timestamp"
        cp $reverse_tmpfile_tx "$reverse_tmpfile_tx"_"$timestamp"
        cp $deltafile_tx "$deltafile_tx"_"$timestamp"
fi
#debug block finish
    if [ $RBITS_SEC -lt $warn_kbits  -o  $TBITS_SEC -lt $warn_kbits ]
        then
            data_output_r=`echo "$RBITS_SEC 1000000" | $bin_awk '{ printf ("%.2f", $1/$2); }'`
            data_output_t=`echo "$TBITS_SEC 1000000" | $bin_awk '{ printf ("%.2f", $1/$2); }'`
            percent_output_r=`echo "$RBITS_SEC $iface_speed_kbits 100" | $bin_awk '{ printf ("%.2f", $1/$2*$3); }'`
            percent_output_t=`echo "$TBITS_SEC $iface_speed_kbits 100" | $bin_awk '{ printf ("%.2f", $1/$2*$3); }'`
            nagvis_perfdata_r="InUsage=$percent_output_r%;$warn_kbits;$crit_kbits"
            nagvis_perfdata_t="OutUsage=$percent_output_t%;$warn_kbits;$crit_kbits"
            pnp4nagios_perfdata_r="in=$RBITS_SEC;$warn_kbits;$crit_kbits"
            pnp4nagios_perfdata_t="in=$TBITS_SEC;$warn_kbits;$crit_kbits"
            output="IN $data_output_r Mbit/s OUT $data_output_t Mbit/s - OK, period $DURATION sec | $nagvis_perfdata_r $nagvis_perfdata_t inBandwidth="$data_output_r"Mbs outBandwidth="$data_output_t"Mbs $pnp4nagios_perfdata_r $pnp4nagios_perfdata_t"
            echo $output > $laststate_file
            exitstatus=0
    elif [ $RBITS_SEC -ge $warn_kbits  -a  $RBITS_SEC -le $crit_kbits ] || [ $TBITS_SEC -ge $warn_kbits -a $TBITS_SEC -le $crit_kbits ];
        then
            data_output_r=`echo "$RBITS_SEC 1000000" | $bin_awk '{ printf ("%.2f", $1/$2); }'`
            data_output_t=`echo "$TBITS_SEC 1000000" | $bin_awk '{ printf ("%.2f", $1/$2); }'`
            percent_output_r=`echo "$RBITS_SEC $iface_speed_kbits 100" | $bin_awk '{ printf ("%.2f", $1/$2*$3); }'`
            percent_output_t=`echo "$TBITS_SEC $iface_speed_kbits 100" | $bin_awk '{ printf ("%.2f", $1/$2*$3); }'`
            nagvis_perfdata_r="InUsage=$percent_output_r%;$warn_kbits;$crit_kbits"
            nagvis_perfdata_t="OutUsage=$percent_output_t%;$warn_kbits;$crit_kbits"
            pnp4nagios_perfdata_r="in=$RBITS_SEC;$warn_kbits;$crit_kbits"
            pnp4nagios_perfdata_t="in=$TBITS_SEC;$warn_kbits;$crit_kbits"
            output="IN $data_output_r Mbit/s OUT $data_output_t Mbit/s WARNING! period $DURATION sec | $nagvis_perfdata_r $nagvis_perfdata_t inBandwidth="$data_output_r"Mbs outBandwidth="$data_output_t"Mbs $pnp4nagios_perfdata_r $pnp4nagios_perfdata_t"
            echo $output > $laststate_file
            exitstatus=1
    elif [ $RBITS_SEC -gt $warn_kbits  -o  $TBITS_SEC -gt $warn_kbits ]
        then
            data_output_r=`echo "$RBITS_SEC 1000000" | $bin_awk '{ printf ("%.2f", $1/$2); }'`
            data_output_t=`echo "$TBITS_SEC 1000000" | $bin_awk '{ printf ("%.2f", $1/$2); }'`
            percent_output_r=`echo "$RBITS_SEC $iface_speed_kbits 100" | $bin_awk '{ printf ("%.2f", $1/$2*$3); }'`
            percent_output_t=`echo "$TBITS_SEC $iface_speed_kbits 100" | $bin_awk '{ printf ("%.2f", $1/$2*$3); }'`
            nagvis_perfdata_r="InUsage=$percent_output_r%;$warn_kbits;$crit_kbits"
            nagvis_perfdata_t="OutUsage=$percent_output_t%;$warn_kbits;$crit_kbits"
            pnp4nagios_perfdata_r="in=$RBITS_SEC;$warn_kbits;$crit_kbits"
            pnp4nagios_perfdata_t="in=$TBITS_SEC;$warn_kbits;$crit_kbits"
            output="IN $data_output_r Mbit/s OUT $data_output_t Mbit/s CRITICAL! period $DURATION sec | $nagvis_perfdata_r $nagvis_perfdata_t inBandwidth="$data_output_r"Mbs outBandwidth="$data_output_t"Mbs $pnp4nagios_perfdata_r $pnp4nagios_perfdata_t"
            echo $output > $laststate_file
            exitstatus=2
    else
        output="unknown status"
        exitstatus=3
    fi
else
    output="incorrect system!"
    exitstatus=3
fi

rm -f $tmpfile_rx
rm -f $reverse_tmpfile_rx
rm -f $deltafile_rx
rm -f $tmpfile_tx
rm -f $reverse_tmpfile_tx
rm -f $deltafile_tx
rm -f $pidfile

echo "$output"
exit $exitstatus

