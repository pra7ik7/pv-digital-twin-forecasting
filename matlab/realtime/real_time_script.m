%% ─────────────────────────────────────────────────────────────
%   REAL-TIME PV DIGITAL TWIN
%   Reads irradiance + temperature from Arduino → feeds Simulink
%   → reads power → logs and plots live
% ──────────────────────────────────────────────────────────────
clc; clear; close all;

% ── Configuration ─────────────────────────────────────────────
SERIAL_PORT  = 'COM6';                    % CHANGE to your Arduino port
BAUD_RATE    = 9600;
MODEL_NAME   = 'Grid_connected_single_phase_solar0x2DCopy';
SIM_TIME     = '0.5';                     % seconds — quick steady-state

IRR_BLOCK    = [MODEL_NAME '/Constant'];
TEMP_BLOCK   = [MODEL_NAME '/Constant1'];

DURATION_SEC = 300;                       % how long to run (5 minutes)
LOG_FILE     = 'realtime_log.csv';
PLOT_FILE    = 'realtime_demo.png';

% ── Open Arduino serial port ──────────────────────────────────
fprintf('Connecting to Arduino on %s...\n', SERIAL_PORT);
arduino = serialport(SERIAL_PORT, BAUD_RATE);
configureTerminator(arduino, "LF");
flush(arduino);
pause(2);                                 % let Arduino reset
fprintf('Connected.\n\n');

% ── Open Simulink model ───────────────────────────────────────
fprintf('Loading Simulink model...\n');
load_system(MODEL_NAME);
fprintf('Model ready.\n\n');

% ── Prepare logging ───────────────────────────────────────────
fid = fopen(LOG_FILE, 'w');
fprintf(fid, 'Timestamp,Irradiance_Wm2,Temperature_C,Power_W\n');

% ── Live plot setup (3 panels) ────────────────────────────────
fig = figure('Color','w','Position',[100 100 1000 700]);

subplot(3,1,1);
h_irr = animatedline('Color','#1a73e8','LineWidth',2);
ylabel('Irradiance (W/m^2)'); grid on;
title('Live Irradiance');

subplot(3,1,2);
h_temp = animatedline('Color','#0d8f47','LineWidth',2);
ylabel('Temperature (°C)'); grid on;
title('Live Temperature');

subplot(3,1,3);
h_pow = animatedline('Color','#e8460a','LineWidth',2);
ylabel('Power (W)'); xlabel('Time (s)'); grid on;
title('Live PV Power Output (Simulink Digital Twin)');

% ── Main real-time loop ──────────────────────────────────────
fprintf('Starting real-time monitoring...\n');
fprintf('Press Ctrl+C to stop early.\n\n');
fprintf('Time(s) | Irradiance | Temp(°C) | Power\n');
fprintf('───────────────────────────────────────\n');

t_start = tic;
sample_idx = 0;

try
    while toc(t_start) < DURATION_SEC
        % --- Read irradiance + temperature from Arduino --
        line   = readline(arduino);
        values = str2double(split(line, ","));
        
        if numel(values) < 2 || any(isnan(values))
            continue;          % skip bad readings
        end
        
        irr  = values(1);
        temp = values(2);
        
        if irr < 0, irr = 0; end
        
        % --- Update Simulink inputs ----------------------
        set_param(IRR_BLOCK,  'Value', num2str(irr));
        set_param(TEMP_BLOCK, 'Value', num2str(temp));
        
        % --- Run simulation ------------------------------
        simOut = sim(MODEL_NAME, 'StopTime', SIM_TIME);
        P_arr  = simOut.power_out;
        if isobject(P_arr), P_arr = P_arr.Data; end
        
        % Steady-state mean (last 10 % of samples)
        n_steady   = max(1, round(length(P_arr) * 0.9));
        power_now  = mean(P_arr(n_steady:end));
        if power_now < 0, power_now = 0; end
        
        % --- Log -----------------------------------------
        t_now = toc(t_start);
        sample_idx = sample_idx + 1;
        fprintf(fid, '%.1f,%.2f,%.2f,%.2f\n', t_now, irr, temp, power_now);
        fprintf('%6.1f  | %8.1f  | %7.2f | %7.2f\n', t_now, irr, temp, power_now);
        
        % --- Update plot ---------------------------------
        addpoints(h_irr,  t_now, irr);
        addpoints(h_temp, t_now, temp);
        addpoints(h_pow,  t_now, power_now);
        drawnow limitrate;
    end
catch err
    fprintf('\nLoop terminated: %s\n', err.message);
end

% ── Cleanup ───────────────────────────────────────────────────
fclose(fid);
clear arduino;
fprintf('\nLive monitoring complete. Log saved to: %s\n', LOG_FILE);
fprintf('Total samples recorded: %d\n', sample_idx);

% ── Generate final report-quality plot from CSV ───────────────
fprintf('\nGenerating final plot for report...\n');

data = readtable(LOG_FILE);

if height(data) < 2
    fprintf('Not enough samples to generate plot.\n');
else
    fig_final = figure('Color','w','Position',[100 100 900 800]);
    
    subplot(3,1,1);
    plot(data.Timestamp, data.Irradiance_Wm2, 'LineWidth', 2, 'Color', '#1a73e8');
    ylabel('Irradiance (W/m^2)'); 
    title('Live Irradiance from Calibrated LDR Sensor','FontSize',11);
    grid on; xlim([0 max(data.Timestamp)]);
    
    subplot(3,1,2);
    plot(data.Timestamp, data.Temperature_C, 'LineWidth', 2, 'Color', '#0d8f47');
    ylabel('Temperature (°C)'); 
    title('Live Ambient Temperature','FontSize',11);
    grid on; xlim([0 max(data.Timestamp)]);
    
    subplot(3,1,3);
    plot(data.Timestamp, data.Power_W, 'LineWidth', 2, 'Color', '#e8460a');
    xlabel('Time (s)'); ylabel('Power (W)');
    title('Simulated PV Power Output (Digital Twin)','FontSize',11);
    grid on; xlim([0 max(data.Timestamp)]);
    
    sgtitle('Real-Time PV Digital Twin Operation','FontSize',13,'FontWeight','bold');
    
    saveas(fig_final, PLOT_FILE);
    fprintf('Final plot saved to: %s\n', PLOT_FILE);
end

fprintf('\n========================================\n');
fprintf('  ALL DONE.\n');
fprintf('  Log file : %s\n', LOG_FILE);
fprintf('  Plot file: %s\n', PLOT_FILE);
fprintf('========================================\n');