/*==============================================================================
  02_sample.do
  Child Proximity and Life Satisfaction in Retirement

  Applies sequential sample restrictions and documents the flow.
  Creates separate sample flags for different analysis populations.

  Input:  $ANALYSIS_DATA/panel_raw.dta
  Output: $ANALYSIS_DATA/sample_main.dta
          $OUTPUT_TABLES/sample_flow.csv
==============================================================================*/

do "code/00_config.do"

log using "$OUTPUT_LOGS/02_sample.log", replace text

use "$ANALYSIS_DATA/panel_raw.dta", clear

* =============================================================================
* SAMPLE FLOW TRACKING
* =============================================================================

* Initialize the sample flow file
tempname flow
postfile `flow' str60 restriction long n_pw long n_persons using ///
    "$OUTPUT_TABLES/sample_flow.dta", replace

* Starting sample
distinct hhidpn
local n0_pw = _N
local n0_id = r(ndistinct)
post `flow' ("0. All person-wave observations") (`n0_pw') (`n0_id')
di as text "0. Starting: " `n0_pw' " person-waves, " `n0_id' " persons"

* =============================================================================
* RESTRICTION 1: Age >= 50 at interview
* =============================================================================

drop if agey_e < $MIN_AGE & agey_e < .
drop if agey_e == .
assert _N == 285895

distinct hhidpn
local n1_pw = _N
local n1_id = r(ndistinct)
post `flow' ("1. Age >= $MIN_AGE at interview") (`n1_pw') (`n1_id')
di as text "1. Age >= $MIN_AGE: " `n1_pw' " person-waves, " `n1_id' " persons"

* =============================================================================
* RESTRICTION 2: Has at least one living child (ever)
* =============================================================================

* child = number of living children. Drop persons who never report any children.
bysort hhidpn: egen max_child = max(child)
drop if max_child == 0 | max_child == .
drop max_child
assert _N == 266423

distinct hhidpn
local n2_pw = _N
local n2_id = r(ndistinct)
post `flow' ("2. Has living children (ever)") (`n2_pw') (`n2_id')
di as text "2. Has children: " `n2_pw' " person-waves, " `n2_id' " persons"

* =============================================================================
* RESTRICTION 3: Non-missing proximity data in at least one wave
* =============================================================================

* lv10mikn is the count of kids within 10 miles from Family Data
* Missing values include .: standard missing, and special codes
bysort hhidpn: egen n_prox_waves = count(lv10mikn)
drop if n_prox_waves == 0
drop n_prox_waves
assert _N == 260762

distinct hhidpn
local n3_pw = _N
local n3_id = r(ndistinct)
post `flow' ("3. Non-missing proximity (any wave)") (`n3_pw') (`n3_id')
di as text "3. Has proximity data: " `n3_pw' " person-waves, " `n3_id' " persons"

* =============================================================================
* CREATE ANALYSIS SAMPLE FLAGS
* =============================================================================

* ---- Flag: CES-D FE sample (primary event study) ----
* Requires 2+ waves with BOTH non-missing cesd AND non-missing lv10mikn
gen has_cesd_prox = (cesd < . & lv10mikn < .)
bysort hhidpn: egen n_cesd_prox = total(has_cesd_prox)
gen sample_cesd_fe = (n_cesd_prox >= $MIN_WAVES_FE)
drop has_cesd_prox n_cesd_prox
label var sample_cesd_fe "In CES-D FE sample (2+ waves cesd & proximity)"

* ---- Flag: SWLS FE sample (confirmatory) ----
gen has_swls_prox = (lbsatwlf < . & lv10mikn < .)
bysort hhidpn: egen n_swls_prox = total(has_swls_prox)
gen sample_swls_fe = (n_swls_prox >= $MIN_WAVES_FE)
drop has_swls_prox n_swls_prox
label var sample_swls_fe "In SWLS FE sample (2+ waves swls & proximity)"

* ---- Flag: Retiree subsample ----
gen sample_retired = (sayret == 1) if sayret < .
label var sample_retired "Considers self retired (wave-specific)"

* ---- Document sample flags ----
count if sample_cesd_fe == 1
local n_cesd_fe = r(N)
distinct hhidpn if sample_cesd_fe == 1
local n_cesd_fe_id = r(ndistinct)
post `flow' ("4a. CES-D FE sample (2+ waves)") (`n_cesd_fe') (`n_cesd_fe_id')
di as text "4a. CES-D FE sample: " `n_cesd_fe' " person-waves, " `n_cesd_fe_id' " persons"

count if sample_swls_fe == 1
local n_swls_fe = r(N)
distinct hhidpn if sample_swls_fe == 1
local n_swls_fe_id = r(ndistinct)
post `flow' ("4b. SWLS FE sample (2+ waves)") (`n_swls_fe') (`n_swls_fe_id')
di as text "4b. SWLS FE sample: " `n_swls_fe' " person-waves, " `n_swls_fe_id' " persons"

count if sample_retired == 1
local n_ret = r(N)
distinct hhidpn if sample_retired == 1
local n_ret_id = r(ndistinct)
post `flow' ("4c. Retiree person-waves") (`n_ret') (`n_ret_id')
di as text "4c. Retirees: " `n_ret' " person-waves, " `n_ret_id' " persons"

postclose `flow'

* =============================================================================
* BASIC DESCRIPTIVES OF PROXIMITY
* =============================================================================

di as text _n "=== Proximity Distribution (non-missing waves) ==="

tab lv10mikn if lv10mikn < ., missing

di as text _n "=== Proximity by wave ==="
tab wave lv10mikn if lv10mikn < . & lv10mikn <= 10, row

* =============================================================================
* SAVE
* =============================================================================

compress
sort hhidpn wave

save "$ANALYSIS_DATA/sample_main.dta", replace

di as text _n "============================================="
di as text "  sample_main.dta saved"
di as text "  Observations: " _N
distinct hhidpn
di as text "  Unique respondents: " r(ndistinct)
di as text "============================================="

log close
