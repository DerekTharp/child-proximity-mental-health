/*==============================================================================
  05_analysis.do
  Child Proximity and Life Satisfaction in Retirement

  Main analysis:
    1. Cross-sectional OLS (Finke replication with progressive controls)
    2. Person fixed effects
    3. Event study — CES-D (primary, 2-year intervals)
    4. Event study — SWLS (confirmatory, coarser timing)
    5. Heterogeneity analysis
    6. Loss event analysis

  Input:  $ANALYSIS_DATA/analysis_final.dta
  Output: $OUTPUT_TABLES/table2_ols.csv
          $OUTPUT_TABLES/table3_fe.csv
          $OUTPUT_TABLES/table4_event_study_cesd.csv
==============================================================================*/

do "code/00_config.do"

log using "$OUTPUT_LOGS/05_analysis.log", replace text

use "$ANALYSIS_DATA/analysis_final.dta", clear
assert _N == 260762

* Set panel structure
xtset hhidpn wave

* =============================================================================
* MODEL 1: CROSS-SECTIONAL OLS (Finke Replication)
* =============================================================================

di as text _n "=========================================="
di as text "  MODEL 1: Cross-sectional OLS"
di as text "=========================================="

* Using CES-D (available every wave)
keep if sample_cesd_fe == 1

* (1a) Bivariate
di as text _n "--- 1a: Bivariate (CES-D) ---"
reg cesd any_near i.wave, cluster(hhidpn)
estimates store ols_1a

* (1b) + demographics
di as text _n "--- 1b: + Demographics ---"
reg cesd any_near i.wave $DEMOGRAPHICS, cluster(hhidpn)
estimates store ols_1b

* (1c) + health, marital status, age, N children
di as text _n "--- 1c: + Health, marital, age ---"
reg cesd any_near i.wave $DEMOGRAPHICS $TIME_VARYING, cluster(hhidpn)
estimates store ols_1c

* (1d) + wealth
di as text _n "--- 1d: + Wealth ---"
reg cesd any_near i.wave $DEMOGRAPHICS $TIME_VARYING $WEALTH, cluster(hhidpn)
estimates store ols_1d

* Export OLS table
estimates table ols_1a ols_1b ols_1c ols_1d, ///
    keep(any_near) b(%9.4f) se(%9.4f) stats(N r2)

* Save coefficients
matrix OLS = J(4, 4, .)
local col = 1
foreach m in ols_1a ols_1b ols_1c ols_1d {
    estimates restore `m'
    matrix OLS[1, `col'] = _b[any_near]
    matrix OLS[2, `col'] = _se[any_near]
    matrix OLS[3, `col'] = e(N)
    matrix OLS[4, `col'] = e(r2)
    local col = `col' + 1
}
matrix rownames OLS = coef se N r2
matrix colnames OLS = bivariate demographics health_marital wealth
matrix list OLS

preserve
    clear
    svmat OLS, names(col)
    gen stat = ""
    replace stat = "coef" in 1
    replace stat = "se" in 2
    replace stat = "N" in 3
    replace stat = "r2" in 4
    order stat
    export delimited using "$OUTPUT_TABLES/table2_ols.csv", replace
restore

* Repeat for SWLS (confirmatory)
di as text _n "--- OLS: SWLS (z-standardized) ---"
reg lbsatwlf_z any_near i.wave $DEMOGRAPHICS $TIME_VARYING $WEALTH ///
    if lbsatwlf_z < ., cluster(hhidpn)
estimates store ols_swls

* =============================================================================
* MODEL 2: PERSON FIXED EFFECTS
* =============================================================================

di as text _n "=========================================="
di as text "  MODEL 2: Person Fixed Effects"
di as text "=========================================="

* CES-D with FE
di as text _n "--- 2a: FE — CES-D ---"
xtreg cesd any_near i.wave $FE_CONTROLS, fe cluster(hhidpn)
estimates store fe_cesd

* CES-D with count (dose-response)
di as text _n "--- 2b: FE — CES-D, count of nearby children ---"
xtreg cesd lv10mikn i.wave $FE_CONTROLS, fe cluster(hhidpn)
estimates store fe_cesd_count

* SWLS with FE
di as text _n "--- 2c: FE — SWLS (z-standardized) ---"
xtreg lbsatwlf_z any_near i.wave $FE_CONTROLS ///
    if lbsatwlf_z < ., fe cluster(hhidpn)
estimates store fe_swls

* Loneliness with FE
di as text _n "--- 2d: FE — Loneliness ---"
xtreg lblonely3 any_near i.wave $FE_CONTROLS ///
    if lblonely3 < ., fe cluster(hhidpn)
estimates store fe_lonely

* Family satisfaction with FE
di as text _n "--- 2e: FE — Family satisfaction ---"
xtreg lbsatfam any_near i.wave $FE_CONTROLS ///
    if lbsatfam < ., fe cluster(hhidpn)
estimates store fe_satfam

* Export FE results
estimates table fe_cesd fe_cesd_count fe_swls fe_lonely fe_satfam, ///
    keep(any_near lv10mikn) b(%9.4f) se(%9.4f) stats(N r2_w)

* Save FE coefficients
matrix FE = J(4, 5, .)
local col = 1
foreach m in fe_cesd fe_cesd_count fe_swls fe_lonely fe_satfam {
    estimates restore `m'
    * Get the proximity coefficient (any_near or lv10mikn)
    if "`m'" == "fe_cesd_count" {
        matrix FE[1, `col'] = _b[lv10mikn]
        matrix FE[2, `col'] = _se[lv10mikn]
    }
    else {
        matrix FE[1, `col'] = _b[any_near]
        matrix FE[2, `col'] = _se[any_near]
    }
    matrix FE[3, `col'] = e(N)
    matrix FE[4, `col'] = e(r2_w)
    local col = `col' + 1
}
matrix rownames FE = coef se N r2_within
matrix colnames FE = cesd cesd_count swls loneliness fam_sat
matrix list FE

preserve
    clear
    svmat FE, names(col)
    gen stat = ""
    replace stat = "coef" in 1
    replace stat = "se" in 2
    replace stat = "N" in 3
    replace stat = "r2_within" in 4
    order stat
    export delimited using "$OUTPUT_TABLES/table3_fe.csv", replace
restore

* =============================================================================
* MODEL 3: EVENT STUDY — CES-D (Primary)
* =============================================================================

di as text _n "=========================================="
di as text "  MODEL 3: Event Study — CES-D (Gain)"
di as text "=========================================="

* Restrict to gain event study sample (save full data, work on subset)
tempfile full_data
save `full_data'
keep if sample_es_gain == 1

* Event study regression
* Omitted category: es_gain_m1 (t = -1, last pre-event period)
* Endpoints (m4, p4) are binned
xtreg cesd es_gain_m4 es_gain_m3 es_gain_m2 ///
    es_gain_p0 es_gain_p1 es_gain_p2 es_gain_p3 es_gain_p4 ///
    i.wave $FE_CONTROLS, fe cluster(hhidpn)
estimates store es_cesd_gain

* Extract coefficients for plotting
matrix ES_CESD = J(8, 3, .)
local row = 1
foreach v in es_gain_m4 es_gain_m3 es_gain_m2 ///
    es_gain_p0 es_gain_p1 es_gain_p2 es_gain_p3 es_gain_p4 {
    matrix ES_CESD[`row', 1] = _b[`v']
    matrix ES_CESD[`row', 2] = _se[`v']
    * Event time
    if substr("`v'", 9, 1) == "m" {
        local et = -real(substr("`v'", 10, .))
    }
    else {
        local et = real(substr("`v'", 10, .))
    }
    matrix ES_CESD[`row', 3] = `et'
    local row = `row' + 1
}
matrix colnames ES_CESD = coef se event_time
matrix list ES_CESD

* Pre-trend test: joint significance of pre-event dummies
di as text _n "--- Pre-trend F-test ---"
test es_gain_m4 es_gain_m3 es_gain_m2
local pretrend_F = r(F)
local pretrend_p = r(p)
di as text "  F = " %6.3f `pretrend_F' "  p = " %6.4f `pretrend_p'

* Save event study coefficients for plotting
preserve
    clear
    svmat ES_CESD, names(col)
    gen ci_lo = coef - 1.96 * se
    gen ci_hi = coef + 1.96 * se
    export delimited using "$OUTPUT_TABLES/table4_event_study_cesd.csv", replace
restore

* Reload full data
use `full_data', clear
xtset hhidpn wave

* =============================================================================
* MODEL 4: EVENT STUDY — SWLS (Confirmatory)
* =============================================================================

di as text _n "=========================================="
di as text "  MODEL 4: Event Study — SWLS (Gain)"
di as text "=========================================="

tempfile before_swls
save `before_swls'
keep if sample_es_gain == 1 & lbsatwlf_z < .

* SWLS event study (same dummies, but many will be zero since SWLS is sparse)
xtreg lbsatwlf_z es_gain_m4 es_gain_m3 es_gain_m2 ///
    es_gain_p0 es_gain_p1 es_gain_p2 es_gain_p3 es_gain_p4 ///
    i.wave $FE_CONTROLS, fe cluster(hhidpn)
estimates store es_swls_gain

* Pre-trend test
test es_gain_m4 es_gain_m3 es_gain_m2

use `before_swls', clear
xtset hhidpn wave

* =============================================================================
* MODEL 5: HETEROGENEITY
* =============================================================================

di as text _n "=========================================="
di as text "  MODEL 5: Heterogeneity"
di as text "=========================================="

tempfile before_het
save `before_het'
keep if sample_cesd_fe == 1

* 5a: By gender
di as text _n "--- 5a: Gender interaction ---"
xtreg cesd c.any_near##i.ragender i.wave $FE_CONTROLS, fe cluster(hhidpn)
estimates store het_gender

* 5b: By marital status (married vs not, time-varying)
* married created in 03_derived.do
di as text _n "--- 5b: Marital status interaction ---"
xtreg cesd c.any_near##c.married i.wave shlt agey_e child $WEALTH, ///
    fe cluster(hhidpn)
estimates store het_married

* 5c: By wealth tercile (baseline)
bysort hhidpn (wave): gen baseline_wealth = atotb if _n == 1
by hhidpn: replace baseline_wealth = baseline_wealth[1]
xtile wealth_terc = baseline_wealth, nq(3)
di as text _n "--- 5c: Wealth tercile interaction ---"
xtreg cesd c.any_near##i.wealth_terc i.wave $FE_CONTROLS, fe cluster(hhidpn)
estimates store het_wealth

* 5d: By health (good vs poor, self-rated health <= 3 vs > 3)
* good_health created in 03_derived.do
di as text _n "--- 5d: Health interaction ---"
xtreg cesd c.any_near##c.good_health i.wave i.mstat agey_e child $WEALTH, ///
    fe cluster(hhidpn)
estimates store het_health

* 5e: By number of children (above/below median)
sum child, detail
local med_child = r(p50)
gen many_kids = (child > `med_child') if child < .
di as text _n "--- 5e: Number of children interaction ---"
xtreg cesd c.any_near##c.many_kids i.wave $FE_CONTROLS, fe cluster(hhidpn)
estimates store het_nkids

* Export heterogeneity results
estimates table het_gender het_married het_wealth het_health het_nkids, ///
    keep(any_near *#c.any_near c.any_near#*) b(%9.4f) se(%9.4f) stats(N)

use `before_het', clear
xtset hhidpn wave

* =============================================================================
* MODEL 6: LOSS EVENT STUDY
* =============================================================================

di as text _n "=========================================="
di as text "  MODEL 6: Loss Event Study — CES-D"
di as text "=========================================="

tempfile before_loss
save `before_loss'
keep if sample_es_loss == 1

xtreg cesd es_loss_m4 es_loss_m3 es_loss_m2 ///
    es_loss_p0 es_loss_p1 es_loss_p2 es_loss_p3 es_loss_p4 ///
    i.wave $FE_CONTROLS, fe cluster(hhidpn)
estimates store es_cesd_loss

* Extract loss event coefficients
matrix ES_LOSS = J(8, 3, .)
local row = 1
foreach v in es_loss_m4 es_loss_m3 es_loss_m2 ///
    es_loss_p0 es_loss_p1 es_loss_p2 es_loss_p3 es_loss_p4 {
    matrix ES_LOSS[`row', 1] = _b[`v']
    matrix ES_LOSS[`row', 2] = _se[`v']
    if substr("`v'", 9, 1) == "m" {
        local et = -real(substr("`v'", 10, .))
    }
    else {
        local et = real(substr("`v'", 10, .))
    }
    matrix ES_LOSS[`row', 3] = `et'
    local row = `row' + 1
}

* Loss event coefficients exported by 06_robustness.do as appendix_es_loss.csv

* Pre-trend test
di as text _n "--- Loss pre-trend F-test ---"
test es_loss_m4 es_loss_m3 es_loss_m2

use `before_loss', clear

* =============================================================================

di as text _n "=========================================="
di as text "  Analysis complete"
di as text "  $S_DATE $S_TIME"
di as text "=========================================="

log close
