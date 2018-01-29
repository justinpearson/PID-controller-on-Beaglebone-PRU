// #include "jpp-pru-lib.h"

#define PRU_TICKS_PER_SEC 


#include "util-jpp.h"
#include <stdio.h> // printf
#include <stdlib.h> // exit
#include <string.h> //  memcpy
#include <unistd.h> // usleep
#include <math.h> // fmod

// run some sine wave thru the lil motor.
  
double voltage_cmd_function(unsigned int sample_num) {

#if 0

  // 1Hz sine wave
  double freq_hz = 1; // cyc/sec
  double rads = (double) sample_num * PRU_TICKS_PER_SAMPLE / PRU_TICKS_PER_SEC * freq_hz * 2 * M_PI;
  //    units: =   samples       ticks / sample         ticks / sec          cyc / sec   rad / cyc
  //           = (                  seconds                            )  (      rad / sec      )
  return MAX_MOTOR_VOLTAGE * sin(rads);

#else

  double t;
  t = (double) (sample_num) * PRU_TICKS_PER_SAMPLE / PRU_TICKS_PER_SEC; // units:    samples       ticks / sample         ticks / sec   = seconds


  double m = 2;
  double t1=1, t2=2, t3=3, t4=4, t5=5, t6=6, t7=8, t8=9, t9=10, t10=11, t11=12, t12=13, t13=14, t14=15, t15=16, t16=17, t17=18, t18=19, t19=20, t20=21, t21=22, t22=23;
  double f1 = 1, f2 = 2, f3=3, f4=4, f5=5, f6=6; // hz
  double x = 0;

  if( t < t1 ) {
    x = 0;
  } else if( t1 <= t && t < t2 ) {
    x = 1;
  } else if( t2 <= t && t < t3 ) {
    x = 0;
  } else if( t3 <= t && t < t4 ) {
    x = -1;
  } else if( t4 <= t && t < t5 ) {
    x = 0;
  } else if( t5 <= t && t < t6 ) {
    x = m*(t-t5);
  } else if( t6 <= t && t < t7 ) {
    x = m*(t6-t5)- m*(t-t6);
  } else if( t7 <= t && t < t8 ) {
    x = m*(t6-t5)- m*(t7-t6) + m*(t-t7);
  } else if( t8 <= t && t < t9 ) {
    x = 0;
  } else if( t9 <= t && t < t10) {
    x = 1.0*sin(2*M_PI*f1*(t-t9));
  } else if( t10 <= t && t < t11 ) {
    x = 0;
  } else if( t11 <= t && t < t12 ) {
    x = 1.0*sin(2*M_PI*f2*(t-t11));
  } else if( t12 <= t && t < t13 ) {
    x = 0;
  } else if( t13 <= t && t < t14 ) {
    x = 1.0*sin(2*M_PI*f3*(t-t13));
  } else if( t14 <= t && t < t15 ) {
    x = 0;
  } else if( t15 <= t && t < t16 ) {
    x = 1.0*sin(2*M_PI*f4*(t-t15));
  } else if( t16 <= t && t < t17 ) {
    x = 0;
  } else if( t17 <= t && t < t18 ) {
    x = 1.0*sin(2*M_PI*f5*(t-t17));
  } else if( t18 <= t && t < t19 ) {
    x = 0;
  } else if( t20 <= t && t < t21 ) {
    x = 1.0*sin(2*M_PI*f6*(t-t20));
  } else if( t21 <= t && t < t22 ) {
    x = 0;
  } else {
    x = 0;
  }



  double voltage_cmd = MAX_MOTOR_VOLTAGE * x;

  if( voltage_cmd > MAX_MOTOR_VOLTAGE ) {
    voltage_cmd = MAX_MOTOR_VOLTAGE;
  }
  if( voltage_cmd < -MAX_MOTOR_VOLTAGE ) {
    voltage_cmd = -MAX_MOTOR_VOLTAGE;
  }

  return voltage_cmd;

#endif
}

int main( int argc, char* argv[] ) {

  //  start_pru();

  //  set_PRU_sample_period(  PRU_TICKS_PER_SAMPLE ); // this does somehting weird, I foret what.


  // This sim runs for SIM_TIME_SEC seconds, and the loop here tries to run once for every PRU_SAMPLES_PER_CPU_ITER pru samples.
  // Armed with the PRU clock freq (PRU_TICKS_PER_SEC) and the number of PRU clock ticks between sample times (PRU_TICKS_PER_SAMPLE), this determines (1) how many CPU iters we'll do,
  // and also how long to pause between CPU iters.
  // (In the real MPC system, the MPC will just run as fast as it can.)
  const unsigned long long SIM_TIME_SEC = 25;
  const unsigned long long PRU_SAMPLES_PER_CPU_ITER = 10;
  const unsigned long long NUM_TSTEPS = SIM_TIME_SEC * PRU_TICKS_PER_SEC / ( PRU_SAMPLES_PER_CPU_ITER * PRU_TICKS_PER_SAMPLE ); // units: cpu iters
  const double PAUSE_MICROS = (double) USEC_PER_SEC * PRU_TICKS_PER_SAMPLE * PRU_SAMPLES_PER_CPU_ITER / PRU_TICKS_PER_SEC; // units: useconds

  DataBuffer db[NUM_TSTEPS];
  CommandBuffer cb_rx[NUM_TSTEPS];
  CommandBuffer cb_tx[NUM_TSTEPS];
  double cputime[NUM_TSTEPS];
  double cputimediff[NUM_TSTEPS];
  unsigned int sns[NUM_TSTEPS];


  printf("Size of  int: %u long: %u long long: %u unsigned int: %u float: %u double: %u unsigned long: %u\n",
	 sizeof(int),
	 sizeof(long),
	 sizeof(long long),
	 sizeof(unsigned int),
	 sizeof(float),
	 sizeof(double),
	 sizeof(unsigned long) );

  printf( "SIM_TIME_SEC: %llu\n"
	  "PRU_TICKS_PER_SEC: %u\n"
	  "PRU_TICKS_PER_SAMPLE: %u\n"
	  "PRU_SAMPLES_PER_CPU_ITER: %llu\n"
	  "NUM_TSTEPS (# cpu iters): %llu\n" 
	  "PAUSE_MICROS: %lf\n", 
	  SIM_TIME_SEC,      
	  PRU_TICKS_PER_SEC,
	  PRU_TICKS_PER_SAMPLE,
	  PRU_SAMPLES_PER_CPU_ITER,
	  NUM_TSTEPS, 
	  PAUSE_MICROS);

    unsigned int sample_num0 = get_sample_num();

  for( int i=0; i<NUM_TSTEPS; i++ ) {

    get_data_cmd_bufs( &(db[i]), &(cb_rx[i]) );


    // some weird problem with the pru not writing its PRU data buffer into the cpu data buffer.
    // fixed by having hte pru code blindly copy the PDB to the CDB and having the jpp-pru-lib.c code sort it intead.
    if( db[i][0].sample_num == 0xcdb0cdb0 ) {
      printf("i: %d, last cyc time: %u\n", i, db[i][PKTS_PER_DATA_BUFFER-1].cycle_count);
      printf("-----------------\n uh oh!!!!!!!!!! \n");
      print_data_buf( db[i] );
      printf("\nhm......\n");
    }

    toc(&(cputime[i]), &(cputimediff[i]) );

    unsigned int sn = get_sample_num();
    sns[i] = sn;

    for( int j=0; j<PKTS_PER_CMD_BUFFER; j++ ) {
      cb_tx[i][j].cycle_count = 13; // verify this doesn't appear -- we're having the PRU write the cyc count of the time when it rx'd the cmd buf, for debugging purposes.
      cb_tx[i][j].sample_num  = sn + j;
      motor_voltage_cmd_to_gpio_duty( voltage_cmd_function(sn+j - sample_num0 ), &(cb_tx[i][j].gpio), &(cb_tx[i][j].duty));
    }

    set_cmd_buf(cb_tx[i]);
    
    usleep(PAUSE_MICROS);
    //printf("sleeping for like 10 sec; pru is real slow when in debugger...");
    //sleep(10);
  }

  send_single_voltage(0);

  FILE* flog;
  flog = fopen("runlog.txt","w");
  fprintf(stderr,"NOTE: Writing log to file: runlog.txt\n");


  for( int i=0; i<NUM_TSTEPS; i++ ) {
    for( int j=0; j<PKTS_PER_DATA_BUFFER; j++ ) {
      fprintf(flog, "Iter: %4d ",i);
      fprintf(flog, "Time: %15.9lf diff: %15.9lf getsampnum: %5u ",cputime[i], cputimediff[i], sns[i]);
      fprintf_data_pkt( flog, db[i][j] );
    fprintf(flog,"\n");
    }

  }

  FILE* flog2;
  flog2 = fopen("runlog_cmd_rx.txt","w");
  fprintf(stderr,"NOTE: Writing log to file: runlog_cmd_rx.txt\n");


  for( int i=0; i<NUM_TSTEPS; i++ ) {
    for( int j=0; j<PKTS_PER_CMD_BUFFER; j++ ) {
      fprintf(flog2, "Iter: %4d ",i);
      fprintf(flog2, "Time: %15.9lf diff: %15.9lf getsampnum: %5u ",cputime[i], cputimediff[i], sns[i]);
      fprintf_cmd_pkt( flog2, cb_rx[i][j] );
    fprintf(flog2,"\n");
    }
  }


  FILE* flog3;
  flog3 = fopen("runlog_cmd_tx.txt","w");
  fprintf(stderr,"NOTE: Writing log to file: runlog_cmd_tx.txt\n");

  for( int i=0; i<NUM_TSTEPS; i++ ) {
    for( int j=0; j<PKTS_PER_CMD_BUFFER; j++ ) {
      fprintf(flog3, "Iter: %4d ",i);
      fprintf(flog3, "Time: %15.9lf diff: %15.9lf getsampnum: %5u ",cputime[i], cputimediff[i], sns[i]);
      fprintf_cmd_pkt( flog3, cb_tx[i][j] );
    fprintf(flog3,"\n");
    }
  }



  fclose(flog);
  fclose(flog2);
  fclose(flog3);

  return(0);
}
