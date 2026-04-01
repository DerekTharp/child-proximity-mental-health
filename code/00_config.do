/*==============================================================================
  00_config.do
  Child Proximity and Life Satisfaction in Retirement

  Centralized configuration: all paths, variable lists, and parameters.
  Every downstream script sources this file at the top.

  REPLICATORS: Set PROJECT_ROOT to match your local directory.
  Place the mobility file at data/raw/HRSXREGION22.dta.
==============================================================================*/

clear all
set more off
set maxvar 32000
version 18

* =============================================================================
* PATHS — Set PROJECT_ROOT only; other paths are repo-relative
* =============================================================================

global PROJECT_ROOT "/path/to/child-proximity-mental-health"

global CODE          "$PROJECT_ROOT/code"
global RAW_DATA      "$PROJECT_ROOT/data/raw"
global ANALYSIS_DATA "$PROJECT_ROOT/data/analysis"
global OUTPUT_TABLES "$PROJECT_ROOT/output/tables"
global OUTPUT_FIGS   "$PROJECT_ROOT/output/figures"
global OUTPUT_LOGS   "$PROJECT_ROOT/output/logs"

* Source data files
global RAND_LONG     "$RAW_DATA/randhrs1992_2022v1.dta"
global RAND_FAM_R    "$RAW_DATA/randhrsfamr1992_2022v1.dta"
global RAND_FAM_K    "$RAW_DATA/randhrsfamk1992_2022v1.dta"
global CPROX_DIR     "$RAW_DATA/cprox"
global MOBILITY_DTA  "$RAW_DATA/HRSXREGION22.dta"

* =============================================================================
* WAVE PARAMETERS
* =============================================================================

global FIRST_WAVE     1
global LAST_WAVE      16
global LB_FIRST_WAVE  8
global LB_LAST_WAVE   16

* Wave-to-year mapping (wave w -> year)
* 1=1992, 2=1994, 3=1996, 4=1998, 5=2000, 6=2002, 7=2004, 8=2006,
* 9=2008, 10=2010, 11=2012, 12=2014, 13=2016, 14=2018, 15=2020, 16=2022

* =============================================================================
* SAMPLE RESTRICTIONS
* =============================================================================

global MIN_AGE        50
global MIN_WAVES_FE   2    // minimum waves with non-missing outcome + proximity for FE
global MIN_WAVES_ES   3    // minimum waves with non-missing proximity for event study

* =============================================================================
* OUTCOME VARIABLES (RAND Longitudinal variable stubs, without wave prefix)
* =============================================================================

* Primary event study outcome (available every 2 years)
global PRIMARY_OUTCOME  cesd

* Confirmatory outcomes (Leave-Behind, every 4 years per person)
global LB_OUTCOMES      lbsatwlf lblonely3 lbsatfam

* All outcomes
global ALL_OUTCOMES     cesd lbsatwlf lblonely3 lbsatfam

* =============================================================================
* CONTROL VARIABLES (stubs)
* =============================================================================

* Time-invariant demographics (no wave prefix needed)
global DEMOGRAPHICS     ragender raedyrs i.raracem rahispan

* Time-varying controls (use wave-specific values)
global TIME_VARYING     shlt i.mstat agey_e child

* Wealth (household level)
global WEALTH           ihs_hatotb

* Personality (from LB, treated as time-invariant — first non-missing)
global PERSONALITY      lbneur lbext lbopen lbagr lbcon5

* Full covariate set for OLS
global FULL_CONTROLS    $DEMOGRAPHICS $TIME_VARYING $WEALTH

* Time-varying controls for FE models (demographics absorbed by FE)
global FE_CONTROLS      $TIME_VARYING $WEALTH

* =============================================================================
* EVENT STUDY PARAMETERS
* =============================================================================

global ES_PRE_PERIODS   4    // 4 waves before event (8 years for CES-D)
global ES_POST_PERIODS  4    // 4 waves after event (8 years for CES-D)
global ES_OMIT_PERIOD  -1    // normalize to last pre-event period

* For LB outcomes (coarser timing)
global ES_LB_PRE       2    // 2 LB observations before event
global ES_LB_POST      2    // 2 LB observations after event

* =============================================================================
* PROXIMITY THRESHOLD
* =============================================================================

global PROX_THRESHOLD   10   // miles (matching Finke et al. and HRS coding)

* =============================================================================
* VARIABLE LISTS FOR KEEPING FROM RAND LONGITUDINAL (wide format)
* =============================================================================

* These are the wave-specific variables to keep before reshaping.
* Format: R{w}VARNAME for respondent, H{w}VARNAME for household, S{w}VARNAME for spouse.

* Variables to keep for each wave w (1-16):
global KEEP_RWVARS  "cesd shlt agey_e mstat sayret work wtresp"
global KEEP_HWVARS  "atotb child itot"

* LB variables to keep for waves 8-16 only:
global KEEP_LBVARS  "lbsatwlf lbsatfam lbsatlife lbsathome lbsatfin lbsathlth"
global KEEP_LBVARS2 "lblonely3 lbneur lbext lbopen lbagr lbcon5 lbwgtr"

* Time-invariant variables (no wave prefix):
global KEEP_TIMEINV "hhidpn ragender raedyrs raracem rahispan rabdate hacohort rabyear"

* =============================================================================
* DISPLAY CONFIGURATION
* =============================================================================

di as text "============================================="
di as text "  Child Proximity & Life Satisfaction Project"
di as text "  Config loaded: $S_DATE $S_TIME"
di as text "  Project root: $PROJECT_ROOT"
di as text "============================================="
