#!/usr/bin/env python3
"""
run_all.py
Master driver: reproduces all outputs from raw data.

Usage:
    python3 run_all.py          # Run full pipeline
    python3 run_all.py --verify # Check that all expected outputs exist

Requires: Stata MP 19.5, Python 3 with pyreadstat/pandas/matplotlib
"""

import subprocess
import sys
import os
import time
import shlex

PROJECT_ROOT = os.path.dirname(os.path.abspath(__file__))
CODE_DIR = os.path.join(PROJECT_ROOT, "code")
ANALYSIS_DIR = os.path.join(PROJECT_ROOT, "data/analysis")
TABLE_DIR = os.path.join(PROJECT_ROOT, "output/tables")
FIG_DIR = os.path.join(PROJECT_ROOT, "output/figures")

STATA = "/Applications/StataNow/StataMP.app/Contents/MacOS/stata-mp"

EXPECTED_OUTPUTS = [
    "data/analysis/rand_extract.dta",
    "data/analysis/panel_raw.dta",
    "data/analysis/sample_main.dta",
    "data/analysis/analysis_final.dta",
    "output/tables/table1_overall.csv",
    "output/tables/table1_by_proximity.csv",
    "output/tables/table2_ols.csv",
    "output/tables/table3_fe.csv",
    "output/tables/table4_event_study_cesd.csv",
    "output/tables/table5_heterogeneity.csv",
    "output/tables/appendix_subgroup_summary.csv",
    "output/tables/appendix_es_clean_gainers.csv",
    "output/tables/appendix_es_loss.csv",
    "output/tables/appendix_secondary_outcomes.csv",
    "output/tables/sample_flow_clean.csv",
    "output/tables/transition_matrix.csv",
    "output/tables/proximity_by_wave.csv",
    "output/tables/appendix_nonmover_summary.csv",
    "output/tables/appendix_es_nonmover_at_gain.csv",
    "output/tables/appendix_es_never_moved.csv",
    "output/tables/appendix_es_mover_at_gain.csv",
    "output/figures/figure1_dag.png",
    "output/figures/figure1_dag.pdf",
    "output/figures/figure2_ols_decomposition.png",
    "output/figures/figure2_ols_decomposition.pdf",
    "output/figures/figure3_event_study_cesd.png",
    "output/figures/figure3_event_study_cesd.pdf",
    "output/figures/figure4_event_study_loss.png",
    "output/figures/figure4_event_study_loss.pdf",
    "output/figures/figure5_clean_gainers.png",
    "output/figures/figure5_clean_gainers.pdf",
    "output/figures/figure6_nonmover_robustness.png",
    "output/figures/figure6_nonmover_robustness.pdf",
]


def run_step(description, cmd_list, cwd=PROJECT_ROOT):
    """Run a command (as argument list) and check for success."""
    print(f"\n{'='*60}")
    print(f"  {description}")
    print(f"{'='*60}")
    t0 = time.time()
    result = subprocess.run(cmd_list, cwd=cwd)
    elapsed = time.time() - t0
    if result.returncode != 0:
        print(f"  FAILED (exit code {result.returncode}) after {elapsed:.1f}s")
        sys.exit(1)
    print(f"  Completed in {elapsed:.1f}s")


def verify():
    """Check that all expected outputs exist."""
    print("\nVerifying outputs...")
    missing = []
    for path in EXPECTED_OUTPUTS:
        full = os.path.join(PROJECT_ROOT, path)
        if os.path.exists(full):
            size = os.path.getsize(full)
            print(f"  OK  {path} ({size/1024:.0f} KB)")
        else:
            print(f"  MISSING  {path}")
            missing.append(path)

    if missing:
        print(f"\n{len(missing)} files missing.")
        sys.exit(1)
    else:
        print(f"\nAll {len(EXPECTED_OUTPUTS)} expected outputs present.")


def main():
    if "--verify" in sys.argv:
        verify()
        return

    t_start = time.time()

    # Step 0: Extract variables from RAND Longitudinal (Python)
    run_step("Step 0: Extract RAND variables (Python)",
             ["python3", os.path.join(CODE_DIR, "00_extract_rand.py")])

    # Steps 1-3: Data prep, sample, derived measures (Stata)
    for script in ["01_data_prep.do", "02_sample.do", "03_derived.do"]:
        run_step(f"Step: {script}",
                 [STATA, "-b", "do", os.path.join("code", script)])

    # Steps 4-9: Analysis scripts (Stata)
    for step_num, script in [(4, "04_descriptive.do"),
                              (5, "05_analysis.do"),
                              (6, "06_robustness.do"),
                              (7, "07_revision_analyses.do"),
                              (8, "08_fix_artifacts.do"),
                              (9, "09_supplementary_analyses.do")]:
        run_step(f"Step {step_num}: {script}",
                 [STATA, "-b", "do", os.path.join("code", script)])

    # Step 10: DAG figure
    run_step("Step 10: Generate DAG figure (Python)",
             ["python3", os.path.join(CODE_DIR, "figure_dag.py")])

    # Step 11: Publication figures
    run_step("Step 11: Generate figures (Python)",
             ["python3", os.path.join(CODE_DIR, "figures.py")])

    elapsed = time.time() - t_start
    print(f"\n{'='*60}")
    print(f"  Pipeline complete in {elapsed:.0f}s")
    print(f"{'='*60}")

    # Verify
    verify()


if __name__ == "__main__":
    main()
