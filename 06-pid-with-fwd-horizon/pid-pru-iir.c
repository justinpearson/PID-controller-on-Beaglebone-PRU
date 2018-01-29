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

const double MAX_VOLTAGE = 5; // Volts

//#define FAKE_OS_PREEMPTION
//#define MAX_SLEEP_SEC (0.005)  // for fake preemption
// #define USEC_PER_SEC (1E6)

#define SLEEP_TYPE (1) // 0=sleep for dt, 1=sleep til next iter, 2=sleep for half dt (hack, sry)

#define ANGLE_PREDICTION_MODEL (1) // 0=constant 1=linear 2=sysd
#define REF_TYPE (2)   // 0=sin 1=square 2=triangle
#define REF_FREQ (0.5); // // Hz, controls how fast the reference angle changes
const int T = 30; // forward horizon

#define SIGN_ERROR (-1) // (1) or (-1)

// 2000 iters, 2300 samples
const int MAX_ITERS = 500;
const int MAX_SAMPLES = 800;


const double Ts = 0.005; // sec, time per iteration
///////
// From matlab pidtuner
const double kp = -0.0304;
const double ki = -0.106;
const double kd = -0.000873;
const double Tf = 0.00405; // sec, time const of 1st-order derivative filter 
///////////


////////////////////////////////////////

double CLAMP(double x, double M) {
  if( x>M ) x=M;
  if( x<-M ) x=-M;
  return x;
}

////////////////////////////////////////////////////
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

/////////////////////////////////////////////

double pid_iir( double ek, double ekm1, double ekm2, double vkm1, double vkm2 ) {      
  // ekm1 = "error at timestep k minus 1"
  // vkm2 = "voltage applied at timestep k minus 2"
  // u(k) = 1/f * ( a*e(k-2) + b*e(k-1) + c*e(k) - (d*u(k-2) + e*u(k-1)) )
  const double a = kd + kp*Tf - kp*Ts - ki*Tf*Ts + ki*Ts*Ts;
  const double b = -2*kd - 2*kp*Tf + kp*Ts + ki*Tf*Ts;
  const double c = kd + kp*Tf;
  const double d = Tf-Ts;
  const double e = -2*Tf + Ts;
  const double f = Tf;
  return 1/f * (a*ekm2 + b*ekm1 + c*ek - (d*vkm2+e*vkm1));
}


/////////////////////////////////////////////



double sys_iir( double thkm1, double thkm2, double thkm3, double vkm1, double vkm2, double vkm3 ) {
  // use the sysd identified by matlab to predict the next angle, 
  // based on the previous few angles and applied voltages. 
  // thkm1: 'theta(k-1)' = angle at timestep k-1
  // vkm3: 'v(k-3)' = voltage at timestep k-3

  /*
  From input to output "shaft angle":
       -0.5898 z^-1 - 1.121 z^-2 - 0.2757 z^-3
      ------------------------------------------
      1 - 1.586 z^-1 + 0.3719 z^-2 + 0.2136 z^-3
  */

  const double n1=-0.5898;// z^-1 
  const double n2=-1.121;// z^-2 
  const double n3=-0.2757; //z^-3
  //      ------------------------------------------
  const double d0=1; //z^0
  const double d1=-1.586; // z^-1 
  const double d2=+0.3719; //z^-2 
  const double d3=+0.2136;// z^-3

  double thk = 1/d0 * (-d1*thkm1 -d2*thkm2 -d3*thkm3 +n1*vkm1 +n2*vkm2 +n3*vkm3);
  return thk;

}


/////////////////////////////////////////////


int main ( int argc, char *argv[] ) {

  printLocalTime(0);

  printf("I am %s %s (%d).\n",__FILE__,__FUNCTION__,__LINE__);

  printf("USING PRU!\n");

  printf("%s %s (%d): HEY IDIOT, sysfs pwm goes out P9_34 but PRU pwm goes out P8_27. \n"
	 "Make sure your wiring reflects this!\n",__FILE__,__FUNCTION__,__LINE__);

  // Input parse.
  //  double duration     = argc>1 ? atof(argv[1]) :  1; // duration, sec
  /* const double kp           = argc>1 ? atof(argv[1]) : -0.082849; // kp */
  /* const double ki           = argc>2 ? atof(argv[2]) : -0.055907; // ki */
  /* const double kd           = argc>3 ? atof(argv[3]) : -0.000645; // kd */
  /* const char* out_name      = argc>4 ? argv[4]  : "data-pid-pru-iir-fwd.txt";    // output file name */
  /* const char* pru_out_name  = argc>5 ? argv[5]  : "pru-data.txt";    // output file name of pru data */
  /* const char* flogname = argc>6 ? argv[6] : "log.txt";  */

  const char* suff = argc > 1 ? argv[1] : "";
  char out_name[100];
  snprintf(out_name, sizeof out_name, "%s%s%s", "pid-iir-pru-dat-n",suff,".txt");
  char pru_out_name[100];
  snprintf(pru_out_name, sizeof pru_out_name, "%s%s%s", "pid-iir-pru-prudat-n",suff,".txt");
  char flogname[100];
  snprintf(flogname, sizeof flogname, "%s%s%s", "pid-iir-pru-log-n",suff,".txt");
  char pru_subset_name[100];
  snprintf(pru_subset_name, sizeof pru_subset_name, "%s%s%s", "pid-iir-pru-prusubset-n",suff,".txt");


  /* const double kp       = -0.082849; // kp */
  /* const double ki           =  -0.055907; // ki */
  /* const double kd           =  -0.000645; // kd */
  /* const char* out_name      = "pid-fwd.txt";        // output file name */
  /* const char* pru_out_name  = "pru-data.txt";        // output file name of pru data */
  /* const char* flogname = "log.txt"; */




  ////////////////////////////////////////////////////////////////////////////
  // files to hold results
  int retval = 0;


  FILE* flog; 
  printf("Log file: %s\n",flogname);
  flog = fopen(flogname,"w");

  // Configure the log file to be "fully buffered",
  // meaning that it won't write to disk until explicitly told (or closed).
  // https://www.chemie.fu-berlin.de/chemnet/use/info/libc/libc_7.html#SEC118

#define flog_buf_size  999999
  char flog_buf[flog_buf_size] = {};
  if( (retval = setvbuf( flog, flog_buf, _IOFBF, flog_buf_size )) != 0 ) {
    printf("BAD: setvbuf returned %d\n",retval);
  }



  // Buffer stdout and stderr.
  #define stderr_buf_size 999999
  char stdout_buf[stderr_buf_size] = {};
  if((retval=setvbuf(stdout, stdout_buf, _IOFBF, stderr_buf_size))!=0) {
    printf("bad: setvbuf returned %d\n",retval);
    return EXIT_FAILURE;
  }
  char stderr_buf[stderr_buf_size] = {};
  if((retval=setvbuf(stderr, stderr_buf, _IOFBF, stderr_buf_size))!=0) {
    printf("bad: setvbuf returned %d\n",retval);
    return EXIT_FAILURE;
  }

  printLocalTime(flog);


  // pseudo-code:

  // init snprev = 0;
  // init intterm = 0;
  // for MAX_ITERS times,
  //   get PRU data. sn = sn of last dpkt.
  //   from snprev+1 to sn,
  //     run the missing input samples thru the iir filter (controller)
  //   snprev = sn.
  //   make a fwd-horizon of T voltages to apply at sn+1, sn+2, ..., sn+T.
  //   from j=0 to T-1 elems of your act sched,
  //     predict angle & error, j steps ahead:
  //       e[sn+j] = ref[sn+j] - angle[sn+j]
  //     v[sn+j] = kp*e + tmp_intterm + ediff * kp / dt

  DataBuffer db_buffer    [MAX_ITERS];
  CommandBuffer cb_buffer [MAX_ITERS];
  CommandBuffer cb_rx     [MAX_ITERS];
  for(int i=0;i<MAX_ITERS;i++)init_data_buf(db_buffer[i]);
  for(int i=0;i<MAX_ITERS;i++)init_cmd_buf(cb_buffer[i]);
  for(int i=0;i<MAX_ITERS;i++)init_cmd_buf(cb_rx[i]);

  // Warning: These are all doubles because if you printf or fprintf an 
  // int using %lf it produces garbage,  ugh.
  // See: http://stackoverflow.com/questions/16607628/printing-int-as-float-in-c
  double cputime_cpu[MAX_ITERS]    ; for(int i=0;i<MAX_ITERS;i++) cputime_cpu[i]=0;
  double cputimediff_cpu[MAX_ITERS]; for(int i=0;i<MAX_ITERS;i++) cputimediff_cpu[i]=0;
  double angles_cpu[MAX_ITERS]     ; for(int i=0;i<MAX_ITERS;i++) angles_cpu[i]=0;
  double voltages_cpu[MAX_ITERS]   ; for(int i=0;i<MAX_ITERS;i++) voltages_cpu[i]=0;
  double refs_cpu[MAX_ITERS]       ; for(int i=0;i<MAX_ITERS;i++) refs_cpu[i]=0;
  double errors_cpu[MAX_ITERS]       ; for(int i=0;i<MAX_ITERS;i++) errors_cpu[i]=0;
  double steps_cpu[MAX_ITERS]       ; for(int i=0;i<MAX_ITERS;i++) steps_cpu[i]=0;
  double sns_cpu[MAX_ITERS]       ; for(int i=0;i<MAX_ITERS;i++) sns_cpu[i]=0;

  // These are wrt to the PRU sample time; 
  // When we fill them in, there should be no gaps.
  double angles_pru[MAX_SAMPLES]; for(int i=0;i<MAX_SAMPLES;i++) angles_pru[i]=0;
  double refs_pru[MAX_SAMPLES]; for(int i=0;i<MAX_SAMPLES;i++) refs_pru[i]=0;
  double voltages_pru[MAX_SAMPLES]; for(int i=0;i<MAX_SAMPLES;i++) voltages_pru[i]=0;
  double sns_pru[MAX_SAMPLES]; for(int i=0;i<MAX_SAMPLES;i++) sns_pru[i]=0;
  double errors_pru[MAX_SAMPLES]; for(int i=0;i<MAX_SAMPLES;i++) errors_pru[i]=0;

  // PID IIR filter
  double vk = 0;
  double vkm1 = 0;
  double vkm2 = 0;
  double ek = 0;
  double ekm1 = 0;
  double ekm2 = 0;

  // Try to get cputime to line up with PRU time by initializing it right before initing PRU.
  toc(&(cputime_cpu[0]), &(cputimediff_cpu[0]) ); // this sets cputime[0]=0 and counts up from there.
  printf("Starting PRU...\n");
  start_pru();

  printf("kp: %lf ki: %lf kd: %lf outfile: %s pru outfile: %s log: %s\n",
	 kp, ki, kd,out_name,pru_out_name,flogname);

  unsigned int snprev = 0;
  ///////////////////////////////////////////////
  // LOOP
  ///////////////////////////////////////////////
  for( int i=0; i<MAX_ITERS; i++ ) {
    fprintf(flog,"\n== Iter %3d ",i);
    steps_cpu[i] = i;

    // get time
    toc(&(cputime_cpu[i]), &(cputimediff_cpu[i]) );

    // read sensors
    get_data_cmd_bufs( &(db_buffer[i]), &(cb_rx[i]) ); 
    unsigned int sn = db_buffer[i][PKTS_PER_DATA_BUFFER-1].sample_num; 
    if( sn + T >= MAX_SAMPLES ) {
      fprintf(flog,"Iter %d. Last sample num %d + fwd-horiz T %d > MAX_SAMPLES %d, so we're done.\n",
	     i,sn,T,MAX_SAMPLES);
      goto BAIL;
    }
      // cutesy dashes show how many pkts arrived.
      for( int j=0; j<sn-snprev; j++ ) fprintf(flog,"-");

    sns_cpu[i] = sn;
    fprintf(flog,"sn=%4d. ",sn);

    // The last vals are what the CPU would see if he'd retrieved them himself.
      angles_cpu[i] = 180.0/M_PI*eqep_to_angle(db_buffer[i][PKTS_PER_DATA_BUFFER-1].eqep);
      voltages_cpu[i] = gpio_duty_to_motor_voltage_cmd(db_buffer[i][PKTS_PER_DATA_BUFFER-1].gpio,
						db_buffer[i][PKTS_PER_DATA_BUFFER-1].duty);
      refs_cpu[i] = reference(Ts*sn);
      errors_cpu[i] = refs_cpu[i] - angles_cpu[i];
    
    // catch up on new data pkts.
    // Don't be fancy about this. Just copy all 32 of the damn samples.
    // This is a little wasteful but avoids fancy-induced bugs.
    for( int j=0; j<PKTS_PER_DATA_BUFFER; j++ ) {
      unsigned int s = db_buffer[i][j].sample_num;
      double a = 180.0/M_PI*eqep_to_angle(db_buffer[i][j].eqep);
      double v = gpio_duty_to_motor_voltage_cmd(db_buffer[i][j].gpio,
						db_buffer[i][j].duty);
      sns_pru[s] = s; 
      angles_pru[s] = a;
      voltages_pru[s] = v;
      refs_pru[s] = reference(Ts*s);
      errors_pru[s] = refs_pru[s] - angles_pru[s];
    }
    // Compute future horizon.
    double da = angles_pru[sn]-angles_pru[sn-1];
    ek   =  errors_pru[sn];     // load up initial state of iir filter
    ekm1 =  errors_pru[sn-1];
    ekm2 =  errors_pru[sn-2];
    vkm1 = SIGN_ERROR*voltages_pru[sn]; // pru wired backwards; minus sign needed.
    vkm2 = SIGN_ERROR*voltages_pru[sn-1];

#if 0    // debugging: single-shot, no fwd-horizon (works!)
    double v = 0;
    v = pid_iir( ek, ekm1, ekm2, vkm1, vkm2 );
    v = CLAMP(v,MAX_VOLTAGE); 
    for( int j=sn+1; j<sn+1+T; j++ ) {
      voltages_pru[j] = SIGN_ERROR*v; // PRU wiring error: minus sign needed.
    }
#else
    for( int j=sn+1; j<sn+1+T; j++ ) {
      vk = pid_iir( ek, ekm1, ekm2, vkm1, vkm2 );
      vk = CLAMP(vk,MAX_VOLTAGE); 
      voltages_pru[j] = SIGN_ERROR*vk; // PRU wiring error: minus sign needed.
      vkm2 = vkm1; // update iir filter.
      vkm1 = vk;
      ekm2 = ekm1;
      ekm1 = ek;
      refs_pru[j] = reference(Ts*j);
#if ANGLE_PREDICTION_MODEL == 0
      angles_pru[j] = angles_pru[sn];  // constant extrapolation of angle. 
#elif ANGLE_PREDICTION_MODEL == 1 // linear
      angles_pru[j] = angles_pru[sn]+da*(j-(sn+1)+1);  // linear extrapolation of angle. 
#elif ANGLE_PREDICTION_MODEL == 2 // use discrete-time system to predict next angle
      angles_pru[j] = sys_iir(  angles_pru[j-1],
				angles_pru[j-2],
				angles_pru[j-3],
				SIGN_ERROR*voltages_pru[j-0], // need minus signs here? Also: j or j-1??
				SIGN_ERROR*voltages_pru[j-1],
				SIGN_ERROR*voltages_pru[j-2]);

#else
      #error "um, not sure what angle prediction model you want!"
#endif
      ek = refs_pru[j] - angles_pru[j];
    }
#endif

    // Send voltage sequence to PRU, starting at sequence num sn+1. 
    motor_voltage_schedule_to_cmd_buf(&(voltages_pru[sn+1]),
				      PKTS_PER_CMD_BUFFER,
				      sn+1,
				      &(cb_buffer[i]) );
    set_cmd_buf( cb_buffer[i] );

  


    /* if( sn==snprev ) { */
    /*   // We've read the same db twice. Chill out until the next timestep, hotshot. */
    /*   fprintf(flog,"--> iter %4d : sn=%4d same snprev=%4d : slow down hotshot!\n",i,sn,snprev); */
    /*   goto WAIT; */
    /* } */
    /* else if( sn<snprev ) {  */
    /*   fprintf(flog,"!!!!--> iter %d: sn=%d < snprev=%d PRU went crazy?? " */
    /* 	      "THIS SHOULD NEVER HAPPEN, QUITTING...\n", */
    /* 	      i,sn,snprev); */
    /*   goto BAIL; */
    /* }  */
    /* else if( sn > snprev ) { */
    /*   // Some new data packets arrived. */
    /*   fprintf(flog,"%3d new pkts.",sn-snprev); */

    /*   // cutesy dashes show how many pkts arrived. */
    /*   for( int j=0; j<sn-snprev; j++ ) fprintf(flog,"-");  */

    /*   // Catch up the IIR filter. */
    /*   for( int j=snprev+1; j<=sn; j++ ) { */
	
    /*   } */

    /*   // Some handy values. */
    /*   double angle      = 180.0 / M_PI *  eqep_to_angle( db_buffer[i][PKTS_PER_DATA_BUFFER-1].eqep ); */
    /*   angles[i] = angle; */
    /*   double prev_angle = 180.0 / M_PI *  eqep_to_angle( db_buffer[i][PKTS_PER_DATA_BUFFER-2].eqep ); */
    /*   refs[i] = reference(DT*sn); */
    /*   double error      = refs[i]- angle; */
    /*   double prev_error = reference(DT*(sn-1)) - prev_angle; */
    /*   voltages[i] = gpio_duty_to_motor_voltage_cmd(  */
    /* 						   db_buffer[i][PKTS_PER_DATA_BUFFER-1].gpio, */
    /* 						   db_buffer[i][PKTS_PER_DATA_BUFFER-1].duty */
    /* 						    ); */

    /*   // Catch up the integral term by moving from last (most recent) back,  */
    /*   // until either hit beginning of db or snprev. */
    /*   for( int j=PKTS_PER_DATA_BUFFER-1; j>=0; j-- ) { */
    /* 	int sn_pkt = db_buffer[i][j].sample_num; */
    /* 	if(  sn_pkt <= snprev ) break; */

    /* 	// Catch up the integral term since last time. */

    /* 	if( iterm < imax && iterm > -imax ) { // anti-windup */
    /* 	  iterm += ki * ( */
    /* 			 reference(DT*sn_pkt) */
    /* 			 - */
    /* 			 180.0/M_PI*eqep_to_angle( db_buffer[i][j].eqep ) */
    /* 			 ) * DT; */
    /* 	} */
    /*   } // import data from db */
    /*   // Now iterm contains sums of errors up to sn.       */
      
    /*   // The actuation schedule: */
    /*   // v[sn+1] = kp*e[sn+0] + iterm + kd*(e[sn+0]-e[sn+0-1])/DT; iterm += ki*e[sn+1]*DT; */
    /*   // v[sn+2] = kp*e[sn+1] + iterm + kd*(e[sn+1]-e[sn+1-1])/DT; iterm += ki*e[sn+2]*DT; */
    /*   // v[sn+3] = kp*e[sn+2] + iterm + kd*(e[sn+2]-e[sn+2-1])/DT; iterm += ki*e[sn+3]*DT; */
    /*   // v[sn+4] = kp*e[sn+3] + iterm + kd*(e[sn+3]-e[sn+3-1])/DT; iterm += ki*e[sn+4]*DT; */
    /*   // ... */

    /*   // Same as: */
    /*   // eprev = (computed above) */
    /*   // e = ref[sn+0]-a[sn+0]; v[sn+1] = kp*e + iterm + kd*(e-eprev)/DT; iterm += ki*e*DT; eprev = e; */
    /*   // e = ref[sn+1]-a[sn+1]; v[sn+2] = kp*e + iterm + kd*(e-eprev)/DT; iterm += ki*e*DT; eprev = e; */
    /*   // e = ref[sn+2]-a[sn+2]; v[sn+3] = kp*e + iterm + kd*(e-eprev)/DT; iterm += ki*e*DT; eprev = e; */
    /*   // e = ref[sn+3]-a[sn+3]; v[sn+4] = kp*e + iterm + kd*(e-eprev)/DT; iterm += ki*e*DT; eprev = e; */
      
    /*   // Same as: */
    /*   // eprev = (computed above) */
    /*   // for j=0; j<T; j++ */
    /*   //   e = reference(sn+j)-angle(sn+j);  */
    /*   //   v[sn+1+j] = kp*e + iterm + kd*(e-eprev)/DT;  */
    /*   //   iterm += ki*e*DT;  */
    /*   //   eprev = e; */
      
    /*   // Same as: */
    /*   double tmp_iterm = iterm; // don't screw up the real integral of the error on our future projection. */
    /*   double eprev = prev_error; */
    /*   double da = angle-prev_angle; */
    /*   double v[PKTS_PER_CMD_BUFFER] = {0}; */
    /*   for( int j=0; j<T; j++ ) { // (Apply v[0] at sn+1.) */
    /* 		double e = reference(DT*(sn+j))-(angle+da*j);  // linear extrapolation of angle. */
    /* 	//	double e = reference(DT*(sn+j))-(angle);  // constant extrapolation of angle. */
    /* 	v[j] = kp*e + tmp_iterm + kd*(e-eprev)/DT;  */
    /* 	v[j] = -1*CLAMP(v[j],MAX_VOLTAGE); // DARN: PRU wired backwards from sysfs; minus sign needed. */
    /* 	if( j>0 ) { // Don't incr tmp_iterm if j==0, since we already did it above. */
    /* 	  tmp_iterm += ki*e*DT;   */
    /* 	  if( tmp_iterm > imax || tmp_iterm < -imax ) { // windup protection */
    /* 	    tmp_iterm -= ki*e*DT;  // undo  */
    /* 	    // Careful! This way allows it to un-stick itself. Not so if you conditionally +=. */
    /* 	  } */
    /* 	} */
    /* 	eprev = e; */
    /*   } */

    /*   // Send voltage sequence to PRU, starting at sequence num sn+1.  */
    /*   motor_voltage_schedule_to_cmd_buf(v, */
    /* 					PKTS_PER_CMD_BUFFER, */
    /* 					sn+1, */
    /* 					&(cb_buffer[i]) ); */
    /*   set_cmd_buf( cb_buffer[i] ); */

    /*   snprev = sn; // remember for next time, so we can fast-fwd int of err */

    /* } */
    /* else { */
    /*   printf("Have no idea how it's possible to get here!!\n"); */
    /*   goto BAIL; */
    /* } */


    ///////////////////////////////////////////////
    // Sleep until next iteration
    ///////////////////////////////////////////////

  WAIT:

#if SLEEP_TYPE == 0
    usleep(Ts*USEC_PER_SEC);
#elif SLEEP_TYPE == 1
    {
    double sec_til_next = sec_til_next_timestep(Ts);
    fprintf(flog,"sleeping for %lf secs! (til next ts)!\n",sec_til_next);
    // sleep until timestep i+1 (must call toc() once at beginning to get a ref time)
    usleep(sec_til_next*USEC_PER_SEC);
    }
#elif SLEEP_TYPE == 2
    // ugh, like don't sleep if you've been preempted but don't fall behind either...
        usleep(Ts/2*USEC_PER_SEC);
#endif


	snprev = sn;
  }  // END OF MAIN LOOP

  fprintf(flog,"%s %s %d: Main loop completed. Shutting down...\n",__FILE__,__FUNCTION__,__LINE__);
  printf("%s %s %d: Main loop completed. Shutting down...\n",__FILE__,__FUNCTION__,__LINE__);

  ///////////////////////////////////////////////
  // Turn off motor
  ///////////////////////////////////////////////

 BAIL:


  send_single_voltage(0);

  printf("%s %s (%d): Stopped hw.\n",__FILE__,__FUNCTION__,__LINE__);


  ///////////////////////////////////////////////
  // Write data to file 
  ///////////////////////////////////////////////




  /////////////////////////////////////
  // Write CPU data


  printf("Writing data to %s...\n",out_name);

  FILE* fp;
  fp = fopen(out_name, "w");
/* #define fp_buf_size 999999 */
/*   char fp_buf[fp_buf_size] = {}; */
/*   if( (retval = setvbuf( fp, fp_buf, _IOFBF, fp_buf_size )) != 0 ) { */
/*     printf("BAD: setvbuf returned %d\n",retval); */
/*   } */


  // Header row
  fprintf(fp,"%11s %11s %11s %11s %11s %11s %11s %11s \n",
	  "step_cpu",
  	  "sn_cpu",
  	  "cputime_cpu",
  	  "cputimediff_cpu",
  	  "angle_cpu",
  	  "ref_cpu",
	  "error_cpu",
  	  "v_cpu"
  	  );



  /* // Header row */
  /* fprintf(fp,"%11s %11s %11s %11s %11s %11s %11s %11s ", */
  /* 	  "step", */
  /* 	  "sn", */
  /* 	  "cputime", */
  /* 	  "cputimediff", */
  /* 	  "angle", */
  /* 	  "ref", */
  /* 	  "error", */
  /* 	  "v" */
  /* 	  ); */

  /* for(int j=0;j<T;j++) { */
  /*   fprintf(fp,"v_future_%01d ",j); */
  /* } */

  for( int i=0; i<MAX_ITERS; i++ ) {

    fprintf(fp,"%11lf %11lf %11lf %11lf %11lf %11lf %11lf %11lf ",
  	    steps_cpu[i],
  	    sns_cpu[i],
  	    cputime_cpu[i],
  	    cputimediff_cpu[i],
  	    angles_cpu[i],
  	    refs_cpu[i],
	    errors_cpu[i],
  	    voltages_cpu[i]
  	    );

  /*   for(int j=0;j<T;j++) { */
  /*     fprintf(fp,"%11lf ",v_future[i][j]); */
  /*   } */

    fprintf(fp,"\n");
  }

  fclose(fp);


  /////////////////////////////////////
  // Write PRU data

  fp = fopen(pru_subset_name,"w");
  // Header row
  fprintf(fp,"%11s %11s %11s %11s %11s\n",
  	  "sn_pru",
  	  "angle_pru",
	  "refs_pru",
	  "errors_pru",
  	  "v_pru"
  	  );
  for( int i=0; i<MAX_SAMPLES; i++ ) {
    fprintf(fp,"%11lf %11lf %11lf %11lf %11lf \n",
  	    sns_pru[i],
  	    angles_pru[i],
  	    refs_pru[i],
	    errors_pru[i],
  	    voltages_pru[i]
  	    );
  }
  fclose(fp);


  ////////////////////////
  // Write PRU data buffers & cmd buffers

  if( 0 ) {
    printf("NOTE: NOT WRITING PRU (for speeding up twiddle)\n");
  }
  else {
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
  }


  fclose(flog);
  printf("%s %s (%d): Closed log %s. Bye!\n",__FILE__,__FUNCTION__,__LINE__,flogname);

  return 0;
}

