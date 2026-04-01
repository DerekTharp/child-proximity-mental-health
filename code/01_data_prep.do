/*==============================================================================
  01_data_prep.do
  Child Proximity and Life Satisfaction in Retirement

  Loads and merges three data sources into a person-wave panel:
    A. RAND HRS Longitudinal File (outcomes, controls, demographics)
    B. RAND HRS Family Data respondent file (child proximity counts)
    C. Cross-Wave Child Proximity file (continuous distance, waves 7-9 only)

  Input:  Raw HRS data files (see 00_config.do for paths)
  Output: $ANALYSIS_DATA/panel_raw.dta
==============================================================================*/

do "code/00_config.do"

log using "$OUTPUT_LOGS/01_data_prep.log", replace text

timer clear
timer on 1

* =============================================================================
* PART A: RAND HRS LONGITUDINAL FILE
* =============================================================================

di as text _n "=== PART A: Loading RAND Longitudinal File ==="

* The 1.6 GB RAND file is pre-extracted to ~65 MB by 00_extract_rand.py
* (pyreadstat reads column-selectively much faster than Stata)
use "$ANALYSIS_DATA/rand_extract.dta", clear

di as text "  Observations: " _N
di as text "  Variables: " c(k)

* ---- Rename for reshape ----
* Variables are already lowercase (e.g., r8cesd, h8atotb).
* Stata reshape requires: stub# format. Rename r{w}var -> var{w}

forvalues w = $FIRST_WAVE / $LAST_WAVE {
    foreach v of global KEEP_RWVARS {
        local lv = lower("`v'")
        cap rename r`w'`lv' `lv'`w'
    }
    foreach v of global KEEP_HWVARS {
        local lv = lower("`v'")
        cap rename h`w'`lv' `lv'`w'
    }
}

forvalues w = $LB_FIRST_WAVE / $LB_LAST_WAVE {
    foreach v of global KEEP_LBVARS {
        local lv = lower("`v'")
        cap rename r`w'`lv' `lv'`w'
    }
    foreach v of global KEEP_LBVARS2 {
        local lv = lower("`v'")
        cap rename r`w'`lv' `lv'`w'
    }
}

* ---- Reshape to long ----

di as text _n "  Reshaping wide to long (this may take a few minutes)..."

* Build the stub list for reshape
local stubs cesd shlt agey_e mstat sayret work wtresp
local stubs `stubs' atotb child itot
local stubs `stubs' lbsatwlf lbsatfam lbsatlife lbsathome lbsatfin lbsathlth
local stubs `stubs' lblonely3 lbneur lbext lbopen lbagr lbcon5 lbwgtr

reshape long `stubs', i(hhidpn) j(wave)

di as text "  After reshape: " _N " person-wave observations"

* ---- Create year variable from wave ----
gen year = .
replace year = 1992 if wave == 1
replace year = 1994 if wave == 2
replace year = 1996 if wave == 3
replace year = 1998 if wave == 4
replace year = 2000 if wave == 5
replace year = 2002 if wave == 6
replace year = 2004 if wave == 7
replace year = 2006 if wave == 8
replace year = 2008 if wave == 9
replace year = 2010 if wave == 10
replace year = 2012 if wave == 11
replace year = 2014 if wave == 12
replace year = 2016 if wave == 13
replace year = 2018 if wave == 14
replace year = 2020 if wave == 15
replace year = 2022 if wave == 16
label var year "Interview year"

* ---- Label key variables ----
label var cesd       "CES-D depressive symptoms (0-8)"
label var shlt       "Self-rated health (1=excellent, 5=poor)"
label var agey_e     "Age at interview (years)"
label var mstat      "Marital status"
label var sayret     "Considers self retired"
label var work       "Currently working"
label var wtresp     "Person-level analysis weight"
label var atotb      "Household total wealth (assets minus debt)"
label var child      "Number of living children"
label var itot       "Household total income"
label var lbsatwlf   "Life satisfaction SWLS (1-6 wave 8; 1-7 waves 9+)"
label var lbsatfam   "Satisfaction with family life"
label var lblonely3  "Loneliness (3-item scale)"
label var lbwgtr     "Leave-Behind respondent weight"
label var lbneur     "Big 5: Neuroticism"
label var lbext      "Big 5: Extraversion"
label var lbopen     "Big 5: Openness"
label var lbagr      "Big 5: Agreeableness"
label var lbcon5     "Big 5: Conscientiousness (5-item)"

compress
sort hhidpn wave

tempfile rand_long
save `rand_long'

di as text "  RAND Longitudinal panel: " _N " person-wave observations"
distinct hhidpn
di as text "  Unique respondents: " r(ndistinct)

* =============================================================================
* PART B: RAND FAMILY DATA (Respondent File — proximity counts)
* =============================================================================

di as text _n "=== PART B: Loading RAND Family Data (Respondent File) ==="

use "$RAND_FAM_R", clear

di as text "  Raw observations: " _N
di as text "  Raw variables: " c(k)

* Keep proximity counts and identifiers
* h{w}lv10mikn = number of kids within 10 miles, waves 1-16
local fam_keepvars hhidpn
forvalues w = $FIRST_WAVE / $LAST_WAVE {
    local fam_keepvars `fam_keepvars' h`w'lv10mikn
}

keep `fam_keepvars'

* Rename for reshape
forvalues w = $FIRST_WAVE / $LAST_WAVE {
    rename h`w'lv10mikn lv10mikn`w'
}

* Reshape to long
reshape long lv10mikn, i(hhidpn) j(wave)

label var lv10mikn "Number of children living within 10 miles"

di as text "  Family data panel: " _N " person-wave observations"
distinct hhidpn
di as text "  Unique respondents: " r(ndistinct)

* ---- Merge with RAND Longitudinal ----
di as text _n "  Merging Family Data onto Longitudinal panel..."

merge 1:1 hhidpn wave using `rand_long'

tab _merge
di as text "  Matched: " r(N) " (keep matched + longitudinal-only)"

* Keep all longitudinal observations (merge==2 means in longitudinal but not family)
* merge==1 means in family but not longitudinal (drop)
* merge==3 means matched
drop if _merge == 1
drop _merge

compress
sort hhidpn wave

tempfile merged
save `merged'

* =============================================================================
* PART C: CROSS-WAVE CHILD PROXIMITY (Continuous distance, waves 7-9)
* =============================================================================

di as text _n "=== PART C: Loading Cross-Wave Child Proximity ==="

* Read the three wave files (A=2004/wave7, B=2006/wave8, C=2008/wave9)
* These are ASCII files read with Stata dictionary files

tempfile cprox_all

local cprox_waves "A B C"
local cprox_wavnum "7 8 9"

local i = 1
foreach letter of local cprox_waves {
    local wn : word `i' of `cprox_wavnum'

    di as text "  Reading CPROX`letter'_R (wave `wn')..."

    * Read ASCII data with inline column positions (avoids Windows path issues
    * in the original .dct dictionary files)
    infix str6 HHID 1-6 str1 SUBHH 7 str3 PN 8-10 str3 OPN 11-13 ///
          long YEAR 14-21 int REL_R 22-24 long DIST_GCD 25-32 long DIST_GIS 33-40 ///
          using "$CPROX_DIR/data/CPROX`letter'_R.da", clear

    * Create numeric HHIDPN for merging
    gen double hhidpn = real(HHID) * 1000 + real(PN)
    format hhidpn %12.0f

    gen wave = `wn'

    * Collapse from child-level to respondent-level
    * Compute: min distance (to closest child), mean distance, N children in file
    collapse (min) dist_gcd_min=DIST_GCD (mean) dist_gcd_mean=DIST_GCD ///
             (count) n_children_far=DIST_GCD, by(hhidpn wave)

    label var dist_gcd_min  "Distance to closest child >10mi (miles, Great Circle)"
    label var dist_gcd_mean "Mean distance to children >10mi (miles, Great Circle)"
    label var n_children_far "Number of children >10 miles (in CPROX file)"

    if `i' == 1 {
        save `cprox_all', replace
    }
    else {
        append using `cprox_all'
        save `cprox_all', replace
    }

    local i = `i' + 1
}

di as text "  CPROX observations: " _N
distinct hhidpn
di as text "  Unique respondents: " r(ndistinct)

* ---- Merge CPROX onto main panel ----
di as text _n "  Merging CPROX onto panel..."

use `merged', clear
merge 1:1 hhidpn wave using `cprox_all', nogenerate keep(master match)

* =============================================================================
* SAVE OUTPUT
* =============================================================================

compress
sort hhidpn wave
order hhidpn wave year ragender raedyrs raracem rahispan rabyear hacohort ///
      agey_e shlt mstat work sayret atotb itot child wtresp ///
      lv10mikn dist_gcd_min dist_gcd_mean n_children_far ///
      cesd lbsatwlf lbsatfam lblonely3 lbwgtr ///
      lbneur lbext lbopen lbagr lbcon5

save "$ANALYSIS_DATA/panel_raw.dta", replace

di as text _n "============================================="
di as text "  panel_raw.dta saved"
di as text "  Observations: " _N
distinct hhidpn
di as text "  Unique respondents: " r(ndistinct)
di as text "============================================="

timer off 1
timer list 1

log close
