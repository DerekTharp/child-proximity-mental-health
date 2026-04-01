/*==============================================================================
  06_robustness.do
  Child Proximity and Life Satisfaction in Retirement

  Robustness and sensitivity analyses:
    1. Clean gainers only (no reversals)
    2. Exclude health shock periods
    3. Retiree subsample
    4. COVID sensitivity (drop waves 15-16)
    5. Loss event study
    6. Alternative outcomes (SWLS, loneliness, family satisfaction)
    7. Dose-response: count of nearby children

  Input:  $ANALYSIS_DATA/analysis_final.dta
  Output: $OUTPUT_TABLES/appendix_*.csv
==============================================================================*/

do "code/00_config.do"

log using "$OUTPUT_LOGS/06_robustness.log", replace text

use "$ANALYSIS_DATA/analysis_final.dta", clear
xtset hhidpn wave

* =============================================================================
* 1. CLEAN GAINERS ONLY (no reversals)
* =============================================================================

di as text _n "=========================================="
di as text "  ROBUSTNESS 1: Clean gainers only"
di as text "=========================================="

tempfile full
save `full'

keep if sample_es_gain == 1 & clean_gainer == 1

di as text "  N person-waves: " _N
distinct hhidpn
di as text "  N persons: " r(ndistinct)

xtreg cesd es_gain_m4 es_gain_m3 es_gain_m2 ///
    es_gain_p0 es_gain_p1 es_gain_p2 es_gain_p3 es_gain_p4 ///
    i.wave $FE_CONTROLS, fe cluster(hhidpn)
estimates store rob_clean

* Extract coefficients
matrix ROB1 = J(8, 3, .)
local row = 1
foreach v in es_gain_m4 es_gain_m3 es_gain_m2 ///
    es_gain_p0 es_gain_p1 es_gain_p2 es_gain_p3 es_gain_p4 {
    matrix ROB1[`row', 1] = _b[`v']
    matrix ROB1[`row', 2] = _se[`v']
    if substr("`v'", 9, 1) == "m" {
        matrix ROB1[`row', 3] = -real(substr("`v'", 10, .))
    }
    else {
        matrix ROB1[`row', 3] = real(substr("`v'", 10, .))
    }
    local row = `row' + 1
}

preserve
    clear
    svmat ROB1, names(col)
    rename c1 coef
    rename c2 se
    rename c3 event_time
    gen ci_lo = coef - 1.96 * se
    gen ci_hi = coef + 1.96 * se
    export delimited using "$OUTPUT_TABLES/appendix_es_clean_gainers.csv", replace
restore

* Pre-trend test
test es_gain_m4 es_gain_m3 es_gain_m2
di as text "  Pre-trend F = " %6.3f r(F) "  p = " %6.4f r(p)

use `full', clear
xtset hhidpn wave

* =============================================================================
* 2. EXCLUDE HEALTH SHOCK PERIODS
* =============================================================================

di as text _n "=========================================="
di as text "  ROBUSTNESS 2: Exclude health shocks"
di as text "=========================================="

save `full', replace
keep if sample_es_gain == 1 & (health_shock == 0 | health_shock == .)

di as text "  N person-waves (no health shocks): " _N
distinct hhidpn

xtreg cesd es_gain_m4 es_gain_m3 es_gain_m2 ///
    es_gain_p0 es_gain_p1 es_gain_p2 es_gain_p3 es_gain_p4 ///
    i.wave $FE_CONTROLS, fe cluster(hhidpn)
estimates store rob_noshock

* Pre-trend
test es_gain_m4 es_gain_m3 es_gain_m2
di as text "  Pre-trend F = " %6.3f r(F) "  p = " %6.4f r(p)

use `full', clear
xtset hhidpn wave

* =============================================================================
* 3. RETIREE SUBSAMPLE
* =============================================================================

di as text _n "=========================================="
di as text "  ROBUSTNESS 3: Retiree subsample"
di as text "=========================================="

* FE model on retirees only
save `full', replace
keep if sample_cesd_fe == 1 & sample_retired == 1

di as text "  N retiree person-waves: " _N
distinct hhidpn

xtreg cesd any_near i.wave $FE_CONTROLS, fe cluster(hhidpn)
estimates store rob_retired_fe

* OLS on retirees (Finke comparison)
reg cesd any_near i.wave $DEMOGRAPHICS $TIME_VARYING $WEALTH, cluster(hhidpn)
estimates store rob_retired_ols

di as text "  Retiree FE: any_near = " %9.4f _b[any_near] " (from last est)"
estimates restore rob_retired_fe
di as text "  Retiree FE: any_near = " %9.4f _b[any_near]

use `full', clear
xtset hhidpn wave

* =============================================================================
* 4. COVID SENSITIVITY (drop waves 15-16)
* =============================================================================

di as text _n "=========================================="
di as text "  ROBUSTNESS 4: Exclude COVID waves (15-16)"
di as text "=========================================="

save `full', replace
keep if sample_es_gain == 1 & wave <= 14

di as text "  N person-waves (pre-COVID): " _N
distinct hhidpn

xtreg cesd es_gain_m4 es_gain_m3 es_gain_m2 ///
    es_gain_p0 es_gain_p1 es_gain_p2 es_gain_p3 es_gain_p4 ///
    i.wave $FE_CONTROLS, fe cluster(hhidpn)
estimates store rob_nocovid

test es_gain_m4 es_gain_m3 es_gain_m2
di as text "  Pre-trend F = " %6.3f r(F) "  p = " %6.4f r(p)

use `full', clear
xtset hhidpn wave

* =============================================================================
* 5. LOSS EVENT STUDY
* =============================================================================

di as text _n "=========================================="
di as text "  ROBUSTNESS 5: Loss event study"
di as text "=========================================="

save `full', replace
keep if sample_es_loss == 1

di as text "  N person-waves (loss sample): " _N
distinct hhidpn
di as text "  N persons: " r(ndistinct)

xtreg cesd es_loss_m4 es_loss_m3 es_loss_m2 ///
    es_loss_p0 es_loss_p1 es_loss_p2 es_loss_p3 es_loss_p4 ///
    i.wave $FE_CONTROLS, fe cluster(hhidpn)
estimates store rob_loss

* Extract loss event coefficients
matrix LOSS = J(8, 3, .)
local row = 1
foreach v in es_loss_m4 es_loss_m3 es_loss_m2 ///
    es_loss_p0 es_loss_p1 es_loss_p2 es_loss_p3 es_loss_p4 {
    matrix LOSS[`row', 1] = _b[`v']
    matrix LOSS[`row', 2] = _se[`v']
    if substr("`v'", 9, 1) == "m" {
        matrix LOSS[`row', 3] = -real(substr("`v'", 10, .))
    }
    else {
        matrix LOSS[`row', 3] = real(substr("`v'", 10, .))
    }
    local row = `row' + 1
}

preserve
    clear
    svmat LOSS, names(col)
    rename c1 coef
    rename c2 se
    rename c3 event_time
    gen ci_lo = coef - 1.96 * se
    gen ci_hi = coef + 1.96 * se
    export delimited using "$OUTPUT_TABLES/appendix_es_loss.csv", replace
restore

test es_loss_m4 es_loss_m3 es_loss_m2
di as text "  Loss pre-trend F = " %6.3f r(F) "  p = " %6.4f r(p)

use `full', clear
xtset hhidpn wave

* =============================================================================
* 6. ALTERNATIVE OUTCOMES (Event study)
* =============================================================================

di as text _n "=========================================="
di as text "  ROBUSTNESS 6: Alternative outcomes"
di as text "=========================================="

save `full', replace
keep if sample_es_gain == 1

* 6a: SWLS event study
di as text _n "--- 6a: SWLS (z-standardized) ---"
xtreg lbsatwlf_z es_gain_m4 es_gain_m3 es_gain_m2 ///
    es_gain_p0 es_gain_p1 es_gain_p2 es_gain_p3 es_gain_p4 ///
    i.wave $FE_CONTROLS if lbsatwlf_z < ., fe cluster(hhidpn)
estimates store rob_swls_es

* 6b: Loneliness event study
di as text _n "--- 6b: Loneliness ---"
xtreg lblonely3 es_gain_m4 es_gain_m3 es_gain_m2 ///
    es_gain_p0 es_gain_p1 es_gain_p2 es_gain_p3 es_gain_p4 ///
    i.wave $FE_CONTROLS if lblonely3 < ., fe cluster(hhidpn)
estimates store rob_lonely_es

* 6c: Family satisfaction event study
di as text _n "--- 6c: Family satisfaction ---"
xtreg lbsatfam es_gain_m4 es_gain_m3 es_gain_m2 ///
    es_gain_p0 es_gain_p1 es_gain_p2 es_gain_p3 es_gain_p4 ///
    i.wave $FE_CONTROLS if lbsatfam < ., fe cluster(hhidpn)
estimates store rob_satfam_es

* Export secondary outcome event-time coefficients
preserve
    clear
    set obs 24
    gen outcome = ""
    gen event_time = .
    gen coef = .
    gen se = .

    local row = 1
    foreach m in rob_swls_es rob_lonely_es rob_satfam_es {
        if "`m'" == "rob_swls_es"   local oname "swls_z"
        if "`m'" == "rob_lonely_es" local oname "loneliness"
        if "`m'" == "rob_satfam_es" local oname "family_sat"
        estimates restore `m'
        foreach v in es_gain_m4 es_gain_m3 es_gain_m2 ///
            es_gain_p0 es_gain_p1 es_gain_p2 es_gain_p3 es_gain_p4 {
            replace outcome = "`oname'" in `row'
            replace coef = _b[`v'] in `row'
            replace se = _se[`v'] in `row'
            if substr("`v'", 9, 1) == "m" {
                replace event_time = -real(substr("`v'", 10, .)) in `row'
            }
            else {
                replace event_time = real(substr("`v'", 10, .)) in `row'
            }
            local row = `row' + 1
        }
    }
    gen ci_lo = coef - 1.96 * se
    gen ci_hi = coef + 1.96 * se
    order outcome event_time coef se ci_lo ci_hi
    export delimited using "$OUTPUT_TABLES/appendix_secondary_outcomes.csv", replace
restore

use `full', clear
xtset hhidpn wave

* =============================================================================
* 7. DOSE-RESPONSE: Count of nearby children (FE)
* =============================================================================

di as text _n "=========================================="
di as text "  ROBUSTNESS 7: Dose-response"
di as text "=========================================="

save `full', replace
keep if sample_cesd_fe == 1

* Categorize count
gen near_cat = 0 if lv10mikn == 0
replace near_cat = 1 if lv10mikn == 1
replace near_cat = 2 if lv10mikn == 2
replace near_cat = 3 if lv10mikn >= 3 & lv10mikn < .
label define near_cat_lbl 0 "None" 1 "One" 2 "Two" 3 "Three+"
label values near_cat near_cat_lbl

di as text _n "--- Dose-response: CES-D ---"
xtreg cesd i.near_cat i.wave $FE_CONTROLS, fe cluster(hhidpn)
estimates store rob_dose

* Compare 0 vs 1 vs 2 vs 3+
estimates table rob_dose, keep(1.near_cat 2.near_cat 3.near_cat) ///
    b(%9.4f) se(%9.4f) stats(N)

use `full', clear

* =============================================================================
* SUMMARY TABLE: All robustness results
* =============================================================================

di as text _n "=========================================="
di as text "  ROBUSTNESS SUMMARY"
di as text "=========================================="

* Collect key coefficients from all robustness checks
di as text _n "  Specification                   | Coef     SE       p      N"
di as text "  --------------------------------|----------------------------------"

foreach m in rob_clean rob_noshock rob_nocovid {
    estimates restore `m'
    local b = _b[es_gain_p1]
    local se = _se[es_gain_p1]
    local p = 2 * ttail(e(df_r), abs(`b'/`se'))
    local n = e(N)
    di as text "  `m'" _col(36) "| " %8.4f `b' " " %8.4f `se' " " %6.4f `p' " " %8.0f `n'
}

estimates restore rob_retired_fe
local b = _b[any_near]
local se = _se[any_near]
local p = 2 * ttail(e(df_r), abs(`b'/`se'))
local n = e(N)
di as text "  rob_retired_fe" _col(36) "| " %8.4f `b' " " %8.4f `se' " " %6.4f `p' " " %8.0f `n'

di as text _n "=========================================="
di as text "  Robustness complete"
di as text "  $S_DATE $S_TIME"
di as text "=========================================="

log close
