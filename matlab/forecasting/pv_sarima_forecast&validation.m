
clc; clear; close all;

%% ── SECTION 1 : Load Historical 8-Day Window ────────────────────
fprintf('=== STEP 1: Loading 8-day historical window ===\n');

CSV_FILE = 'kathmandu_8day_window.csv';

opts = detectImportOptions(CSV_FILE);
opts = setvaropts(opts, 'Timestamp', 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
rawTbl = readtable(CSV_FILE, opts);
data = table2timetable(rawTbl);

% Confirm we have 8 days of hourly data = 192 rows
fprintf('Loaded %d rows from %s to %s\n', height(data), ...
    char(data.Timestamp(1)), char(data.Timestamp(end)));

% Sampling interval (hourly data)
interval_min = 60;          % 60 minutes between samples
S            = 24;          % 24 hourly samples per day
horizon      = 24;          % forecast 24 hours = 1 day

%% ── SECTION 2 : Split into Training (7 days) and Test (1 day) ──
fprintf('\n=== STEP 2: Splitting data ===\n');

n_train = 7 * S;            % 168 rows = days 1-7
trainData = data(1:n_train, :);
testData  = data(n_train+1:end, :);

fprintf('Training set: %d rows (%s to %s)\n', height(trainData), ...
    char(trainData.Timestamp(1)), char(trainData.Timestamp(end)));
fprintf('Test set    : %d rows (%s to %s)\n', height(testData), ...
    char(testData.Timestamp(1)), char(testData.Timestamp(end)));

%% ── SECTION 3 : Stability Fix (nighttime zeros) ─────────────────
fprintf('\n=== STEP 3: Stability fix ===\n');

rng(42); % reproducibility
trainData.Irradiance  = trainData.Irradiance  + 1e-6 * randn(height(trainData), 1);
trainData.Temperature = trainData.Temperature + 1e-6 * randn(height(trainData), 1);

trainData.Irradiance(trainData.Irradiance < 0) = 0;

%% ── SECTION 4 : Define & Train SARIMA Model ─────────────────────
fprintf('\n=== STEP 4: Defining SARIMA(1,1,1)(1,1,1)[24] model ===\n');

% Hourly data → S=24 (24 samples per day)
% AR(1) + I(1) + MA(1) at non-seasonal level
% Seasonal AR(1) + I(1) + MA(1) at lag-24
Mdl = arima('ARLags',       1,  ...
            'D',            1,  ...
            'MALags',       1,  ...
            'Constant',     0,  ...
            'Seasonality',  S,  ...
            'SARLags',      S,  ...
            'SMALags',      S);

fprintf('\n=== STEP 5: Training models on Days 1-7 (1-3 minutes) ===\n');

fprintf('  Training Irradiance model...\n');
estIrr  = estimate(Mdl, trainData.Irradiance, 'Display','off');
fprintf('  Done.\n');

fprintf('  Training Temperature model...\n');
estTemp = estimate(Mdl, trainData.Temperature, 'Display','off');
fprintf('  Done.\n');

%% ── SECTION 6 : Forecast Day 8 ──────────────────────────────────
fprintf('\n=== STEP 6: Forecasting Day 8 ===\n');

[irrF,  irrMSE]  = forecast(estIrr,  horizon, 'Y0', trainData.Irradiance);
[tempF, tempMSE] = forecast(estTemp, horizon, 'Y0', trainData.Temperature);

% Physical constraint
irrF(irrF < 0) = 0;

% 95 % confidence intervals
irrCI_upper = irrF  + 1.96 * sqrt(irrMSE);
irrCI_lower = max(irrF - 1.96 * sqrt(irrMSE), 0);

% Forecast timestamps
tForecast = trainData.Timestamp(end) + hours(1:horizon);
tForecast = tForecast(:);

fprintf('Forecast range: %s to %s\n', ...
    char(tForecast(1)), char(tForecast(end)));
fprintf('Peak forecasted irradiance : %.1f W/m^2\n', max(irrF));
fprintf('Peak actual    irradiance  : %.1f W/m^2\n', max(testData.Irradiance));

%% ── SECTION 7 : Compute Validation Metrics ──────────────────────
fprintf('\n=== STEP 7: Forecast Accuracy Metrics ===\n');

actualIrr  = testData.Irradiance;
actualTemp = testData.Temperature;

% Irradiance metrics
err_i = irrF - actualIrr;
rmse_i = sqrt(mean(err_i.^2));
mae_i  = mean(abs(err_i));
% Avoid div-by-zero for nighttime (use only daytime, irr > 5)
day_mask = actualIrr > 5;
mape_i = mean(abs(err_i(day_mask) ./ actualIrr(day_mask))) * 100;
r_i = corrcoef(actualIrr, irrF); r_i = r_i(1,2);
R2_i = r_i^2;

% Temperature metrics
err_t = tempF - actualTemp;
rmse_t = sqrt(mean(err_t.^2));
mae_t  = mean(abs(err_t));
mape_t = mean(abs(err_t ./ actualTemp)) * 100;
r_t = corrcoef(actualTemp, tempF); r_t = r_t(1,2);
R2_t = r_t^2;

fprintf('\n┌─────────────────────────────────────────────┐\n');
fprintf('│  IRRADIANCE FORECAST METRICS                │\n');
fprintf('├─────────────────────────────────────────────┤\n');
fprintf('│  RMSE       : %7.2f W/m^2                  │\n', rmse_i);
fprintf('│  MAE        : %7.2f W/m^2                  │\n', mae_i);
fprintf('│  MAPE (day) : %7.2f %%                       │\n', mape_i);
fprintf('│  R^2        : %7.4f                          │\n', R2_i);
fprintf('└─────────────────────────────────────────────┘\n');

fprintf('\n┌─────────────────────────────────────────────┐\n');
fprintf('│  TEMPERATURE FORECAST METRICS               │\n');
fprintf('├─────────────────────────────────────────────┤\n');
fprintf('│  RMSE       : %7.2f °C                      │\n', rmse_t);
fprintf('│  MAE        : %7.2f °C                      │\n', mae_t);
fprintf('│  MAPE       : %7.2f %%                       │\n', mape_t);
fprintf('│  R^2        : %7.4f                          │\n', R2_t);
fprintf('└─────────────────────────────────────────────┘\n');

%% ── SECTION 8 : Save Results CSV ────────────────────────────────
fprintf('\n=== STEP 8: Saving results ===\n');

resultsTbl = table(tForecast, ...
                   actualIrr, irrF, irrCI_lower, irrCI_upper, ...
                   actualTemp, tempF, ...
                   'VariableNames', { ...
                       'Timestamp', ...
                       'Actual_Irradiance', 'Forecast_Irradiance', ...
                       'CI_Lower', 'CI_Upper', ...
                       'Actual_Temperature', 'Forecast_Temperature'});

writetable(resultsTbl, 'forecast_vs_actual_day8.csv');
fprintf('Saved: forecast_vs_actual_day8.csv\n');

% Save metrics table
metricsTbl = table( ...
    {'RMSE';'MAE';'MAPE';'R^2'}, ...
    [rmse_i; mae_i; mape_i; R2_i], ...
    [rmse_t; mae_t; mape_t; R2_t], ...
    'VariableNames', {'Metric','Irradiance','Temperature'});
writetable(metricsTbl, 'forecast_metrics.csv');
fprintf('Saved: forecast_metrics.csv\n');

%% ── SECTION 9 : Plots ────────────────────────────────────────────
fprintf('\n=== STEP 9: Generating plots ===\n');

figure('Color','w','Position',[80 80 1100 850]);

% ── Plot 1: Irradiance — full 8 days with forecast overlay ────
subplot(3,1,1);
plot(trainData.Timestamp, trainData.Irradiance, ...
     'Color', [0.55 0.55 0.55], 'LineWidth', 1.2); hold on;
plot(testData.Timestamp,  actualIrr, ...
     'Color', [0.10 0.45 0.85], 'LineWidth', 2);
plot(tForecast, irrF, ...
     'Color', [0.85 0.20 0.10], 'LineWidth', 2, 'LineStyle', '--');
fill([tForecast; flipud(tForecast)], ...
     [irrCI_upper; flipud(irrCI_lower)], ...
     [0.85 0.20 0.10], 'FaceAlpha', 0.15, 'EdgeColor','none');
xline(trainData.Timestamp(end), '--k','Forecast Start','LabelHorizontalAlignment','right','FontSize',8);
title('Irradiance — Training (Days 1-7) + Day 8 Forecast vs Actual','FontSize',11);
ylabel('GHI (W/m^2)'); grid on;
legend('Training (Days 1-7)','Actual Day 8','Forecasted Day 8','95% CI', ...
       'Location','northwest','FontSize',8);

% ── Plot 2: Temperature ───────────────────────────────────────
subplot(3,1,2);
plot(trainData.Timestamp, trainData.Temperature, ...
     'Color', [0.55 0.55 0.55], 'LineWidth', 1.2); hold on;
plot(testData.Timestamp,  actualTemp, ...
     'Color', [0.10 0.45 0.85], 'LineWidth', 2);
plot(tForecast, tempF, ...
     'Color', [0.85 0.20 0.10], 'LineWidth', 2, 'LineStyle', '--');
xline(trainData.Timestamp(end), '--k','Forecast Start','LabelHorizontalAlignment','right','FontSize',8);
title('Temperature — Training (Days 1-7) + Day 8 Forecast vs Actual','FontSize',11);
ylabel('°C'); grid on;
legend('Training (Days 1-7)','Actual Day 8','Forecasted Day 8','Location','northwest','FontSize',8);

% ── Plot 3: Day 8 zoom — direct forecast vs actual comparison ─
subplot(3,1,3);
yyaxis left;
plot(testData.Timestamp,  actualIrr, '-o','Color',[0.10 0.45 0.85], ...
     'LineWidth',2,'MarkerSize',4); hold on;
plot(tForecast, irrF, '--s','Color',[0.85 0.20 0.10], ...
     'LineWidth',2,'MarkerSize',4);
ylabel('Irradiance (W/m^2)');

yyaxis right;
plot(testData.Timestamp,  actualTemp, '-^','Color',[0.10 0.65 0.30], ...
     'LineWidth',1.2,'MarkerSize',4);
plot(tForecast, tempF, '--v','Color',[0.85 0.55 0.10], ...
     'LineWidth',1.2,'MarkerSize',4);
ylabel('Temperature (°C)');

title(sprintf('Day 8 Zoom — Actual vs Forecast | Irr R^2 = %.3f, Temp R^2 = %.3f', R2_i, R2_t), ...
      'FontSize',11);
xlabel('Hour of Day'); grid on;
legend('Actual Irr','Forecast Irr','Actual Temp','Forecast Temp', ...
       'Location','northwest','FontSize',8);

sgtitle('PV Digital Twin — ARIMA Forecast Validation (Hourly, Kathmandu)', ...
        'FontSize', 13, 'FontWeight', 'bold');

saveas(gcf, 'forecast_validation.png');
fprintf('Plot saved: forecast_validation.png\n');

%% ── DONE ─────────────────────────────────────────────────────────
fprintf('\n========================================\n');
fprintf('  ALL DONE. Files generated:\n');
fprintf('    forecast_vs_actual_day8.csv\n');
fprintf('    forecast_metrics.csv\n');
fprintf('    forecast_validation.png\n');
fprintf('========================================\n');
fprintf('\nNext step: Feed forecast_vs_actual_day8.csv into your\n');
fprintf('Simulink model to get the final POWER forecast for Day 8.\n');
