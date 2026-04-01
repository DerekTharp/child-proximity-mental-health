/*==============================================================================
  08_fix_artifacts.do
  Export final analysis tables and derived variables:
    1. Export real CSV sample_flow
    2. Export by-proximity Table 1 descriptives
    3. Export heterogeneity interaction table (table5_heterogeneity.csv)
    4. Export race/ethnicity and gender subgroup summary tables
    5. Pooled race interaction tests
==============================================================================*/

do "code/00_config.do"

log using "$OUTPUT_LOGS/08_fix_artifacts.log", replace text

* =============================================================================
* 1. REAL CSV SAMPLE FLOW
* =============================================================================

di as text _n "=== 1. Exporting sample_flow as real CSV ==="

* The sample_flow.dta was created by postfile. Convert to CSV.
use "$OUTPUT_TABLES/sample_flow.dta", clear
export delimited using "$OUTPUT_TABLES/sample_flow_clean.csv", replace
list, noobs clean
di "  Exported sample_flow_clean.csv"

* =============================================================================
* 2. BY-PROXIMITY TABLE 1
* =============================================================================

di as text _n "=== 2. By-proximity Table 1 ==="

use "$ANALYSIS_DATA/analysis_final.dta", clear
keep if sample_cesd_fe == 1

* Create proximity group
gen prox_group = .
replace prox_group = 1 if always_near == 1
replace prox_group = 2 if never_near == 1
replace prox_group = 3 if switcher == 1

* Overall + by-group descriptives
* Use one observation per person for demographics
bysort hhidpn (wave): gen first_obs = (_n == 1)

* Export by-group table
preserve
    keep if first_obs == 1

    * Compute means by group
    collapse (mean) mean_age=agey_e pct_female=ragender mean_educ=raedyrs ///
                    mean_shlt=shlt mean_cesd=cesd mean_wealth=atotb ///
                    mean_nkids=child mean_near=lv10mikn ///
             (sd) sd_age=agey_e sd_cesd=cesd sd_wealth=atotb ///
             (count) n_persons=hhidpn, by(prox_group)

    * ragender is 1=male, 2=female; convert to pct female
    replace pct_female = (pct_female - 1) * 100

    export delimited using "$OUTPUT_TABLES/table1_by_proximity.csv", replace
    list, noobs clean
restore

di "  Exported table1_by_proximity.csv"

* =============================================================================
* 3. FIXED HETEROGENEITY EXPORT
* =============================================================================

di as text _n "=== 3. Fixed heterogeneity export ==="

xtset hhidpn wave

* Run each interaction model and manually extract coefficients

* Gender
gen female = (ragender == 2)
xtreg cesd c.any_near##c.female i.wave $FE_CONTROLS, fe cluster(hhidpn)
local g_b = _b[c.any_near#c.female]
local g_se = _se[c.any_near#c.female]
local g_p = 2 * ttail(e(df_r), abs(`g_b'/`g_se'))
local g_n = e(N)

* Married (created in 03_derived.do)
xtreg cesd c.any_near##c.married i.wave shlt agey_e child $WEALTH, fe cluster(hhidpn)
local m_b = _b[c.any_near#c.married]
local m_se = _se[c.any_near#c.married]
local m_p = 2 * ttail(e(df_r), abs(`m_b'/`m_se'))
local m_n = e(N)

* Health (good_health created in 03_derived.do)
xtreg cesd c.any_near##c.good_health i.wave i.mstat agey_e child $WEALTH, fe cluster(hhidpn)
local h_b = _b[c.any_near#c.good_health]
local h_se = _se[c.any_near#c.good_health]
local h_p = 2 * ttail(e(df_r), abs(`h_b'/`h_se'))
local h_n = e(N)
* Simple effects
lincom any_near
local h_poor_b = r(estimate)
local h_poor_se = r(se)
lincom any_near + c.any_near#c.good_health
local h_good_b = r(estimate)
local h_good_se = r(se)

* N children
sum child, detail
local med_child = r(p50)
gen many_kids = (child > `med_child') if child < .
xtreg cesd c.any_near##c.many_kids i.wave $FE_CONTROLS, fe cluster(hhidpn)
local k_b = _b[c.any_near#c.many_kids]
local k_se = _se[c.any_near#c.many_kids]
local k_p = 2 * ttail(e(df_r), abs(`k_b'/`k_se'))
local k_n = e(N)

* Write to CSV using file handle (avoids input command issues)
tempname fh
file open `fh' using "$OUTPUT_TABLES/table5_heterogeneity.csv", write replace
file write `fh' "moderator,interaction_coef,interaction_se,p_value,N,notes" _n
file write `fh' "Female," (`g_b') "," (`g_se') "," (`g_p') "," (`g_n') ",time-invariant; absorbed by FE" _n
file write `fh' "Married," (`m_b') "," (`m_se') "," (`m_p') "," (`m_n') ",time-varying" _n
file write `fh' "Good health," (`h_b') "," (`h_se') "," (`h_p') "," (`h_n') ",poor health simple effect=" (`h_poor_b') " SE=" (`h_poor_se') "; good health simple effect=" (`h_good_b') " SE=" (`h_good_se') _n
file write `fh' "Many children," (`k_b') "," (`k_se') "," (`k_p') "," (`k_n') "," _n
file close `fh'

di "  Exported table5_heterogeneity.csv"
type "$OUTPUT_TABLES/table5_heterogeneity.csv"

drop female many_kids

* =============================================================================
* 4. SUBGROUP SUMMARY TABLE
* =============================================================================

di as text _n "=== 4. Subgroup summary table ==="

* race_eth created in 03_derived.do

tempname fh2
file open `fh2' using "$OUTPUT_TABLES/appendix_subgroup_summary.csv", write replace
file write `fh2' "subgroup,n_persons,n_person_waves,es_gain_p1_coef,es_gain_p1_se,es_gain_p1_p,pretrend_F,pretrend_p" _n

foreach r in 1 2 3 {
    local rlabel "White NH"
    if `r' == 2 local rlabel "Black NH"
    if `r' == 3 local rlabel "Hispanic"

    preserve
    keep if sample_es_gain == 1 & race_eth == `r'
    local npw = _N
    distinct hhidpn
    local np = r(ndistinct)

    xtreg cesd es_gain_m4 es_gain_m3 es_gain_m2 ///
        es_gain_p0 es_gain_p1 es_gain_p2 es_gain_p3 es_gain_p4 ///
        i.wave $FE_CONTROLS, fe cluster(hhidpn)

    local coef = _b[es_gain_p1]
    local se = _se[es_gain_p1]
    local pval = 2 * ttail(e(df_r), abs(`coef'/`se'))

    test es_gain_m4 es_gain_m3 es_gain_m2
    local ptf = r(F)
    local ptp = r(p)

    file write `fh2' "`rlabel'," (`np') "," (`npw') "," (`coef') "," (`se') "," (`pval') "," (`ptf') "," (`ptp') _n
    restore
}

* Gender
foreach g in 1 2 {
    local glabel "Male"
    if `g' == 2 local glabel "Female"

    preserve
    keep if sample_es_gain == 1 & ragender == `g'
    local npw = _N
    distinct hhidpn
    local np = r(ndistinct)

    xtreg cesd es_gain_m4 es_gain_m3 es_gain_m2 ///
        es_gain_p0 es_gain_p1 es_gain_p2 es_gain_p3 es_gain_p4 ///
        i.wave $FE_CONTROLS, fe cluster(hhidpn)

    local coef = _b[es_gain_p1]
    local se = _se[es_gain_p1]
    local pval = 2 * ttail(e(df_r), abs(`coef'/`se'))

    test es_gain_m4 es_gain_m3 es_gain_m2
    local ptf = r(F)
    local ptp = r(p)

    file write `fh2' "`glabel'," (`np') "," (`npw') "," (`coef') "," (`se') "," (`pval') "," (`ptf') "," (`ptp') _n
    restore
}

* Retirees
foreach ret in 1 0 {
    local rlabel "Retiree"
    if `ret' == 0 local rlabel "Non-retiree"

    preserve
    if `ret' == 1 {
        keep if sample_es_gain == 1 & sayret == 1
    }
    else {
        keep if sample_es_gain == 1 & sayret == 0
    }
    local npw = _N
    distinct hhidpn
    local np = r(ndistinct)

    xtreg cesd es_gain_m4 es_gain_m3 es_gain_m2 ///
        es_gain_p0 es_gain_p1 es_gain_p2 es_gain_p3 es_gain_p4 ///
        i.wave $FE_CONTROLS, fe cluster(hhidpn)

    local coef = _b[es_gain_p1]
    local se = _se[es_gain_p1]
    local pval = 2 * ttail(e(df_r), abs(`coef'/`se'))

    test es_gain_m4 es_gain_m3 es_gain_m2
    local ptf = r(F)
    local ptp = r(p)

    file write `fh2' "`rlabel'," (`np') "," (`npw') "," (`coef') "," (`se') "," (`pval') "," (`ptf') "," (`ptp') _n
    restore
}

file close `fh2'

di "  Exported appendix_subgroup_summary.csv"
type "$OUTPUT_TABLES/appendix_subgroup_summary.csv"

* =============================================================================
* 5. POOLED RACE INTERACTION TESTS
* =============================================================================

di as text _n "=== 5. Pooled race interaction tests ==="

preserve
keep if sample_es_gain == 1

gen race_eth2 = .
replace race_eth2 = 1 if raracem == 1 & rahispan == 0
replace race_eth2 = 2 if raracem == 2 & rahispan == 0
replace race_eth2 = 3 if rahispan == 1

* Interaction: race x es_gain_p1 (the key post-gain coefficient)
xtreg cesd c.es_gain_p1##i.race_eth2 ///
    es_gain_m4 es_gain_m3 es_gain_m2 ///
    es_gain_p0 es_gain_p2 es_gain_p3 es_gain_p4 ///
    i.wave $FE_CONTROLS, fe cluster(hhidpn)

di as text _n "  Joint test: race x es_gain_p1"
test 2.race_eth2#c.es_gain_p1 3.race_eth2#c.es_gain_p1
di "  F = " %6.3f r(F) "  p = " %6.4f r(p)

di as text _n "  Black NH vs White NH:"
lincom 2.race_eth2#c.es_gain_p1
di as text _n "  Hispanic vs White NH:"
lincom 3.race_eth2#c.es_gain_p1

restore

di as text _n "=========================================="
di as text "  Artifact fixes complete"
di as text "  $S_DATE $S_TIME"
di as text "=========================================="

log close
