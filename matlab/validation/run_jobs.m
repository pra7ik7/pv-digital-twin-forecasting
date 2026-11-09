function worker2(k, modeldir, jobfile, outfile, stopT)
% Run job list on the final twin. Each worker uses its own copy.
% jobs columns: set, idx, G, T, noct  (noct=1: T is ambient; 0: T is cell temp)
base = fileparts(mfilename('fullpath'));
wd = fullfile(base, sprintf('cw%d', k)); if ~exist(wd,'dir'), mkdir(wd); end
d = dir(fullfile(modeldir,'*.slx')); [~,m] = fileparts(d(1).name);
copyfile(fullfile(modeldir, d(1).name), fullfile(wd, d(1).name)); cd(wd);
load_system(m);
add_block('simulink/Sinks/To Workspace',[m '/LgV'],'VariableName','vpv','SaveFormat','Array','Decimation','20');
add_line(m,'Bus Selector/1','LgV/1');
add_block('simulink/Sinks/To Workspace',[m '/LgDC'],'VariableName','vdc','SaveFormat','Array','Decimation','20');
add_line(m,['Zero-Order' newline 'Hold/1'],'LgDC/1');
J = readtable(jobfile);
fid = fopen(outfile,'w'); fprintf(fid,'set,idx,G,T,noct,P_avg,P_min,P_max,Vpv_avg,Vdc_avg\n');
for i = 1:height(J)
    set_param([m '/Constant'],'Value',num2str(J.G(i)));
    set_param([m '/Constant1'],'Value',num2str(J.T(i)));
    set_param([m '/NOCT_ON'],'Value',num2str(J.noct(i)));
    so = sim(m,'StopTime',num2str(stopT));
    P = so.power_out; if isobject(P), P = P.Data; end
    n0 = max(1,round(numel(P)*0.8)); pe = P(n0:end);           % last 20 %
    v = so.vpv; v = v(round(numel(v)*0.8):end); dc = so.vdc; dc = dc(round(numel(dc)*0.8):end);
    fprintf(fid,'%s,%d,%g,%g,%d,%.3f,%.3f,%.3f,%.3f,%.3f\n', J.set{i}, J.idx(i), J.G(i), J.T(i), J.noct(i), ...
        mean(pe), min(pe), max(pe), mean(v), mean(dc));
end
fclose(fid);
end
