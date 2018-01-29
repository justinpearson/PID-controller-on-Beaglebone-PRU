#ifndef BB_SIMPLE_SYSFS_C_LIB_H
#define BB_SIMPLE_SYSFS_C_LIB_H

// sysfs entries
#include "sysfs-paths.h"

#define MAX_VOLTAGE 5 // Volts
#define NS_PER_PWM_PERIOD 20000
#define NS_PER_PWM_PERIOD_STR "20000"
#define EQEP_PER_REV 4096 // eqep ticks per revolution


// Setup
void setup();
void shutdown();

// PWM
void stop();
void run();
void rawduty(char* d, int len);
void duty( double d );
void voltage( double v );

// GPIO
void stby();
void unstby();
void cw();
void ccw();

// EQEP
int eqep_counts();
double shaft_angle_deg();



#endif // header guard
