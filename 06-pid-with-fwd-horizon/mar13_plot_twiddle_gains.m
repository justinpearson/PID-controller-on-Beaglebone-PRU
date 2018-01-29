S = importdata('twiddle-data.txt');
kp = S(:,1);
ki = S(:,2);
kd = S(:,3);
er = S(:,4);



c = {kp, ki, kd, er};

for i=1:4
    figure(i); clf;
    plot(c{i});
end

%%

figure(99); clf;
for i=1:length(kp)
    plot3(kp,ki,kd)
end

%%
figure(50); clf;


colormap('jet')
cm = colormap;
norm_er = er/max(er);
ind_er = round(er * length(cm)/max(er));
colors = cm( round(er*length(cm)/max(er)), : );

for i=1:length(kp)
    
    plot3(kp(i),ki(i),kd(i),'.','markersize',20,'color',colors(i,:))
%     if i>1
%         daspect([1 1 1]) % needed for arrow3 error.
%         arrow3([kp(i-1),ki(i-1),kd(i-1)],[kp(i),ki(i),kd(i)])
%     end

    

    hold on
end
quiver3(kp(1:end-1),ki(1:end-1),kd(1:end-1),kp(2:end)-kp(1:end-1),ki(2:end)-ki(1:end-1),kd(2:end)-kd(1:end-1))
plot3(kp,ki,kd,':','linewidth',.2,'color',[.2,.2,.2])
text(kp,ki,kd-.00001,num2str(round(er)))
    xlabel('kp'); ylabel('ki'); zlabel('kd')
    shg
    
%%

center = [...
  0 0 0
  1 1 1
  2 1 1];

r = [1 1 0.5];
d = [1 0.5 0.3];

figure;
axes;
hold on;

[xu,yu,zu] = sphere;
for ii = 1:size(center)
  x = xu*r(ii) + center(ii,1);
  y = yu*r(ii) + center(ii,2);
  z = zu*r(ii) + center(ii,3);
  c = ones(size(z))*d(ii);
  surf(x,y,z,c);
end
view(3);
axis equal;
