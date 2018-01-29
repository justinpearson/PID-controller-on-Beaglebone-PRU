clear all; close all; fclose all; clc

% S=importdata('data-pid.txt');
FILENAME = 'pid-iir-sysfs10.txt'
S=importdata(FILENAME);

disp('header:')
disp(S.colheaders);

%%

for i=1:length(S.colheaders)
    cmd = [S.colheaders{i} '=S.data(:,' num2str(i) ');']
    eval(cmd);
end
    

% on 'portrait' monitor
if 1

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

else % landscape monitor
    

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

end


vars = {'cputime','cputimediff','ref','step','angle','v','error'};


for i=1:length(vars)
    figure(i); clf;
    var = vars{i};
    cmd = ['plot(' var ',''k.-''); title(''' var ''')']
    eval(cmd)
    set(gcf,'position',window_pos(i,:))
end

%%
figure(99); clf;
% set(gcf,'position',[400   981   560   420]) % right screen
% set(gcf,'position',[-589   -83   560   420])  % left screen
set(gcf,'position',[1           1        1920        1001]) % right screen, full
h(1) = subplot(3,1,1)
plot(cputime,ref,'k.-')
hold on
plot(cputime,angle,'r.-')
xlabel('cputime (s)')
ylabel('shaft angle (deg)')
legend('ref','angle')
title(FILENAME)
h(2) = subplot(3,1,2);
plot(cputime,error,'k.-')
xlabel('cputime (s)')
title('error (deg)')
h(3) = subplot(3,1,3);
plot(cputime,cputimediff,'k.-')
xlabel('cputime (s)')
title('cputimediff (s)')