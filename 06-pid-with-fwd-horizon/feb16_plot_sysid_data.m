clear all; close all; fclose all; clc

data_files = {
    'sq_8s_p1hz_15hz.txt',
'sq_8s_1hz_10hz.txt',
'ch_8s_p1hz_15hz.txt',
'ch_8s_1hz_10hz.txt'
}
% 
% for i=1:length(data_files)
%     f=data_files{i};
% pltfile(f)
% pause
% end
% 


%% Use ARX to fit a model
% ... imposing a structural integrator (pole at z=1)

S = importdata( 'sq_8s_p1hz_15hz.txt' )

u = S.data(:,5);  % input voltage
y = S.data(:,4); % output angle degrees
Ts = mean(S.data(:,3)) % average time btwn iterations

% trick: know the TF has an integrator (pole at z=1), so 
% id the u-to-ybar system and add in the pole later.
ybar = y(2:end)-1*y(1:end-1);
ubar = u(1:end-1);

data = iddata(ybar,ubar,Ts,'outputname','shaft angle','outputunit','deg','inputname','motor voltage','inputunit','V')
plot(data)

na = 2 % motor system has 3 poles in cts time sys, -1 bc one is an integrator
nk = 0 % delay
nb = na-nk+1

model=arx(data,[na,nb,nk])

compare(data,model)

sysdbar = tf(model,'measured')
z = tf('z',Ts);
sysd = sysdbar / (z-1)


%% Validate on other datasets
figure(50); clf;
j=0
for i=1:length(data_files)
    j=j+1;
    f = data_files{i}; S = importdata( f );
    u_val = S.data(:,5);  % input voltage
y_val = S.data(:,4); % output angle degrees
data_val = iddata(y_val,u_val,Ts,'outputname','shaft angle','outputunit','deg','inputname','motor voltage','inputunit','V')
% figure(10+i)
subplot(2,4,j); j=j+1;
compare(data_val,sysd)
title(['Simulated response comparision: ' f],'interpreter','none')


ybar_val = y_val(2:end)-1*y_val(1:end-1);
ubar_val = u_val(1:end-1);
databar_val = iddata(ybar_val,ubar_val,Ts,...
    'outputname','shaft angle','outputunit','deg',...
    'inputname','motor voltage','inputunit','V')
% figure(20+i)
subplot(2,4,j)
compare(databar_val,sysdbar)
title(['Simulated response comparison (bar system): ' f],'interpreter','none')

end

%%
% Looks pretty good.

%% NOTE:
% Could iterate using techniques from Joao's ECE 147C:
%
% - scale u and y so they're about the same size
% - downsample data to fight overfitting due to quantization error
% - look at model.Report.Fit to figure out if it's a good fit

%% Design PID controller

close all;
pidTuner(sysd,'PI') % when I did PID, I got a non-causal model.
% Error: 
% step(C/(1+G*C))
% Cannot simulate the time response of models with more zeros than poles. 


% C =
%  
%               Ts            z-1 
%   Kp + Ki * ------ + Kd * ------
%               z-1           Ts  
% 
%   with Kp = -0.0109, Ki = -0.0343, Kd = -0.00043, Ts = 0.00525
%  
% Sample time: 0.0052477 seconds
% Discrete-time PID controller in parallel form.


% workaround: do a PI ctrller

% C =
%  
%               Ts  
%   Kp + Ki * ------
%               z-1 
% 
%   with Kp = -0.00499, Ki = -0.0103, Ts = 0.00525
%  
% Sample time: 0.0052477 seconds
% Discrete-time PI controller in parallel form.


%% Closed-loop reference-tracking response
G = sysd;
k = 360; % output is in deg; conver to revs
figure(60); clf
step(k*G*C/(1+G*C))
title('reference tracking')
figure(61); clf;
step(k*C/(1+G*C))
title('control effort')

% We see that the controller uses a couple volts to drive the angle to 1
% rev.

%%


return

tests={'chirp','rails'};
types={'test','train'};
for itest=1:length(tests)
    for itype=1:length(types)
    test=tests{itest};
    type=types{itype};
    S=importdata(['data_sysid_' test '_' type '.txt']);
    for i=1:length(S.colheaders)
        cmd = [S.colheaders{i} '_' test '_' type '=S.data(:,' num2str(i) ');']
        eval(cmd);
    end
    end
end
   

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
[-539   124   529   248],
[       -1079        -147         529         247],
[  -545  -147   529   247],

];

basevars = {'cputime','cputimediff','step','angle','v'};
vars = {};
for i=1:length(basevars)
    vars{end+1} = [basevars{i} '_chirp_test'];
    vars{end+1} = [basevars{i} '_rails_test'];
end
% vars ={'cputime_chirp','cputime_rails','cputimediff_chirp','cputimediff_rails','step_chirp','step_rails','angle_chirp','angle_rails','v_chirp','v_rails'};

for i=1:length(vars)
    var = vars{i};
    if ~exist(var,'var')
        disp(['no var: ' var])
        continue
    end
    figure(i); clf;
    cmd = ['plot(' var ',''k.-''); title(''' var ''',''interpreter'',''none'')']
    eval(cmd)
    set(gcf,'position',window_pos(i,:))
end



%% Run sysid app

