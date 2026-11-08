"""Validation metrics for the PV digital twin, computed from the saved simulation runs.

Run from the repository root:  python python/validation_metrics.py
Inputs : data/field_dataset.csv, data/simulation/runs_*.csv, data/simulation/pv_curve_sweep.csv,
         data/forecast_vs_actual_day8.csv
Prints : STC power, MPPT tracking efficiency, field validation metrics (on-site and Solcast
         irradiance), measured/twin power ratio per day, and Day 8 forecast energy.
"""
import glob, os
import numpy as np, pandas as pd

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
P = lambda *a: os.path.join(ROOT, *a)


def metrics(y, p):
    y, p = np.asarray(y, float), np.asarray(p, float)
    e = p - y
    return dict(n=len(y), RMSE=np.sqrt((e**2).mean()), MAE=np.abs(e).mean(),
                MAPE=100*np.mean(np.abs(e)/y), MBE=e.mean(), r=np.corrcoef(y, p)[0, 1],
                R2_1to1=1-(e**2).sum()/((y-y.mean())**2).sum())


d = pd.read_csv(P('data', 'field_dataset.csv'))
runs = pd.concat([pd.read_csv(f) for f in sorted(glob.glob(P('data', 'simulation', 'runs_*.csv')))])
sw = pd.read_csv(P('data', 'simulation', 'pv_curve_sweep.csv'))


def series(name):
    s = runs[runs.set == name].sort_values('idx')
    return s.P_avg.values


print('Twin runs:', len(runs), '| DC-link voltage range: %.1f-%.1f V' % (runs.Vdc_avg.min(), runs.Vdc_avg.max()))
stc = runs[runs.set == 'STC'].iloc[0]
print('STC: %.1f W at Vpv = %.1f V' % (stc.P_avg, stc.Vpv_avg))

print('\nMPPT tracking efficiency (twin with P&O vs maximum of its own P-V curve)')
for G in (200, 400, 600, 800, 1000):
    pmax = sw[sw.G == G].P_avg.max()
    p_t = runs[(runs.set == 'SWP') & (runs.G == G)].P_avg
    if len(p_t):
        print('  G = %4d W/m2: %.2f %%' % (G, 100*p_t.iloc[0]/pmax))

print('\nField validation, 41 readings (power in W)')
for label, key in (('on-site irradiance', 'SITE'), ('Solcast irradiance', 'SOL')):
    m = metrics(d.Power_Real, series(key))
    print('  %-20s RMSE %.1f  MAE %.1f  MAPE %.1f%%  MBE %+.1f  r %.3f  1:1 R2 %.2f'
          % (label, m['RMSE'], m['MAE'], m['MAPE'], m['MBE'], m['r'], m['R2_1to1']))

sim = series('SITE')
for day in d.Date.unique():
    k = (d.Date == day).values
    print('  %s: mean measured / twin power = %.3f' % (day, d.Power_Real[k].mean()/sim[k].mean()))

print('\nDay 8 (22 March 2020) daily energy through the twin, Wh')
f = pd.read_csv(P('data', 'forecast_vs_actual_day8.csv'))
E = {}
for key in ('D8A', 'D8F', 'D8P'):
    s = runs[runs.set == key]
    E[key] = s.P_avg.sum()     # hourly values, 1 h per sample; night hours are zero
print('  reference %.1f | SARIMA %.1f (%+.2f %%) | persistence %.1f (%+.2f %%)'
      % (E['D8A'], E['D8F'], 100*(E['D8F']/E['D8A']-1), E['D8P'], 100*(E['D8P']/E['D8A']-1)))
