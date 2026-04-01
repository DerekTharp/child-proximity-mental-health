/*==============================================================================
  04_descriptive.do
  Child Proximity and Life Satisfaction in Retirement

  Generates descriptive statistics:
    - Table 1: Sample characteristics by proximity group
    - Transition matrix for any_near
    - Proximity distribution by wave

  Input:  $ANALYSIS_DATA/analysis_final.dta
  Output: $OUTPUT_TABLES/table1_*.csv
          $OUTPUT_TABLES/transition_matrix.csv
==============================================================================*/

do "code/00_config.do"

log using "$OUTPUT_LOGS/04_descriptive.log", replace text

use "$ANALYSIS_DATA/analysis_final.dta", clear

* =============================================================================
* TABLE 1: SAMPLE CHARACTERISTICS BY PROXIMITY GROUP
* =============================================================================

di as text _n "=== Table 1: Descriptive Statistics ==="

* Restrict to CES-D FE sample for descriptives
preserve
keep if sample_cesd_fe == 1

* Create group variable for table columns
gen prox_group = .
replace prox_group = 1 if always_near == 1
replace prox_group = 2 if never_near == 1
replace prox_group = 3 if switcher == 1
label define prox_grp 1 "Always near" 2 "Never near" 3 "Switcher"
label values prox_group prox_grp

* ---- Demographics (use first observation per person) ----
bysort hhidpn (wave): gen first_obs = (_n == 1)

di as text _n "--- Demographics (person-level, first observation) ---"
tab prox_group if first_obs == 1, missing

* Age at first observation
bysort prox_group: sum agey_e if first_obs == 1, detail

* Gender
tab ragender prox_group if first_obs == 1, col

* Education
bysort prox_group: sum raedyrs if first_obs == 1

* Race
tab raracem prox_group if first_obs == 1, col

* ---- Time-varying characteristics (all person-waves) ----
di as text _n "--- Time-varying (all person-waves in CES-D FE sample) ---"

* Self-rated health
bysort prox_group: sum shlt

* CES-D
bysort prox_group: sum cesd

* Marital status
tab mstat prox_group, col

* Wealth
bysort prox_group: sum atotb, detail

* N children
bysort prox_group: sum child

* Proximity count
bysort prox_group: sum lv10mikn

* ---- LB outcomes (available subset) ----
di as text _n "--- Leave-Behind outcomes (available observations) ---"

bysort prox_group: sum lbsatwlf if lbsatwlf < .
bysort prox_group: sum lbsatwlf_z if lbsatwlf_z < .
bysort prox_group: sum lblonely3 if lblonely3 < .
bysort prox_group: sum lbsatfam if lbsatfam < .

* ---- Export Table 1 as CSV ----
* Overall means
tabstat agey_e ragender raedyrs shlt cesd atotb child lv10mikn ///
    lbsatwlf lblonely3 if first_obs == 1 | first_obs == 0, ///
    statistics(mean sd n) columns(statistics) save
matrix T1_all = r(StatTotal)

* By group
tabstat agey_e ragender raedyrs shlt cesd atotb child lv10mikn ///
    lbsatwlf lblonely3, ///
    by(prox_group) statistics(mean sd n) columns(statistics) save nototal

restore

* Save overall table as CSV
preserve
    clear
    svmat T1_all, names(col)
    export delimited using "$OUTPUT_TABLES/table1_overall.csv", replace
restore

* =============================================================================
* TRANSITION MATRIX
* =============================================================================

di as text _n "=== Transition Matrix: any_near at t vs t+1 ==="

use "$ANALYSIS_DATA/analysis_final.dta", clear
keep if sample_cesd_fe == 1

sort hhidpn wave
by hhidpn: gen any_near_next = any_near[_n+1] if _n < _N

di as text "Transition counts:"
tab any_near any_near_next, cell

di as text _n "Transition rates (row %):"
tab any_near any_near_next, row

* Export transition matrix
tab any_near any_near_next, matcell(trans_mat)
matrix list trans_mat

preserve
    clear
    svmat trans_mat, names(col)
    gen from_near = _n - 1
    order from_near
    export delimited using "$OUTPUT_TABLES/transition_matrix.csv", replace
restore

* =============================================================================
* EVENT TIMING DISTRIBUTION
* =============================================================================

di as text _n "=== Distribution of gain events by wave ==="

use "$ANALYSIS_DATA/analysis_final.dta", clear

* One row per person
bysort hhidpn: keep if _n == 1

tab first_gain_wave if first_gain_wave < ., missing

di as text _n "=== Distribution of loss events by wave ==="
tab first_loss_wave if first_loss_wave < ., missing

* =============================================================================
* PROXIMITY BY WAVE
* =============================================================================

di as text _n "=== Mean number of children within 10 miles, by wave ==="

use "$ANALYSIS_DATA/analysis_final.dta", clear
keep if sample_cesd_fe == 1

collapse (mean) mean_near=lv10mikn (mean) pct_any_near=any_near ///
    (count) n_obs=lv10mikn, by(wave)

list, noobs clean

export delimited using "$OUTPUT_TABLES/proximity_by_wave.csv", replace

di as text _n "============================================="
di as text "  Descriptive tables complete"
di as text "============================================="

log close
