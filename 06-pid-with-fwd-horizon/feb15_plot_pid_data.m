clear all; close all; fclose all; clc

% S=importdata('data-pid.txt');
S=importdata('pid-data.txt');
for i=1:length(S.colheaders)
    cmd = [S.colheaders{i} '=S.data(:,' num2str(i) ');']
    eval(cmd);
end
    

% window_pos = [
% 
% [       -1079        1416         529         247],
% [        -549        1414         550         252],
% [       -1079        1082         529         247],
% [        -543        1083         529         247],
% [       -1079         768         529         247],
% [  -550   772   529   247],
% [       -1085         450         529         247],
% [-543   445   529   247],
% [       -1076         124         529         247],
% [-539   169   529   203],
% [       -1079        -147         529         247],
% [  -545  -147   529   247],
% 
% ];


window_pos = [
    
           1         600         522         374
         501         600         522         374
         909         600         522         374
        1392         600         522         374
           7          13         522         374
         496          22         522         374
        1004          22         522         374
        1399          19         522         374

];

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
plot(cputime,ref,'k.-')
hold on
plot(cputime,angle,'r.-')
xlabel('time (s)')
ylabel('shaft angle (deg)')
legend('ref','angle')