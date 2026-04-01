/*==============================================================================
  00_master.do
  Child Proximity and Life Satisfaction in Retirement

  Master script: runs the full pipeline from raw data to analysis outputs.
  All steps run without `cap` so failures are visible and halt execution.

  Usage: stata-mp -b do code/00_master.do
==============================================================================*/

clear all
set more off

* Source configuration (single place replicators edit the project root)
do "code/00_config.do"

di as text _n "============================================="
di as text "  MASTER PIPELINE START"
di as text "  $S_DATE $S_TIME"
di as text "============================================="

timer clear
timer on 99

* Step 0: Extract variables from large RAND file (Python, fast)
di as text _n ">>> Step 0: RAND Variable Extraction (Python)"
shell python3 "$CODE/00_extract_rand.py"

* Step 1: Data preparation (load, merge, reshape)
di as text _n ">>> Step 1: Data Preparation"
do "$CODE/01_data_prep.do"

* Step 2: Sample construction
di as text _n ">>> Step 2: Sample Construction"
do "$CODE/02_sample.do"

* Step 3: Derived measures (events, z-scores, flags)
di as text _n ">>> Step 3: Derived Measures"
do "$CODE/03_derived.do"

* Step 4: Descriptive statistics
di as text _n ">>> Step 4: Descriptive Statistics"
do "$CODE/04_descriptive.do"

* Step 5: Main analysis
di as text _n ">>> Step 5: Main Analysis"
do "$CODE/05_analysis.do"

* Step 6: Robustness checks
di as text _n ">>> Step 6: Robustness"
do "$CODE/06_robustness.do"

* Step 7: Revision analyses
di as text _n ">>> Step 7: Revision Analyses"
do "$CODE/07_revision_analyses.do"

* Step 8: Artifact fixes and export cleanup
di as text _n ">>> Step 8: Artifact Fixes"
do "$CODE/08_fix_artifacts.do"

* Step 9: Nonmover robustness (mobility file merge + event study)
di as text _n ">>> Step 9: Supplementary Analyses (Nonmover Robustness)"
do "$CODE/09_supplementary_analyses.do"

* Step 10: DAG figure
di as text _n ">>> Step 10: DAG Figure"
shell python3 "$CODE/figure_dag.py"

* Step 11: Publication figures
di as text _n ">>> Step 11: Publication Figures"
shell python3 "$CODE/figures.py"

timer off 99

di as text _n "============================================="
di as text "  MASTER PIPELINE COMPLETE"
di as text "  $S_DATE $S_TIME"
timer list 99
di as text "============================================="
