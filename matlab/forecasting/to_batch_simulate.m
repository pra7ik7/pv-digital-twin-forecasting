%% Batch PV Simulation — runs FORECAST and ACTUAL inputs in one pass
clc; clear;

% ── Configuration ─────────────────────────────────────
INPUT_CSV   = 'forecast_vs_actual_day8.csv';
OUTPUT_CSV  = 'day8_power_comparison.csv';

% Column names in the input CSV
FORECAST_IRR_COL  = 'Forecast_Irradiance';
FORECAST_TEMP_COL = 'Forecast_Temperature';
ACTUAL_IRR_COL    = 'Actual_Irradiance';
ACTUAL_TEMP_COL   = 'Actual_Temperature';

SIM_TIME    = '2';
MODEL_NAME  = 'Grid_connected_single_phase_solar0x2DCopy';

% Block paths — CHANGE if your block names differ
IRR_BLOCK   = [MODEL_NAME '/Constant'];
TEMP_BLOCK  = [MODEL_NAME '/Constant1'];

% ── Load data ────────────────────────────────────────
T = readtable(INPUT_CSV);
fprintf('Loaded %d rows from %s\n\n', height(T), INPUT_CSV);

n = height(T);

% ── Open model ───────────────────────────────────────
load_system(MODEL_NAME);

% ── Helper function: run one simulation case ─────────
function P_steady = simulate_one_case(G, Tc, IRR_BLOCK, TEMP_BLOCK, MODEL_NAME, SIM_TIME)
    if G < 1
        P_steady = 0;
        return;
    end
    set_param(IRR_BLOCK,  'Value', num2str(G));
    set_param(TEMP_BLOCK, 'Value', num2str(Tc));
    simOut = sim(MODEL_NAME, 'StopTime', SIM_TIME);
    P = simOut.power_out;
    if isobject(P), P = P.Data; end
    n_steady = max(1, round(length(P) * 0.9));
    P_steady = mean(P(n_steady:end));
end

% ── Run both passes ──────────────────────────────────
sim_forecast = zeros(n, 1);
sim_actual   = zeros(n, 1);

fprintf('Running batch simulation (forecast + actual)...\n');
fprintf('─────────────────────────────────────────────────────────────────\n');
fprintf('Row | Forecast G | Sim_F (W)  || Actual G  | Sim_A (W)\n');
fprintf('─────────────────────────────────────────────────────────────────\n');

for i = 1:n
    % Forecast inputs
    G_f  = T.(FORECAST_IRR_COL)(i);
    T_f  = T.(FORECAST_TEMP_COL)(i);
    sim_forecast(i) = simulate_one_case(G_f, T_f, IRR_BLOCK, TEMP_BLOCK, MODEL_NAME, SIM_TIME);
    
    % Actual inputs
    G_a  = T.(ACTUAL_IRR_COL)(i);
    T_a  = T.(ACTUAL_TEMP_COL)(i);
    sim_actual(i) = simulate_one_case(G_a, T_a, IRR_BLOCK, TEMP_BLOCK, MODEL_NAME, SIM_TIME);
    
    fprintf('%3d | %7.1f W/m² | %7.2f   || %7.1f W/m² | %7.2f\n', ...
            i, G_f, sim_forecast(i), G_a, sim_actual(i));
end

% ── Save results ─────────────────────────────────────
T.Sim_Power_Forecast = round(sim_forecast, 2);
T.Sim_Power_Actual   = round(sim_actual,   2);

writetable(T, OUTPUT_CSV);

fprintf('\n─────────────────────────────────────────────────────────────────\n');
fprintf('DONE. Output saved to: %s\n', OUTPUT_CSV);

% ── Comparison metrics: Sim_Power_Forecast vs Sim_Power_Actual ─
err = T.Sim_Power_Forecast - T.Sim_Power_Actual;
day_mask = T.Sim_Power_Actual > 5;   % daytime only for MAPE

rmse = sqrt(mean(err.^2));
mae  = mean(abs(err));
mbe  = mean(err);
mape = mean(abs(err(day_mask) ./ T.Sim_Power_Actual(day_mask))) * 100;
r    = corrcoef(T.Sim_Power_Forecast, T.Sim_Power_Actual);
R2   = r(1,2)^2;

fprintf('\n┌───────────────────────────────────────────────────────────┐\n');
fprintf('│  END-TO-END FORECAST PIPELINE METRICS                     │\n');
fprintf('│  (Forecast-driven Sim power  vs  Actual-driven Sim power) │\n');
fprintf('├───────────────────────────────────────────────────────────┤\n');
fprintf('│  RMSE              : %7.2f W                             │\n', rmse);
fprintf('│  MAE               : %7.2f W                             │\n', mae);
fprintf('│  Mean Bias (MBE)   : %+7.2f W                             │\n', mbe);
fprintf('│  MAPE (daytime)    : %7.2f %%                             │\n', mape);
fprintf('│  R²                : %7.4f                                │\n', R2);
fprintf('└───────────────────────────────────────────────────────────┘\n');