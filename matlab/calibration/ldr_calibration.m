%% LDR Calibration — Power-Law Fit (G = a × V^b)
clc; clear; close all;

ldr_voltage = [1.867, 1.823, 1.437, 1.339, 1.281, 1.271, ...
               1.217, 1.197, 1.163, 1.149, 1.139, 1.114, ...
               1.134, 1.716, 1.686, 1.628, 1.554, ...
               1.745, 1.207, 1.461, 1.701];

mobile_irr  = [779, 699, 272, 215, 194, 160, ...
               156, 143, 142, 127, 127, 116, ...
               132, 528, 480, 536, 476, ...
               612, 165, 284, 469];

V = ldr_voltage(:);
G = mobile_irr(:);

% ── Power-law model: G = a * V^b ─────────────────────
power_law = @(p, V) p(1) * V.^p(2);    % p(1)=a, p(2)=b

p0 = [300, 0.6];                        % initial guess
opts = optimoptions('lsqcurvefit', 'Display', 'off');
p_fit = lsqcurvefit(power_law, p0, V, G, [], [], opts);
a = p_fit(1);
b = p_fit(2);

% ── Compute R² ───────────────────────────────────────
G_pred = power_law(p_fit, V);
ss_res = sum((G - G_pred).^2);
ss_tot = sum((G - mean(G)).^2);
R2     = 1 - ss_res/ss_tot;

fprintf('Fitted: G = %.2f * V^%.4f\n', a, b);
fprintf('R²    : %.4f\n', R2);
% ── Plot ─────────────────────────────────────────────
V_smooth = linspace(min(V), max(V), 200);
G_smooth = power_law(p_fit, V_smooth);

figure('Color','w','Position',[100 100 800 500]);
scatter(V, G, 70, 'MarkerFaceColor', '#1a73e8', ...
        'MarkerEdgeColor', '#1a73e8', 'LineWidth', 1.2); hold on;
plot(V_smooth, G_smooth, 'r-', 'LineWidth', 2);

xlabel('LDR Voltage (V)','FontSize',11);
ylabel('Reference Irradiance (W/m^2)','FontSize',11);
title('LDR Calibration Curve','FontSize',12,'FontWeight','bold');

legend({'Measured pairs', ...
        sprintf('Fit: G = %.1f  V^{%.3f}\nR^2 = %.3f', a, b, R2)}, ...
       'Location','southeast','FontSize',10);
grid on;
saveas(gcf, 'ldr_calibration.png');
