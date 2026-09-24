*===============================================================================
* EYUG analysis
* -------------------------------------------------------------------------------
* Life-table, "Expected Years as University Graduate" (EYUG) and exact
* decomposition analysis, implementing the Methods section:
*
*   Step 1 & 2  Life-table cumulative probability of graduation by age (a),
*               absolute/relative background differences, and EYUG (Eq. 1-2),
*               following Preston, Heuveline & Guillot (2001).
*   Step 2b     Two-factor Das Gupta (1993) decomposition of EYUG differences
*               between parental background k and the reference (upper
*               secondary) background into the probability-of-graduating
*               component and the mean-age-at-graduation ("timing") component
*               (Eq. 3-4).
*   Step 3      EYUG re-expressed as a function of the probabilities and
*               timing (delay) of the three transitions - first applying,
*               first entering, and graduating from university (Eq. 5-6) -
*               and an exact six-factor Das Gupta decomposition of background
*               differences in EYUG into these six components.
*
* Stata 18. Requires only official Stata commands - no user-written packages needed.
*===============================================================================
clear all
set more off
cd "W:\Lotta Lintunen\WP 3"

* outcome folders
global do "W:\Lotta Lintunen\WP 3\Do"
global data "W:\Lotta Lintunen\WP 3\Data"
global newdata "W:\Lotta Lintunen\WP 3\Data\Revisions data"
global graphs "W:\Lotta Lintunen\WP 3\Graphs"
global tables "W:\Lotta Lintunen\WP 3\Tables"
global revisions "W:\Lotta Lintunen\WP 3\ESR Revisions"


*===============================================================================
* 0. DATA STRUCTURE
*===============================================================================
* This code expects a person-level (wide) file "master.dta" with one row per
* individual and, at minimum, the following variables (all ages in completed
* years; missing = event never observed within the data window):
*
*   id       unique person identifier
*   cohort      birth cohort (1960 1970 1980 1990)
*   pedu     	parental education background, categorical, coded so that
*               the reference category ("upper secondary") = 2
*   age_gym     age at Gymnasium / upper-secondary graduation
*   age_appl    age at FIRST application to university   (missing if never)
*   age_enter   age at FIRST entry into university        (missing if never)
*   age_grad    age at university graduation               (missing if never)
*   age_exit    age at end of observation (admin. censoring at the end of the 
*				data window - whichever comes first, *before* truncating 
*               at the analytic age limit j below)
* data sources
* "$newdata\EYUG_survival1980.dta"
* "$newdata\19601990_survival.dta"
*===============================================================================
* DESCRIPTIVES
*===============================================================================
use "$newdata\EYUG_survival1980.dta", clear
gen TA = (VOC==1 | YO==1)

* 1980
tab1 POLY MA TERT if YO==1
tab1 POLY MA TERT if VOC==1
tab1 POLY MA TERT if TA==1

tab YO MA, row
tab VOC MA, row
tab TA MA, row
tab YO POLY, row
tab VOC POLY, row
tab TA POLY, row
tab YO TERT, row
tab VOC TERT, row
tab TA TERT, rom

* alltogether
* mean age of graduation
sum age_YO age_amis age_ta age_amk age_ma age_kork

* by the type of upper secondary degree
sum age_amk age_ma age_kork if YO==1
sum age_amk age_ma age_kork if VOC==1
sum age_amk age_ma age_kork if TA==1

* by parental education
* grdauation %
ta pedu YO, row
ta pedu VOC, row
ta pedu TA, row
ta pedu POLY, row
ta pedu TERT, row
ta pedu MA, row

* mean age of graduation
bysort pedu: sum age_YO age_amis age_ta age_amk age_ma age_kork

* by the type of upper secondary degree
* grdauation %
ta pedu female if YO==1, row
ta pedu POLY if YO==1, row
ta pedu TERT if YO==1, row
ta pedu MA if YO==1, row

ta pedu female if VOC==1, row
ta pedu POLY if VOC==1, row
ta pedu TERT if VOC==1, row
ta pedu MA if VOC==1, row

ta pedu female if TA==1, row
ta pedu POLY if TA==1, row
ta pedu TERT if TA==1, row
ta pedu MA if TA==1, row

* mean age of graduation
bysort pedu: sum age_amk age_ma age_kork if YO==1
bysort pedu: sum age_amk age_ma age_kork if VOC==1
bysort pedu: sum age_amk age_ma age_kork if TA==1

use "$newdata\EYUG_survival1980.dta", clear

* 1960, 1970, 1980, 1990
use "$newdata\19601990_survival.dta", clear
drop if ulkom==1
bysort cohort: tab1 female YO VOC POLY MA

bysort cohort: ta pedu female, row
bysort cohort: ta pedu YO, row 
bysort cohort: ta pedu VOC, row 
bysort cohort: ta pedu POLY, row 
bysort cohort: ta pedu MA, row

* if Gymnasium graduate
bysort cohort: ta pedu POLY if YO==1, row 
bysort cohort: ta pedu MA if YO==1, row

*===============================================================================
* MAIN ANALYSIS COHORT 1980
*===============================================================================
 log using "eyug_analysis_1980.log", replace text
*-------------------------------------------------------------------------------
* PARAMETERS
*-------------------------------------------------------------------------------
local i           = 21      // age at which the population becomes "at risk"
                             // of graduating (Methods: institutional design /
                             // sufficient number of graduations - here, 21)
local j           = 40      // upper age limit j for the main analysis
local refval      = 2       // value of background identifying the reference
                             // ("upper secondary") background category
local gymage_grand = 19.15  // grand mean age at Gymnasium graduation, used
                             // in place of the background-specific mean 
                             // because it varies only trivially 
                             // by background (19.13-19.17)
local masterfile  = "$newdata\EYUG_survival1980.dta"

*===============================================================================
* 1. PERSON-PERIOD FILE FOR OVERALL UNIVERSITY GRADUATION (age clock)
*===============================================================================
use "`masterfile'", clear // for 1980 cohort
keep if YO==1 // keep only gymnasium graduates (30,254 observations deleted)

* exclusions
ta ulkom // degrees from abroad
destring ulkom, replace
drop if ulkom==1 

drop if year_applied==. & MA==1 
drop if year_received==. & MA==1  
drop if year_enrolled==. & MA==1 

* create age_exit variable
gen age_exit = 40

* keep only necessary variables
keep id cohort pedu age_grad age_exit


* Window of exposure, in calendar age, from i to j (or until the person graduates)
gen age_lo = `i'
gen age_hi = min(`j', age_exit, cond(missing(age_grad), `j', age_grad))
drop if age_hi < age_lo            // never actually at risk in [i,j]: drop

expand age_hi - age_lo + 1
bysort id: gen age = age_lo + _n - 1

gen event = (age == age_grad) if !missing(age_grad)
replace event = 0 if missing(event)

keep id cohort pedu age event
save "period_grad.dta", replace


*===============================================================================
* 2. DISCRETE-TIME (ACTUARIAL) LIFE TABLE: cumulative probability of
*    university graduation by age, by cohort x background
*    (Preston, Heuveline & Guillot 2001)
*===============================================================================
use "period_grad.dta", clear
collapse (sum) D = event (count) N = id, by(cohort pedu age) 

fillin cohort pedu age            					// fill any empty age x group cells
replace D = 0 if missing(D)
replace N = 0 if missing(N)
drop _fillin

sort cohort pedu age
by cohort pedu: gen h    = D / N                    // hazard at age a
replace h = 0 if N == 0
by cohort pedu: gen S    = exp(sum(ln(1 - h)))       // P(not graduated by end of a)
by cohort pedu: gen Slag = S[_n-1]
replace Slag = 1 if missing(Slag)                    // S = 1 just before age i
gen G = 1 - S                                        // cumulative probability of
                                                     // graduating by age a
gen f = Slag * h                                     // density of graduations at a

label var G "Cumulative probability of university graduation by age a"
label var f "Density of graduations at age a"
label var h "Hazard (conditional probability) of graduating at age a"
label var S "Survivor function: P(not yet graduated by end of age a)"
save "lifetable_grad.dta", replace


*===============================================================================
* 3. STEP 1 OUTPUT: absolute (percentage-point) and relative (ratio)
*    background differences in cumulative probability of graduation by age
*===============================================================================
use "lifetable_grad.dta", clear
sort cohort pedu age
keep cohort pedu age G

preserve
    keep if pedu == `refval'
    rename G G_ref
    keep cohort age G_ref
    tempfile ref_g
    save `"ref_g"', replace
restore

merge m:1 cohort age using `"ref_g"', nogen
drop if pedu == `refval'

gen diff_pp    = 100 * (G - G_ref)     // absolute (percentage-point) difference
gen ratio      = G / G_ref             // relative difference (ratio)

label var diff_pp "Absolute difference vs. reference background (p.p.)"
label var ratio   "Relative difference vs. reference background (ratio)"
save "step1_age_differences.dta", replace


*===============================================================================
* 4. EYUG, P_j AND MEAN AGE AT GRADUATION  (Equations 1-2)
*===============================================================================
use "lifetable_grad.dta", clear
sort cohort pedu age
keep if age >= `i' & age <= `j'

by cohort pedu: egen EYUG    = total(cond(age < `j', G, .))       // Eq. (1): discrete
                                                                  // analogue of the
                                                                  // integral of G(a)
by cohort pedu: egen Pj      = max(cond(age == `j', G, .))    // P(j,UNI)
by cohort pedu: egen sum_af  = total(age * f)
gen meanage      = sum_af / Pj                                   // mean age at graduation
gen EYUG_eq2     = Pj * (`j' - meanage)                          // Eq. (2), sanity check

collapse (mean) EYUG Pj meanage EYUG_eq2, by(cohort pedu)
gen check_eq1_eq2 = EYUG - EYUG_eq2                               // should be ~0

label var EYUG      "Expected Years as University Graduate (Eq. 1)"
label var Pj        "Cumulative probability of graduating by age j"
label var meanage   "Mean age at graduation among graduates"
label var EYUG_eq2  "EYUG via Eq. 2 = Pj*(j-meanage): should equal EYUG"
save "eyug_summary.dta", replace
list cohort pedu EYUG Pj meanage check_eq1_eq2, sepby(cohort)


*===============================================================================
* 5. TWO-FACTOR DAS GUPTA (1993) DECOMPOSITION OF EYUG DIFFERENCES
*    (Equations 3-4): probability-of-graduating component vs.
*    mean-age-at-graduation ("timing") component
*===============================================================================
use "eyug_summary.dta", clear

preserve
    keep if pedu == `refval'
    rename EYUG    EYUG_ref
    rename Pj      Pj_ref
    rename meanage meanage_ref
    keep cohort EYUG_ref Pj_ref meanage_ref
    tempfile ref_eyug
    save `"ref_eyug"', replace
restore

merge m:1 cohort using `"ref_eyug"', nogen
drop if pedu == `refval'

gen diff_EYUG   = EYUG - EYUG_ref
gen contrib_P   = (Pj - Pj_ref) * ((`j' - meanage) + (`j' - meanage_ref)) / 2   // Eq. 3
gen contrib_age = ((`j' - meanage) - (`j' - meanage_ref)) * (Pj + Pj_ref) / 2   // Eq. 4
gen check_sum   = contrib_P + contrib_age - diff_EYUG                          // ~0

label var contrib_P   "Contribution of P(graduating by j) - Eq. 3"
label var contrib_age "Contribution of mean age at graduation (timing) - Eq. 4"
save "decomp_2factor.dta", replace
list cohort pedu diff_EYUG contrib_P contrib_age check_sum, sepby(cohort)


*===============================================================================
* 6.0  PREPARE THE TRANSITION SAMPLE ONCE (identical population to Section 1)
*===============================================================================
use "`masterfile'", clear
keep if YO==1                                   // Gymnasium graduates
capture destring ulkom, replace
drop if ulkom==1                                // degrees from abroad
drop if year_applied==.  & MA==1
drop if year_received==. & MA==1
drop if year_enrolled==. & MA==1

gen age_exit = `j'                              // admin. censoring at age j (=40)
gen grad     = !missing(age_grad) & age_grad <= `j'              // = 1 if university graduate by age j (|UNI)

keep id cohort pedu age_gym age_appl age_enter age_grad age_exit grad
save "trans_master.dta", replace

*===============================================================================
* 6.-7. TRANSITION PROBABILITIES *BY AGE J*
*===============================================================================
use "trans_master.dta", clear

gen byte appl40 = !missing(age_appl) & age_appl <= `j'
gen byte enter40 = !missing(age_enter) & age_enter <= `j'
gen byte grad40 = !missing(age_grad) & age_grad <= `j'

gen p_appl = appl40								// risk set: all Gymnasium grads
gen p_enter = enter40 if appl40==1				// risk set: applied by j
gen p_grad = grad40 if appl40==1 & enter40==1	// risk set: applied & entered by j

collapse (mean) P_appl=p_appl P_enter=p_enter P_grad=p_grad, by(cohort pedu)
label var P_appl "P(first application by age j)"
label var P_enter "P(first entry by age j | applied by j)"
label var P_grad "P(graduation by age j | applied & entered by j)"
save "transprob.dta", replace

*===============================================================================
* 7b. MEAN DURATIONS OF THE THREE TRANSITIONS, CONDITIONAL ON UNIVERSITY 
* GRADUATION 
*===============================================================================
use "trans_master.dta", clear
keep if grad == 1                                // |UNI : university graduates only
gen t_appl  = max(0, age_appl  - age_gym )
gen t_enter = max(0, age_enter - age_appl)
gen t_grad  = max(0, age_grad  - age_enter)
collapse (mean) t_appl t_enter t_grad, by(cohort pedu)
label var t_appl  "Mean years Gymnasium->application, univ. graduates (Eq.5)"
label var t_enter "Mean years application->entry, univ. graduates (Eq.5)"
label var t_grad  "Mean years entry->graduation, univ. graduates (Eq.5)"
save "meandur_grad.dta", replace

*===============================================================================
* 8. ASSEMBLE THE SIX FACTORS + CONSTANT; RECONSTRUCT EYUG (Eq. 5-6)
*===============================================================================
use "transprob.dta", clear
merge 1:1 cohort pedu using "meandur_grad.dta", nogen

local C = `j' - `gymage_grand'				// = j - abar_GYM|UNI 

gen Pj_UNI_eq6 = P_appl * P_enter * P_grad
gen EYUG_eq6 = Pj_UNI_eq6 * (`C' - t_appl - t_enter - t_grad)
label var Pj_UNI_eq6 "P(graduation by age j) reconstructed"
label var EYUG_eq6 "EYUG via Eq. 5-6"
save "transitions_summary.dta", replace

* compare againts the direct life-table EYUG from section 4
merge 1:1 cohort pedu using "eyug_summary.dta", nogen
gen check_eq1_eq6 = EYUG - EYUG_eq6			// now expected to be ~0 (residual = grand-mean gym age)
gen check_Pj = Pj - Pj_UNI_eq6				// now expected to be ~0
save "transitions_summary.dta", replace
list cohort pedu EYUG EYUG_eq6 check_eq1_eq6 Pj Pj_UNI_eq6 check_Pj, sepby(cohort)

*===============================================================================
* 9. EXACT SIX-FACTOR DAS GUPTA (1993) DECOMPOSITION 
*===============================================================================
mata:
    real scalar bitset(real scalar num, real scalar pos)
    {
        return( mod(floor(num / 2^(pos-1)), 2) )
    }

    real scalar eyug_fn(real rowvector x, real scalar C)
    {
        return( x[1]*x[2]*x[3] * (C - x[4] - x[5] - x[6]) )
    }

    real rowvector dasgupta_decomp(real rowvector x_ref, real rowvector x_k, real scalar C)
    {
        real scalar n, s, subset, i, bit, w
        real rowvector contrib, xs, xsi

        n = cols(x_ref)
        contrib = J(1, n, 0)
        for (i=1; i<=n; i++) {
            for (subset=0; subset<=2^n-1; subset++) {
                if (bitset(subset,i)==1) continue
                s = 0
                for (bit=1; bit<=n; bit++) {
                    s = s + bitset(subset,bit)
                }
                xs = x_ref
                for (bit=1; bit<=n; bit++) {
                    if (bitset(subset,bit)==1) xs[bit] = x_k[bit]
                }
                xsi = xs
                xsi[i] = x_k[i]
                w = exp(lnfactorial(s) + lnfactorial(n-1-s) - lnfactorial(n))
                contrib[i] = contrib[i] + w * (eyug_fn(xsi,C) - eyug_fn(xs,C))
            }
        }
        return(contrib)
    }

    void dasgupta_decomp_stata()
    {
        real rowvector x_ref, x_k, contrib
        real scalar C, tot

        x_ref = st_matrix("Xref")
        x_k   = st_matrix("Xk")
        C     = st_numscalar("Cconst")
        contrib = dasgupta_decomp(x_ref, x_k, C)
        tot = eyug_fn(x_k,C) - eyug_fn(x_ref,C)

        st_matrix("Contrib", contrib)
        st_numscalar("TotalDiff", tot)
    }
end

use "transitions_summary.dta", clear
scalar Cconst = `C'

tempname results
postfile `results' cohort pedu ///
    diff_EYUG contrib_Pappl contrib_Penter contrib_Pgrad ///
    contrib_tappl contrib_tenter contrib_tgrad check_sum ///
    using "decomp_6factor.dta", replace

levelsof cohort, local(cohorts)
foreach c of local cohorts {
    quietly count if cohort == `c' & pedu == `refval'
    if r(N) == 0 continue

    mkmat P_appl P_enter P_grad t_appl t_enter t_grad ///
        if cohort == `c' & pedu == `refval', matrix(Xref)

    levelsof pedu if cohort == `c' & pedu != `refval', local(bgs)
    foreach b of local bgs {
        mkmat P_appl P_enter P_grad t_appl t_enter t_grad ///
            if cohort == `c' & pedu == `b', matrix(Xk)

        mata: dasgupta_decomp_stata()

        scalar checksum = Contrib[1,1] + Contrib[1,2] + Contrib[1,3] ///
                        + Contrib[1,4] + Contrib[1,5] + Contrib[1,6] - TotalDiff

        post `results' (`c') (`b') (TotalDiff) ///
            (Contrib[1,1]) (Contrib[1,2]) (Contrib[1,3]) ///
            (Contrib[1,4]) (Contrib[1,5]) (Contrib[1,6]) (checksum)
    }
}
postclose `results'

use "decomp_6factor.dta", clear
sort cohort pedu
egen total_contrib = rowtotal(contrib_Pappl contrib_Penter contrib_Pgrad ///
        contrib_tappl contrib_tenter contrib_tgrad)
foreach v in Pappl Penter Pgrad tappl tenter tgrad {
    gen pct_`v' = 100 * contrib_`v' / total_contrib if total_contrib != 0
}
save "decomp_6factor.dta", replace
list cohort pedu diff_EYUG contrib_* check_sum, sepby(cohort)
list pct_*

cap l"og close

*===============================================================================
* COHORT COMPARISON
*===============================================================================
 log using "eyug_analysis_1960-80.log", replace text

*-------------------------------------------------------------------------------
* PARAMETERS
*-------------------------------------------------------------------------------
local i           = 21      // age at which the population becomes "at risk"
                             // of graduating (Methods: institutional design /
                             // sufficient number of graduations - here, 21)
local j           = 40      // upper age limit j for the main analysis
local refval      = 2       // value of background identifying the reference
                             // ("upper secondary") background category
local gymage_grand = 19.15  // grand mean age at Gymnasium graduation, used
                             // in place of the background-specific mean 
                             // because it varies only trivially 
                             // by background (19.13-19.17)
local masterfile  = "$newdata\19601990_survival.dta"


*===============================================================================
* 1. PERSON-PERIOD FILE FOR OVERALL UNIVERSITY GRADUATION (age clock)
*===============================================================================
use "`masterfile'", clear // for 1960, 1970, 1980 cohort
drop if cohort == 1990
keep if YO==1 // keep only gymnasium graduates (30,254 observations deleted)

* exclusions
ta ulkom // degrees from abroad
destring ulkom, replace
drop if ulkom==1 

drop if year_applied==. & MA==1 
drop if year_received==. & MA==1  
drop if year_enrolled==. & MA==1 

* create age_exit variable
gen age_exit = 40

* keep only necessary variables
keep id cohort pedu age_grad age_exit


* Window of exposure, in calendar age, from i to j (or until the person graduates)
gen age_lo = `i'
gen age_hi = min(`j', age_exit, cond(missing(age_grad), `j', age_grad))
drop if age_hi < age_lo            // never actually at risk in [i,j]: drop

expand age_hi - age_lo + 1
bysort id: gen age = age_lo + _n - 1

gen event = (age == age_grad) if !missing(age_grad)
replace event = 0 if missing(event)

keep id cohort pedu age event
save "period_grad_comp.dta", replace


*===============================================================================
* 2. DISCRETE-TIME (ACTUARIAL) LIFE TABLE: cumulative probability of
*    university graduation by age, by cohort x background
*    (Preston, Heuveline & Guillot 2001)
*===============================================================================
use "period_grad_comp.dta", clear
collapse (sum) D = event (count) N = id, by(cohort pedu age) 

fillin cohort pedu age            					// fill any empty age x group cells
replace D = 0 if missing(D)
replace N = 0 if missing(N)
drop _fillin

sort cohort pedu age
by cohort pedu: gen h    = D / N                    // hazard at age a
replace h = 0 if N == 0
by cohort pedu: gen S    = exp(sum(ln(1 - h)))       // P(not graduated by end of a)
by cohort pedu: gen Slag = S[_n-1]
replace Slag = 1 if missing(Slag)                    // S = 1 just before age i
gen G = 1 - S                                        // cumulative probability of
                                                     // graduating by age a
gen f = Slag * h                                     // density of graduations at a

label var G "Cumulative probability of university graduation by age a"
label var f "Density of graduations at age a"
label var h "Hazard (conditional probability) of graduating at age a"
label var S "Survivor function: P(not yet graduated by end of age a)"
save "lifetable_grad_comp.dta", replace


*===============================================================================
* 3. STEP 1 OUTPUT: absolute (percentage-point) and relative (ratio)
*    background differences in cumulative probability of graduation by age
*===============================================================================
use "lifetable_grad_comp.dta", clear
sort cohort pedu age
keep cohort pedu age G

preserve
    keep if pedu == `refval'
    rename G G_ref
    keep cohort age G_ref
    tempfile ref_g
    save `"ref_g"', replace
restore

merge m:1 cohort age using `"ref_g"', nogen
drop if pedu == `refval'

gen diff_pp    = 100 * (G - G_ref)     // absolute (percentage-point) difference
gen ratio      = G / G_ref             // relative difference (ratio)

label var diff_pp "Absolute difference vs. reference background (p.p.)"
label var ratio   "Relative difference vs. reference background (ratio)"
save "step1_age_differences_comp.dta", replace


*===============================================================================
* 4. EYUG, P_j AND MEAN AGE AT GRADUATION  (Equations 1-2)
*===============================================================================
use "lifetable_grad_comp.dta", clear
sort cohort pedu age
keep if age >= `i' & age <= `j'

by cohort pedu: egen EYUG    = total(cond(age < `j', G, .))       // Eq. (1): discrete
                                                                  // analogue of the
                                                                  // integral of G(a)
by cohort pedu: egen Pj      = max(cond(age == `j', G, .))    // P(j,UNI)
by cohort pedu: egen sum_af  = total(age * f)
gen meanage      = sum_af / Pj                                   // mean age at graduation
gen EYUG_eq2     = Pj * (`j' - meanage)                          // Eq. (2), sanity check

collapse (mean) EYUG Pj meanage EYUG_eq2, by(cohort pedu)
gen check_eq1_eq2 = EYUG - EYUG_eq2                               // should be ~0

label var EYUG      "Expected Years as University Graduate (Eq. 1)"
label var Pj        "Cumulative probability of graduating by age j"
label var meanage   "Mean age at graduation among graduates"
label var EYUG_eq2  "EYUG via Eq. 2 = Pj*(j-meanage): should equal EYUG"
save "eyug_summary_comp.dta", replace
list cohort pedu EYUG Pj meanage check_eq1_eq2, sepby(cohort)


*===============================================================================
* 5. TWO-FACTOR DAS GUPTA (1993) DECOMPOSITION OF EYUG DIFFERENCES
*    (Equations 3-4): probability-of-graduating component vs.
*    mean-age-at-graduation ("timing") component
*===============================================================================
use "eyug_summary_comp.dta", clear

preserve
    keep if pedu == `refval'
    rename EYUG    EYUG_ref
    rename Pj      Pj_ref
    rename meanage meanage_ref
    keep cohort EYUG_ref Pj_ref meanage_ref
    tempfile ref_eyug
    save `"ref_eyug"', replace
restore

merge m:1 cohort using `"ref_eyug"', nogen
drop if pedu == `refval'

gen diff_EYUG   = EYUG - EYUG_ref
gen contrib_P   = (Pj - Pj_ref) * ((`j' - meanage) + (`j' - meanage_ref)) / 2   // Eq. 3
gen contrib_age = ((`j' - meanage) - (`j' - meanage_ref)) * (Pj + Pj_ref) / 2   // Eq. 4
gen check_sum   = contrib_P + contrib_age - diff_EYUG                          // ~0

label var contrib_P   "Contribution of P(graduating by j) - Eq. 3"
label var contrib_age "Contribution of mean age at graduation (timing) - Eq. 4"
save "decomp_2factor_comp.dta", replace
list cohort pedu diff_EYUG contrib_P contrib_age check_sum, sepby(cohort)

cap log close

 
*===============================================================================
* EXTENDED AGE FOR COHORTS 1960 AND 1970
*===============================================================================
log using "eyug_analysis_age5060.log", replace text
*-------------------------------------------------------------------------------
* PARAMETERS
*-------------------------------------------------------------------------------
local i           = 21      // age at which the population becomes "at risk"
                             // of graduating (Methods: institutional design /
                             // sufficient number of graduations - here, 21)
local j           = 60      // upper age limit j for the main analysis
local refval      = 2       // value of background identifying the reference
                             // ("upper secondary") background category
local gymage_grand = 19.15  // grand mean age at Gymnasium graduation, used
                             // in place of the background-specific mean 
                             // because it varies only trivially 
                             // by background (19.13-19.17)
local masterfile  = "$newdata\19601990_survival.dta"


*===============================================================================
* 1. PERSON-PERIOD FILE FOR OVERALL UNIVERSITY GRADUATION (age clock)
*===============================================================================
use "`masterfile'", clear // 
keep if cohort == 1960
keep if YO==1 // keep only gymnasium graduates 

* exclusions
ta ulkom // degrees from abroad
destring ulkom, replace
drop if ulkom==1 

* create age_exit variable
gen age_exit = 60

* keep only necessary variables
keep id cohort pedu age_grad age_exit


* Window of exposure, in calendar age, from i to j (or until the person graduates)
gen age_lo = `i'
gen age_hi = min(`j', age_exit, cond(missing(age_grad), `j', age_grad))
drop if age_hi < age_lo            // never actually at risk in [i,j]: drop

expand age_hi - age_lo + 1
bysort id: gen age = age_lo + _n - 1

gen event = (age == age_grad) if !missing(age_grad)
replace event = 0 if missing(event)

keep id cohort pedu age event
save "period_grad60.dta", replace


*===============================================================================
* 2. DISCRETE-TIME (ACTUARIAL) LIFE TABLE: cumulative probability of
*    university graduation by age, by cohort x background
*    (Preston, Heuveline & Guillot 2001)
*===============================================================================
use "period_grad60.dta", clear
collapse (sum) D = event (count) N = id, by(cohort pedu age) 

fillin cohort pedu age            // fill any empty age x group cells
replace D = 0 if missing(D)
replace N = 0 if missing(N)
drop _fillin

sort cohort pedu age
by cohort pedu: gen h    = D / N                    // hazard at age a
replace h = 0 if N == 0
by cohort pedu: gen S    = exp(sum(ln(1 - h)))       // P(not graduated by end of a)
by cohort pedu: gen Slag = S[_n-1]
replace Slag = 1 if missing(Slag)                       // S = 1 just before age i
gen G = 1 - S                                            // cumulative probability of
                                                          // graduating by age a
gen f = Slag * h                                         // density of graduations at a

label var G "Cumulative probability of university graduation by age a"
label var f "Density of graduations at age a"
label var h "Hazard (conditional probability) of graduating at age a"
label var S "Survivor function: P(not yet graduated by end of age a)"
save "lifetable_grad60.dta", replace


*===============================================================================
* 3. STEP 1 OUTPUT: absolute (percentage-point) and relative (ratio)
*    background differences in cumulative probability of graduation by age
*===============================================================================
use "lifetable_grad60.dta", clear
sort cohort pedu age
keep cohort pedu age G

preserve
    keep if pedu == `refval'
    rename G G_ref
    keep cohort age G_ref
    tempfile ref_g
    save `"ref_g"', replace
restore

merge m:1 cohort age using `"ref_g"', nogen
drop if pedu == `refval'

gen diff_pp    = 100 * (G - G_ref)     // absolute (percentage-point) difference
gen ratio      = G / G_ref             // relative difference (ratio)

label var diff_pp "Absolute difference vs. reference background (p.p.)"
label var ratio   "Relative difference vs. reference background (ratio)"
save "step1_age_differences60.dta", replace


*===============================================================================
* 4. EYUG, P_j AND MEAN AGE AT GRADUATION  (Equations 1-2)
*===============================================================================
use "lifetable_grad60.dta", clear
sort cohort pedu age
keep if age >= `i' & age <= `j'

by cohort pedu: egen EYUG    = total(cond(age < `j', G, .))                      // Eq. (1): discrete
                                                                  // analogue of the
                                                                  // integral of G(a)
**# Bookmark #2
by cohort pedu: egen Pj      = max(cond(age == `j', G, .))    // P(j,UNI)
by cohort pedu: egen sum_af  = total(age * f)
gen meanage      = sum_af / Pj                                   // mean age at graduation
gen EYUG_eq2     = Pj * (`j' - meanage)                          // Eq. (2), sanity check

collapse (mean) EYUG Pj meanage EYUG_eq2, by(cohort pedu)
gen check_eq1_eq2 = EYUG - EYUG_eq2                               // should be ~0

label var EYUG      "Expected Years as University Graduate (Eq. 1)"
label var Pj        "Cumulative probability of graduating by age j"
label var meanage   "Mean age at graduation among graduates"
label var EYUG_eq2  "EYUG via Eq. 2 = Pj*(j-meanage): should equal EYUG"
save "eyug_summary60.dta", replace
list cohort pedu EYUG Pj meanage check_eq1_eq2, sepby(cohort)


*===============================================================================
* 5. TWO-FACTOR DAS GUPTA (1993) DECOMPOSITION OF EYUG DIFFERENCES
*    (Equations 3-4): probability-of-graduating component vs.
*    mean-age-at-graduation ("timing") component
*===============================================================================
use "eyug_summary60.dta", clear

preserve
    keep if pedu == `refval'
    rename EYUG    EYUG_ref
    rename Pj      Pj_ref
    rename meanage meanage_ref
    keep cohort EYUG_ref Pj_ref meanage_ref
    tempfile ref_eyug
    save `"ref_eyug"', replace
restore

merge m:1 cohort using `"ref_eyug"', nogen
drop if pedu == `refval'

gen diff_EYUG   = EYUG - EYUG_ref
gen contrib_P   = (Pj - Pj_ref) * ((`j' - meanage) + (`j' - meanage_ref)) / 2   // Eq. 3
gen contrib_age = ((`j' - meanage) - (`j' - meanage_ref)) * (Pj + Pj_ref) / 2   // Eq. 4
gen check_sum   = contrib_P + contrib_age - diff_EYUG                          // ~0

label var contrib_P   "Contribution of P(graduating by j) - Eq. 3"
label var contrib_age "Contribution of mean age at graduation (timing) - Eq. 4"
save "decomp_2factor60.dta", replace
list cohort pedu diff_EYUG contrib_P contrib_age check_sum, sepby(cohort)

*-------------------------------------------------------------------------------
* USER-ADJUSTABLE PARAMETERS
*-------------------------------------------------------------------------------
local i           = 21      // age at which the population becomes "at risk"
                             // of graduating (Methods: institutional design /
                             // sufficient number of graduations - here, 21)
local j           = 50      // upper age limit j for the main analysis
local refval      = 2       // value of background identifying the reference
                             // ("upper secondary") background category
local gymage_grand = 19.15  // grand mean age at Gymnasium graduation, used
                             // in place of the background-specific mean 
                             // because it varies only trivially 
                             // by background (19.13-19.17)
local masterfile  = "$newdata\19601990_survival.dta"


*===============================================================================
* 1. PERSON-PERIOD FILE FOR OVERALL UNIVERSITY GRADUATION (age clock)
*===============================================================================
use "`masterfile'", clear // 
keep if cohort == 1960 | cohort == 1970
keep if YO==1 // keep only gymnasium graduates 

* exclusions
ta ulkom // degrees from abroad
destring ulkom, replace
drop if ulkom==1 

* create age_exit variable
gen age_exit = 50

* keep only necessary variables
keep id cohort pedu age_grad age_exit


* Window of exposure, in calendar age, from i to j (or until the person graduates)
gen age_lo = `i'
gen age_hi = min(`j', age_exit, cond(missing(age_grad), `j', age_grad))
drop if age_hi < age_lo            // never actually at risk in [i,j]: drop

expand age_hi - age_lo + 1
bysort id: gen age = age_lo + _n - 1

gen event = (age == age_grad) if !missing(age_grad)
replace event = 0 if missing(event)

keep id cohort pedu age event
save "period_grad70.dta", replace


*===============================================================================
* 2. DISCRETE-TIME (ACTUARIAL) LIFE TABLE: cumulative probability of
*    university graduation by age, by cohort x background
*    (Preston, Heuveline & Guillot 2001)
*===============================================================================
use "period_grad70.dta", clear
collapse (sum) D = event (count) N = id, by(cohort pedu age) 

fillin cohort pedu age            // fill any empty age x group cells
replace D = 0 if missing(D)
replace N = 0 if missing(N)
drop _fillin

sort cohort pedu age
by cohort pedu: gen h    = D / N                    // hazard at age a
replace h = 0 if N == 0
by cohort pedu: gen S    = exp(sum(ln(1 - h)))       // P(not graduated by end of a)
by cohort pedu: gen Slag = S[_n-1]
replace Slag = 1 if missing(Slag)                       // S = 1 just before age i
gen G = 1 - S                                            // cumulative probability of
                                                          // graduating by age a
gen f = Slag * h                                         // density of graduations at a

label var G "Cumulative probability of university graduation by age a"
label var f "Density of graduations at age a"
label var h "Hazard (conditional probability) of graduating at age a"
label var S "Survivor function: P(not yet graduated by end of age a)"
save "lifetable_grad70.dta", replace


*===============================================================================
* 3. STEP 1 OUTPUT: absolute (percentage-point) and relative (ratio)
*    background differences in cumulative probability of graduation by age
*===============================================================================
use "lifetable_grad70.dta", clear
sort cohort pedu age
keep cohort pedu age G

preserve
    keep if pedu == `refval'
    rename G G_ref
    keep cohort age G_ref
    tempfile ref_g
    save `"ref_g"', replace
restore

merge m:1 cohort age using `"ref_g"', nogen
drop if pedu == `refval'

gen diff_pp    = 100 * (G - G_ref)     // absolute (percentage-point) difference
gen ratio      = G / G_ref             // relative difference (ratio)

label var diff_pp "Absolute difference vs. reference background (p.p.)"
label var ratio   "Relative difference vs. reference background (ratio)"
save "step1_age_differences70.dta", replace


*===============================================================================
* 4. EYUG, P_j AND MEAN AGE AT GRADUATION  (Equations 1-2)
*===============================================================================
use "lifetable_grad70.dta", clear
sort cohort pedu age
keep if age >= `i' & age <= `j'

by cohort pedu: egen EYUG    = total(cond(age < `j', G, .))                      // Eq. (1): discrete
                                                                  // analogue of the
                                                                  // integral of G(a)
by cohort pedu: egen Pj      = max(cond(age == `j', G, .))    // P(j,UNI)
by cohort pedu: egen sum_af  = total(age * f)
gen meanage      = sum_af / Pj                                   // mean age at graduation
gen EYUG_eq2     = Pj * (`j' - meanage)                          // Eq. (2), sanity check

collapse (mean) EYUG Pj meanage EYUG_eq2, by(cohort pedu)
gen check_eq1_eq2 = EYUG - EYUG_eq2                               // should be ~0

label var EYUG      "Expected Years as University Graduate (Eq. 1)"
label var Pj        "Cumulative probability of graduating by age j"
label var meanage   "Mean age at graduation among graduates"
label var EYUG_eq2  "EYUG via Eq. 2 = Pj*(j-meanage): should equal EYUG"
save "eyug_summary70.dta", replace
list cohort pedu EYUG Pj meanage check_eq1_eq2, sepby(cohort)


*===============================================================================
* 5. TWO-FACTOR DAS GUPTA (1993) DECOMPOSITION OF EYUG DIFFERENCES
*    (Equations 3-4): probability-of-graduating component vs.
*    mean-age-at-graduation ("timing") component
*===============================================================================
use "eyug_summary70.dta", clear

preserve
    keep if pedu == `refval'
    rename EYUG    EYUG_ref
    rename Pj      Pj_ref
    rename meanage meanage_ref
    keep cohort EYUG_ref Pj_ref meanage_ref
    tempfile ref_eyug
    save `"ref_eyug"', replace
restore

merge m:1 cohort using `"ref_eyug"', nogen
drop if pedu == `refval'

gen diff_EYUG   = EYUG - EYUG_ref
gen contrib_P   = (Pj - Pj_ref) * ((`j' - meanage) + (`j' - meanage_ref)) / 2   // Eq. 3
gen contrib_age = ((`j' - meanage) - (`j' - meanage_ref)) * (Pj + Pj_ref) / 2   // Eq. 4
gen check_sum   = contrib_P + contrib_age - diff_EYUG                          // ~0

label var contrib_P   "Contribution of P(graduating by j) - Eq. 3"
label var contrib_age "Contribution of mean age at graduation (timing) - Eq. 4"
save "decomp_2factor70.dta", replace
list cohort pedu diff_EYUG contrib_P contrib_age check_sum, sepby(cohort)

cap log close