clear all; close all; fclose all; clc

vars = {};

if 0 % single file
    
    % S=importdata('data-pid.txt');
    FILENAME = 'pid-iir-sysfs10.txt'
    S=importdata(FILENAME);
    
    disp('header:')
    disp(S.colheaders);
    
    for i=1:length(S.colheaders)
        cmd = [S.colheaders{i} '=S.data(:,' num2str(i) ');']
        eval(cmd);
    end
    
else % multiple files
    
    FILES = {'pid-iir-pru-prusubset-n7.txt','pid-iir-pru-dat-n7.txt'};
    for k=1:length(FILES)
        FILENAME = FILES{k};
        S=importdata(FILENAME);
        
        for i=1:length(S.colheaders)
            varname = S.colheaders{i};
            vars{end+1} = varname;
            cmd = [varname '=S.data(:,' num2str(i) ');']
            eval(cmd);
        end
        
        
    end
end

%%
cputimediff_cpu(1) = 0;


%%
for i=1:length(vars)
    figure(i)
    var = vars{i};
    cmd = ['plot(' var ',''k.-'')'];
    eval(cmd)
    title(var,'interpreter','none')
end


%%

% 
% % on 'portrait' monitor
% if 1
% 
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
% 
% else % landscape monitor
%     
% 
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
% 
% end
% 
% 
% vars = {'cputime','cputimediff','ref','step','angle','v','error'};
% 
% 
% for i=1:length(vars)
%     figure(i); clf;
%     var = vars{i};
%     cmd = ['plot(' var ',''k.-''); title(''' var ''')']
%     eval(cmd)
%     set(gcf,'position',window_pos(i,:))
% end

%%
% 
% figure(99); clf;
% % set(gcf,'position',[400   981   560   420]) % right screen
% % set(gcf,'position',[-589   -83   560   420])  % left screen
% % set(gcf,'position',[1           1        1920        1001]) % right screen, full
% h(1) = subplot(3,1,1)
% plot(cputime,ref,'k.-')
% hold on
% plot(cputime,angle,'r.-')
% xlabel('cputime (s)')
% ylabel('shaft angle (deg)')
% legend('ref','angle')
% title(FILENAME)
% h(2) = subplot(3,1,2);
% plot(cputime,error,'k.-')
% xlabel('cputime (s)')
% title('error (deg)')
% h(3) = subplot(3,1,3);
% plot(cputime,cputimediff,'k.-')
% xlabel('cputime (s)')
% title('cputimediff (s)')

figure(99); clf;
plot(refs_pru,'k.-'); hold on;
plot(angle_pru,'r.-');
plot(v_pru*100,'b.-');
xlabel('index')
title({'pru vals',FILENAME})
legend('ref','angle','v*100')

%%
figure(98); clf;
plot(errors_pru,'k.-'); hold on;
plot(v_pru*100,'r.-')
xlabel('idx')
legend('errors','v*100')
title({'pru vals',FILENAME})


%%
figure(97); clf;
h(1) = subplot(2,1,1);
plot(cputime_cpu,ref_cpu,'k.-'); hold on;
plot(cputime_cpu,angle_cpu,'r.-');
title(FILENAME)
legend('ref','angle')
xlabel('cputime (s)')
h(2) = subplot(2,1,2);
plot(cputime_cpu,cputimediff_cpu,'k.-')
title('cputime diff')
linkaxes(h,'x')


%% arrange figures nicely

distFig('Screen','External'); % https://www.mathworks.com/matlabcentral/fileexchange/37176-distribute-figures
