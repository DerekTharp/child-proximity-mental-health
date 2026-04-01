"""
00_extract_rand.py
Extract needed variables from the 1.6 GB RAND HRS Longitudinal File.

Stata is very slow loading this file due to ~20K variables.
This script uses pyreadstat (C-backed) for fast column-selective reads,
saves a smaller .dta for Stata to load quickly.

Input:  data/raw/randhrs1992_2022v1.dta (1.6 GB, ~20K variables)
Output: data/analysis/rand_extract.dta (~200 variables, much smaller)
"""

import pyreadstat
import os
import time

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAND_FILE = os.path.join(PROJECT_ROOT, "HRS/randhrs1992_2022v1_STATA/randhrs1992_2022v1.dta")
OUTPUT_FILE = os.path.join(PROJECT_ROOT, "data/analysis/rand_extract.dta")

# Build variable list
WAVES = range(1, 17)       # waves 1-16
LB_WAVES = range(8, 17)    # waves 8-16

# NOTE: These variables must stay in sync with the KEEP_* globals in code/00_config.do.
# If you add a variable here, also add it to the corresponding Stata global.

# Time-invariant (all lowercase in RAND file)
keep_vars = ["hhidpn", "ragender", "raedyrs", "raracem", "rahispan", "rabdate",
             "hacohort", "rabyear"]

# Wave-specific respondent variables
r_stubs = ["cesd", "shlt", "agey_e", "mstat", "sayret", "work", "wtresp"]
for w in WAVES:
    for stub in r_stubs:
        keep_vars.append(f"r{w}{stub}")

# Wave-specific household variables
h_stubs = ["atotb", "child", "itot"]
for w in WAVES:
    for stub in h_stubs:
        keep_vars.append(f"h{w}{stub}")

# Leave-Behind variables (waves 8-16 only)
lb_stubs = ["lbsatwlf", "lbsatfam", "lbsatlife", "lbsathome", "lbsatfin", "lbsathlth",
            "lblonely3", "lbneur", "lbext", "lbopen", "lbagr", "lbcon5", "lbwgtr"]
for w in LB_WAVES:
    for stub in lb_stubs:
        keep_vars.append(f"r{w}{stub}")

print(f"Extracting {len(keep_vars)} variables from RAND Longitudinal File...")
print(f"  Source: {RAND_FILE}")
print(f"  Output: {OUTPUT_FILE}")

t0 = time.time()

# Read only the columns we need (pyreadstat is fast at column-selective reads)
df, meta = pyreadstat.read_dta(RAND_FILE, usecols=keep_vars)

t1 = time.time()
print(f"  Read complete: {df.shape[0]} obs x {df.shape[1]} vars in {t1-t0:.1f}s")

# Convert categorical columns to numeric codes for Stata compatibility
import pandas as pd
for col in df.columns:
    if df[col].dtype == 'object' or df[col].dtype.name == 'category':
        # Convert to numeric, coercing errors to NaN
        df[col] = pd.to_numeric(df[col], errors='coerce')

# Save as Stata .dta (version 118 = Stata 14 format, compatible with SE)
df.to_stata(OUTPUT_FILE, version=118, write_index=False)

t2 = time.time()
print(f"  Write complete in {t2-t1:.1f}s")
print(f"  Output size: {os.path.getsize(OUTPUT_FILE) / 1e6:.1f} MB")
print("Done.")
