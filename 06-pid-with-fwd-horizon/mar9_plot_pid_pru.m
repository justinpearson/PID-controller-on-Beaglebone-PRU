clear all; close all; fclose all; clc

% FILENAME = 'data-sysfs-other-proc-nice-14.txt';
% FILENAME = 'data-pru2-other-proc-nice-0.txt';
% FILENAME = 'pid-fwd.txt';
% FILENAME = 'pid3-5-n.txt';
FILENAME = 'pid22-5-n.txt';
% FILENAME = 'data-sysfs-other-proc-nice-8.txt';
SEC_PER_SAMPLE = 5e-3; % 5 ms

%%
% system(['./hack.sh libreoffice --calc ' FILENAME])
%%
% !./hack.sh libreoffice --calc data-pru2-other-proc-nice-0.txt
%%
% S=importdata('data-pid.txt');
% S=importdata('pid-data.txt');
% S=importdata('pid-data-sleep-0p1sec.txt');

% S=importdata('pid-data-sleep-0.005sec-1.txt');
% S=importdata('pid-data-square-share-cpu.txt');
% S=importdata('pid-fwd.txt');

%  S=importdata('pid-pru-20ms-rw-err-cmdbuf-triangle.txt');
%   S=importdata('pid-sysfs-20ms-rw-err-triangle.txt');
  
% S=importdata('pid-sysfs-20ms-rw-err-triangle-2.txt');

% S=importdata('tmp.txt');
% S=importdata('data-pru-buf-other-proc-nice-10.txt');

% S = importdata('data-sysfs-other-proc-nice-13.txt');
S = importdata(FILENAME);


% S=importdata('pid-data-sin-share-cpu.txt');

for i=1:length(S.colheaders)
    cmd = [S.colheaders{i} '=S.data(:,' num2str(i) ');']
    eval(cmd);
end
   
%% shitty hack
cputime(1) = cputime(2);
cputimediff(1) = 0;

%%

% landscape
window_pos = [

[       -1079        1416         529         247],
[        -549        1414         550         252],
[       -1079        1082         529         247],
[        -543        1083         529         247],
[       -1079         768         529         247],
[  -550   772   529   247],
[       -1085         450         529         247],
[-543   445   529   247],
[       -1076         124         529         247],
[-539   169   529   203],
[       -1079        -147         529         247],
[  -545  -147   529   247],

];

% portrait 
% window_pos = [
%     
%            1         600         522         374
%          501         600         522         374
%          909         600         522         374
%         1392         600         522         374
%            7          13         522         374
%          496          22         522         374
%         1004          22         522         374
%         1399          19         522         374
% 
% ];

vars = {'cputime','cputimediff','ref','step','angle','v','sn'};


for i=1:length(vars)
    figure(i); clf;
    var = vars{i};
    cmd = ['plot(' var ',''k.-''); title(''' var ''')']
    eval(cmd)
    set(gcf,'position',window_pos(i,:))
end

%%
figure(50); clf;
plot(diff(sn),'k.-')
title('diff sn')


%%
figure(99); clf;
set(gcf,'position',[400   981   560   420])
h(1) = subplot(2,1,1)
% t = (1:length(ref))*SEC_PER_SAMPLE;
t = cputime;
plot(t,ref,'k.-')
hold on
plot(t,angle,'r.-')
% xlabel('sample num (5ms/iter)')
% xlabel('time (from sample num)')
xlabel('cputime (s)')
ylabel('shaft angle (deg)')
legend('ref','angle')
h(2) = subplot(2,1,2)
plot(cputime,cputimediff,'k.-')
xlabel('cputime (s)')
ylabel('cputimediff')
linkaxes(h,'x')
subplot(2,1,1)
title(FILENAME)