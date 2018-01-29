function pltfile(f)

vars={};
S=importdata(f);
for i=1:length(S.colheaders)
    vars{end+1} = S.colheaders{i};
    cmd = [S.colheaders{i} '=S.data(:,' num2str(i) ');']
    eval(cmd);
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


for i=1:length(vars)
    var = vars{i};
    if ~exist(var,'var')
        disp(['no var??: ' var])
        continue
    end
    figure(i); clf;
    cmd = ['plot(' var ',''k.-''); title(''' var ''',''interpreter'',''none'')']
    eval(cmd)
    ii = 1+mod(i-1,size(window_pos,1))
    set(gcf,'position',window_pos(ii,:))
end
