/*==============================================================================
  07_revision_analyses.do
  Additional analyses for SSM revision:
    1. Race/ethnicity split-sample event studies
    2. Gender split-sample event studies
    3. No-health-controls sensitivity
    4. Formal retirement interaction test
    5. Health interaction simple effects
    6. Fixed heterogeneity coefficient export

  Input:  $ANALYSIS_DATA/analysis_final.dta
  Output: $OUTPUT_TABLES/appendix_es_*.csv
==============================================================================*/

do "code/00_config.do"

log using "$OUTPUT_LOGS/07_revision_analyses.log", replace text

use "$ANALYSIS_DATA/analysis_final.dta", clear
xtset hhidpn wave

* =============================================================================
* 1. RACE/ETHNICITY SPLIT-SAMPLE EVENT STUDIES
* =============================================================================

di as text _n "=========================================="
di as text "  RACE/ETHNICITY EVENT STUDIES"
di as text "=========================================="

* race_eth created in 03_derived.do

tab race_eth if sample_es_gain == 1, missing

foreach r in 1 2 3 {
    local rlabel : label race_eth_lbl `r'
    di as text _n "--- Event study: `rlabel' ---"

    tempfile pre_race
    save `pre_race'
    keep if sample_es_gain == 1 & race_eth == `r'

    di "  N person-waves: " _N
    distinct hhidpn
    di "  N persons: " r(ndistinct)

    xtreg cesd es_gain_m4 es_gain_m3 es_gain_m2 ///
        es_gain_p0 es_gain_p1 es_gain_p2 es_gain_p3 es_gain_p4 ///
        i.wave $FE_CONTROLS, fe cluster(hhidpn)

    di _n "  Pre-trend test:"
    test es_gain_m4 es_gain_m3 es_gain_m2
    di "  F = " %6.3f r(F) "  p = " %6.4f r(p)

    * Extract coefficients
    matrix ES_R`r' = J(8, 3, .)
    local row = 1
    foreach v in es_gain_m4 es_gain_m3 es_gain_m2 ///
        es_gain_p0 es_gain_p1 es_gain_p2 es_gain_p3 es_gain_p4 {
        matrix ES_R`r'[`row', 1] = _b[`v']
        matrix ES_R`r'[`row', 2] = _se[`v']
        if substr("`v'", 9, 1) == "m" {
            matrix ES_R`r'[`row', 3] = -real(substr("`v'", 10, .))
        }
        else {
            matrix ES_R`r'[`row', 3] = real(substr("`v'", 10, .))
        }
        local row = `row' + 1
    }

    preserve
        clear
        svmat ES_R`r', names(col)
        rename c1 coef
        rename c2 se
        rename c3 event_time
        gen ci_lo = coef - 1.96 * se
        gen ci_hi = coef + 1.96 * se
        export delimited using "$OUTPUT_TABLES/appendix_es_race`r'.csv", replace
    restore

    use `pre_race', clear
    xtset hhidpn wave
}

* =============================================================================
* 2. GENDER SPLIT-SAMPLE EVENT STUDIES
* =============================================================================

di as text _n "=========================================="
di as text "  GENDER EVENT STUDIES"
di as text "=========================================="

* ragender: 1=Male, 2=Female

foreach g in 1 2 {
    local glabel "Male"
    if `g' == 2 local glabel "Female"
    di as text _n "--- Event study: `glabel' ---"

    tempfile pre_gender
    save `pre_gender'
    keep if sample_es_gain == 1 & ragender == `g'

    di "  N person-waves: " _N
    distinct hhidpn
    di "  N persons: " r(ndistinct)

    xtreg cesd es_gain_m4 es_gain_m3 es_gain_m2 ///
        es_gain_p0 es_gain_p1 es_gain_p2 es_gain_p3 es_gain_p4 ///
        i.wave $FE_CONTROLS, fe cluster(hhidpn)

    di _n "  Pre-trend test:"
    test es_gain_m4 es_gain_m3 es_gain_m2
    di "  F = " %6.3f r(F) "  p = " %6.4f r(p)

    use `pre_gender', clear
    xtset hhidpn wave
}

* =============================================================================
* 3. NO-HEALTH-CONTROLS SENSITIVITY
* =============================================================================

di as text _n "=========================================="
di as text "  NO-HEALTH-CONTROLS SENSITIVITY"
di as text "=========================================="

* Main spec controls for shlt (self-rated health). If shlt is on the causal
* pathway (proximity -> health -> CES-D), controlling for it attenuates the
* estimate. Run without health controls.

tempfile pre_nohealth
save `pre_nohealth'
keep if sample_es_gain == 1

di as text _n "--- With health controls (main spec) ---"
xtreg cesd es_gain_m4 es_gain_m3 es_gain_m2 ///
    es_gain_p0 es_gain_p1 es_gain_p2 es_gain_p3 es_gain_p4 ///
    i.wave $FE_CONTROLS, fe cluster(hhidpn)
estimates store es_with_health

di as text _n "--- Without health controls ---"
xtreg cesd es_gain_m4 es_gain_m3 es_gain_m2 ///
    es_gain_p0 es_gain_p1 es_gain_p2 es_gain_p3 es_gain_p4 ///
    i.wave i.mstat agey_e child $WEALTH, fe cluster(hhidpn)
estimates store es_no_health

di as text _n "--- Without health or wealth controls ---"
xtreg cesd es_gain_m4 es_gain_m3 es_gain_m2 ///
    es_gain_p0 es_gain_p1 es_gain_p2 es_gain_p3 es_gain_p4 ///
    i.wave i.mstat agey_e child, fe cluster(hhidpn)
estimates store es_minimal

estimates table es_with_health es_no_health es_minimal, ///
    keep(es_gain_m4 es_gain_m3 es_gain_m2 ///
         es_gain_p0 es_gain_p1 es_gain_p2 es_gain_p3 es_gain_p4) ///
    b(%9.4f) se(%9.4f) stats(N)

use `pre_nohealth', clear
xtset hhidpn wave

* =============================================================================
* 4. FORMAL RETIREMENT INTERACTION TEST
* =============================================================================

di as text _n "=========================================="
di as text "  RETIREMENT INTERACTION"
di as text "=========================================="

tempfile pre_retire
save `pre_retire'
keep if sample_es_gain == 1

* Pooled model with retirement*event_time interactions
di as text _n "--- Pooled model with retirement interaction ---"
gen retired = (sayret == 1) if sayret < .

xtreg cesd c.es_gain_p1##c.retired ///
    es_gain_m4 es_gain_m3 es_gain_m2 ///
    es_gain_p0 es_gain_p2 es_gain_p3 es_gain_p4 ///
    i.wave $FE_CONTROLS, fe cluster(hhidpn)

di as text "  Retirement x post-gain interaction p-value:"
test c.es_gain_p1#c.retired

use `pre_retire', clear
xtset hhidpn wave

* =============================================================================
* 5. HEALTH INTERACTION SIMPLE EFFECTS
* =============================================================================

di as text _n "=========================================="
di as text "  HEALTH INTERACTION SIMPLE EFFECTS"
di as text "=========================================="

tempfile pre_health
save `pre_health'
keep if sample_cesd_fe == 1

* good_health created in 03_derived.do

di as text _n "--- Full interaction model ---"
xtreg cesd c.any_near##c.good_health i.wave i.mstat agey_e child $WEALTH, ///
    fe cluster(hhidpn)

di as text _n "  Effect of any_near when good_health=0 (poor health):"
lincom any_near
di as text _n "  Effect of any_near when good_health=1 (good health):"
lincom any_near + c.any_near#c.good_health

use `pre_health', clear
xtset hhidpn wave

* Note: Heterogeneity coefficient export is handled by 08_fix_artifacts.do
* to avoid dual-write of table5_heterogeneity.csv.

di as text _n "=========================================="
di as text "  Revision analyses complete"
di as text "  $S_DATE $S_TIME"
di as text "=========================================="

log close
