"""Job lists for the twin batch runs (matlab/validation/run_jobs.m and pv_curve_sweep.m).

Run from the repository root:  python python/make_jobs.py [n_workers]
Writes matlab/validation/jobs/jobs_<k>.csv (twin runs) and sweep_0.csv (P-V sweep).

Set names: STC, SWP (irradiance sweep), SITE / SOL (field readings driven by on-site
or Solcast irradiance, NOCT cell temperature), SITE0 / SOL0 (same, ambient temperature
fed straight to the cell), D8A / D8F / D8P (Day 8 actual, SARIMA forecast, persistence),
RT (irradiance values logged in the live run).
"""
import os, sys
import pandas as pd

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
OUT = os.path.join(ROOT, 'matlab', 'validation', 'jobs')
os.makedirs(OUT, exist_ok=True)
d = pd.read_csv(os.path.join(ROOT, 'data', 'field_dataset.csv'))
f = pd.read_csv(os.path.join(ROOT, 'data', 'forecast_vs_actual_day8.csv'))
w = pd.read_csv(os.path.join(ROOT, 'data', 'kathmandu_8day_window.csv'))
d7 = w.iloc[144:168].reset_index(drop=True)          # Day 7, used as the persistence forecast
rt = pd.read_csv(os.path.join(ROOT, 'data', 'realtime_log.csv'))

rows = [('STC', 0, 1000, 25, 0)]
for G in range(100, 1001, 100):
    rows.append(('SWP', G, G, 25, 0))
for i, r in d.iterrows():
    for noct in (1, 0):
        rows.append(('SITE' if noct else 'SITE0', i, r.Irr_Mobile, r.Temperature, noct))
        rows.append(('SOL' if noct else 'SOL0', i, r.Irr_Solcast, r.Temperature, noct))
for i, r in f.iterrows():
    if r.Actual_Irradiance > 0:
        rows.append(('D8A', i, r.Actual_Irradiance, r.Actual_Temperature, 1))
    if r.Forecast_Irradiance > 0:
        rows.append(('D8F', i, r.Forecast_Irradiance, r.Forecast_Temperature, 1))
    if d7.Irradiance[i] > 0:
        rows.append(('D8P', i, d7.Irradiance[i], d7.Temperature[i], 1))
for g in sorted(rt.Irradiance_Wm2.unique()):
    rows.append(('RT', 0, g, 25, 1))

J = pd.DataFrame(rows, columns=['set', 'idx', 'G', 'T', 'noct'])
n = int(sys.argv[1]) if len(sys.argv) > 1 else 4
J = J.sample(frac=1, random_state=0).reset_index(drop=True)
for k in range(n):
    J.iloc[k::n].to_csv(os.path.join(OUT, f'jobs_{k}.csv'), index=False)

sw = pd.DataFrame([(G, 25, V) for G in (200, 400, 600, 800, 1000)
                   for V in (32, 34, 35, 36, 36.5, 37, 37.5, 38, 38.5, 39, 40, 42)],
                  columns=['G', 'T', 'V'])
sw.to_csv(os.path.join(OUT, 'sweep_0.csv'), index=False)
print(len(J), 'twin jobs;', len(sw), 'sweep jobs')
