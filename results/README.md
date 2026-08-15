# Results

This directory summarizes the main quantitative results obtained from
the PV digital twin, irradiance sensor calibration, forecasting
analysis, and real-time demonstration.

## Digital Twin Validation

Using site-specific LDR-based irradiance measurements:

- Pearson correlation: r = 0.918
- R² = 0.843
- RMSE = 34.76 W
- MAE = 30.38 W

Using satellite-derived irradiance:

- Pearson correlation: r = 0.703
- R² = 0.494
- RMSE = 114.23 W
- MAE = 100.11 W

## LDR Calibration

The nonlinear irradiance calibration achieved:

- R² = 0.974

## SARIMA Forecasting

Irradiance forecasting:

- R² = 0.921
- RMSE = 76.30 W/m²
- MAE = 34.69 W/m²

Temperature forecasting:

- R² = 0.964
- RMSE = 1.30 °C
- MAE = 1.06 °C

## End-to-End PV Power Forecast

For the selected validation day:

- Forecast daily energy: 1193 Wh
- Reference daily energy: 1199 Wh
- Daily energy error: -0.50%
- Power-profile R²: 0.858
- Power RMSE: 30.09 W
- Power MAE: 12.43 W

Detailed methodology and results are provided in the project report.
