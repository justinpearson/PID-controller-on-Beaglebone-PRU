#!/bin/bash

echo "Running $exefile at realtime priority:"
chrt 20 ./main $1


#echo "Make mpc-data-999.txt -- only 999 columns (needed for matlab import)..."

# cols needed in the -999 version:
# %% Allocate imported array to column variable names
# t_9 = dataArray{:, 1};
# t_10 = dataArray{:, 2};
# ref_0 = dataArray{:, 3};
# cycle_count31 = dataArray{:, 4};
# sample_num31 = dataArray{:, 5};
# adc31 = dataArray{:, 6};
# eqep31 = dataArray{:, 7};
# gpio31 = dataArray{:, 8};
# duty31 = dataArray{:, 9};
# data_req_time31 = dataArray{:, 10};
# reqs_and_schs31 = dataArray{:, 11};
# num_reqs31 = dataArray{:, 12};
# num_cmdschs31 = dataArray{:, 13};
# amps31 = dataArray{:, 14};
# angle31 = dataArray{:, 15};
# volts31 = dataArray{:, 16};
# rxcmd_sch_rx_time0 = dataArray{:, 17};
# rxcmd_sample_num0 = dataArray{:, 18};
# rxcmd_gpio0 = dataArray{:, 19};
# rxcmd_duty0 = dataArray{:, 20};
# rxcmd_volts0 = dataArray{:, 21};

#cat mpc-data.txt | tr -s ' ' | cut -d" " -f228,229,249,674-691 > mpc-data-999.txt # oct 10
#cat mpc-data.txt | tr -s ' ' | cut -d" " -f256,257,277,702-719 > mpc-data-999.txt # oct 11

#cat mpc-data.txt | tr -s ' ' | cut -d" " -f674-691 > mpc-data-999.txt
# cat runlog.txt | cut -d" " -f2- | sort -n | uniq > runlog-nice.txt
# cat runlog.txt | cut -d" " -f2- | sort -n | uniq > runlog-nice.txt
#cat runlog.txt | tr -s ' ' | cut -d" " -f12- | sort -n | uniq > runlog-nice.txt



echo "Quitting 'run' shell script..."
exit 0

################################################################

# set -x
set -e

echo "I'm in: "
echo `pwd`

#echo " building jadcpwmeqep.o"
#gcc -std=gnu99 -g -Wall -Werror -pthread -lstdc++ -std=gnu99  -c jadcpwmeqep.c


# .p: PRU code
# .c: PRU lib implementation







EQEP_DIR=/sys/devices/ocp.3/48302000.epwmss/48302180.eqep/
if [ -d "$EQEP_DIR" ]; then
    # Control will enter here if $DIRECTORY exists.
    echo "Resetting eqep..."
    echo 0 > $EQEP_DIR"position"
else
    echo "EQEP dir not found; are you aware that you may be compiling on a non-BB?"
fi


name=jpp-pru-lib
pfile=$name.p



#testname=test0-get-data
#testname=test1-get-data-fast
#testname=test2-gpio-tests
#testname=test3-drive-motor
#testname=test4-sysid
#testname=test5-calibrate-sensors
#testname=test6-chirp
#testname=test7-david-chirp
#testname=20160729_T5_L3_Ts8_4V-pru
#testname=09_10_2016_V4_final
#testname=20160913_V4_future_u
#testname=20160914_T32_V4_future_u
#testname=20160914_T32_V4_future_u-with-sensors
#testname=x0-hack2-20160914
#testname=20160915_Ts0008_S5L5T10
#testname=set-pwm-duty-schedule
#testname=send-late-cmd-sch
# testname=20160916_Ts016_T10L5
#testname=sysid-take-2
#testname=20160916_Ts23_T10_L5
#testname=20160917_Ts12_T5_L3
#testname=20160917_Ts20_T5_L3
#testname=20160917_Ts20_T5_L3_angle_only
#testname=20160917_Ts20_T5_L3_angle_only-header-row-FAKE_DATA_COMPARE
#testname=20160917_Ts20_T5_L3_angle_only-header-row-FAKE_DATA_COMPARE-log-to-file
#testname=test01-set-sample-period
#testname=test02-get-sample-num
#testname=test03-get-data-cmd-bufs-at-once
#testname=test04-cycle-count-reset
#testname=test05-magic-cmd-pkts
#testname=test06-reconstruct-cmd-seq
#testname=20160928_Ts20_T5_L3_S1-new
testname=20160929_T5_L3_S1
ctestfile=$testname.c
exefile=$testname


    echo "building..."


echo "=========================="
echo "building util-jpp library..."

echo "------------------------"

utilname="util-jpp"
gcc -Wall -std=gnu99 -g -Wall -Werror -lstdc++ -std=gnu99 -lrt -c $utilname.c


echo "=========================="
echo "building PRU C library..."

echo "------------------------"

echo "Using pasm to assemble .p file $pfile into .bin file $binfile..."


pasm -b $pfile

echo "~~~~~~~~~~~~~~~~~"

binfile=$name.bin
clibfile=$name.c
olibfile=$name.o

echo "Compiling .c file $clibfile into .o file $olibfile"

gcc -Wall -std=gnu99 -g -Wall -Werror -pthread -lstdc++ -std=gnu99 -c $clibfile


echo "~~~~~~~~~~~~~~~~~~~~~~~~~~"

echo "Building test .c file $ctestfile to make $exefile"

# echo "(Careful - does your .c load the correct .p / .bin?)"

# use -std=c99 to permit for( int i=0
# without this you get: ‘for’ loop initial declarations are only allowed in C99 mode
# Or: -std=gnu99 and usleep. gnu99 and nanosleep no work.

# -lm: needed for fmod in angle wrap alg
#        http://stackoverflow.com/questions/11336477/gcc-will-not-properly-include-math-h

# -lprussdrv : PRU livs
# -lrt: clock_gettime( CLOCK_REALTIME , )
# -lpthread : threading stuff? prob not needed.
#gcc -Wall -std=gnu99 -lm -g $ctestfile $olibfile -o $exefile -lprussdrv -lrt

date
gcc -g -Wall -Werror -Wno-unused-variable -Wno-unused-result -lstdc++ -std=gnu99 -O0 -DNDEBUG -lprussdrv -lrt -lm  $ctestfile $olibfile $utilname.o -o $exefile 
date

if [ "$1" == "b" ]; then
    echo "you gave me 'b', so I'll just build. Run it yourself: ./$exefile or chrt 20 ./$exefile"
    exit 0
fi

echo "Just running $exefile ..."

#echo "Running $exefile"
#./$exefile

echo "Running $exefile at realtime priority:"
chrt 20 ./$exefile


echo "Making nicer data file..."
# cat runlog.txt | cut -d" " -f2- | sort -n | uniq > runlog-nice.txt
#cat runlog.txt | tr -s ' ' | cut -d" " -f12- | sort -n | uniq > runlog-nice.txt

#fi


