clear all; close all; fclose all; clc;



P = importdata('pid-iir-pru-dat-n7.txt');

        for i=1:length(P.colheaders)
            varname = P.colheaders{i};
            cmd = ['p_' varname '=P.data(:,' num2str(i) ');']
            eval(cmd);
        end
        
S = importdata('pid-iir-sysfs10.txt');
        for i=1:length(S.colheaders)
            varname = S.colheaders{i};
            cmd = ['s_' varname '=S.data(:,' num2str(i) ');']
            eval(cmd);
        end
        %%
        p_cputimediff_cpu(1) = 0;
%%
yy = 400;
yy2 = .08
figure(1); clf;
imin = 200; imax=1400;
subplot(4,1,1)
plot(s_cputime(imin:imax)-s_cputime(imin), s_ref(imin:imax), 'k--')
hold on
plot(s_cputime(imin:imax)-s_cputime(imin), s_angle(imin:imax),'k-')
xlabel('cpu time (s)')
title('Sysfs: Shaft angle (deg)')
legend('ref','angle')
xlim([0,10])
ylim(yy*[-1,1])
subplot(4,1,2)
plot(s_cputime(imin:imax)-s_cputime(imin), s_cputimediff(imin:imax),'k-')
xlabel('cpu time (s)')
title('Sysfs: Wall-clock time per iteration (s)')
ylim([0,yy2])
xlim([0,10])

subplot(4,1,3)
imin = 10; imax=689;
plot(p_cputime_cpu(imin:imax)-p_cputime_cpu(imin), p_ref_cpu(imin:imax), 'k--')
hold on
plot(p_cputime_cpu(imin:imax)-p_cputime_cpu(imin), p_angle_cpu(imin:imax),'k-')
xlabel('cpu time (s)')
title('PRU: Shaft angle (deg)')
legend('ref','angle')
xlim([0,10])
ylim(yy*[-1,1])
subplot(4,1,4)
plot(p_cputime_cpu(imin:imax)-p_cputime_cpu(imin), p_cputimediff_cpu(imin:imax),'k-')
xlabel('cpu time (s)')
title('PRU: Wall-clock time per iteration (s)')
xlim([0,10])
ylim([0,yy2])