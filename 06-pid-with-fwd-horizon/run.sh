#!/bin/bash

# http://askubuntu.com/questions/15853/how-can-a-script-check-if-its-being-run-as-root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# set -x #echo on
set -e # bail if fail


# Build and deploy device-tree overlays

yourDtcVersion=`dtc --version`
goodDtcVersion="Version: DTC 1.4.1-g1e75ebc9"
if [ "$yourDtcVersion" = "$goodDtcVersion" ]
then
    echo "You've got a good version of the device-tree compiler program ($(which dtc)) ($yourDtcVersion)."
else
    echo "Your version of dtc (${yourDtcVersion}) isn't what " \
	 "I was expecting (${goodDtcVersion}). Plz update!"
    exit 1
fi
for mydir in /root/ucla-nesl-pru-lib/overlay /root/qot-stack/targets/am335x
do
    echo "Entering $mydir to find DTOs..."
    pushd $mydir
    for dts in `ls *.dts`
    do
	dtbo="$(basename $dts .dts)"
	dtbo="$(basename $dtbo -00A0)" # strip off trailing -00A0 just in case it's there
	dtbo="${dtbo}-00A0.dtbo"
	echo "dtc'ing $dts into $dtbo..."
	dtc -O dtb -o $dtbo -b 0 -@ $dts
	echo "Copying $dtbo to /lib/firmware"
	cp $dtbo /lib/firmware
    done
    popd
done



SLOTS=$(find /sys/devices -name slots)
echo "Note: SLOTS = $SLOTS"

# Ensure the relevant device-tree overlays are loaded
for dto in BB-ADC am33xx_pwm bone_eqep1 BBB-AM335X nesl-jpp NESL-PRU; do  #  bone_pwm_P8_34
    if grep --quiet $dto $SLOTS; then
	echo "$dto in $SLOTS, good"
    else
	echo "$dto not in $SLOTS, loading it..."
	dmesg --clear
	echo $dto > $SLOTS
	echo "dmesg after load:"
	dmesg 
    fi
done 


# NOT OBVIOUS: nesl-jpp sets up its pins in a weird way that requires
# that we execute a pin configuration script:
echo "Configuring pins that were enabled by nesl-jpp..."
/root/ucla-nesl-pru-lib/examples/time_sync/config-pins.sh

# Load uio_pruss kernel module (needed?)
if lsmod | grep --quiet uio_pruss ; then
    echo "kernel module uio_pruss already loaded, good"
else
    echo "Loading modprobe uio_pruss..."    
    modprobe uio_pruss
fi


# Load QoT kernel modules
BBB_MODULES_DIR=/lib/modules/4.1.12-bone-rt-r16/kernel/drivers/misc/
pushd $BBB_MODULES_DIR
for km in qot.ko qot_am335x.ko 
do
    km2=`basename $km .ko`  # strip file extension
    if lsmod | grep --quiet $km2 ; then
	echo "kernel module $km loaded already, good"
    else
	echo "kernel module $km not in lsmod; loading it..."
	dmesg --clear
	insmod $km
	echo "dmesg after load:"
	dmesg 
	echo "lsmod after load:"
	lsmod
    fi
done
popd




#############################################################
# Compile

# Notes: 
# -std=gnu99 or -std=c99 needed for for(int i=0;...)
# -lm needed to include math library, even with #include <math.h>, 
# -lrt needed to include clock_gettime, even with #include <time.h>, in util-jpp.c

# set -e # bail if fail
# set -x # echo


################
# Old ~ Mar 1: main() calls a function like test_pid() in tests.c

#echo "compiling tests"

# gcc -g -std=gnu99 -lm -c util-jpp.c 
# gcc -g -std=gnu99 -lm -c bb-simple-sysfs-c-lib.c 
# gcc -g -std=gnu99 -lm -c tests.c                 
# -Wall -Werror to avoid shitty problems like this one:
  # http://stackoverflow.com/questions/2398791/how-is-conversion-of-float-double-to-int-handled-in-printf
# gcc -g -Wall -Werror -lm -lrt -std=gnu99 util-jpp.c bb-simple-sysfs-c-lib.c tests.c main.c -o main 

#echo "compiling main"

#gcc -g -Wall -Werror -lm -lrt -std=gnu99 -lprussdrv util-jpp.c jpp-pru-lib.c tests.c main.c -o main 


####################
# Mar 6: dedicate main() into pid-fwd.c, pid-fwd2.c , ...


#  echo "compiling pasm"
# 	pasm -b jpp-pru-lib.p

#  echo "compiling util-jpp"
# 	gcc -g -Wall -Werror -lstdc++ -std=gnu99 -lm -lrt -c util-jpp.c

# echo "compiling jpp-pru-lib"
# 	gcc -g -Wall -Werror -lstdc++ -std=gnu99 -lm -lprussdrv -c jpp-pru-lib.c

# echo "compiling bb-simple-sysfs-c-lib"
#  gcc -g -Wall -Werror -lstdc++ -std=gnu99 -lm -c bb-simple-sysfs-c-lib.c 


#  echo "compiling pid-fwd"
#  gcc -g -Wall -Werror -lstdc++ -std=gnu99 \
#      -lm -lprussdrv -Wno-unused-but-set-variable -Wno-unused-variable -c pid-fwd.c

#  echo "compiling pid-fwd2"
#  gcc -g -Wall -Werror -lstdc++ -std=gnu99 \
#      -lm -lprussdrv -Wno-unused-but-set-variable -Wno-unused-variable -c pid-fwd2.c

#  echo "compiling pid-fwd3"
#  gcc -g -Wall -Werror -lstdc++ -std=gnu99 \
#      -lm -lprussdrv -Wno-unused-but-set-variable -Wno-unused-variable -c pid-fwd3.c

#  echo "compiling pid-fwd22"
#  gcc -g -Wall -Werror -lstdc++ -std=gnu99 \
#      -lm -lprussdrv -Wno-unused-but-set-variable -Wno-unused-variable -c pid-fwd22.c

#  echo "compiling pid-fwd22-arggains"
#  gcc -g -Wall -Werror -lstdc++ -std=gnu99 \
#      -lm -lprussdrv -Wno-unused-but-set-variable -Wno-unused-variable -c pid-fwd22-arggains.c



#  echo "linking pid-fwd..."
#  gcc -g -Wall -Werror -lm -lrt -std=gnu99 -lprussdrv util-jpp.o jpp-pru-lib.o bb-simple-sysfs-c-lib.o pid-fwd.o -o pid-fwd

#  echo "linking pid-fwd2..."
# gcc -g -Wall -Werror -lm -lrt -std=gnu99 -lprussdrv util-jpp.o jpp-pru-lib.o bb-simple-sysfs-c-lib.o pid-fwd2.o -o pid-fwd2

#  echo "linking pid-fwd3..."
# gcc -g -Wall -Werror -lm -lrt -std=gnu99 -lprussdrv util-jpp.o jpp-pru-lib.o bb-simple-sysfs-c-lib.o pid-fwd3.o -o pid-fwd3

#  echo "linking pid-fwd22..."
# gcc -g -Wall -Werror -lm -lrt -std=gnu99 -lprussdrv util-jpp.o jpp-pru-lib.o bb-simple-sysfs-c-lib.o pid-fwd22.o -o pid-fwd22


#  echo "linking pid-fwd22-arggains..."
# gcc -g -Wall -Werror -lm -lrt -std=gnu99 -lprussdrv util-jpp.o jpp-pru-lib.o bb-simple-sysfs-c-lib.o pid-fwd22-arggains.o -o pid-fwd22-arggains


#####################
# mar 13 2017: too many files to keep track of ,takes long time to compile.
# put in make file

make



#############################################################
# Run

echo "Running programs!"



############################
# System Identification

# ./main sysid square_chirp 8 0.1 15 sq_8s_p1hz_15hz.txt
# sleep 1
# ./main sysid square_chirp 8 1 10 sq_8s_1hz_10hz.txt
# sleep 1
# ./main sysid chirp 8 0.1 15 ch_8s_p1hz_15hz.txt
# sleep 1
# ./main sysid chirp 8 1 10 ch_8s_1hz_10hz.txt



#########################################
# PID controller
# manual guess of gains
# ./main pid 5 -.02 0.001 0 pid-data.txt  

# PID ctrl feb16 tuned gains via pidTuner (assumes 5ms sample time!)
# Kp = -0.0109, Ki = -0.0343, Kd = -0.00043, Ts = 0.00525
# ./main pid 5 -0.0109 -0.0343 -0.00043 pid-data.txt  


# PI ctrl feb16 tuned gains via pidTuner (assumes 5ms sample time!)
# Kp = -0.00499, Ki = -0.0103, Ts = 0.00525
# ./main pid 5 -0.00499 -0.0103 0 pid-data.txt  

# PI ctrl gains x4:
# ./main pid 5 -0.02 -0.04 0 pid-data.txt  

# too much v. halve gains:
# ./main pid 5 -0.01 -0.02 0 pid-data.txt  

# try to get rid of ss overshoot.
# ./main pid 5 -0.015 -0.08 0 pid-data.txt  
# ./main pid 5 -0.012 -0.16 0 pid-data.txt  
# ./main pid 5 -0.01 -0.10 -.0007 pid-data.txt  

# After twiddle:
# kp: -0.082849 ki: -0.055907 kd: -0.000645
# ./main pid 5 -0.082849 -0.055907 -0.000645 pid-data-post-twiddle.txt  

# Twiddling for only the proportional gain...




##########################################
# Adding uniformly-distributed random timing errors

# ./main pid 5 -0.082849 -0.055907 -0.000645 pid-data-sleep-0.0sec-1.txt  
# ./main pid 5 -0.082849 -0.055907 -0.000645 pid-data-sleep-0.0sec-2.txt  
# ./main pid 5 -0.082849 -0.055907 -0.000645 pid-data-sleep-0.0sec-3.txt  

# ./main pid 5 -0.082849 -0.055907 -0.000645 pid-data-sleep-0.001sec-1.txt  
# ./main pid 5 -0.082849 -0.055907 -0.000645 pid-data-sleep-0.001sec-2.txt  
# ./main pid 5 -0.082849 -0.055907 -0.000645 pid-data-sleep-0.001sec-3.txt  

# ./main pid 5 -0.082849 -0.055907 -0.000645 pid-data-sleep-0.005sec-1.txt  
# ./main pid 5 -0.082849 -0.055907 -0.000645 pid-data-sleep-0.005sec-2.txt  
# ./main pid 5 -0.082849 -0.055907 -0.000645 pid-data-sleep-0.005sec-3.txt  

#########################################33
# Run PID with a high-priority program also running

#echo "Compiling busy-wait..."
#gcc -g -Wall -Werror -lm -lrt -std=gnu99 util-jpp.c busy-wait.c -o busy-wait

# Use 'nice' to de-prioritize PID and prioritize busy-wait:
# you can see 
# nice -n -10 ./busy-wait 10 &  # nice -20 (most favorable for proc) to 19 (least favorable)
# nice -n  10 ./main pid 20 -0.02 -0.6 0.00 pid-data-square-share-cpu.txt &

# Use 'nice' to de-prioritize PID and prioritize busy-wait:
# -5/5 still hurts PID
#nice -n -5 ./busy-wait 10 &  # nice -20 (most favorable for proc) to 19 (least favorable)
#nice -n  5 ./main pid 20 -0.02 -0.6 -0.003 pid-data-square-share-cpu.txt &

##################################################
# Run PID-with-forward-horizon and PRU, usleeps added in at either "btwn read & write" or "after normal 5ms sleep".
# Compare the 'sysfs' I/O to using the PRU I/O.
# Also compare: 20ms preemption comes (1) btwn read/write, (2) after usleep @ bottom of loop.

# ./main pid 5 -0.082849 -0.055907 -0.000645 pid-fwd-horizon.txt  

 # kp=-0.082849
 # ki=-0.055907 
 # kd=-0.000645
 # dur_busy=8
 # dur_pid=8
 # niceval=8

# ./pid-fwd

# ./pid-fwd $dur_pid $kp $ki $kd pid-pru-20ms-EOL-err-cmdbuf-triangle.txt

# ./pid-fwd $dur_pid $kp $ki $kd pid-pru-cmdbuf-triangle.txt
# ./pid-fwd $dur_pid $kp $ki $kd pid-pru-20ms-EOL-err-cmdbuf-triangle.txt
# ./pid-fwd $dur_pid $kp $ki $kd pid-pru-20ms-rw-err-cmdbuf-triangle.txt
# ./pid-fwd $dur_pid $kp $ki $kd pid-sysfs-triangle.txt
#./pid-fwd $dur_pid $kp $ki $kd pid-sysfs-20ms-EOL-err-triangle.txt
#  ./pid-fwd $dur_pid $kp $ki $kd pid-sysfs-20ms-rw-err-triangle.txt

############################################
# Run PID-fwd-horizon & PID-sysfs, no preempt added, with competing process


 # kp=-0.082849
 # ki=-0.055907 
 # kd=-0.000645
 # dur_busy=3
 # dur_pid=6
 # niceval=14


# echo "Compiling busy-wait..."
# gcc -g -Wall -Werror -lm -lrt -std=gnu99 util-jpp.c busy-wait.c -o busy-wait


# nice -n $niceval ./pid-fwd $dur_pid $kp $ki $kd data-sysfs-other-proc-nice-$niceval.txt &
# sleep 2
# nice -n "-$niceval" ./busy-wait $dur_busy &  # nice -20 (most favorable for proc) to 19 (least favorable)

# nice -n $niceval ./pid-fwd $dur_pid $kp $ki $kd data-sysfs-other-proc-nice-$niceval.txt &



# ./pid-fwd $dur_pid $kp $ki $kd tmp.txt





#########################################
# Run PID-fwd-horizon (w/ longer than 2 future samples), w/ competing process
# mar 9, 2017


#gdb --args ./pid-fwd2 
# ./pid-fwd2 


# note: for debugging, disabled the input args.
# kp=-0.082849
# ki=-0.055907 
# kd=-0.000645
#dur_busy=99
# dur_pid=7 # note: duration hard-coded; 5sec=stable 8=unstable, wtf
#niceval=2
# datafile=data-pru2-nice-$niceval.txt 
# prudatafile=pru-data-$niceval.txt 



#pidpid=$! # process identifier of PID task, in case we started it in background.
#echo "Waiting for PID to finish..."
#wait $pidpid

#echo "Compiling busy-wait..."
#gcc -g -Wall -Werror -lm -lrt -std=gnu99 util-jpp.c busy-wait.c -o busy-wait


# nice -n $niceval ./pid-fwd2 &
# pidpid=$! # process identifier of PID task, in case we started it in background.
# sleep 4
# nice -n "-$niceval" ./busy-wait $dur_busy &  # nice -20 (most favorable for proc) to 19 (least favorable)
# waitpid=$!

# echo "waiting for PID..."
# wait $pidpid
# echo "killing busywait..."
# kill $waitpid



#######################################################
# Hack: Add a couple extra points to the pid-fwd-horizon.
# pid-fwd3.c

# ./pid-fwd3

#  echo "Compiling busy-wait..."
#  gcc -g -Wall -Werror -lm -lrt -std=gnu99 util-jpp.c busy-wait.c -o busy-wait

# kp=-0.082849
# ki=-0.055907 
# kd=-0.000645
# dur_busy=4
# dur_pid=7 
# niceval=2
# datafile=data-pru3-nice-$niceval.txt 
# prudatafile=pru3-data-$niceval.txt 


#  nice -n $niceval ./pid-fwd3 $dur_pid $kp $ki $kd $datafile $prudatafile &
#  sleep 4
#  nice -n "-$niceval" ./busy-wait $dur_busy &  # nice -20 (most favorable for proc) to 19 (least favorable)

#####################################################
# Try to simplify ./pid-fwd2 

# ./pid-fwd22

 # niceval=5
 # dur_busy=2

 #   echo "Compiling busy-wait..."
 #   gcc -g -Wall -Werror -lm -lrt -std=gnu99 util-jpp.c busy-wait.c -o busy-wait

 #   nice -n $niceval ./pid-fwd22 pid22-$niceval-n.txt pid22-pru-$niceval-n.txt pid22-log-$niceval-n.txt &
 #   sleep 3
 #   nice -n "-$niceval" ./busy-wait $dur_busy &  # nice -20 (most favorable for proc) to 19 (least favorable)



#########################################################
# mar 13: re-twiddle pru gains

# # first test the format
#  kp=-0.082849
#  ki=-0.055907 
#  kd=-0.000645

# ./pid-fwd22-arggains $kp $ki $kd
# # don't run the competing process concurrently.



#######################################3
# mar 13: express the sysfs pid as an iir filter

# ./pid-sysfs-iir

##########################
# mar 14: see how pid sysfs iir does when preempted:


# niceval=10
# dur_busy=8
#   nice -n $niceval ./pid-sysfs-iir $niceval &
#   sleep 3
#   nice -n "-$niceval" ./busy-wait $dur_busy &  # nice -20 (most favorable for proc) to 19 (least favorable)


## start / stop multiple tasks
# niceval=10
# dur_busy=3
# sleep_btwn=1
# nice -n $niceval ./pid-sysfs-iir $niceval &
# sleep 3
# nice -n "-$niceval" ./busy-wait $dur_busy &  # nice -20 (most favorable for proc) to 19 (least favorable)
# sleep $sleep_btwn
# nice -n "-$niceval" ./busy-wait $dur_busy &  # nice -20 (most favorable for proc) to 19 (least favorable)
# sleep $sleep_btwn
# nice -n "-$niceval" ./busy-wait $dur_busy &  # nice -20 (most favorable for proc) to 19 (least favorable)
# sleep $sleep_btwn
# nice -n "-$niceval" ./busy-wait $dur_busy &  # nice -20 (most favorable for proc) to 19 (least favorable)
# sleep $sleep_btwn
# nice -n "-$niceval" ./busy-wait $dur_busy &  # nice -20 (most favorable for proc) to 19 (least favorable)
# sleep $sleep_btwn
# nice -n "-$niceval" ./busy-wait $dur_busy &  # nice -20 (most favorable for proc) to 19 (least favorable)
# sleep $sleep_btwn
# nice -n "-$niceval" ./busy-wait $dur_busy &  # nice -20 (most favorable for proc) to 19 (least favorable)

##############################
# mar 14: pid pru iir

# ./pid-pru-iir


###########################
# mar 14: pid pru iir preemption test

# niceval=5
# dur_busy=3
#   nice -n $niceval ./pid-pru-iir $niceval &
#   sleep 3
#   nice -n "-$niceval" ./busy-wait $dur_busy &  # nice -20 (most favorable for proc) to 19 (least favorable)




## start / stop multiple tasks
# niceval=7
# dur_busy=3
# sleep_btwn=1
# nice -n $niceval ./pid-pru-iir $niceval &
# sleep 3
# nice -n "-$niceval" ./busy-wait $dur_busy &  # nice -20 (most favorable for proc) to 19 (least favorable)
# sleep $sleep_btwn
# nice -n "-$niceval" ./busy-wait $dur_busy &  # nice -20 (most favorable for proc) to 19 (least favorable)
# sleep $sleep_btwn
# nice -n "-$niceval" ./busy-wait $dur_busy &  # nice -20 (most favorable for proc) to 19 (least favorable)
# sleep $sleep_btwn
# nice -n "-$niceval" ./busy-wait $dur_busy &  # nice -20 (most favorable for proc) to 19 (least favorable)
# sleep $sleep_btwn
# nice -n "-$niceval" ./busy-wait $dur_busy &  # nice -20 (most favorable for proc) to 19 (least favorable)
# sleep $sleep_btwn
# nice -n "-$niceval" ./busy-wait $dur_busy &  # nice -20 (most favorable for proc) to 19 (least favorable)
# sleep $sleep_btwn
# nice -n "-$niceval" ./busy-wait $dur_busy &  # nice -20 (most favorable for proc) to 19 (least favorable)




#################################
# Mar 28: run pru-time-sync alongside my pid

#echo "starting PRU time sync..."
#pushd /root/ucla-nesl-pru-lib/examples/time_sync/gen
#./host 
#popd

echo "starting PID..."
./pid-pru-iir





echo "#############################"

# echo "Opening data files" (can't do this on BB dummy)
# libreoffice --calc $datafile &
# libreoffice --calc $prudatafile &
# subl log.txt &


echo "All done with $0, bye!"
