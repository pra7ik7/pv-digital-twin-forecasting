# PV Digital Twin for Real-Time Monitoring and Short-Term Forecasting

MATLAB/Simulink implementation of a physics-based digital twin for a 335 W grid-connected photovoltaic (PV) system, integrating site-specific irradiance sensing, SARIMA-based short-term forecasting, and real-time sensor-to-model operation.

## Overview

This project develops a digital twin of a grid-connected photovoltaic system installed at the Department of Electrical Engineering, Pulchowk Campus, Institute of Engineering, Nepal.

The framework integrates:

* Physics-based PV system modeling in MATLAB/Simulink
* DC-DC boost converter and Perturb & Observe (P&O) MPPT
* Single-phase grid-tied inverter
* Site-specific irradiance measurement using an Arduino/LDR sensor
* SARIMA forecasting of irradiance and ambient temperature
* Forecast-driven PV power prediction
* Real-time sensor-to-Simulink model operation

## System Architecture

The developed framework consists of three interconnected layers.

### Physical Layer

The physical layer consists of the installed PV system and the associated measurements:

**PV system → irradiance / temperature / power measurements**

The experimental system uses a 335 W RenewSys DESERV 3M6H-335 PV module installed at the Department of Electrical Engineering, Pulchowk Campus.

### Virtual Layer

The virtual layer is implemented in MATLAB/Simulink and represents the electrical behavior of the physical PV system.

It includes:

* Single-diode PV model
* DC-DC boost converter
* Perturb & Observe MPPT
* Single-phase voltage-source inverter
* Output filter
* Grid representation

### Data and Forecasting Layer

Historical meteorological data are processed using SARIMA models to forecast environmental variables.

**Historical meteorological data → SARIMA forecasting → forecasted irradiance and temperature → Simulink digital twin → predicted PV power**

## PV Digital Twin

The PV system was modeled in MATLAB/Simulink using a physics-based representation of the physical 335 W PV module.

The model was parameterized from the module's electrical specifications and includes the main conversion and control stages required for grid-connected operation.

Under Standard Test Conditions, the simulated PV output was approximately 335 W, consistent with the rated module power.

## Experimental Validation

The digital twin was validated against measurements from the physical PV system over two observation days representing different irradiance conditions.

Using site-specific irradiance measurements, the combined validation results were:

| Metric                 | LDR-Based Irradiance |
| ---------------------- | -------------------: |
| RMSE                   |              34.76 W |
| MAE                    |              30.38 W |
| MAPE                   |               24.58% |
| Mean Bias              |             -12.41 W |
| Pearson correlation, r |                0.918 |
| R²                     |                0.843 |

For comparison, the simulation using satellite-derived irradiance produced:

| Metric                 | Satellite-Derived Irradiance |
| ---------------------- | ---------------------------: |
| RMSE                   |                     114.23 W |
| MAE                    |                     100.11 W |
| MAPE                   |                       78.73% |
| Mean Bias              |                     +97.07 W |
| Pearson correlation, r |                        0.703 |
| R²                     |                        0.494 |

The site-specific irradiance input therefore produced substantially better agreement with the measured PV power than the satellite-derived irradiance input.

## Irradiance Sensor

A low-cost irradiance sensing system was developed using an LDR, resistor, and Arduino Uno.

The LDR was configured as a voltage-divider circuit and its output voltage was mapped to irradiance using a nonlinear power-law calibration model:

[
G = aV^b
]

A total of 21 paired voltage-irradiance measurements were used for calibration over an approximate range of 116-779 W/m².

The resulting calibration achieved:

**R² = 0.974**

The calibration reference was obtained using a mobile irradiance measurement application rather than a certified reference pyranometer. Therefore, the calibration accuracy is limited by the accuracy of the reference measurement.

## Short-Term Forecasting

Separate SARIMA models were developed for irradiance and ambient temperature.

The selected model configuration was:

```text
SARIMA(1,1,1) × (1,1,1)24
```

The forecasting dataset consisted of eight days of hourly meteorological data, with seven days used for training and the eighth day used as the held-out validation day.

### Forecasting Results

| Variable    |    R² |       RMSE |        MAE |   MAPE |
| ----------- | ----: | ---------: | ---------: | -----: |
| Irradiance  | 0.921 | 76.30 W/m² | 34.69 W/m² | 26.03% |
| Temperature | 0.964 |    1.30 °C |    1.06 °C |  6.56% |

The forecasted irradiance and temperature were subsequently supplied to the validated Simulink model to generate an end-to-end PV power forecast.

### End-to-End PV Power Forecast

For the validation day:

| Metric                 |  Result |
| ---------------------- | ------: |
| Forecast daily energy  | 1193 Wh |
| Reference daily energy | 1199 Wh |
| Daily energy error     |  -0.50% |
| Power-profile R²       |   0.858 |
| Power RMSE             | 30.09 W |
| Power MAE              | 12.43 W |
| Power MAPE (daytime)   |  32.29% |
| Mean Bias              | -0.25 W |

The reference power profile for this evaluation was generated by running the Simulink model with the actual irradiance and temperature inputs for the validation day. The forecast profile was generated using SARIMA-forecasted environmental inputs.

## Real-Time Digital Twin Demonstration

A real-time sensor-to-Simulink demonstration was implemented using an Arduino Uno, LDR irradiance sensing, temperature measurement, serial communication, MATLAB, and Simulink.

The real-time pipeline was:

```text
Arduino Uno
    ↓
LDR + Temperature Sensor
    ↓
Serial Communication
    ↓
MATLAB Interface
    ↓
Simulink Digital Twin
    ↓
Simulated PV Power
```

The demonstration used:

* 9600-baud serial communication
* Approximately 1-second sensor acquisition
* A 0.15-second Simulink simulation horizon per sample
* 5 minutes of continuous operation
* 28 recorded live samples

The live irradiance and temperature measurements were supplied to the Simulink model, which generated corresponding simulated PV power in real time.

## Error Analysis

The validation results showed that the simulation error varied systematically with irradiance.

At low irradiance, the LDR-based simulation tended to underpredict power. At higher irradiance, the model tended to overpredict power.

The observed error structure was analyzed in terms of both measurement-side and model-side effects.

Potential measurement-side limitations include reduced LDR sensitivity and limitations of the mobile irradiance reference.

Potential model-side limitations include unmodeled physical effects such as panel heating, soiling, cable losses, and other real-world losses not explicitly represented in the simplified PV model.

## Key Findings

1. Site-specific irradiance measurements produced substantially better agreement between the digital twin and measured PV power than satellite-derived irradiance.

2. The physics-based MATLAB/Simulink model reproduced the general behavior of the physical PV system while revealing systematic deviations across different irradiance levels.

3. The SARIMA models provided useful short-term forecasts of irradiance and ambient temperature for the selected validation dataset.

4. Forecasted environmental variables could be propagated through the validated digital twin to generate an end-to-end PV power forecast.

5. Real-time sensor-to-Simulink operation was demonstrated using Arduino-based data acquisition and serial communication.

## Limitations

* The LDR irradiance sensor was calibrated against a mobile irradiance measurement application rather than a certified reference pyranometer.
* SARIMA does not capture sudden localized cloud transients particularly well.
* The physics-based PV model does not explicitly represent all real-world losses and degradation effects.
* The real-time digital-twin demonstration operates in an open-loop configuration.
* Automatic model-state correction and closed-loop recalibration were not implemented.
* The forecasting evaluation used a limited dataset with a single held-out validation day.

## Future Work

Potential extensions of this work include:

* Calibration using a certified reference pyranometer
* Improved irradiance forecasting using nonlinear or deep-learning models
* Improved thermal and loss modeling
* Adaptive digital-twin state updating
* Closed-loop digital-twin operation
* Anomaly detection and PV fault identification
* Extension of the framework to larger PV installations

## Repository Structure

```text
pv-digital-twin-forecasting/
│
├── README.md
│
├── simulink/
│   └── MATLAB/Simulink digital-twin models
│
├── matlab/
│   ├── validation/
│   ├── forecasting/
│   ├── calibration/
│   └── realtime/
│
├── arduino/
│   └── Arduino sensing code
│
├── figures/
│   ├── validation/
│   ├── forecasting/
│   ├── calibration/
│   └── realtime/
│
├── results/
│   └── Results summaries
│
└── report/
    └── Final project report
```

## Project Report

The complete undergraduate project report documents the system architecture, modeling methodology, experimental measurements, validation procedure, forecasting methodology, real-time demonstration, results, limitations, and future work.

## Authors

**Pratik Adhikari**
**Nirajan Chaudhary**
**Prashant Bisokarma**
**Shasank Adhikari**

Department of Electrical Engineering
Institute of Engineering, Pulchowk Campus
Tribhuvan University, Nepal
