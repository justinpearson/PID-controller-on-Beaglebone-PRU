Here are the DTO files that need to be in /lib/firmware for the BB PRU Controls library.

Most of them are included on a stock BB, but a few come from .dts files that I edited:

jppprugpio-00A0.dtbo -- from Derek Molloy's book, changed for different GPIO I think.
bone_eqep1-00A0.dtbo -- from Nathaniel Lewis?


Also, my uEnv.txt, which loads some .dto's on boot, and my hw-init.sh shell script, which loads the rest of them. (For some reason, having all my .dto's on a single line in uEnv.txt didn't work.)

