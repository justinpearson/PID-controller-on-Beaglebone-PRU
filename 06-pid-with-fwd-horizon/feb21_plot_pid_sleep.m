clear all; close all; fclose all; clc

FILENAME = 'data-sysfs-other-proc-nice-14.txt';

% FILENAME = 'data-pru-other-proc-nice-8.txt';
% FILENAME = 'data-pru3-nice-2.txt';

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

vars = {'cputime','cputimediff','ref','step','angle','v','error','pterm','ierror','iterm','derror','dterm'};


for i=1:length(vars)
    figure(i); clf;
    var = vars{i};
    cmd = ['plot(' var ',''k.-''); title(''' var ''')']
    eval(cmd)
    set(gcf,'position',window_pos(i,:))
end

%%
figure(99); clf;
set(gcf,'position',[400   981   560   420])
h(1) = subplot(2,1,1)
plot(cputime,ref,'k.-')
hold on
plot(cputime,angle,'r.-')
xlabel('time (s)')
ylabel('shaft angle (deg)')
legend('ref','angle')
h(2) = subplot(2,1,2)
plot(cputime,cputimediff,'k.-')
xlabel('time (s)')
ylabel('cputimediff')
linkaxes(h,'x')
subplot(2,1,1)
title(FILENAME)