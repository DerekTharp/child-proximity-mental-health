# Replication Package

**Do older adults feel better when their children live closer? Longitudinal evidence from the Health and Retirement Study**

## Overview

This package reproduces all tables, figures, and in-text estimates reported in the manuscript. The analysis uses publicly available data from the Health and Retirement Study (HRS).

## Data Availability

All data are publicly available from the HRS:
- **RAND HRS Longitudinal File 2022 (V1)**: https://hrs.isr.umich.edu/
- **RAND HRS Family Data 2022 (V1)**: https://hrs.isr.umich.edu/
- **HRS Cross-Wave Child Proximity File**: https://hrs.isr.umich.edu/
- **HRS Cross-Wave Census Region/Division and Mobility File (V10)**: https://hrs.isr.umich.edu/

Users must register for an HRS account (free) to download data files. Place downloaded files following the structure documented in `code/00_config.do`.

### Data Citations

Health and Retirement Study, (RAND HRS Longitudinal File 2022 V1) public use data. Produced and distributed by the University of Michigan with funding from the National Institute on Aging (grant number NIA U01AG009740). Ann Arbor, MI.

Health and Retirement Study, (RAND HRS Family Data 2022 V1) public use data. Produced and distributed by the University of Michigan with funding from the National Institute on Aging (grant number NIA U01AG009740). Ann Arbor, MI.

Health and Retirement Study, (Cross-Wave Census Region/Division and Mobility File, Version 10) public use data. Produced and distributed by the University of Michigan.

## Computational Requirements

### Software
- **Stata MP 19.5** (or SE 18+)
  - Required user-written command: `distinct` (install via `ssc install distinct`)
- **Python 3.12+** with packages listed in `requirements.txt`

### Setup
```bash
pip install -r requirements.txt
```

In Stata, install required community commands:
```stata
ssc install distinct
```

### Hardware
- Approximately 4 GB RAM
- Approximately 1 GB disk space for outputs
- Runtime: approximately 15-20 minutes on a modern laptop

### Controlled Randomness
No stochastic operations are used. All results are deterministic.

## Instructions to Replicators

1. Set the placeholder `PROJECT_ROOT` path in `code/00_config.do` to match your local directory.
2. Ensure Stata is accessible at the path specified in `run_all.py`. Update the `STATA` variable if your installation differs.
3. Place HRS data files in `data/raw/` following the filenames documented in `code/00_config.do`, including `data/raw/HRSXREGION22.dta` for the mobility file.
4. Run the full pipeline:

```bash
python3 run_all.py
```

This executes all Stata and Python scripts in sequence and verifies that all expected output files are produced.

To verify outputs without re-running:
```bash
python3 run_all.py --verify
```

## Code Description

| Script | Purpose |
|---|---|
| `code/00_config.do` | Centralized configuration (paths, variable lists, parameters) |
| `code/00_extract_rand.py` | Extract needed variables from 1.6 GB RAND file (fast) |
| `code/00_master.do` | Stata master script (runs all .do files sequentially) |
| `code/01_data_prep.do` | Load and merge RAND Longitudinal, Family, and Proximity data |
| `code/02_sample.do` | Apply sample restrictions, document flow |
| `code/03_derived.do` | Create event indicators, z-scores, classification flags |
| `code/04_descriptive.do` | Table 1 descriptive statistics |
| `code/05_analysis.do` | OLS, fixed effects, event-time models, heterogeneity |
| `code/06_robustness.do` | Sensitivity analyses |
| `code/07_revision_analyses.do` | Race/ethnicity, gender, no-health-controls subgroups |
| `code/08_fix_artifacts.do` | Export manuscript-facing tables and summary artifacts |
| `code/09_supplementary_analyses.do` | Nonmover robustness test (mobility file merge, event study by parent mobility) |
| `code/figures.py` | Publication figures (reads from Stata CSV output) |
| `code/figure_dag.py` | DAG figure |
| `run_all.py` | Master Python driver (runs all steps, verifies outputs) |

## List of Tables and Figures

| Display item | Program | Output file |
|---|---|---|
| Figure 1 (DAG) | `code/figure_dag.py` | `output/figures/figure1_dag.pdf` |
| Figure 2 (OLS decomposition) | `code/figures.py` | `output/figures/figure2_ols_decomposition.pdf` |
| Figure 3 (Event-time CES-D) | `code/figures.py` | `output/figures/figure3_event_study_cesd.pdf` |
| Table 1 (Descriptives) | `code/04_descriptive.do`, `code/08_fix_artifacts.do` | `output/tables/table1_overall.csv`, `output/tables/table1_by_proximity.csv` |
| Table 2 (OLS progression) | `code/05_analysis.do` | `output/tables/table2_ols.csv` |
| Table 3 (Fixed effects) | `code/05_analysis.do` | `output/tables/table3_fe.csv` |
| Appendix Table A1 (Sample flow) | `code/02_sample.do` | `output/tables/sample_flow_clean.csv` |
| Appendix Table A2 (Secondary outcomes) | `code/06_robustness.do` | `output/tables/appendix_secondary_outcomes.csv` |
| Appendix Table A3 (Subgroups) | `code/08_fix_artifacts.do` | `output/tables/appendix_subgroup_summary.csv` |
| Appendix Table A4 (Nonmover robustness) | `code/09_supplementary_analyses.do` | `output/tables/appendix_nonmover_summary.csv` |
| Appendix Figure A1 (Loss event) | `code/figures.py` | `output/figures/figure4_event_study_loss.pdf` |
| Appendix Figure A2 (Clean gainers) | `code/figures.py` | `output/figures/figure5_clean_gainers.pdf` |
| Appendix Figure A3 (Nonmover robustness) | `code/figures.py` | `output/figures/figure6_nonmover_robustness.pdf` |

## License

Code: MIT License. Data: Subject to HRS data use agreement.
