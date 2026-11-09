function pv_curve_sweep(k, modeldir, jobfile, outfile, stopT)
% Measure the PV block's own P-V curve inside the final twin: MPPT is
% disabled (MPPT_On = 0) so the P&O holds V_ref at its initial value, which
% is set to each sweep voltage; the PV-voltage PI then holds V_pv there.
% jobs columns: G, T, V
base = fileparts(mfilename('fullpath'));
wd = fullfile(base, sprintf('sw%d', k)); if ~exist(wd,'dir'), mkdir(wd); end
d = dir(fullfile(modeldir,'*.slx')); [~,m] = fileparts(d(1).name);
copyfile(fullfile(modeldir, d(1).name), fullfile(wd, d(1).name)); cd(wd);
load_system(m);
add_block('simulink/Sinks/To Workspace',[m '/LgV'],'VariableName','vpv','SaveFormat','Array','Decimation','20');
add_line(m,'Bus Selector/1','LgV/1');
set_param([m '/MPPT_On'],'Value','0');
set_param([m '/NOCT_ON'],'Value','0');
J = readtable(jobfile);
fid = fopen(outfile,'w'); fprintf(fid,'G,T,Vset,P_avg,Vpv_avg\n');
for i = 1:height(J)
    set_param([m '/Constant'],'Value',num2str(J.G(i)));
    set_param([m '/Constant1'],'Value',num2str(J.T(i)));
    set_param([m '/MPPT ' newline 'Parameters/Iph_'],'Value',num2str(J.V(i)));
    so = sim(m,'StopTime',num2str(stopT));
    P = so.power_out; if isobject(P), P = P.Data; end
    pe = P(round(numel(P)*0.8):end); v = so.vpv; v = v(round(numel(v)*0.8):end);
    fprintf(fid,'%g,%g,%g,%.3f,%.3f\n', J.G(i), J.T(i), J.V(i), mean(pe), mean(v));
end
fclose(fid);
end
