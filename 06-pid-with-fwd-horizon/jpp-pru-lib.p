// This program records the adc and eqep, and twiddles the gpios according to a certain schedule.
// When asked by the CPU, the PRU delivers the last several adc, eqep, and gpio values (see below
// for packet structure.)
// CPU can specify a GPIO actuation schedule for the PRU to obey.	
	

#include "jpp-pru-lib.hp"
#include "pwm-registers.hp"

	
//////////////////////////
// Named registers	
//////////////////////////

#define tmp0 				r1
#define tmp1 				r2
#define tmp2 				r3
#define tmp3 				r4
#define current_time 			r5
#define cycles_at_next_sample_time 	r6
#define time_of_last_cpu_data_req	r7
#define gpio_cmd			r8
#define gpio_actual			r9
#define pru_cmd_buf_read_head		r10
#define num_cmd_pkts_in_buffer		r11
#define adc_value			r12
#define pru_data_buf_write_head		r13
#define idx_in_pru_data_buf		r14
#define current_sample			r15
#define idx_in_log_of_req_times		r16 
#define num_cmd_schedules		r17
#define eqep				r18
#define time_of_last_cpu_cmd_sch	r19	
#define rADDR_CPU_PRU_CTRL_REG  	r20
#define rADDR_CPU_DATA_BUF      	r21
#define rADDR_PRU_DATA_BUF      	r22
#define rADDR_CPU_CMD_BUF       	r23
#define rADDR_PRU_CMD_BUF       	r24
#define duty_cmd			r25
#define duty_actual			r26
#define sample_period                   r27	
#define num_data_reqs	                r28
/////////////////////////////////////// r29 - DO NOT USE r29 - already in use!!

	
	
    .setcallreg  r29.w2  // Use R29.W2 in the CALL/RET pseudo ops, not the default of r30 (used for GPIOS)
    .origin 0
    .entrypoint INIT


INIT:

	// init registers
	mov r0, INITIAL_REG_VALUE
	mov r1, INITIAL_REG_VALUE
	mov r2, INITIAL_REG_VALUE
	mov r3, INITIAL_REG_VALUE
	mov r4, INITIAL_REG_VALUE
	mov r5, INITIAL_REG_VALUE
	mov r6, INITIAL_REG_VALUE
	mov r7, INITIAL_REG_VALUE
	mov r8, INITIAL_REG_VALUE
	mov r9, INITIAL_REG_VALUE
	mov r10, INITIAL_REG_VALUE
	mov r11, INITIAL_REG_VALUE
	mov r12, INITIAL_REG_VALUE
	mov r13, INITIAL_REG_VALUE
	mov r14, INITIAL_REG_VALUE
	mov r15, INITIAL_REG_VALUE
	mov r16, INITIAL_REG_VALUE
	mov r17, INITIAL_REG_VALUE
	mov r18, INITIAL_REG_VALUE
	mov r19, INITIAL_REG_VALUE
	mov r20, INITIAL_REG_VALUE
	mov r21, INITIAL_REG_VALUE
	mov r22, INITIAL_REG_VALUE
	mov r23, INITIAL_REG_VALUE
	mov r24, INITIAL_REG_VALUE
	mov r25, INITIAL_REG_VALUE
	mov r26, INITIAL_REG_VALUE
	mov r27, INITIAL_REG_VALUE
	mov r28, INITIAL_REG_VALUE
	// r29 used for "RET" register

	// clear pru0 data ram
	// don't, debugging atm
	call CLEAR_PRU0_DATA_RAM
	

	// Set up the PRU's ability to access memory outside its own private 8kB
	// http://exploringbeaglebone.com/chapter13/#The_Programs
	LBCO tmp0, C4, 4, 4	// Load Bytes Constant Offset (?)
	CLR  tmp0, tmp0, 4	// Clear bit 4 
	SBCO tmp0, C4, 4, 4	// Store Bytes Constant Offset


	// Cycle counter setup
	// Use the CTPPR0 reg (Constant table Programmable Pointer Register 0) to 
	// confgure C28 to point to the family of 'PRU_ICSS_PRU_CTRL Registers' (0x0002_2000)
	// (The cycle counter lives in this family at offset 0xC)
	//http://theembeddedkitchen.net/beaglelogic-building-a-logic-analyzer-with-the-prus-part-1/449

	MOV    tmp1,  	0x22028  // Constant table Programmable Pointer Register 0
	MOV    tmp2, 	0x00000220  
	SBBO   tmp2, 	tmp1, 0, 4

// - init regs & addrs
	call INIT_REGISTERS
// - init adc
	call INIT_ADC
// - init pwm
	call INIT_PWM
// - init cycle counter
	call RESET_CYCLE_COUNTER


	
BEGIN_LOOP:	

// If CPU has set 'cpu wants data' reg, copy over the PRU data buffer to the CPU data buffer.
        LBBO tmp0, rADDR_CPU_PRU_CTRL_REG, OFST_CPU_WANTS_DATA, 4
	AND tmp0, tmp0, 1 // keep bottom bit
	QBEQ DELIVER_TO_CPU, tmp0, 1 
	DONE_DELIVERING:	

// If CPU has set 'cpu gives new actuation schedule' reg, copy new actuation schedule from cpu buf to pru buf.
        LBBO tmp0, rADDR_CPU_PRU_CTRL_REG, OFST_CPU_NEW_SCHED, 4
	qbne COPY_NEW_ACTUATION_SCHEDULE, tmp0, 0  // if nonzero, that's the number of new pkts!
	DONE_COPYING_NEW_SCH:	

// If CPU has set 'new sample period' reg, copy it over.
        LBBO tmp0, rADDR_CPU_PRU_CTRL_REG, OFST_CPU_NEW_PERIOD, 4
	and tmp0, tmp0, 1 
	qbne COPY_NEW_SAMPLE_PERIOD, tmp0, 0 
	DONE_COPYING_NEW_PERIOD:	

// If CPU has set 'give me cycle count' reg, copy it over.
	
        LBBO tmp0, rADDR_CPU_PRU_CTRL_REG, OFST_CYCLE_COUNT_REQ, 4
	and tmp0, tmp0, 1 
	qbne COPY_CYCLE_COUNT, tmp0, 0 
	DONE_COPYING_CYCLE_COUNT:	


	
	
// Spin until next sample time.
WAIT_FOR_SAMPLE_TIME:
	LBCO current_time, C28, 0xC, 4     // What time is it?
	qbgt BEGIN_LOOP, current_time, cycles_at_next_sample_time // If next_samp_time > current_time, keep waiting for next sample time.
	
	// Else, current cycle count >= cycles_at_next_sample_time. So time for a sample.

/////////////////
// SAMPLE TIME
/////////////////
INCREMENT_SAMPLE_NUM:
	add current_sample, current_sample, 1
	// if it's safe to write the current sample number to the "public" register, do it.
	lbbo tmp0, rADDR_CPU_PRU_CTRL_REG, OFST_SAMPLE_NUM_LOCK, 4
	and tmp0, tmp0, 1 // keep lowest bit
	qbeq DONT_WRITE_CUR_SAMPLE_NUM, tmp0, 1 // skip if locked
	sbbo current_sample, rADDR_CPU_PRU_CTRL_REG, OFST_SAMPLE_NUM, 4
        DONT_WRITE_CUR_SAMPLE_NUM:	

	
ADVANCE_NEXT_SAMPLE_TIME:
	// Advance cycles_at_next in steps of SAMPLE_PERIOD until it's greater than cycle count.
	// Also advance our sample number (current_sample).
	add cycles_at_next_sample_time, cycles_at_next_sample_time, sample_period
	qble ADVANCE_NEXT_SAMPLE_TIME, current_time, cycles_at_next_sample_time   // advance cycles_at_next until it's greater than current_time. May need to do this more than once if PRU got bogged down or something.

CHECK_CYCLE_COUNTER_TOO_BIG:	
	// If the cycle counter is not too big, skip ahead.
	mov tmp0, CYCLE_COUNTER_RESET_VALUE
	qbgt CYCLE_COUNTER_NOT_TOO_BIG, current_time, tmp0 // if current_time < RESET_VALUE, we're ok.
	// Else, the cycle counter is too big and may overrun soon.
	// Reset it and set the next sample time appropriately.
	mov current_time, 0
	mov cycles_at_next_sample_time, sample_period
	call RESET_CYCLE_COUNTER
	
CYCLE_COUNTER_NOT_TOO_BIG:	
	
// Now it's a sample time.
//         - initiate an adc sample
TRIGGER_ADC_SAMPLE:
	mov tmp0, 2  // bit 1: enable ADC state machine step 1 (adc channel 0)
	mov tmp1, ADDR_ADC
	SBBO tmp0, tmp1, OFFSET_STEPENABLE, 4   // triggers a capture / sample!
	LBCO current_time, C28, 0xC, 4     // save the time that we actually triggered the sample.

// while we're waiting for the ADC,	
//         - read the eqep register
	mov tmp0, ADDR_EQEP1
	lbbo eqep, tmp0, QPOSCNT, 4
	
//         - write the next gpio/duty cmd, if there are any left.
//           (searches thru whole cmd buf each time for sample num)
	qba ACTUATE
	DONE_ACTUATING:	

//         - wait until adc complete
WAIT_FOR_ADC_FIFO0:
	mov tmp1, ADDR_ADC
        LBBO tmp0, tmp1, OFFSET_FIFO0COUNT, 4
        AND tmp0, tmp0, 127    // only bits 0 thru 6 are unreserved, so turn others off and keep only bits 0-6.
        QBEQ WAIT_FOR_ADC_FIFO0, tmp0, 0 // spin until we have an adc sample.
	// TODO: What if ACTUATE took so long that there are multiple pkts in it?

//        - retrieve adc sample
RETRIEVE_VALUE:
	// There's a sample in the FIFO!
	mov tmp2, ADDR_FIFO0DATA
        LBBO tmp0, tmp2, 0, 4  // grab the sample from the ADC
	MOV tmp1, 0xfff	// keep the 12 lowest bits (12-bit adc)
        AND adc_value, tmp0, tmp1
	
//         - write sample #, cycle count, adc, eqep, and gpio to data pkt in pru-sensor-buf.
WRITE_DATA_TO_PRU_DATA_BUF:	
	//
	// data packet: 8 words = 32 byets = 0x20 bytes
	//
	// - cycle count
	// - sample num
	// - adc value
	// - eqep value
	// - gpios written @ this time
	// - duty written @ this time
	// - reserved
	// - reserved
	
	mov tmp0, ADDR_PRU_DATA_BUF	
	
	// cycle count
	SBBO current_time, rADDR_PRU_DATA_BUF, pru_data_buf_write_head, 4
	ADD pru_data_buf_write_head, pru_data_buf_write_head, 4
	// sample num
	SBBO current_sample, rADDR_PRU_DATA_BUF, pru_data_buf_write_head, 4
	ADD pru_data_buf_write_head, pru_data_buf_write_head, 4
	// adc value
	SBBO adc_value, rADDR_PRU_DATA_BUF, pru_data_buf_write_head, 4
	ADD pru_data_buf_write_head, pru_data_buf_write_head, 4
	// eqep value
	SBBO eqep, rADDR_PRU_DATA_BUF, pru_data_buf_write_head, 4 
	ADD pru_data_buf_write_head, pru_data_buf_write_head, 4
	// gpios
	SBBO gpio_actual, rADDR_PRU_DATA_BUF, pru_data_buf_write_head, 4
	ADD pru_data_buf_write_head, pru_data_buf_write_head, 4
	// duty
	SBBO duty_actual, rADDR_PRU_DATA_BUF, pru_data_buf_write_head, 4
	ADD pru_data_buf_write_head, pru_data_buf_write_head, 4
	// last time PRU heard a CPU data request
	// oct 3: now sending "total # data reqs heard so far" to help assess how much preemption
	// oct 5: we're writing the *real* time of cpu data req in the "DELIVER TO CPU" section
//	SBBO time_of_last_cpu_data_req, rADDR_PRU_DATA_BUF, pru_data_buf_write_head, 4
//	SBBO num_data_reqs, rADDR_PRU_DATA_BUF, pru_data_buf_write_head, 4
	ADD pru_data_buf_write_head, pru_data_buf_write_head, 4
	// last time PRU rx'd a CPU cmd buffer
	// oct 3: now sending "total # command schedules given to PRU by CPU"
	// oct 5: now sending a combination of # data reqs and # cmd scheds: top 16 bits is # cmd schs, bottom 16 bits is # data reqs.
	//        And doing  this in the "DEVLIER TO CPU" section
//	SBBO time_of_last_cpu_cmd_sch, rADDR_PRU_DATA_BUF, pru_data_buf_write_head, 4
//	SBBO num_cmd_schedules, rADDR_PRU_DATA_BUF, pru_data_buf_write_head, 4
	ADD pru_data_buf_write_head, pru_data_buf_write_head, 4
	
	
	ADD idx_in_pru_data_buf, idx_in_pru_data_buf, 1  // keep track of where we're at in the data buf
	                                                 // so that we can wrap around at the right time
	
	
	// If buf full, start overwriting old ones.
	// NOTE: This fn modifies idx_in_pru_data_buf and write_head, so must come
	// after DELIVER_TO_CPU, since DELIVER_TO_CPU uses those to help it
	// write to the output buffer.
	QBEQ RESET_WRITE_HEAD, idx_in_pru_data_buf, PKTS_PER_DATA_BUFFER
	DONE_RESETTING_WRITE_HEAD:


	
	
// - repeat
	qba BEGIN_LOOP

QUIT: // never quit, I think.
	
        MOV R31.b0, PRU0_ARM_INTERRUPT+16   // Send notification to Host for program completion
        HALT

	






/////////////////////////////////////////////////////////////////
// Functions
/////////////////////////////////////////////////////////////////

COPY_NEW_SAMPLE_PERIOD:
	mov current_time, 0
	lbbo sample_period, rADDR_CPU_PRU_CTRL_REG, OFST_SAMPLE_PERIOD_CMD, 4
	mov cycles_at_next_sample_time, sample_period
	call RESET_CYCLE_COUNTER
	// wipe out the "new period rdy" flag and the period too
	mov tmp0, 0
	sbbo tmp0, rADDR_CPU_PRU_CTRL_REG, OFST_SAMPLE_PERIOD_CMD, 4
	sbbo tmp0, rADDR_CPU_PRU_CTRL_REG, OFST_CPU_NEW_PERIOD , 4
	qba DONE_COPYING_NEW_PERIOD

	
DELIVER_TO_CPU:
//     - copy from PRU-sensor-buf to CPU-sensor-buf, then set 'data-ready' flag.

	// We write it backwards, since pru_data_buf_write_head already points to the most recent sample.

	// Remember the last time heard from CPU:
	LBCO time_of_last_cpu_data_req, C28, 0xC, 4

	// Increment # data reqs we've gotten
	add num_data_reqs, num_data_reqs, 1

	// idea oct 5: it's confusing that the "time of last cpu data req" is always one req old.
	// Better if we real quick write it here, right before we deliver it.
	// Then the "time of last cpu data req" will truly be the time when the CPU requested the data pkt that's about to be delivered.
	// Also, it's confusing that # reqs and # schedules is only updated at sample times, not at reqest time.
	//  Just write the # data reqs and # cmd schedules to every pkt's "time of last cmd pkt" here, right before we deliver it.
	//
	//  NOTE: neither buffer is sorted, so too hard to find "last" buffer. Just write to all of them. Don't worry about waste for now.
	// WARNING: This assumes last 2 ints in a data pkt are "time of last cpu data req" then "# reqs and # schedules".
COPY_REQ_TIME_INTO_PDB:
	mov tmp2, BYTES_PER_DATA_BUFFER // yes bytes, not ints.
	mov tmp1, 0 // offset into PRU DATA BUF. 
   COPY_ONE_REQ_TIME_INTO_PDB:
	add tmp1, tmp1, 24 // 0th "time of last cpu data req" is 6=6th-int-in-data-pkt * 4=bytes-per-int = 24 bytes from start of PDB
	SBBO time_of_last_cpu_data_req, rADDR_PRU_DATA_BUF, tmp1, 4
	add tmp1, tmp1, 4 // next int: "# reqs & # schedules"
	mov tmp0, num_cmd_schedules
	LSL tmp0, tmp0, 16
	or  tmp0, tmp0, num_data_reqs
	SBBO tmp0, rADDR_PRU_DATA_BUF, tmp1, 4
	add tmp1, tmp1, 4 // next int is the start of next data pkt.
	qbgt COPY_ONE_REQ_TIME_INTO_PDB, tmp1, tmp2

	
	// Clear "cpu wants" bit
	mov tmp0, 0
	SBBO tmp0, rADDR_CPU_PRU_CTRL_REG, OFST_CPU_WANTS_DATA, 4
	// Clear "data ready" bit too, for good measure
	SBBO tmp0, rADDR_CPU_PRU_CTRL_REG, OFST_PRU_DATA_READY, 4


	
	// sep 27: uh oh. we're having problems with this fancy writing-backwards thing.
	// Sometimes the PRU claims it's copied over the PDB to the CDB, but it actually didn't.
	// Instead, just copy the PDB into the CDB directly, and let the
	// damn cpu figure out how to sort it right.
	
	mov tmp2, BYTES_PER_DATA_BUFFER // yes bytes, not ints.
	mov tmp1, 0 // how many bytes copied	
COPY_ONE_INT_FROM_PDB_TO_CDB:	
	LBBO tmp0, rADDR_PRU_DATA_BUF, tmp1, 4 
	SBBO tmp0, rADDR_CPU_DATA_BUF, tmp1, 4
	add tmp1, tmp1, 4
	qbgt COPY_ONE_INT_FROM_PDB_TO_CDB, tmp1, tmp2



	
// Old fancy way: copy backwards so that CDB is in chronological order	
//	MOV tmp1, pru_data_buf_write_head // addr offset in backup buffer
//	mov tmp3, ( BYTES_PER_DATA_BUFFER) // addr offset of end of cpu's buffer
//	MOV tmp2, 0 // num samples copied
//  COPY_ONE_SAMPLE:
//	// 8 uints per data packet (todo: should loop here)
//	sub tmp1, tmp1, 4
//	sub tmp3, tmp3, 4
//	LBBO tmp0, rADDR_PRU_DATA_BUF, tmp1, 4 
//	SBBO tmp0, rADDR_CPU_DATA_BUF, tmp3, 4
//	sub tmp1, tmp1, 4
//	sub tmp3, tmp3, 4	
//	LBBO tmp0, rADDR_PRU_DATA_BUF, tmp1, 4 
//	SBBO tmp0, rADDR_CPU_DATA_BUF, tmp3, 4
//	sub tmp1, tmp1, 4
//	sub tmp3, tmp3, 4	
//	LBBO tmp0, rADDR_PRU_DATA_BUF, tmp1, 4 
//	SBBO tmp0, rADDR_CPU_DATA_BUF, tmp3, 4
//	sub tmp1, tmp1, 4
//	sub tmp3, tmp3, 4	
//	LBBO tmp0, rADDR_PRU_DATA_BUF, tmp1, 4 
//	SBBO tmp0, rADDR_CPU_DATA_BUF, tmp3, 4
//	sub tmp1, tmp1, 4
//	sub tmp3, tmp3, 4
//	LBBO tmp0, rADDR_PRU_DATA_BUF, tmp1, 4 
//	SBBO tmp0, rADDR_CPU_DATA_BUF, tmp3, 4
//	sub tmp1, tmp1, 4
//	sub tmp3, tmp3, 4	
//	LBBO tmp0, rADDR_PRU_DATA_BUF, tmp1, 4 
//	SBBO tmp0, rADDR_CPU_DATA_BUF, tmp3, 4
//	sub tmp1, tmp1, 4
//	sub tmp3, tmp3, 4	
//	LBBO tmp0, rADDR_PRU_DATA_BUF, tmp1, 4 
//	SBBO tmp0, rADDR_CPU_DATA_BUF, tmp3, 4
//	sub tmp1, tmp1, 4
//	sub tmp3, tmp3, 4	
//	LBBO tmp0, rADDR_PRU_DATA_BUF, tmp1, 4 
//	SBBO tmp0, rADDR_CPU_DATA_BUF, tmp3, 4
//
//	ADD tmp2, tmp2, 1  // num_samples++
//	QBEQ DONE_COPYING_PDB_TO_CDB, tmp2, PKTS_PER_DATA_BUFFER // if we've copied this many samples, we're done
//
//	// if write head is 0 or less, reset it to end of backup buffer
//	// NOTE: these reg values are all unsigned, so they never get <0!!!!!!
//	// 
//	qbge RESET_COPY_HEAD, tmp1, 0 // qbge    myLabel, r3, r4    // Branch if r4 >= r3
//	DONE_RESETTING_COPY_HEAD:	
//	
//	QBA COPY_ONE_SAMPLE // copy another sample
//
//RESET_COPY_HEAD:
//	mov tmp1, BYTES_PER_DATA_BUFFER
//	qba DONE_RESETTING_COPY_HEAD

	

DONE_COPYING_PDB_TO_CDB:	
	
	// Idea sep 22, 2016: during a data-write event, also copy the PRU cmd buf to the CPU cmd buf.
	//  This could help w debugging.
COPY_PRU_CMDS_TO_CPU_CMDS:
	mov tmp2, BYTES_PER_CMD_BUFFER
	mov tmp1, 0 // how many bytes copied	
COPY_ONE_INT_FROM_PCB_TO_CCB:	
	LBBO tmp0, rADDR_PRU_CMD_BUF, tmp1, 4 
	SBBO tmp0, rADDR_CPU_CMD_BUF, tmp1, 4
	add tmp1, tmp1, 4
	qbgt COPY_ONE_INT_FROM_PCB_TO_CCB, tmp1, tmp2



	
	
SET_DELIVERED_BIT_AND_LEAVE:	
	// Set "data delivered" bit
	mov tmp0, 1
	SBBO tmp0, rADDR_CPU_PRU_CTRL_REG, OFST_PRU_DATA_READY, 4

	qba DONE_DELIVERING
	

RESET_WRITE_HEAD:
	mov idx_in_pru_data_buf, 0
	mov pru_data_buf_write_head, 0
	qba DONE_RESETTING_WRITE_HEAD


	

	
COPY_NEW_ACTUATION_SCHEDULE:
//     - copy from CPU-sch-buf to PRU-sch-buf, then set 'ack-new-sch' flag
	// See jpp-pru-lib.h for cmd pkt format.

	// sep 21, 2016:
	// Joao's idea: scan thru the cmd pkts and execute the first non-executed one that has a sample number matching the current sample number.
	// When a new cmd buf comes in, wipe out the entire cmd buf with the new one.
	// - if new cmd buf contains future timestamps, any pending cmd pkts will not be executed.
	//     + that rarely happens; more likely the cmd buf has stale pkts.
	// + simple



	// sep 17, 2016:
	// Examine sample num of 1st cmd pkt in given buffer.
	// Compare that to the current sample num (current_sample)
	// Throw out given cmd pkts whose sample times are in the past.
	



	// Remember the last time heard from CPU:
	LBCO time_of_last_cpu_cmd_sch, C28, 0xC, 4

	// incr # cmd schedules we've rx'd
	add num_cmd_schedules, num_cmd_schedules, 1
	
	// How many new pkts?
	lbbo num_cmd_pkts_in_buffer, rADDR_CPU_PRU_CTRL_REG, OFST_CPU_NEW_SCHED, 4

	// Clear "cpu new sched" bit
//	mov tmp0, 0
//	mov tmp1, ADDR_CPU_PRU_CTRL_REG
//	SBBO tmp0, tmp1, OFST_CPU_NEW_SCHED, 4
	SBBO 0, rADDR_CPU_PRU_CTRL_REG, OFST_CPU_NEW_SCHED, 4

	// If no pkts for some reason, skip all this.
	qbge SET_PRU_ACK_AND_LEAVE, num_cmd_pkts_in_buffer, 0


	// Totally overwrite our existing actuation schedule:
	
	mov tmp2, 0 // num pkts copied
	mov tmp1, 0 // addr offset 
	
  COPY_ONE_PKT:
	// todo: loop for as many ints as are in a cmd pkt.
	//  Hack: instead of copying over the cmd pkt's cycle count (which we don't use),
	//  let's copy the time that this pkt was heard.
	//  Then we'll have some idea of where these rogue packets are coming from.
	mov tmp0, time_of_last_cpu_cmd_sch
//	lbbo tmp0, rADDR_CPU_CMD_BUF, tmp1, 4
	sbbo tmp0, rADDR_PRU_CMD_BUF, tmp1, 4
	add tmp1, tmp1, 4
	lbbo tmp0, rADDR_CPU_CMD_BUF, tmp1, 4
	sbbo tmp0, rADDR_PRU_CMD_BUF, tmp1, 4
	add tmp1, tmp1, 4
	lbbo tmp0, rADDR_CPU_CMD_BUF, tmp1, 4
	sbbo tmp0, rADDR_PRU_CMD_BUF, tmp1, 4
	add tmp1, tmp1, 4
	lbbo tmp0, rADDR_CPU_CMD_BUF, tmp1, 4
	sbbo tmp0, rADDR_PRU_CMD_BUF, tmp1, 4
	add tmp1, tmp1, 4

	add tmp2, tmp2, 1 // # cmd pkts copied so far
	
	qbgt COPY_ONE_PKT, tmp2, num_cmd_pkts_in_buffer // copy another pkt unless we've got 'em all

	// If that was the whole buffer, skip this next part: no pkts need to be erased.
	qbeq DONE_ERASING_REST_OF_CMD_BUF, num_cmd_pkts_in_buffer, PKTS_PER_CMD_BUFFER
	// Else, erase the rest of the cmd buffer:
	
	mov tmp0, 0
WIPE_OUT_ONE_PKT:
	// Erase a cmd pkt.
	sbbo tmp0, rADDR_PRU_CMD_BUF, tmp1, 4
	add tmp1, tmp1, 4
	sbbo tmp0, rADDR_PRU_CMD_BUF, tmp1, 4
	add tmp1, tmp1, 4
	sbbo tmp0, rADDR_PRU_CMD_BUF, tmp1, 4
	add tmp1, tmp1, 4
	sbbo tmp0, rADDR_PRU_CMD_BUF, tmp1, 4
	add tmp1, tmp1, 4

	add tmp2, tmp2, 1 // # cmd pkts erased so far
	
	qbgt WIPE_OUT_ONE_PKT, tmp2, PKTS_PER_CMD_BUFFER // wipe out another pkt until you've got to the end of the cmd buf.
	
DONE_ERASING_REST_OF_CMD_BUF:	
	
// done copying the new cmd schedule over.

	mov pru_cmd_buf_read_head, 0 // reset read head to start of new cmd buffer	
//	mov idx_in_pru_cmd_buf, 0	// Reset the index of which cmd pkt we're at.


///////////////////////////////////////
// Skip over the "Throw away old cmd pkts" logic
//	qba DONE_DISCARDING_STALE_CMD_PKTS
//
//CHECK_FOR_OLD_CMD_PKTS:
//	// num_total_samples is the number of samples already taken.
//	// hopefully the 0th cmd pkt from the CPU has sample number num_total_samples+1 (the next timestep).
//	// If it's less than num_total_samples+1, the OS may have preempted our ctrl alg,
//	// and the ctrl alg sent some old cmd pkts.
//	
//	// fast-forward the read-head and idx past the out-of-date given cmd pkts.
//	// Look at the sample time of the 0th new cmd pkt. If it's less than the num_cmd_pkts_in_buffer,
//	// 1. advance pru_cmd_buf_read_head by a # of bytes that's 1 cmd pkt
//	// 2. advance idx_in_pru_cmd_buf by 1
//	mov tmp0, pru_cmd_buf_read_head
//	add tmp0, tmp0, 4 // sample_num is after cycle_count
//	mov tmp1, ADDR_PRU_CMD_BUF
//	lbbo tmp2, tmp1, tmp0, 4 // load sample_num into tmp2
//
//	// If sample_num >= num_total_samples, no stale cmd pkts need to be skipped.
//	qble DONE_DISCARDING_STALE_CMD_PKTS, tmp2, num_total_samples
//	// else, sample_num < num_total_samples, so we need to skip some of these new cmd packets.
//	sub tmp3, num_total_samples, tmp2 // tmp3 = # samples we need to fast-fwd the cmd buffer
//	// TODO: WHY?: Hm, off-by-one error where PRU is throwing away one-too-many cmd pkts. Comment this out:
////		add tmp3, tmp3, 1 // if sample_num == num_total_samples, we still need to discard one new cmd pkt.
//
//	
//	min tmp3, tmp3, num_cmd_pkts_in_buffer // never throw away more pkts than exist in the cmd buffer.
//	
//SKIP_ONE_CMD_PKT:	
//	add pru_cmd_buf_read_head, pru_cmd_buf_read_head, (BYTES_PER_CMD_PKT)	// advance read head to next cmd.
//	add idx_in_pru_cmd_buf, idx_in_pru_cmd_buf, 1
//	sub tmp3, tmp3, 1
//	qblt SKIP_ONE_CMD_PKT, tmp3, 0 // repeat if 0 < # samples to discard
//
//DONE_DISCARDING_STALE_CMD_PKTS:	




SET_PRU_ACK_AND_LEAVE:	
	// Set "pru ack sched" bit
	mov tmp0, 1
	mov tmp1, ADDR_CPU_PRU_CTRL_REG
	sbbo tmp0, tmp1, OFST_PRU_ACK_SCHED, 4
	
// all done copying new :
	qba DONE_COPYING_NEW_SCH





INIT_ADC:
	
	mov tmp1, ADDR_ADC
        LBBO tmp0, tmp1, OFFSET_CTRL, 4	// Disable ADC so we can config it.
        CLR  tmp0.t0
        SBBO tmp0, tmp1, OFFSET_CTRL, 4

        MOV tmp0, 0 // To capture 1 adc channel at full speed, set the clock-divider to 0 (whole reg?)
        SBBO tmp0, tmp1, OFFSET_ADC_CLKDIV, 4

	// Now we configure the first step of the ADC-conversion-state-machine. 

	// Initially disable all steps of the state machine.
	// We'll trigger a sample by enabling one later on.
	// See "single-shot" vs "continuous" in TRM.

        LBBO tmp0, tmp1, OFFSET_STEPENABLE, 4
        CLR  tmp0, 16   // top 16 bits are reserved.
        SBBO tmp0, tmp1, OFFSET_STEPENABLE, 4


	// Configure the 1st step of ADC stat machine

	// Use `SET` and `CLR` here to set the bits correctly. (Note:
	// everything's spelled out here for pedagogical purposes; could
	// shorten the code a lot.)

        LBBO tmp0, tmp1, OFFSET_STEPCONFIG1, 4
        CLR tmp0.t27   // disable range-check
        CLR tmp0.t26   // store in FIFO0
        CLR tmp0.t25   // differential ctrl pin (?)

        // SEL_RFM pins SW configuration. (?)
        CLR tmp0.t24
        CLR tmp0.t23   

        // SEL_INP pins SW configuration. (0000 = Channel 1, 0111 = Channel 8)
        CLR tmp0.t22
        CLR tmp0.t21
        CLR tmp0.t20
        CLR tmp0.t19

        // SEL_INM pins for negative differential. (?) (0000 = Channel 1, 0111 = Channel 8)
        CLR tmp0.t18
        CLR tmp0.t17
        CLR tmp0.t16
        CLR tmp0.t15

        // SEL_RFP pins SW configuration. (000 = VDDA_ADC)
        CLR tmp0.t14
        CLR tmp0.t13
        CLR tmp0.t12

        // WPNSW pin SW configuration (, YPNSW, XNPSW, ... ) (???)
        CLR tmp0.t11
        CLR tmp0.t10
        CLR tmp0.t9
        CLR tmp0.t8        
        CLR tmp0.t7        
        CLR tmp0.t6        
        CLR tmp0.t5        

        // Number of samplings to average: 
        // 000 = No average.
        // 001 = 2 samples average.
        // 010 = 4 samples average.
        // 011 = 8 samples average.
	// 100 = 16 samples average.
        CLR tmp0.t4  // sep 6, 2016: current-measuring circuit is noisy, can this help?
        CLR tmp0.t3
        CLR tmp0.t2

        // Mode:
        // 00 = SW enabled, one-shot.
        // 01 = SW enabled, continuous.
        // 10 = HW synchronized, one-shot. 
        // 11 = HW synchronized, continuous.        
        CLR tmp0.t1
        CLR tmp0.t0

        // Write it back to the ADC register:
        SBBO tmp0, tmp1, OFFSET_STEPCONFIG1, 4

	// Now we're ready to enable the ADC.
	// It won't do anything because we've disabled all the steps.
        LBBO tmp0, tmp1, OFFSET_CTRL, 4
        SET  tmp0.t2 // 1 = Step configuration registers are writable. Needed to trigger a sample.
        SET  tmp0.t1 // 1 = Store the Step ID number with the captured ADC data in the FIFO.
	             // (good to verify correct channel is being read)
        SET  tmp0.t0 // 1 = Turn on the ADC. 
        SBBO tmp0, tmp1, OFFSET_CTRL, 4 // now the ADC is on, so the state  machine is running,
						   // but there are no enabled steps, so it doesn't do anyhting.
	RET


RESET_CYCLE_COUNTER:
// Reset the cycle counter when it maxes out: disable counter, set 0 to cycle counter reg, enable counter:
	LBCO   tmp0, C28, 0, 4      // Disable CYCLE counter
	CLR    tmp0, 3
	SBCO   tmp0, C28, 0, 4
	MOV    tmp0, 0              // Set cycle count to 0
	SBCO   tmp0, C28, 0xC, 4
	LBCO   tmp0, C28, 0, 4      // Enable CYCLE counter
	SET    tmp0, 3
	SBCO   tmp0, C28, 0, 4
	
	RET



INIT_REGISTERS:

	// init named registers
	// (Copy list of named regs above to here, then init them.)

	mov tmp0 			, 0
	mov tmp1 			, 0
	mov tmp2 			, 0
	mov tmp3 			, 0
	mov current_time 		, 0
	mov cycles_at_next_sample_time 	, PRU_TICKS_PER_SAMPLE
	mov time_of_last_cpu_data_req	, 0
	mov gpio_cmd			, 0
	mov gpio_actual			, 0
	mov pru_cmd_buf_read_head	, 0
	mov num_cmd_pkts_in_buffer	, 0
	mov adc_value			, 0
	mov pru_data_buf_write_head	, 0
	mov idx_in_pru_data_buf		, 0
	mov current_sample		, 0
	mov idx_in_log_of_req_times	, 0
	mov num_cmd_schedules		, 0
	mov eqep			, 0
	mov time_of_last_cpu_cmd_sch	, 0
	mov rADDR_CPU_PRU_CTRL_REG  	, ADDR_CPU_PRU_CTRL_REG  		
	mov rADDR_CPU_DATA_BUF      	, ADDR_CPU_DATA_BUF      	
	mov rADDR_PRU_DATA_BUF      	, ADDR_PRU_DATA_BUF      	
	mov rADDR_CPU_CMD_BUF       	, ADDR_CPU_CMD_BUF       	
	mov rADDR_PRU_CMD_BUF       	, ADDR_PRU_CMD_BUF       	
	mov duty_cmd			, 0
	mov duty_actual			, 0
	mov sample_period               , PRU_TICKS_PER_SAMPLE
	mov num_data_reqs	        , 0
	ret


ACTUATE:
	// cmd pkt: 4 words = 16 bytes = 0x10 bytes
	//
	// - cycle count
	// - sample num
	// - gpio states
	// - duty cycle

	// sep 21 2016:
	
	// joao idea: search thru whole cmd buf until you find a cmd
	//   pkt whose samp num matches the current sample time. Execute
	//   it.
	// Bonus: if a cmd pkt's sample number is 0xffffffff, execute it unconditionally.
	//   Leave its sample # at 0xffffffff so that we continue to execute it forever (until the CPU writes a new cmd buffer).
	// If a cmd pkt's sample number if 0xfffffffe, execute it unconditionally but set its sample # to 0 so we don't execute it again.

	// Look for a cmd pkt whose sample-num matches our current sample num.
	mov pru_cmd_buf_read_head, 0 // start at beginning of cmd buf.
	mov tmp1, 0 // how many pkts we've checked
	add pru_cmd_buf_read_head, pru_cmd_buf_read_head, 4 // this is where the sample number lives: after the cycle counter (4 bytes after)
CHECK_CMD_PKT_SAMPLE_NUM:	
	lbbo tmp0, rADDR_PRU_CMD_BUF, pru_cmd_buf_read_head, 4 // get sample num of this pkt
	// if sample_num == MAGIC_SAMPLE_NUM_ALWAYS_EXECUTE, break out and execute it.
	mov tmp2, MAGIC_SAMPLE_NUM_ALWAYS_EXECUTE
	qbeq READ_HEAD_IS_AT_GOOD_PKT, tmp0, tmp2
	// else,
	// if sample_num == MAGIC_SAMPLE_NUM_ALWAYS_EXECUTE_ONCE, break out and execute it, wiping its sample number first.
	mov tmp2, MAGIC_SAMPLE_NUM_ALWAYS_EXECUTE_ONCE
	qbeq AT_MAGIC_SAMPLE_NUM_ALWAYS_EXECUTE_ONCE, tmp0, tmp2
	// else,
	// if sample num == current sample time, we've found the "current" cmd pkt. Break out and execute it.
	qbeq READ_HEAD_IS_AT_GOOD_PKT, tmp0, current_sample

	// else, advance to the next cmd pkt.
	add tmp1, tmp1, 1
	add pru_cmd_buf_read_head, pru_cmd_buf_read_head, (BYTES_PER_CMD_PKT)	// advance read head to next cmd.
	// if # pkts examined < num in cmd buffer, repeat
	qbgt CHECK_CMD_PKT_SAMPLE_NUM, tmp1, PKTS_PER_CMD_BUFFER
	// else, we're exhaused the cmd buffer and haven't found a cmd pkt with our current sample time.
	// Give up: leave the gpio & duty alone.
	qba DONE_ACTUATING	


AT_MAGIC_SAMPLE_NUM_ALWAYS_EXECUTE_ONCE:	
	mov tmp0, 0
	sbbo tmp0, rADDR_PRU_CMD_BUF, pru_cmd_buf_read_head, 4 // wipe out this sample number
	
	
READ_HEAD_IS_AT_GOOD_PKT:
	// oops, rewind read head 4 bytes, since we were skipping by sample-num above
	sub  pru_cmd_buf_read_head,  pru_cmd_buf_read_head, 4 // now head is at begin of cmd pkt

	
	// pkt structure: see jpp-pru-lib.h 
	// read gpio cmd int
	mov tmp0, pru_cmd_buf_read_head
	add tmp0, tmp0, 8 // gpio states is 3rd int
	lbbo gpio_cmd, rADDR_PRU_CMD_BUF, tmp0, 4
	add tmp0, tmp0, 4 // duty is right after gpio
	lbbo duty_cmd, rADDR_PRU_CMD_BUF, tmp0, 4 // note: duty goes into a 2-byte reg, so only the lower 2 bytes actually get used here.

	
	// The DTO specifies that only bits 0,1,2,5 of r30 belong to the PRU.
	// Who knows what toggling the other bits of r30 will do. 
	// So you're only allowed to modify r30 bits 0,1,2,5.
	// I want to set bits 0,1,2,5 of r30 equal to bits 0,1,2,5 of gpio_cmd. How??
	// http://stackoverflow.com/questions/4439078/how-do-you-set-only-certain-bits-of-a-byte-in-c-without-affecting-the-rest
	// value = (value & ~mask) | (newvalue & mask);
	// Or:
	// value &= ~mask
	// newvalue &= mask
	// value |= newvalue
	mov tmp1, r30                      // tmp1 = value
	and tmp1, tmp1, NOT_GPIO_MASK      // value &= ~mask    (zero out bits we may change)
	and gpio_cmd, gpio_cmd, GPIO_MASK  // newvalue &= mask  (don't change any bits you're not allowed to)
	or  tmp1, tmp1, gpio_cmd           // value |= newvalue (add in the gpio cmd bits)

	mov tmp2, EPWM1_0_BASE          // (where we'll write the next duty cycle -- the PWM peripheral)
	
	mov r30, tmp1                      // write new gpio vals to regs. All should change at once.
	sbbo duty_cmd, tmp2, CMPB, 2  // Set the duty cycle in the pwm module.

	and tmp1, tmp1, GPIO_MASK          // Record only the GPIO bits that we're allowed to change.
	mov gpio_actual, tmp1
	mov duty_actual, duty_cmd  // record what we applied (probably could remove this if low on registers)
	
	
//	add pru_cmd_buf_read_head, pru_cmd_buf_read_head, (BYTES_PER_CMD_PKT)	// advance read head to next cmd.
//	add idx_in_pru_cmd_buf, idx_in_pru_cmd_buf, 1



	qba DONE_ACTUATING


CLEAR_PRU0_DATA_RAM:
	mov tmp0, 0
	mov tmp1, ADDR_PRU0_DATA_RAM
	mov tmp2, (ADDR_PRU0_DATA_RAM+BYTES_PER_DATA_RAM)
    CLEAR_ONE_INT:
	sbbo tmp0, tmp1, 0, 4
	add tmp1, tmp1, 4
	// if addr < max addr of the PRU0 data ram, repeat
	qbgt CLEAR_ONE_INT, tmp1, tmp2
	ret


INIT_PWM:

// Init the PWMSS1:
	
// Register Bit Value Comments
/////////////////////////////////////
	mov tmp0, EPWM1_0_BASE
	
// TBPRD, TBPRD, 258h (period = 258h = 601 tbclk counts)

	mov tmp1, _100MHZ_TICKS_PER_PWM_PERIOD
	sbbo tmp1, tmp0, TBPRD, 2
	
// TBPHS TBPHS 0 Clear Phase Register to 0
	mov tmp1, 0
	sbbo tmp1, tmp0, TBPHS, 2
	
// TBCNT TBCNT 0 Clear TB counter
	mov tmp1, 0
	sbbo tmp1, tmp0, TBCNT, 2
	
// TBCTL
	mov tmp1, 0	
	clr tmp1.t0 // CTRMODE TB_UP
	clr tmp1.t1
	clr tmp1.t2 // PHSEN TB_DISABLE   // Phase loading disabled
	clr tmp1.t3 // PRDLD TB_SHADOW
	set tmp1.t4 // SYNCOSEL TB_SYNC_DISABLE
	set tmp1.t5
	clr tmp1.t6 // no software-forced synchronization pulse? TRM no mentions this.
	clr tmp1.t7 // HSPCLKDIV TB_DIV1  ( TBCLK = SYSCLK )
	clr tmp1.t8
	clr tmp1.t9
	clr tmp1.t10 // CLKDIV TB_DIV1
	clr tmp1.t11
	clr tmp1.t12

	clr tmp1.t13 // phase direction (not really used)
	set tmp1.t14 // "emulation mode bits" - free run during "emulation-suspend events" TRM no mentions.
	set tmp1.t15

	sbbo tmp1, tmp0, TBCTL, 2  // write this 16-bit reg

// CMPA CMPA 350 (15Eh) Compare A = 350 TBCLK counts
	mov tmp1, 0 // disable this damn thing, it's not showing up at P8_36
	sbbo tmp1, tmp0, CMPA, 2
	
// CMPB CMPB 200 (C8h) Compare B = 200 TBCLK counts
	mov tmp1, 0 // example: 333 w/ TBPRD 3333 => 10% duty cycle
	sbbo tmp1, tmp0, CMPB, 2
	
// CMPCTL
	// This reg has 'reserved' bits; don't change those.
	mov tmp1, 0  // clear out the whole 32-bits before loading in anything
	lbbo tmp1, tmp0, CMPCTL, 2
	// compute new value
	clr tmp1.t4 // SHDWAMODE CC_SHADOW
	clr tmp1.t6 // SHDWBMODE CC_SHADOW

	set tmp1.t0 // jpp: disabling ch A. No loads possible.
	set tmp1.t1 // (old: LOADAMODE CC_CTR_ZERO  (Load on CTR = 0))

	clr tmp1.t2 // LOADBMODE CC_CTR_ZERO  (Load on CTR = 0)
	clr tmp1.t3

	sbbo tmp1, tmp0, CMPCTL, 2 // put it back
	

// AQCTLA
	// jpp: disabling ch A. Take no actions on ch a:
	lbbo tmp1, tmp0, AQCTLA, 2
	clr tmp1.t0
	clr tmp1.t1
	clr tmp1.t2
	clr tmp1.t3
	clr tmp1.t4
	clr tmp1.t5
	clr tmp1.t6
	clr tmp1.t7
	clr tmp1.t8
	clr tmp1.t9
	clr tmp1.t10
	clr tmp1.t11
	sbbo tmp1, tmp0, AQCTLA, 2

// AQCTLB
	lbbo tmp1, tmp0, AQCTLB, 2
	clr tmp1.t0	// ZRO AQ_SET
	set tmp1.t1
	set tmp1.t8	// CBU AQ_CLEAR
	clr tmp1.t9
	sbbo tmp1, tmp0, AQCTLB, 2

	RET

	
COPY_CYCLE_COUNT:	
	// wipe out reg
	mov tmp0, 0
        SBBO tmp0, rADDR_CPU_PRU_CTRL_REG, OFST_CYCLE_COUNT_REQ, 4
	LBCO tmp0, C28, 0xC, 4     // What time is it?
	sbbo tmp0, rADDR_CPU_PRU_CTRL_REG, OFST_CYCLE_COUNT, 4 
	qba DONE_COPYING_CYCLE_COUNT
	