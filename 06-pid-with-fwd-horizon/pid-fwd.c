#include <stdio.h>
#include <errno.h> // for strerror(errno)
// #include <fcntl.h> // flags for 'open', eg O_WRONLY, O_SYNC, etc
#include <string.h> // for strerror also?
#include <math.h> // fabs, M_PI
#include <stdlib.h> // exit,  EXIT_FAILURE
#include <unistd.h> // usleep, pread


#include "util-jpp.h"
#include "bb-simple-sysfs-c-lib.h"
#include "jpp-pru-lib.h"


// #define USING_PRU
// #define USING_PRU_SINGLE_SHOT

//#define FAKE_OS_PREEMPTION
//#define MAX_SLEEP_SEC (0.005)  // for fake preemption
// #define USEC_PER_SEC (1E6)

// #define SMART_SLEEP

#define REFTYPE (2)   // 0=sin 1=square 2=triangle


int main ( int argc, char *argv[] ) {

#ifdef USING_PRU
  printf("USING PRU!\n");
#else
  printf("NOT using pru!\n");
#endif


  printf("%s %s (%d): HEY IDIOT, sysfs pwm goes out P9_34 but PRU pwm goes out P8_27. \n"
	 "Make sure your wiring reflects this!\n",__FILE__,__FUNCTION__,__LINE__);


  double duration     = argc>1 ? atof(argv[1]) :  3; // duration, sec
  double kp           = argc>2 ? atof(argv[2]) : -0.082849; // kp
  double ki           = argc>3 ? atof(argv[3]) : -0.055907; // ki
  double kd           = argc>4 ? atof(argv[4]) : -0.000645; // kd
  char* out_name      = argc>5 ? argv[5]       : "pid-fwd.txt";        // output file name
  char* pru_out_name  = argc>6 ? argv[6]       : "pru-data.txt";        // output file name of pru data


#ifdef USING_PRU
  printf("Starting PRU...\n");
  start_pru();
#else
  setup();
  unstby();
  run();
  cw();
#endif


  printf("duration: %lf kp: %lf ki: %lf kd: %lf outfile: %s\n",duration, kp, ki, kd,out_name);

  const double DT = 0.005; // sec, time per iteration
  const double max_time = duration; // sec, max time of sim
  const int num_iters = max_time / DT;
  const int N = num_iters;
  const int MAX_TSTEPS = num_iters;


  DataBuffer db_buffer    [MAX_TSTEPS];
  CommandBuffer cb_buffer [MAX_TSTEPS];
  CommandBuffer cb_rx     [MAX_TSTEPS];

  for( int i=0; i<MAX_TSTEPS; i++ ) {
    init_data_buf( db_buffer[i] );
  }
  for( int i=0; i<MAX_TSTEPS; i++ ) {
    init_cmd_buf( cb_buffer[i] );
  }
  for( int i=0; i<MAX_TSTEPS; i++ ) {
    init_cmd_buf( cb_rx[i] );
  }



  const double freq = .5; // Hz, controls how fast the reference angle changes

  // Warning: These are all doubles because if you printf or fprintf an int using %lf it produces garbage,  ugh.
  // http://stackoverflow.com/questions/16607628/printing-int-as-float-in-c

  double step[N]       ; for(int i=0;i<N;i++) step[i]=0;
  double cputime[N]    ; for(int i=0;i<N;i++) cputime[i]=0;
  double cputimediff[N]; for(int i=0;i<N;i++) cputimediff[i]=0;
  double angle[N]      ; for(int i=0;i<N;i++) angle[i]=0;
  double ref[N]        ; for(int i=0;i<N;i++) ref[i]=0;
  double error[N]      ; for(int i=0;i<N;i++) error[i]=0;
  double ierror[N]     ; for(int i=0;i<N;i++) ierror[i]=0;
  double derror[N]     ; for(int i=0;i<N;i++) derror[i]=0;
  double pterm[N]      ; for(int i=0;i<N;i++) pterm[i]=0;
  double iterm[N]      ; for(int i=0;i<N;i++) iterm[i]=0;
  double dterm[N]      ; for(int i=0;i<N;i++) dterm[i]=0;
  double v[N]          ; for(int i=0;i<N;i++) v[i]=0;
  double imax = 2; // max volts allowed volts

  double t = 0; // time
  double dt = DT; // time since last iter

  ///////////////////////////////////////////////
  // LOOP
  ///////////////////////////////////////////////
  for( int i=0; i<num_iters; i++ ) {
    step[i]    	  = i;

    ///////////////////////////////////////////////
    // Get time
    ///////////////////////////////////////////////




    ///////////////////////////////////////////////
    // Read sensors
    ///////////////////////////////////////////////


#ifdef USING_PRU
    // write it to the huge history of buffers for writing the data file later:
    get_data_cmd_bufs( &(db_buffer[i]), &(cb_rx[i]) ); 

    // Sample number that our Vm's should start at:
    unsigned int sn = db_buffer[i][PKTS_PER_DATA_BUFFER-1].sample_num; // get_sample_num();

    // ugh, eqep_to_angle return radians, sysfs lib returns degs... and gains assume degs.
    angle[i]   	  =   180.0 / M_PI *  eqep_to_angle( db_buffer[i][PKTS_PER_DATA_BUFFER-1].eqep );
    cputime[i]=sn*DT;
    cputimediff[i]=(i>0)?cputime[i]-cputime[i-1]:0;
#else
    angle[i]   	  = shaft_angle_deg();
    toc(&(cputime[i]), &(cputimediff[i]) );
#endif


    ///////////////////////////////////////////////
    // Possibly fake an OS preemption
    ///////////////////////////////////////////////

    


    ///////////////////////////////////////////////
    // Run control algorithm
    ///////////////////////////////////////////////



    // make a crude forward-horizon 
    double slope  = i>0 ? (angle[i]-angle[i-1])/cputimediff[i] : 0;
    double angle2 = angle[i] + slope * DT;
    double angle3 = angle2   + slope * DT;


#if REFTYPE == 0 // sine wave
    ref[i]     	  = 180 * sin(2.0 * M_PI * freq * cputime[i]); // deg
    double ref2   = 180 * sin(2.0 * M_PI * freq * (cputime[i]+DT)); // deg
    double ref3   = 180 * sin(2.0 * M_PI * freq * (cputime[i]+DT+DT)); // deg
#elif REFTYPE == 1 // square wave
    ref[i]     	  = 180 * sin(2.0 * M_PI * freq * cputime[i]); // deg
    double ref2   = 180 * sin(2.0 * M_PI * freq * (cputime[i]+DT)); // deg
    double ref3   = 180 * sin(2.0 * M_PI * freq * (cputime[i]+DT+DT)); // deg
    if(ref[i]>0) ref[i]=180; else ref[i]=-180; // make square wave.
    if(ref2>0)   ref2=180;   else ref2=-180; // make square wave.
    if(ref3>0)   ref3=180;   else ref3=-180; // make square wave.
#elif REFTYPE == 2 // triangle wave
    // https://en.wikipedia.org/wiki/Triangle_wave
    //    4*a/p*(fabs(fmod(x-p/4,p)-p/2) - p/4)
    double a = 180; // amplitude (deg)
    double p = 1/freq; // period (s?)
    //    ref[i] =     4*a/p*(fabs(fmod(cputime[i]-p/4,p)-p/2) - p/4);
    //  http://stackoverflow.com/questions/11980292/how-to-wrap-around-a-range
    // arg, don't use fmod because it goes up beyond 180 deg to 360 on the first cycle.
    ref[i] =        4*a/p*(fabs(  (cputime[i]-p/4)-p*floor((cputime[i]-p/4)/p)  -p/2) - p/4);
    double ref2 =   4*a/p*(fabs(  (cputime[i]+DT-p/4)-p*floor((cputime[i]+DT-p/4)/p)  -p/2) - p/4);
    double ref3 =   4*a/p*(fabs(  (cputime[i]+DT+DT-p/4)-p*floor((cputime[i]+DT+DT-p/4)/p)  -p/2) - p/4);
#endif

    error[i]   	  = ref[i]-angle[i];
    double error2        = ref2-angle2;
    double error3        = ref3-angle3;

    // Integral term: 
    // - if 1st iter, don't add prev integral
    // - if real delta-time <=0, don't add current integral.
    double prev_int = i>0 ? ierror[i-1] : 0;
    double cur_int  = cputimediff[i]>0 ? error[i]*cputimediff[i] : 0;
    ierror[i]       = prev_int + cur_int;

    double cur_int2 = error2 * DT; // don't know what the future DT will be (w/ preempt), but guess.
    double cur_int3 = error3 * DT; // don't know what the future DT will be (w/ preempt), but guess.
    double ierror2  = prev_int + cur_int + cur_int2;
    double ierror3  = prev_int + cur_int + cur_int2 + cur_int3;

    derror[i]       = cputimediff[i]>0 && i>0 ? (error[i] - error[i-1])/cputimediff[i] : 0;
    double derror2  = (error2 - error[i])/DT;
    double derror3  = (error3 - error2)/DT;

    pterm[i]        = kp * error[i];
    double pterm2   = kp * error2;
    double pterm3   = kp * error3;

    iterm[i]        = ki * ierror[i];
    double iterm2   = ki * ierror2;
    double iterm3   = ki * ierror3;
    
    // Don't integrate if it's wound up
    if( iterm[i] > imax || iterm[i] < -imax) { 
      iterm[i] = iterm[i-1]; 
      ierror[i] = ierror[i-1]; 
      iterm2 = iterm[i];
      iterm3 = iterm[i];
    } 
    dterm[i]      = kd * derror[i];
    double dterm2 = kd * derror2;
    double dterm3 = kd * derror3;

    v[i]          = pterm[i] + iterm[i] + dterm[i];
    double v2     = pterm2 + iterm2 + dterm2;
    double v3     = pterm3 + iterm3 + dterm3;
    if( v[i]>MAX_VOLTAGE ) v[i]=MAX_VOLTAGE;
    if( v[i]<-MAX_VOLTAGE) v[i]=-MAX_VOLTAGE;
    if( v2>MAX_VOLTAGE ) v2=MAX_VOLTAGE;
    if( v2<-MAX_VOLTAGE) v2=-MAX_VOLTAGE;
    if( v3>MAX_VOLTAGE ) v3=MAX_VOLTAGE;
    if( v3<-MAX_VOLTAGE) v3=-MAX_VOLTAGE;

    // Now we assemble a ctrl buffer and send it to the PRU.
    double vbuf[32] = {};
    vbuf[0] = -v[i]; // DARN: for some reason, PRU voltage spins it wrong direction.
    vbuf[1] = -v2;
    vbuf[2] = -v3;







    ///////////////////////////////////////////////
    // Write voltage
    ///////////////////////////////////////////////



#ifdef USING_PRU
#ifdef USING_PRU_SINGLE_SHOT
    send_single_voltage(vbuf[0]); 
#else
    // Send multiple voltage cmds to PRU
    motor_voltage_schedule_to_cmd_buf(vbuf,
				      PKTS_PER_CMD_BUFFER,
				      sn+1,
				      &(cb_buffer[i]) );
    set_cmd_buf( cb_buffer[i] );
#endif
#else
    // Use sysfs interface to send single voltage to motor
    voltage(v[i]);
#endif
    





    ///////////////////////////////////////////////
    // Sleep until next iteration
    ///////////////////////////////////////////////

#ifdef SMART_SLEEP
    double sec_til_next = sec_til_next_timestep(DT);
  //  printf("sleeping for %lf secs! (til next ts)!\n",sec_til_next);
    // sleep until timestep i+1 (must call toc() once at beginning to get a ref time)
    usleep(sec_til_next*USEC_PER_SEC);
#else

    usleep(DT*USEC_PER_SEC);
#endif

    


    ///////////////////////////////////////////////
    // Possibly fake an OS preemption
    ///////////////////////////////////////////////

    // Could fake an OS preemption here

#ifdef FAKE_OS_PREEMPTION
    // fake an OS preemption 
    double fake_preemption_usecs = (double)(rand()) / RAND_MAX * MAX_SLEEP_SEC * USEC_PER_SEC;
    //        printf("Gonna sleep %lf\n",fake_preemption_usecs);
    usleep(fake_preemption_usecs); // Simulate pre-emption
#endif




  }  // END OF MAIN LOOP


  ///////////////////////////////////////////////
  // Turn off motor
  ///////////////////////////////////////////////



#ifdef USING_PRU
  send_single_voltage(0);
#else
  stop();
  shutdown();
#endif

  printf("%s %s (%d): Stopped hw.\n",__FILE__,__FUNCTION__,__LINE__);


  ///////////////////////////////////////////////
  // Write data to file 
  ///////////////////////////////////////////////



  printf("Writing data to %s...\n",out_name);

  // files to hold results
  FILE* fp;
  /* FILE* flog; */

  fp = fopen(out_name, "w");
  /* flog = fopen("runlog.txt","w"); */

  // Configure the data file and log file to be "fully buffered",
  // meaning that they won't write to disk until explicitly told (or closed).
  // https://www.chemie.fu-berlin.de/chemnet/use/info/libc/libc_7.html#SEC118
  /* #define fp_buf_size 999999 */
  /* #define flog_buf_size  999999 */
  /* char fp_buf[fp_buf_size] = {}; */
  /* char flog_buf[flog_buf_size] = {}; */
  /* int retval = 0; */
  /* if( (retval = setvbuf( fp, fp_buf, _IOFBF, fp_buf_size )) != 0 ) { */
  /*   printf("BAD: setvbuf returned %d\n",retval); */
  /* } */
  /* if( (retval = setvbuf( flog, flog_buf, _IOFBF, flog_buf_size )) != 0 ) { */
  /*   printf("BAD: setvbuf returned %d\n",retval); */
  /* } */
  /* char stdout_buf[fp_buf_size] = {}; */
  /* if((retval=setvbuf(stdout, stdout_buf, _IOFBF, fp_buf_size))!=0) { */
  /*   printf("bad: setvbuf returned %d\n",retval); */
  /*   return EXIT_FAILURE; */
  /* } */
  /* char stderr_buf[fp_buf_size] = {}; */
  /* if((retval=setvbuf(stderr, stderr_buf, _IOFBF, fp_buf_size))!=0) { */
  /*   printf("bad: setvbuf returned %d\n",retval); */
  /*   return EXIT_FAILURE; */
  /* } */

  // Header row
  fprintf(fp,"%11s %11s %11s %11s %11s %11s %11s %11s %11s %11s %11s %11s\n",
	  "step",
	  "cputime",
	  "cputimediff",
	  "angle", 
	  "ref", 
	  "error",
	  "ierror",
	  "derror",  
	  "pterm",
	  "iterm",
	  "dterm",
	  "v");

  // Write data
  for( int i=0; i<num_iters; i++ ) {

    fprintf(fp,"%11lf %11lf %11lf %11lf %11lf %11lf %11lf %11lf %11lf %11lf %11lf %11lf\n",
	    step[i],
	    cputime[i],
	    cputimediff[i],
	    angle[i], 
	    ref[i], 
	    error[i],
	    ierror[i],
	    derror[i],  
	    pterm[i],
	    iterm[i],
	    dterm[i],
	    v[i]);

  }

  fclose(fp);


  fp = fopen(pru_out_name, "w");

   // Print data buffer header
   fprintf_data_buf_header( fp ); // databuffer
   fprintf_cmd_buf_header_prefix( fp, "rx" ); // cb_rx
   fprintf_cmd_buf_header_prefix( fp, "tx" ); // cb_buffer
   fprintf(fp,"\n");
   // Print data buffer:
   for( int tstep=0; tstep<MAX_TSTEPS; tstep++ ) {
   fprintf_data_buf( fp, db_buffer[tstep] );
   fprintf_cmd_buf(fp, cb_rx[tstep] );
   fprintf_cmd_buf(fp, cb_buffer[tstep] );
   fprintf(fp,"\n");
   }
   fclose(fp);



  printf("%s %s (%d): Bye!\n",__FILE__,__FUNCTION__,__LINE__);

  return 0;
}

