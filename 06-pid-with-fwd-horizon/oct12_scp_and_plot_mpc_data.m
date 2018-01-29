clear all; close all; clc

%% Plot the mpc-data.txt data file after running the MPC/MHE controller on the Beaglebone / PRU.
% Justin Pearson, Oct 12, 2016

%% Flags.

FLAG_SCP = false;
FLAG_IMPORT_ALL_DATA = true;
FLAG_TIME_IS_X_AXIS = false;

FLAG_SET_FIG_POS = false;

FILENAME = 'pru-data.txt'

%%

if FLAG_SCP
    
    disp('Gonna try to secure-copy over the data file.')
    
    bb_path = ['root@10.42.0.122:/home/debian/BB_PRU_stuff/' ...
        'Integration-test/14-dead-zone/20161010/mpc-data-999.txt' ];
    
    bb_path = ['root@10.42.0.122:/home/debian/BB_PRU_stuff/' ...
        'Integration-test/14-dead-zone/Ts5_T20_L10_S5/mpc-data-999.txt' ];
    
    bb_path = ['root@10.42.0.122:/home/debian/BB_PRU_stuff/' ...
        'Integration-test/14-dead-zone/20161011/TS5_T20_L10_S5/mpc-data-999.txt' ];
    
    bb_path = ['root@10.42.0.122:/home/debian/BB_PRU_stuff/' ...
        'Integration-test/14-dead-zone/20161010_/Ts5_T20_L10_S5/mpc-data-999.txt' ];
    
    bb_path = ['root@10.42.0.122:/home/debian/BB_PRU_stuff/' ...
        'Integration-test/14-dead-zone/20161010_/Ts5_T20_L10_S5/mpc-data.txt' ];
    
    bb_path = ['root@10.42.0.122:/home/debian/BB_PRU_stuff/' ...
        'Integration-test/14-dead-zone/20161011/zoh/mpc-data.txt' ];
    
    scp_matlab_script = './scp-matlab.sh';
    
    disp(['Using script ' scp_matlab_script ' to import file: ' bb_path ' ...'])
    
    system([scp_matlab_script ' ' bb_path ' .'])
    
end

%%
if FLAG_IMPORT_ALL_DATA
    
    disp(['Gonna import ' FILENAME ' into like 1000 variables.'])
    
    % Matlab's auto-gen'd import script can't handle >1000 cols
    % good old-fashioned importing: make a variable for each column
    d = importdata(FILENAME);
    for i=1:length(d.colheaders)
        cmd = [d.colheaders{i} ' = d.data(:,' num2str(i) ');'];
        eval(cmd);
    end
    
    clear d cmd
    disp('Done importing mpc-data.txt.')
end

%% Plot angle and voltage

% figure(1); clf;
% h(1) = subplot(2,1,1)
% if FLAG_TIME_IS_X_AXIS
%     plot(t9, angle31,'k.-'); hold on;
%     plot(t10, ref0,'r.-');
%     xlabel('sec')
% else
%     plot(angle31,'k.-'); hold on;
%     plot(ref0,'r.-');
%     xlabel('index')
% end
% legend('angle','ref')
% 
% % ylim([-1.5*max(ref_0),1.5*max(ref_0)])
% title('angle (rad) & volts (V)')
% ylabel('angle31')
% % line(xlim, 2*[pi pi]);
% % line(xlim, -2*[pi pi]);
% grid minor
% h(2) = subplot(2,1,2);
% 
% if FLAG_TIME_IS_X_AXIS
%     plot(t9,volts31,'r.-')
%     xlabel('sec')
% else
%     plot(volts31,'r.-')
%     xlabel('index')
% end
% % ylim([-6,6])
% ylabel('volts31')
% linkaxes(h,'x')
% grid minor
% if FLAG_SET_FIG_POS
%     set(gcf,'position',[ 1945          64        1841        1000])
% end

%% Time vector -- did the time increase reasonably?

% if exist('t9','var')
% figure(3); clf;
% plot(t9,1:length(t9),'k.-')
% ylabel('iter')
% xlabel('t9 (sec)')
% title('time vector - time of each start of iteration')
% else
%     disp('no t9 var!')
% end

%% PRU Cycle count
figure(1); clf;
h(1) = subplot(2,1,1);
plot(cycle_count31,'k.-')
title('PRU cycle counter')
ylabel('cycle count')
xlabel('index')
h(2) = subplot(2,1,2)
PRUTICKS_PER_SEC = 200e6;
plot(cycle_count31/PRUTICKS_PER_SEC,'k.-')
ylabel('cycle count * (ticks/sec)')
linkaxes(h,'x')

%% PRU Cycle count at each iteration
figure(5); clf;
plot(cycle_count31,1:length(cycle_count31),'k.-')
xlabel('cycle count (1 cc = 5ns)')
ylabel('CPU loop iteration')
title('PRU cycle-counts at times when CPU asked for data (top of CPU loop)')

%% Optimization variables: noise, disturbance, status, solver-time
% if exist('optNoise_10','var')
% figure(2); clf
% h(1) = subplot(3,1,1);
% plot(optNoise_10,'k.-')
% title('noise 10')
% h(2) = subplot(3,1,2)
% plot(optD_10,'k.-')
% title('disturbance 10')
% h(3) = subplot(3,1,3);
% plot(status_0,'k.-'); hold on;
% plot(time_0,'r.-');
% title('status (k) time (r)');
% linkaxes(h,'x')
% if FLAG_SET_FIG_POS 
%     set(gcf,'position',[ 1927          17         911        1077]);
% end
% else 
%     disp('no var optNoise_10!')
% end

%%

% if exist('optD_5','var')
% figure(2); clf
% h(1) = subplot(3,1,1);
% plot(optNoise_5,'k.-')
% title('noise 5')
% h(2) = subplot(3,1,2)
% plot(optD_5,'k.-')
% title('disturbance 5')
% h(3) = subplot(3,1,3);
% plot(status_0,'k.-'); hold on;
% plot(time_0,'r.-');
% title('status (k) time (r)');
% linkaxes(h,'x')
% if FLAG_SET_FIG_POS 
%     set(gcf,'position',[ 1927          17         911        1077]);
% end
% end

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Plot Timing stuff
figure(4); clf;


%% Set axes.
axis([min(cycle_count0) max(cycle_count31) 0 5])
grid minor
grid
hold on


%% Theoretical sample times.
TICKS_PER_SAMPLE = 1e6; % NOTE: This must match the sample time in jpp-pru-lib.hp.
for i=0:99
    x=i*TICKS_PER_SAMPLE;
    text(x, 2.5, num2str(i),'color','k');
    line([x,x],[-1,5],'color','k');
    hold on
end


%% Data buffer request rx'd at PRU at these times
for i=1:length(data_req_time31)
    plot(data_req_time31(i),2,'k.','markersize',12);
    text(data_req_time31(i),2,{'D:',
        [num2str(sample_num31(i)) ':' num2str(volts31(i),2)],
        [num2str(sample_num30(i)) ':' num2str(volts30(i),2)],
        [num2str(sample_num29(i)) ':' num2str(volts29(i),2)],
        [num2str(sample_num28(i)) ':' num2str(volts28(i),2)],
        })
end


%% Cmd buffer rx'd at PRU at these times
for i=1:length(rxcmd_sch_rx_time0)
    plot(rxcmd_sch_rx_time0(i),3,'k.','markersize',12); hold on
    text(rxcmd_sch_rx_time0(i), 3, {
        'Crx:',
        [num2str(rxcmd_sample_num0(i)) ':' num2str(rxcmd_volts0(i),2)],
        [num2str(rxcmd_sample_num1(i)) ':' num2str(rxcmd_volts1(i),2)],
        [num2str(rxcmd_sample_num2(i)) ':' num2str(rxcmd_volts2(i),2)],
        [num2str(rxcmd_sample_num3(i)) ':' num2str(rxcmd_volts3(i),2)]
        });
end

%% Line from "when CPU rx'd data" to "when PRU rx'd cmd buffer based on that data"
for i=1:length(data_req_time31)-1
    line([data_req_time31(i), rxcmd_sch_rx_time0(i+1)],[2,3],'color','r');
end


%% Get unique values of angle & voltage.