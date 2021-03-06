#include <stdio.h>
#include <errno.h> // for strerror(errno)
// #include <fcntl.h> // flags for 'open', eg O_WRONLY, O_SYNC, etc
#include <string.h> // for strerror also?
#include <math.h> // fabs, M_PI
#include <stdlib.h> // exit,  EXIT_FAILURE
#include <unistd.h> // usleep, pread


#include "util-jpp.h"
// #include "bb-simple-sysfs-c-lib.h" 
#include "jpp-pru-lib.h"

#define MAX_VOLTAGE 5 // Volts


//#define FAKE_OS_PREEMPTION
//#define MAX_SLEEP_SEC (0.005)  // for fake preemption
// #define USEC_PER_SEC (1E6)

#define SLEEP_TYPE (2) // 0=sleep for dt, 1=sleep til next iter, 2=sleep for half dt (hack, sry)

#define ANGLE_PREDICTION_MODEL (0) // 0=constant 1=linear
#define REF_TYPE (2)   // 0=sin 1=square 2=triangle
#define REF_FREQ (0.5); // // Hz, controls how fast the reference angle changes
const int T = 10; // forward horizon

////////////////////////////////////////

double reference( double t ) {
  const double freq = REF_FREQ; 
  double r = 0;
#if REF_TYPE == 0 // sine wave
  r = 180 * sin(2.0 * M_PI * freq * t); // deg
#elif REF_TYPE == 1 // square wave
  r = 180 * sin(2.0 * M_PI * freq * t); // deg
  if(r>0) r=180; else r=-180; // make square wave.
#elif REF_TYPE == 2 // triangle wave
  // https://en.wikipedia.org/wiki/Triangle_wave
  //    4*a/p*(fabs(fmod(x-p/4,p)-p/2) - p/4)
  double a = 180; // amplitude (deg)
  double p = 1/freq; // period (s?)
  //    ref[i] =     4*a/p*(fabs(fmod(cputime[i]-p/4,p)-p/2) - p/4);
  //  http://stackoverflow.com/questions/11980292/how-to-wrap-around-a-range
  // arg, don't use fmod because it goes up beyond 180 deg to 360 on the first cycle.
  // instead of fmod(x,y) use x-y*floor(x/y).
  r =        4*a/p*(fabs(  (t-p/4)-p*floor((t-p/4)/p)  -p/2) - p/4);
#endif

  return r;
}


void printLocalTime(FILE* fp) {
  // https://www.tutorialspoint.com/c_standard_library/c_function_localtime.htm
  time_t rawtime;
  time( &rawtime );
  struct tm *info;
  info = localtime( &rawtime );
  if( fp == 0 ) {
    printf("Current local time and date: %s", asctime(info));
  } else {
    fprintf(fp,"Current local time and date: %s", asctime(info));
  }

}

int main ( int argc, char *argv[] ) {

  printLocalTime(0);

  printf("USING PRU!\n");

  printf("%s %s (%d): HEY IDIOT, sysfs pwm goes out P9_34 but PRU pwm goes out P8_27. \n"
	 "Make sure your wiring reflects this!\n",__FILE__,__FUNCTION__,__LINE__);

  // Input parse.
    double duration     = argc>1 ? atof(argv[1]) :  1; // duration, sec
  /* const double kp           = argc>2 ? atof(argv[2]) : -0.082849; // kp */
  /* const double ki           = argc>3 ? atof(argv[3]) : -0.055907; // ki */
  /* const double kd           = argc>4 ? atof(argv[4]) : -0.000645; // kd */
  /* char* out_name      = argc>5 ? argv[5]       : "pid-fwd.txt";        // output file name */
  /* char* pru_out_name  = argc>6 ? argv[6]       : "pru-data.txt";        // output file name of pru data */


  const double kp       = -0.082849; // kp
  const double ki           =  -0.055907; // ki
  const double kd           =  -0.000645; // kd
  const char* out_name      = "pid-fwd.txt";        // output file name
  const char* pru_out_name  = "pru-data.txt";        // output file name of pru data
  const char* flogname = "log.txt";




  ////////////////////////////////////////////////////////////////////////////
  // files to hold results
  FILE* fp;
  fp = fopen(out_name, "w");

  FILE* flog; 

  printf("Log file: %s\n",flogname);
  flog = fopen(flogname,"w");

  // Configure the data file and log file to be "fully buffered",
  // meaning that they won't write to disk until explicitly told (or closed).
  // https://www.chemie.fu-berlin.de/chemnet/use/info/libc/libc_7.html#SEC118
#define fp_buf_size 999999
#define flog_buf_size  999999
  char fp_buf[fp_buf_size] = {};
  char flog_buf[flog_buf_size] = {};
  int retval = 0;
  if( (retval = setvbuf( fp, fp_buf, _IOFBF, fp_buf_size )) != 0 ) {
    printf("BAD: setvbuf returned %d\n",retval);
  }
  if( (retval = setvbuf( flog, flog_buf, _IOFBF, flog_buf_size )) != 0 ) {
    printf("BAD: setvbuf returned %d\n",retval);
  }
  char stdout_buf[fp_buf_size] = {};
  if((retval=setvbuf(stdout, stdout_buf, _IOFBF, fp_buf_size))!=0) {
    printf("bad: setvbuf returned %d\n",retval);
    return EXIT_FAILURE;
  }
  char stderr_buf[fp_buf_size] = {};
  if((retval=setvbuf(stderr, stderr_buf, _IOFBF, fp_buf_size))!=0) {
    printf("bad: setvbuf returned %d\n",retval);
    return EXIT_FAILURE;
  }

  printLocalTime(flog);


  const double DT = 0.005; // sec, time per iteration


  const double max_time = duration; // sec, max time of sim
  const int num_iters = max_time / DT;
  const int N = num_iters;
  const int MAX_ITERS = num_iters;

  DataBuffer db_buffer    [MAX_ITERS];
  CommandBuffer cb_buffer [MAX_ITERS];
  CommandBuffer cb_rx     [MAX_ITERS];

  for(int i=0;i<MAX_ITERS;i++)init_data_buf(db_buffer[i]);
  for(int i=0;i<MAX_ITERS;i++)init_cmd_buf(cb_buffer[i]);
  for(int i=0;i<MAX_ITERS;i++)init_cmd_buf(cb_rx[i]);

  printf("cb_buffer[0]: \n");

  printf( "%10u %6d %4u %5u %10lf\n",
	 cb_buffer[0][0].cycle_count,
	 cb_buffer[0][0].sample_num,
	 cb_buffer[0][0].gpio,
	  cb_buffer[0][0].duty,
	 gpio_duty_to_motor_voltage_cmd(cb_buffer[0][0].gpio,cb_buffer[0][0].duty)
	 );


  double v_future[num_iters][T]; 
  for(int i=0;i<num_iters;i++){for(int j=0;j<T;j++){v_future[i][j]=0;}}



  // Warning: These are all doubles because if you printf or fprintf an int using %lf it produces garbage,  ugh.
  // http://stackoverflow.com/questions/16607628/printing-int-as-float-in-c

  double step[N]       ; for(int i=0;i<N;i++) step[i]=0;
  double sn_buf[N]     ; for(int i=0;i<N;i++) sn_buf[i]=0;
  double ts_buf[N]     ; for(int i=0;i<N;i++) ts_buf[i]=0;
  double cputime[N]    ; for(int i=0;i<N;i++) cputime[i]=0;
  double cputimediff[N]; for(int i=0;i<N;i++) cputimediff[i]=0;
  double angle[N]      ; for(int i=0;i<N;i++) angle[i]=0;
  double ref[N]        ; for(int i=0;i<N;i++) ref[i]=0;
  double error[N]      ; for(int i=0;i<N;i++) error[i]=0;
  double v[N]          ; for(int i=0;i<N;i++) v[i]=0;
  double cycle_count[N]; for(int i=0;i<N;i++) cycle_count[i]=0;
  
  double imax = 2; // max volts allowed of integral term. (volts)




  // Try to get cputime to line up with PRU time by initializing it here.
  toc(&(cputime[0]), &(cputimediff[0]) ); // this sets cputime[0]=0 and counts up from there.

  printf("Starting PRU...\n");
  start_pru();

  printf("duration: %lf kp: %lf ki: %lf kd: %lf outfile: %s\n",duration, kp, ki, kd,out_name);



  // PRU gets some time to warm up, so his sample nums are huge by the time start_pru() returns.
  // Get the sample num that we should consider "t=0" : the start of our test.
  get_data_cmd_bufs( &(db_buffer[0]), &(cb_rx[0]) ); 
  const unsigned int sn0 = db_buffer[0][PKTS_PER_DATA_BUFFER-1].sample_num;

  printf("PRU sample number: %d\n",sn0);

  fprintf(flog,"PRU starting at sn0=%d\n",sn0);

  // Compute the entire reference signal in advance.
  for( int j=0; j<num_iters; j++ ) {
    double t = j * DT;
    ref[j] = reference( t );
  }

  fprintf(flog,"ref signal: 0:%lf 1:%lf 2:%lf 3:%lf...\n",ref[0],ref[1],ref[2],ref[3]);

  unsigned int snprev = 0;
  double iterm = 0;




  ///////////////////////////////////////////////
  // LOOP
  ///////////////////////////////////////////////

  int i=-1;
  while( 1 ) {
    i++;
    step[i]    	  = i;
    fprintf(flog,"/////////////// Iter %d\n",i);

    ///////////////////////////////////////////////
    // Get time
    ///////////////////////////////////////////////

    toc(&(cputime[i]), &(cputimediff[i]) );

    fprintf(flog,"iter %d cputime %lf cputimediff %lf ",i,cputime[i],cputimediff[i]);

    if( cputime[i] > duration ) {
      fprintf(flog,"cputime[i=%d]=%lf exceeds duration (%lf), exiting.\n",i,cputime[i],duration);
      goto BAIL;
    }


    ///////////////////////////////////////////////
    // Read sensors
    ///////////////////////////////////////////////

    get_data_cmd_bufs( &(db_buffer[i]), &(cb_rx[i]) ); 
    unsigned int sn = db_buffer[i][PKTS_PER_DATA_BUFFER-1].sample_num; 
    sn_buf[i] = sn;
    unsigned int ts = sn; // ditch the "ts different than sn" idea. (was sn-sn0).
    ts_buf[i] = ts;

    fprintf(flog,"sn=%d ts=%d. ",sn,ts);

    if( i==10 ) {
      printf("breakpoint! i=%d\n",i);
    }


    if( sn > snprev ) {
      // Some new data packets arrived.
      fprintf(flog,"sn=%d > snprev=%d so %d new pkts!\n",sn,snprev, sn-snprev);

      fprintf(flog,"iterm before catch up: %lf\n",iterm);

      // Copy samples from db to "local" array.
      for( int j=PKTS_PER_DATA_BUFFER-1; j>=0; j-- ) {
	// db elem 31 has sample num "sn-0" (index sn-sn0-0)
	// db elem 30 has sample num "sn-1" (index sn-sn0-1)
	// ...
	// continue until your index goes negative or 
	// when you're caught up (sn == snprev)

	int sn_pkt = db_buffer[i][j].sample_num;
	int ts_pkt = sn_pkt;
	if( ts_pkt < 0 ) {
	  fprintf(flog,"ts_pkt=%d<0, bad unless you're just starting. anyway, done copying.\n",ts_pkt);
	  break;
	}
	if(  sn_pkt <= snprev ) {
	  fprintf(flog,"sn_pkt=%d <= snprev=%d so caught up w/ data.\n",sn_pkt,snprev);
	  break;
	}

	if( ts_pkt >= N ) {
	  fprintf(flog,"ts_pkt=%d >= N=%d, ie the sequence nums exceeded len(angle)! OH NOOO\n",
		  ts_pkt,N);
	  goto BAIL;
	}

	if( j==0 ) {
	  fprintf(flog,"UH OH: j==0, meaning we're out of buffered data. "
		  "Maybe preempted longer than 32 pkts! :-0\n");
	}
	

	// ugh, eqep_to_angle return radians, sysfs lib returns degs... and gains assume degs.
	angle[ts_pkt] = 180.0 / M_PI *  eqep_to_angle( db_buffer[i][j].eqep );
	v[ts_pkt] = gpio_duty_to_motor_voltage_cmd( 
						    db_buffer[i][j].gpio,
						    db_buffer[i][j].duty
						     );
	cycle_count[ts_pkt] = db_buffer[i][j].cycle_count;
	error[ts_pkt] = ref[ts_pkt] - angle[ts_pkt];

	fprintf(flog,"angle[ts=%d]=%lf, gpio=%d, duty=%d, v[ts=%d]=%lf, cc[ts=%d]=%lf, err[ts=%d]=%lf\n",
		ts_pkt,
		angle[ts_pkt],
		db_buffer[i][j].gpio, 
		db_buffer[i][j].duty,
		ts_pkt,
		v[ts_pkt],
		ts_pkt,
		cycle_count[ts_pkt],
		ts_pkt,
		error[ts_pkt]
		);

	// Catch up the integral term since last time.
	if( iterm < imax && iterm > -imax ) { // anti-windup
	  iterm += ki * error[ts_pkt] * DT;
	}
      } // import data from db
      
      fprintf(flog,"iterm after catch up: %lf\n",iterm);
      
      fprintf(flog,"Make a forward horizon of voltage cmds.\n");

      double tmp_iterm = iterm;
      double eprev = ts>0 ? error[ts-1] : 0;

      // Bail if future horizon exceeds len of arrays.
      if( ts+T >= num_iters ) {
	fprintf(flog,"Constructing future horiz (ts=%d + T=%d would "
		"exceed arrays (num_iters=%d); exiting.\n",ts,T,num_iters);
	goto BAIL;
      }


      double slope = angle[ts]-angle[ts-1];


      for( int j=0; j<T; j++ ) {
	fprintf(flog,"j=%d ",j);

#if ANGLE_PREDICTION_MODEL == 0 // 0=constant 
	double a = angle[ts]; // assume constant (for now)
#elif ANGLE_PREDICTION_MODEL == 1 // 1 = linear
	double a = angle[ts] + slope*j;
#endif

	double e = ref[ts+j] - a;
	if( tmp_iterm < imax && tmp_iterm > -imax ) { // anti-windup of fwd horizon
	  tmp_iterm += j>0 ? ki*e*DT : 0; // when j==0, we've already int'd from above.
	}
	double tmp_dterm = kd*(e-eprev)/DT;
	double vv = kp*e + tmp_iterm + tmp_dterm;
	fprintf(flog,"pterm=%lf, iterm=%lf, dterm=%lf ",kp*e,tmp_iterm, tmp_dterm);
	if( vv > MAX_VOLTAGE ) vv =  MAX_VOLTAGE;
	if( vv < -MAX_VOLTAGE) vv = -MAX_VOLTAGE;
	v_future[i][j] = -vv; // DARN: PRU wired backwards from sysfs; minus sign needed.
	fprintf(flog,"vfut[j=%d ts=%d sn=%d]=%lf\n",j,ts+1+j,sn+1+j,v_future[i][j]);
	eprev = e;
      }

      // Send voltage sequence to PRU, starting at sequence num sn+1. 
      motor_voltage_schedule_to_cmd_buf(v_future[i],
					PKTS_PER_CMD_BUFFER,
					sn+1,
					&(cb_buffer[i]) );
      set_cmd_buf( cb_buffer[i] );

      snprev = sn; // remember for next time, so we can fast-fwd int of err

    } // If sn > snprev
    else if( sn==snprev ) {
      // Else, we've read the same db twice. Chill out until the next timestep, hotshot.
      fprintf(flog,"--> iter %d : sn=%d same snprev=%d : slow down hotshot!\n",i,sn,snprev);
    }
    else {
      fprintf(flog,"!!!!--> iter %d: sn=%d < snprev=%d THIS SHOULD NEVER HAPPEN, QUITTING...\n",
	      i,sn,snprev);
      goto BAIL;
    }



    ///////////////////////////////////////////////
    // Sleep until next iteration
    ///////////////////////////////////////////////

#if SLEEP_TYPE == 0
    usleep(DT*USEC_PER_SEC);
#elif SLEEP_TYPE == 1
    double sec_til_next = sec_til_next_timestep(DT);
    fprintf(flog,"sleeping for %lf secs! (til next ts)!\n",sec_til_next);
    // sleep until timestep i+1 (must call toc() once at beginning to get a ref time)
    usleep(sec_til_next*USEC_PER_SEC);
#elif SLEEP_TYPE == 2
    // ugh, like don't sleep if you've been preempted but don't fall behind either...
        usleep(DT/4*USEC_PER_SEC);
#endif



  }  // END OF MAIN LOOP


  ///////////////////////////////////////////////
  // Turn off motor
  ///////////////////////////////////////////////

 BAIL:


  send_single_voltage(0);

  printf("%s %s (%d): Stopped hw.\n",__FILE__,__FUNCTION__,__LINE__);


  ///////////////////////////////////////////////
  // Write data to file 
  ///////////////////////////////////////////////



  printf("Writing data to %s...\n",out_name);


  // Header row
  fprintf(fp,"%11s %11s %11s %11s %11s %11s %11s %11s %11s %11s ",
	  "step",
	  "sn",
	  "ts",
	  "cyclecount",
	  "cputime",
	  "cputimediff",
	  "angle", 
	  "ref", 
	  "error",
	  "v"
	  );

  for(int j=0;j<T;j++) {
    fprintf(fp,"v_future_%01d ",j);
  }


  fprintf(fp,"\n");



  // Write data
  for( int i=0; i<num_iters; i++ ) {

    fprintf(fp,"%11lf %11lf %11lf %11lf %11lf %11lf %11lf %11lf %11lf %11lf ",
	    step[i],
	    sn_buf[i],
	    ts_buf[i],
	    cycle_count[i],
	    cputime[i],
	    cputimediff[i],
	    angle[i], 
	    ref[i],
	    error[i],
	    v[i]
	    );

    for(int j=0;j<T;j++) {
      fprintf(fp,"%11lf ",v_future[i][j]);
    }

    fprintf(fp,"\n");
  }



  fclose(fp);


  fp = fopen(pru_out_name, "w");
  printf("pru data to %s...\n",pru_out_name);

  // Print data buffer header
  fprintf_data_buf_header( fp ); // databuffer
  fprintf_cmd_buf_header_prefix( fp, "rx" ); // cb_rx
  fprintf_cmd_buf_header_prefix( fp, "tx" ); // cb_buffer
  fprintf(fp,"\n");
  // Print data buffer:
  for( int tstep=0; tstep<MAX_ITERS; tstep++ ) {
    fprintf_data_buf( fp, db_buffer[tstep] );
    fprintf_cmd_buf(fp, cb_rx[tstep] );
    fprintf_cmd_buf(fp, cb_buffer[tstep] );
    fprintf(fp,"\n");
  }
  fclose(fp);


  fclose(flog);


  printf("%s %s (%d): Bye!\n",__FILE__,__FUNCTION__,__LINE__);

  return 0;
}

