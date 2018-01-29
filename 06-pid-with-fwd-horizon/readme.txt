mar 1, 2017

- This crappy program illustrates how to run a PID loop using the PRU. 
- 3 ways to run this PID loop:
    1. sysfs interfaces
       - You can run it as a normal PID loop that uses sysfs interfaces to the I/O,
    2. PRU "single shot"
       - you can use the PRU lib I wrote to send a single voltage cmd to the PRU, which it will execute at the next sampling time,
    3. PRU "forward horizon" 
       - ie, C code uses simple linear interpolation on the output (angle) and computes the next few PID voltages based on it, then send to the PRU to execute. Should more robust to OS preemption

Switch between these options using

     #define USING_PRU
     #define USING_PRU_SINGLE_SHOT

in  `pid-fwd.c` and

      USINGPRU=true    # or false

in `run.sh`. 


NOTE: Dammit: enabling jppprugpio DTO screws up the GPIO pins so that sysfs can't access them correctly!! So gotta edit `USINGPRU` in `run.sh` to ensure only the correct DTOs get loaded. Can't have both PRU and GPIO loaded at the same time.

You should reboot after changing these flags, because unloading DTOs is buggy, and reloading DTOs over each other seems risky.
