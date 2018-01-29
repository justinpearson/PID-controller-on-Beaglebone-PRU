figure(1); clf;
% set(gcf,'position',[400   981   560   420])
% set(gcf,'position',[ 1           1        1050        1601])
t = {};
r = {};
a = {};

for j=1:100
    disp('iter:')
    disp(j)
    
    
    S=importdata('pid-fwd-bak.txt');
    for i=1:length(S.colheaders)
        cmd = [S.colheaders{i} '=S.data(:,' num2str(i) ');'];
        eval(cmd);
    end
    
    t = cputime;
    r = ref;
    a = angle;
    
    if j==1
        plot(t,r);
        hold on;
    end
    
    plot(t,a); 
    
% %     plot(t{j},r{j},'k.-')
%     if j==1
%         hold on
%     end
%     plot(t{j},a{j})
% %     plot(t{j},a{j},'r.-')
%     if j==1
%         xlabel('time (s)')
%         ylabel('shaft angle (deg)')
%         legend('ref','angle')
%     end
%     
    title(['iter: ' num2str(j)])
    shg
    pause(4)
end