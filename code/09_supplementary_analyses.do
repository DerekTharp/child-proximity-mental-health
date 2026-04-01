/*==============================================================================
  09_supplementary_analyses.do
  Child Proximity and Life Satisfaction in Retirement

  Nonmover robustness test: event study restricted to gain events where the
  parent did not relocate, isolating cases where the child moved closer.
  Contrasts nonmovers with movers to assess reverse causality.

  Data: HRS Cross-Wave Census Region/Division and Mobility File (v10, 2022)
        provides miles-moved between waves for each respondent.

  Input:  $ANALYSIS_DATA/analysis_final.dta
          $MOBILITY_DTA (set in 00_config.do)
  Output: $OUTPUT_TABLES/appendix_es_nonmover_at_gain.csv
          $OUTPUT_TABLES/appendix_es_never_moved.csv
          $OUTPUT_TABLES/appendix_es_mover_at_gain.csv
          $OUTPUT_TABLES/appendix_nonmover_summary.csv
==============================================================================*/

do "code/00_config.do"

log using "$OUTPUT_LOGS/09_supplementary_analyses.log", replace text

timer clear
timer on 1

* =============================================================================
* A. PREPARE MOBILITY DATA
* =============================================================================

di as text _n "=========================================="
di as text "  A: Preparing Mobility Data"
di as text "=========================================="

use HHID PN MOVE9294 MOVE9496 MOVE9698 MOVE9800 MOVE0002 MOVE0204 ///
    MOVE0406 MOVE0608 MOVE0810 MOVE1012 MOVE1214 MOVE1416 ///
    MOVE1618 MOVE1820 MOVE2022 using "$MOBILITY_DTA", clear

gen double hhidpn = real(strtrim(HHID)) * 1000 + real(strtrim(PN))
format hhidpn %12.0f
drop HHID PN

* Map MOVE variables to destination wave number
rename MOVE9294 miles_moved2
rename MOVE9496 miles_moved3
rename MOVE9698 miles_moved4
rename MOVE9800 miles_moved5
rename MOVE0002 miles_moved6
rename MOVE0204 miles_moved7
rename MOVE0406 miles_moved8
rename MOVE0608 miles_moved9
rename MOVE0810 miles_moved10
rename MOVE1012 miles_moved11
rename MOVE1214 miles_moved12
rename MOVE1416 miles_moved13
rename MOVE1618 miles_moved14
rename MOVE1820 miles_moved15
rename MOVE2022 miles_moved16

reshape long miles_moved, i(hhidpn) j(wave)
label var miles_moved "Miles respondent moved since prior wave"

compress
tempfile mobility_long
save `mobility_long'

di as text "  Mobility observations: " _N
distinct hhidpn
di as text "  Unique persons: " r(ndistinct)

* =============================================================================
* B. MERGE AND CLASSIFY
* =============================================================================

di as text _n "=========================================="
di as text "  B: Merge and classify movers"
di as text "=========================================="

use "$ANALYSIS_DATA/analysis_final.dta", clear
xtset hhidpn wave

merge 1:1 hhidpn wave using `mobility_long', keep(master match) nogenerate

count if miles_moved < .
di as text "  Person-waves with mobility data: " r(N)

* Parent nonmover at the gain event wave
gen parent_nonmover = (miles_moved == 0) if miles_moved < .
label var parent_nonmover "Parent did not move since prior wave"

gen _nm_at_event = .
replace _nm_at_event = (miles_moved == 0) ///
    if wave == first_gain_wave & miles_moved < . & first_gain_wave < .
bysort hhidpn: egen nonmover_at_gain = max(_nm_at_event)
drop _nm_at_event
label var nonmover_at_gain "Parent did not move in first gain event wave"

* Parent never moved in any observed wave
bysort hhidpn: egen _max_miles = max(miles_moved)
gen parent_never_moved = (_max_miles == 0) if _max_miles < .
drop _max_miles
label var parent_never_moved "Parent never moved across all observed waves"

* Report classification
preserve
    keep if sample_es_gain == 1
    bysort hhidpn: keep if _n == 1
    di as text _n "  Gain-event persons: " _N
    count if nonmover_at_gain == 1
    di as text "    Nonmover at gain: " r(N)
    count if nonmover_at_gain == 0
    di as text "    Mover at gain: " r(N)
    count if nonmover_at_gain == .
    di as text "    Missing mobility: " r(N)
    count if parent_never_moved == 1
    di as text "    Never moved (any wave): " r(N)
restore

tempfile analysis_mob
save `analysis_mob'

* =============================================================================
* C. EVENT STUDY: PARENT NONMOVER AT GAIN
* =============================================================================

di as text _n "=========================================="
di as text "  C: Nonmover at gain — event study"
di as text "=========================================="

keep if sample_es_gain == 1 & nonmover_at_gain == 1

di as text "  N person-waves: " _N
distinct hhidpn
di as text "  N persons: " r(ndistinct)

xtset hhidpn wave
xtreg cesd es_gain_m4 es_gain_m3 es_gain_m2 ///
    es_gain_p0 es_gain_p1 es_gain_p2 es_gain_p3 es_gain_p4 ///
    i.wave $FE_CONTROLS, fe cluster(hhidpn)
estimates store es_nonmover

* Pre-trend test
test es_gain_m4 es_gain_m3 es_gain_m2
di as text "  Pre-trend F = " %6.3f r(F) "  p = " %6.4f r(p)

* Export
matrix NM = J(8, 3, .)
local row = 1
foreach v in es_gain_m4 es_gain_m3 es_gain_m2 ///
    es_gain_p0 es_gain_p1 es_gain_p2 es_gain_p3 es_gain_p4 {
    matrix NM[`row', 1] = _b[`v']
    matrix NM[`row', 2] = _se[`v']
    if substr("`v'", 9, 1) == "m" {
        matrix NM[`row', 3] = -real(substr("`v'", 10, .))
    }
    else {
        matrix NM[`row', 3] = real(substr("`v'", 10, .))
    }
    local row = `row' + 1
}

preserve
    clear
    svmat NM, names(col)
    rename c1 coef
    rename c2 se
    rename c3 event_time
    gen ci_lo = coef - 1.96 * se
    gen ci_hi = coef + 1.96 * se
    gen spec = "nonmover_at_gain"
    export delimited using "$OUTPUT_TABLES/appendix_es_nonmover_at_gain.csv", replace
restore

* =============================================================================
* D. EVENT STUDY: PARENT NEVER MOVED
* =============================================================================

di as text _n "=========================================="
di as text "  D: Never-mover — event study"
di as text "=========================================="

use `analysis_mob', clear
keep if sample_es_gain == 1 & parent_never_moved == 1

di as text "  N person-waves: " _N
distinct hhidpn
di as text "  N persons: " r(ndistinct)

xtset hhidpn wave
xtreg cesd es_gain_m4 es_gain_m3 es_gain_m2 ///
    es_gain_p0 es_gain_p1 es_gain_p2 es_gain_p3 es_gain_p4 ///
    i.wave $FE_CONTROLS, fe cluster(hhidpn)
estimates store es_never_moved

test es_gain_m4 es_gain_m3 es_gain_m2
di as text "  Pre-trend F = " %6.3f r(F) "  p = " %6.4f r(p)

preserve
    clear
    matrix NV = J(8, 3, .)
    local row = 1
    foreach v in es_gain_m4 es_gain_m3 es_gain_m2 ///
        es_gain_p0 es_gain_p1 es_gain_p2 es_gain_p3 es_gain_p4 {
        estimates restore es_never_moved
        matrix NV[`row', 1] = _b[`v']
        matrix NV[`row', 2] = _se[`v']
        if substr("`v'", 9, 1) == "m" {
            matrix NV[`row', 3] = -real(substr("`v'", 10, .))
        }
        else {
            matrix NV[`row', 3] = real(substr("`v'", 10, .))
        }
        local row = `row' + 1
    }
    svmat NV, names(col)
    rename c1 coef
    rename c2 se
    rename c3 event_time
    gen ci_lo = coef - 1.96 * se
    gen ci_hi = coef + 1.96 * se
    gen spec = "never_moved"
    export delimited using "$OUTPUT_TABLES/appendix_es_never_moved.csv", replace
restore

* =============================================================================
* E. EVENT STUDY: PARENT MOVER AT GAIN (comparison)
* =============================================================================

di as text _n "=========================================="
di as text "  E: Mover at gain — event study (comparison)"
di as text "=========================================="

use `analysis_mob', clear
keep if sample_es_gain == 1 & nonmover_at_gain == 0

di as text "  N person-waves: " _N
distinct hhidpn
di as text "  N persons: " r(ndistinct)

xtset hhidpn wave
xtreg cesd es_gain_m4 es_gain_m3 es_gain_m2 ///
    es_gain_p0 es_gain_p1 es_gain_p2 es_gain_p3 es_gain_p4 ///
    i.wave $FE_CONTROLS, fe cluster(hhidpn)
estimates store es_mover

test es_gain_m4 es_gain_m3 es_gain_m2
di as text "  Pre-trend F = " %6.3f r(F) "  p = " %6.4f r(p)

preserve
    clear
    matrix MV = J(8, 3, .)
    local row = 1
    foreach v in es_gain_m4 es_gain_m3 es_gain_m2 ///
        es_gain_p0 es_gain_p1 es_gain_p2 es_gain_p3 es_gain_p4 {
        estimates restore es_mover
        matrix MV[`row', 1] = _b[`v']
        matrix MV[`row', 2] = _se[`v']
        if substr("`v'", 9, 1) == "m" {
            matrix MV[`row', 3] = -real(substr("`v'", 10, .))
        }
        else {
            matrix MV[`row', 3] = real(substr("`v'", 10, .))
        }
        local row = `row' + 1
    }
    svmat MV, names(col)
    rename c1 coef
    rename c2 se
    rename c3 event_time
    gen ci_lo = coef - 1.96 * se
    gen ci_hi = coef + 1.96 * se
    gen spec = "mover_at_gain"
    export delimited using "$OUTPUT_TABLES/appendix_es_mover_at_gain.csv", replace
restore

* =============================================================================
* F. SUMMARY TABLE
* =============================================================================

di as text _n "=========================================="
di as text "  F: Nonmover robustness summary"
di as text "=========================================="

di as text _n "  Spec                      | p0 coef   p0 SE    p1 coef   p1 SE     N"
di as text "  ----------------------------|--------------------------------------------------"

foreach m in es_nonmover es_never_moved es_mover {
    estimates restore `m'
    local b0 = _b[es_gain_p0]
    local se0 = _se[es_gain_p0]
    local b1 = _b[es_gain_p1]
    local se1 = _se[es_gain_p1]
    local n = e(N)
    di as text "  `m'" _col(30) "| " %8.4f `b0' " " %8.4f `se0' " " %8.4f `b1' " " %8.4f `se1' " " %8.0f `n'
}

preserve
    clear
    set obs 3
    gen spec = ""
    gen coef_p0 = .
    gen se_p0 = .
    gen coef_p1 = .
    gen se_p1 = .
    gen n_persons = .
    gen n_obs = .

    local r = 1
    foreach m in es_nonmover es_never_moved es_mover {
        estimates restore `m'
        if `r' == 1 replace spec = "nonmover_at_gain" in `r'
        if `r' == 2 replace spec = "never_moved" in `r'
        if `r' == 3 replace spec = "mover_at_gain" in `r'
        replace coef_p0 = _b[es_gain_p0] in `r'
        replace se_p0 = _se[es_gain_p0] in `r'
        replace coef_p1 = _b[es_gain_p1] in `r'
        replace se_p1 = _se[es_gain_p1] in `r'
        replace n_obs = e(N) in `r'
        replace n_persons = e(N_g) in `r'
        local r = `r' + 1
    }

    export delimited using "$OUTPUT_TABLES/appendix_nonmover_summary.csv", replace
restore

* =============================================================================

timer off 1
timer list 1

di as text _n "=========================================="
di as text "  Supplementary analyses complete"
di as text "  $S_DATE $S_TIME"
di as text "=========================================="

log close
