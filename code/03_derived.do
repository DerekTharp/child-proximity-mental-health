/*==============================================================================
  03_derived.do
  Child Proximity and Life Satisfaction in Retirement

  Creates derived measures for analysis:
    - Proximity event indicators (gain/loss of nearby child)
    - Event time variables and dummies
    - Classification flags (always-near, never-near, switchers)
    - Z-standardized SWLS
    - Health shock indicators
    - IHS-transformed wealth
    - Time-invariant personality composites

  Input:  $ANALYSIS_DATA/sample_main.dta
  Output: $ANALYSIS_DATA/analysis_final.dta
==============================================================================*/

do "code/00_config.do"

log using "$OUTPUT_LOGS/03_derived.log", replace text

use "$ANALYSIS_DATA/sample_main.dta", clear

* =============================================================================
* A. PROXIMITY INDICATORS
* =============================================================================

di as text _n "=== A: Creating proximity indicators ==="

* Binary: any child within 10 miles
gen any_near = (lv10mikn > 0) if lv10mikn < .
label var any_near "Any child lives within 10 miles"
label define yn 0 "No" 1 "Yes"
label values any_near yn

tab any_near if any_near < ., missing

* =============================================================================
* B. EVENT INDICATORS — First transition in any_near
* =============================================================================

di as text _n "=== B: Creating event indicators ==="

* Sort by person and wave
sort hhidpn wave

* Lagged proximity (previous observed wave)
* Only compute lag when the prior row is the immediately preceding wave
* (wave difference == 1). This avoids misclassifying transitions across
* gaps in observed proximity data (e.g., 0 -> missing -> 1).
by hhidpn: gen wave_gap = wave - wave[_n-1] if _n > 1
by hhidpn: gen any_near_lag = any_near[_n-1] if _n > 1 & wave_gap == 1 & any_near[_n-1] < .

* Identify transitions (only between consecutively observed waves)
gen gain_event = (any_near == 1 & any_near_lag == 0) if any_near < . & any_near_lag < .
gen loss_event = (any_near == 0 & any_near_lag == 1) if any_near < . & any_near_lag < .

* Report how many observations had non-adjacent waves
count if wave_gap > 1 & wave_gap < .
di as text "  Observations with non-adjacent prior wave (gap > 1): " r(N)
count if wave_gap == 1 & any_near < . & any_near[_n-1] < .
di as text "  Observations with valid adjacent-wave transition check: " r(N)
label var gain_event "Transition: no child near -> child near (this wave)"
label var loss_event "Transition: child near -> no child near (this wave)"

* First gain event wave (per person)
bysort hhidpn: egen first_gain_wave = min(cond(gain_event == 1, wave, .))
label var first_gain_wave "Wave of first 0->1 proximity transition"

* First loss event wave (per person)
bysort hhidpn: egen first_loss_wave = min(cond(loss_event == 1, wave, .))
label var first_loss_wave "Wave of first 1->0 proximity transition"

* Event time (relative to first gain)
gen event_time_gain = wave - first_gain_wave if first_gain_wave < .
label var event_time_gain "Waves relative to first gain event"

* Event time (relative to first loss)
gen event_time_loss = wave - first_loss_wave if first_loss_wave < .
label var event_time_loss "Waves relative to first loss event"

* =============================================================================
* C. CLASSIFICATION FLAGS
* =============================================================================

di as text _n "=== C: Classification flags ==="

* Count person-level proximity states
bysort hhidpn: egen n_near_waves = total(any_near == 1) if any_near < .
bysort hhidpn: egen n_prox_obs = count(any_near)
bysort hhidpn: egen n_gain_events = total(gain_event == 1) if gain_event < .
bysort hhidpn: egen n_loss_events = total(loss_event == 1) if loss_event < .

* Fill across waves within person
foreach v in n_near_waves n_prox_obs n_gain_events n_loss_events {
    bysort hhidpn: egen `v'_max = max(`v')
    drop `v'
    rename `v'_max `v'
}

* Classification
gen always_near  = (n_near_waves == n_prox_obs) if n_prox_obs > 0
gen never_near   = (n_near_waves == 0)          if n_prox_obs > 0
gen switcher     = (always_near == 0 & never_near == 0) if n_prox_obs > 0
gen clean_gainer = (n_gain_events == 1 & n_loss_events == 0) if switcher == 1
gen reverser     = (n_gain_events > 1 | (n_gain_events >= 1 & n_loss_events >= 1)) if switcher == 1

* Handle missing clean_gainer for non-switchers
replace clean_gainer = 0 if clean_gainer == . & switcher < .
replace reverser = 0 if reverser == . & switcher < .

label var always_near  "All observed waves: child within 10mi"
label var never_near   "All observed waves: no child within 10mi"
label var switcher     "At least one proximity transition"
label var clean_gainer "Exactly one 0->1 transition, no reversal"
label var reverser     "Multiple transitions (gain + loss or multiple gains)"

* Tabulate classification
di as text _n "Person classification (one row per person):"
preserve
    bysort hhidpn: keep if _n == 1
    tab always_near, missing
    tab never_near, missing
    tab switcher, missing
    tab clean_gainer if switcher == 1, missing
    tab reverser if switcher == 1, missing

    di as text "Always near: " _N * always_near[1] " (if constant)"
    count if always_near == 1
    di as text "  Always near: " r(N)
    count if never_near == 1
    di as text "  Never near: " r(N)
    count if switcher == 1
    di as text "  Switcher: " r(N)
    count if clean_gainer == 1
    di as text "    Clean gainer: " r(N)
    count if reverser == 1
    di as text "    Reverser: " r(N)
restore

* =============================================================================
* D. EVENT STUDY DUMMIES (CES-D — 2-year intervals)
* =============================================================================

di as text _n "=== D: Event study dummies ==="

* Gain event dummies for CES-D (available every wave)
forvalues k = -$ES_PRE_PERIODS / $ES_POST_PERIODS {
    if `k' < 0 {
        local vname "es_gain_m`=abs(`k')'"
    }
    else {
        local vname "es_gain_p`k'"
    }
    gen `vname' = (event_time_gain == `k') if event_time_gain < .
    replace `vname' = 0 if `vname' == .
    label var `vname' "Event time = `k' (gain)"
}

* Bin endpoints (absorb periods beyond the window)
replace es_gain_m${ES_PRE_PERIODS} = 1 if event_time_gain < -$ES_PRE_PERIODS & event_time_gain < .
replace es_gain_p${ES_POST_PERIODS} = 1 if event_time_gain > $ES_POST_PERIODS & event_time_gain < .

* Drop the omitted period (normalization to t-1)
drop es_gain_m1

* Loss event dummies (parallel structure)
forvalues k = -$ES_PRE_PERIODS / $ES_POST_PERIODS {
    if `k' < 0 {
        local vname "es_loss_m`=abs(`k')'"
    }
    else {
        local vname "es_loss_p`k'"
    }
    gen `vname' = (event_time_loss == `k') if event_time_loss < .
    replace `vname' = 0 if `vname' == .
    label var `vname' "Event time = `k' (loss)"
}
replace es_loss_m${ES_PRE_PERIODS} = 1 if event_time_loss < -$ES_PRE_PERIODS & event_time_loss < .
replace es_loss_p${ES_POST_PERIODS} = 1 if event_time_loss > $ES_POST_PERIODS & event_time_loss < .
drop es_loss_m1

* Event study sample flag: must have first_gain_wave, be in CES-D FE sample,
* AND have at least MIN_WAVES_ES waves of non-missing proximity data
bysort hhidpn: egen n_prox_waves_es = count(any_near)
gen sample_es_gain = (first_gain_wave < . & sample_cesd_fe == 1 & n_prox_waves_es >= $MIN_WAVES_ES)
label var sample_es_gain "In gain event study sample"

gen sample_es_loss = (first_loss_wave < . & sample_cesd_fe == 1 & n_prox_waves_es >= $MIN_WAVES_ES)
label var sample_es_loss "In loss event study sample"
drop n_prox_waves_es

count if sample_es_gain == 1
di as text "  Gain event study person-waves: " r(N)
distinct hhidpn if sample_es_gain == 1
di as text "  Gain event study persons: " r(ndistinct)

count if sample_es_loss == 1
di as text "  Loss event study person-waves: " r(N)
distinct hhidpn if sample_es_loss == 1
di as text "  Loss event study persons: " r(ndistinct)

* =============================================================================
* E. Z-STANDARDIZED SWLS
* =============================================================================

di as text _n "=== E: Z-standardizing SWLS ==="

* Z-standardize within wave to handle 1-6 vs 1-7 scale change
bysort wave: egen swls_mean = mean(lbsatwlf)
bysort wave: egen swls_sd   = sd(lbsatwlf)
gen lbsatwlf_z = (lbsatwlf - swls_mean) / swls_sd if lbsatwlf < .
label var lbsatwlf_z "Life satisfaction SWLS (z-standardized within wave)"
drop swls_mean swls_sd

sum lbsatwlf_z, detail

* =============================================================================
* F. ADDITIONAL DERIVED MEASURES
* =============================================================================

di as text _n "=== F: Additional derived measures ==="

* ---- IHS-transformed wealth ----
gen ihs_hatotb = ln(atotb + sqrt(atotb^2 + 1)) if atotb < .
label var ihs_hatotb "Household wealth (IHS-transformed)"

* ---- Health shock indicator ----
sort hhidpn wave
by hhidpn: gen shlt_change = shlt - shlt[_n-1] if _n > 1
gen health_shock = (shlt_change >= 2) if shlt_change < .
label var health_shock "Health decline of 2+ points (worse health)"

* ---- Widowhood transition ----
by hhidpn: gen mstat_lag = mstat[_n-1] if _n > 1
gen widowed_transition = (mstat == 7 & mstat_lag != 7) if mstat < . & mstat_lag < .
label var widowed_transition "Became widowed this wave"

* ---- Time-invariant personality (first non-missing value per person) ----
foreach trait in lbneur lbext lbopen lbagr lbcon5 {
    bysort hhidpn (wave): gen `trait'_first = `trait' if `trait' < .
    by hhidpn: replace `trait'_first = `trait'_first[_n-1] if `trait'_first == . & _n > 1
    by hhidpn: egen `trait'_ti = min(`trait'_first)
    drop `trait'_first
    label var `trait'_ti "Big 5: `trait' (time-invariant, first non-missing)"
}

* ---- Married indicator (time-varying) ----
gen married = (mstat == 1 | mstat == 2 | mstat == 3) if mstat < .
label var married "Currently married/partnered (time-varying)"

* ---- Good health indicator (time-varying) ----
gen good_health = (shlt <= 3) if shlt < .
label var good_health "Self-rated health good or better (time-varying)"

* ---- Race/ethnicity groups ----
gen race_eth = .
replace race_eth = 1 if raracem == 1 & rahispan == 0  // White non-Hispanic
replace race_eth = 2 if raracem == 2 & rahispan == 0  // Black non-Hispanic
replace race_eth = 3 if rahispan == 1                   // Hispanic (any race)
replace race_eth = 4 if race_eth == .                   // Other/missing
label define race_eth_lbl 1 "White NH" 2 "Black NH" 3 "Hispanic" 4 "Other"
label values race_eth race_eth_lbl
label var race_eth "Race/ethnicity (4 groups)"

* ---- Cohort indicators ----
gen cohort_group = .
replace cohort_group = 1 if hacohort <= 2  // AHEAD + CODA (born before 1931)
replace cohort_group = 2 if hacohort == 3  // HRS (born 1931-1941)
replace cohort_group = 3 if hacohort == 4  // War Babies (born 1942-1947)
replace cohort_group = 4 if hacohort == 5  // Early Boomers (born 1948-1953)
replace cohort_group = 5 if hacohort >= 6  // Mid/Late Boomers + Gen X
label define cohort_lbl 1 "AHEAD/CODA" 2 "HRS" 3 "War Babies" 4 "Early Boomers" 5 "Later cohorts"
label values cohort_group cohort_lbl
label var cohort_group "Birth cohort group"

* =============================================================================
* CLEAN UP
* =============================================================================

drop any_near_lag wave_gap shlt_change mstat_lag

compress
sort hhidpn wave
order hhidpn wave year ragender raedyrs raracem rahispan race_eth rabyear hacohort cohort_group ///
      agey_e shlt good_health mstat married work sayret atotb ihs_hatotb itot child wtresp ///
      lv10mikn any_near dist_gcd_min dist_gcd_mean n_children_far ///
      cesd lbsatwlf lbsatwlf_z lbsatfam lblonely3 lbwgtr ///
      first_gain_wave first_loss_wave event_time_gain event_time_loss ///
      always_near never_near switcher clean_gainer reverser ///
      sample_cesd_fe sample_swls_fe sample_retired sample_es_gain sample_es_loss ///
      health_shock widowed_transition

save "$ANALYSIS_DATA/analysis_final.dta", replace

di as text _n "============================================="
di as text "  analysis_final.dta saved"
di as text "  Observations: " _N
distinct hhidpn
di as text "  Unique respondents: " r(ndistinct)
di as text "============================================="

* Summary of event study sample
di as text _n "=== Event Study Summary ==="
di as text "  Gain events by wave:"
tab first_gain_wave if switcher == 1, missing

log close
