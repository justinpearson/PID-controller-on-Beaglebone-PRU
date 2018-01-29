

CC=gcc
CFLAGS=-g -Wall -Werror -lstdc++ -std=gnu99 -lm -lrt
WOFF=-Wno-unused-but-set-variable -Wno-unused-variable -Wno-unused-label
# TENSCALC=$(shell echo tmpC_TS_*.c)
# TENSCALCO=$(TENSCALC:.c=.o)

# pthread ?
# -Werror : I'd rather see all the warnings and 

.PHONY: all clean

# IMPORTANT: Add more to this.
all : pid-pru-iir pid-sysfs-iir pid-fwd pid-fwd2 pid-fwd3 pid-fwd22 busy-wait jpp-pru-lib.bin jpp-pru-lib.o util-jpp.o bb-simple-sysfs-c-lib.o tests.o pid-fwd.o pid-fwd2.o pid-fwd3.o pid-fwd22.o pid-sysfs-iir.o pid-pru-iir.o


pid-pru-iir : pid-pru-iir.o util-jpp.o jpp-pru-lib.o
	@echo "linking pid-pru-iir..."
	$(CC) $(CFLAGS) -lprussdrv util-jpp.o jpp-pru-lib.o pid-pru-iir.o -o pid-pru-iir


pid-sysfs-iir : pid-sysfs-iir.o util-jpp.o bb-simple-sysfs-c-lib.o 
	@echo "linking pid-sysfs-iir..."
	$(CC) $(CFLAGS) util-jpp.o bb-simple-sysfs-c-lib.o pid-sysfs-iir.o -o pid-sysfs-iir

pid-fwd : pid-fwd.o util-jpp.o jpp-pru-lib.o 
	@echo "linking pid-fwd..."
	$(CC) $(CFLAGS) -lprussdrv util-jpp.o jpp-pru-lib.o bb-simple-sysfs-c-lib.o pid-fwd.o -o pid-fwd

pid-fwd2 : pid-fwd2.o util-jpp.o jpp-pru-lib.o  
	@echo "linking pid-fwd..."
	$(CC) $(CFLAGS) -lprussdrv util-jpp.o jpp-pru-lib.o bb-simple-sysfs-c-lib.o  pid-fwd2.o -o pid-fwd2

pid-fwd3 : pid-fwd3.o util-jpp.o jpp-pru-lib.o  
	@echo "linking pid-fwd..."
	$(CC) $(CFLAGS) -lprussdrv util-jpp.o jpp-pru-lib.o bb-simple-sysfs-c-lib.o pid-fwd3.o -o pid-fwd3

pid-fwd22 : pid-fwd22.o util-jpp.o jpp-pru-lib.o  
	@echo "linking pid-fwd..."
	$(CC) $(CFLAGS) -lprussdrv util-jpp.o jpp-pru-lib.o bb-simple-sysfs-c-lib.o pid-fwd22.o -o pid-fwd22

busy-wait : busy-wait.c util-jpp.o
	@echo "Compiling busy-wait..."
	$(CC) $(CFLAGS) util-jpp.o busy-wait.c -o busy-wait


$(TENSCALCO) : $(TENSCALC)
	@echo "=========================="
	@echo "Compiling tenscalc lib ..."
	date
	$(CC) $(CFLAGS) -Wno-unused-variable -Wno-unused-result -O1 -DNDEBUG  -c $<
	date

jpp-pru-lib.bin : jpp-pru-lib.p jpp-pru-lib.hp 
	@echo "=========================="
	@echo "Using pasm to assemble .p file into .bin file ..."
	pasm -b $<

jpp-pru-lib.o : jpp-pru-lib.c jpp-pru-lib.h jpp-pru-lib.hp 
	@echo "=========================="
	@echo "building PRU C library..."
	$(CC) $(CFLAGS) -lprussdrv -c $<

util-jpp.o : util-jpp.c
	@echo "=========================="
	@echo "building util-jpp library..."
	$(CC) $(CFLAGS)  -c $<

bb-simple-sysfs-c-lib.o : bb-simple-sysfs-c-lib.c 
	@echo "=========================="
	@echo "building bb-simple-sysfs-lib library..."
	$(CC) $(CFLAGS)  -c $<

tests.o : tests.c 
	@echo "=========================="
	@echo "building tests.c library..."
	$(CC) $(CFLAGS) -c $<


pid-fwd.o : pid-fwd.c
	@echo "=========================="
	@echo "building " $<
	${CC} ${CFLAGS} ${WOFF} -c $<

pid-fwd2.o : pid-fwd2.c
	@echo "=========================="
	@echo "building " $<
	${CC} ${CFLAGS} ${WOFF} -c $<

pid-fwd3.o : pid-fwd3.c
	@echo "=========================="
	@echo "building " $<
	${CC} ${CFLAGS} ${WOFF} -c $<

pid-fwd22.o : pid-fwd22.c
	@echo "=========================="
	@echo "building " $<
	${CC} ${CFLAGS} ${WOFF} -c $<

pid-sysfs-iir.o : pid-sysfs-iir.c
	@echo "=========================="
	@echo "building " $<
	${CC} ${CFLAGS} ${WOFF} -c $<


pid-pru-iir.o : pid-pru-iir.c
	@echo "=========================="
	@echo "building " $<
	${CC} ${CFLAGS} ${WOFF} -c $<



clean:
	rm -f *.o *.bin main pid-pru-iir pid-sysfs-iir pid-fwd pid-fwd2 pid-fwd3 pid-fwd22 busy-wait 


