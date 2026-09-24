*===============================================================================
* EYUG data
* data version: 09/04/2026 
*===============================================================================
clear
set more off, perm
cd "W:\Lotta Lintunen\WP 3"

global temp "W:\Lotta Lintunen\statatemp"

* outcome folders
global do "W:\Lotta Lintunen\WP 3\Do"
global data "W:\Lotta Lintunen\WP 3\Data\Revisions data"

* source data
global folk "D:\ready-made\CONTINUOUS\FOLK_PERUS_C\shnro_suojattu" 
	global census "D:\ready-made\FOLK_vl_7085\vl7085_1.dta"
	global folk8700 "${folk}\folk_19872000_tua_perus22tot_1.dta"
	global folk0110 "${folk}\folk_20012010_tua_perus22tot_1.dta"
	global folk1120 "${folk}\folk_20112020_tua_perus22tot_1.dta"
	global folk21 "${folk}\folk_perus_2021_1.dta"
	global folk22 "${folk}\folk_perus_2022_1.dta"
	global folk23 "${folk}\folk_perus_2023_1.dta"
	
global tutk "D:\ready-made\CONTINUOUS\FOLK_TUTK_C\shnro_suojattu" 
	global tutk8700 "${tutk}\FOLK_19872000_tua_TUTK21TOT_1.dta"
	global tutk0110 "${tutk}\FOLK_20012010_tua_TUTK21TOT_1.dta"
	global tutk1119 "${tutk}\FOLK_20112019_tua_TUTK21TOT_1.dta"
	global tutk20 "${tutk}\FOLK_TUTK_2020_1.dta"
	global tutk21 "${tutk}\FOLK_TUTK_2021_1.dta"
	global tutk22 "${tutk}\FOLK_TUTK_2022_1.dta"
	global tutk23 "${tutk}\FOLK_TUTK_2023_1.dta"

*===============================================================================
* 1. basic data
*===============================================================================

global master_vars shnro vuosi syntyv kuolv sukup kunta ptoim1 // 
use $master_vars using $census, clear 
duplicates drop shnro vuosi, force // (2,721 observations deleted)
global new_vars yotutk ututku* suorv*

keep if syntyv==1960 | syntyv==1970 | syntyv==1980 | syntyv==1990

local datasets folk8700 folk0110 folk1120
foreach dataset of local datasets {
    merge 1:1 shnro vuosi using $`dataset', keepusing($master_vars $new_vars) update
	keep if syntyv==1960 | syntyv==1970 | syntyv==1980 | syntyv==1990
	drop _merge
}

* from 2021 onwards gender in a separate file (fixed --> annually updated)
local datasets folk21 folk22 folk23
foreach dataset of local datasets {
    merge 1:1 shnro vuosi using $`dataset', keepusing(syntyv kuolv kunta $new_vars) update
	keep if syntyv==1960 | syntyv==1970 | syntyv==1980 | syntyv==1990
	drop _merge
}

drop if kuolv<=syntyv+40 // drop those who died before the age 40(767,024 observations deleted)
sort shnro vuosi
duplicates drop shnro vuosi, force //

compress
save "$data\basic6090.dta", replace

*===============================================================================
* 2. create degree data
*===============================================================================

global tutk_vars shnro vuosi koulk kaste saika kirtuv ktutk_* suorv_* ulkom
use $tutk_vars using "$tutk8700", clear
duplicates drop shnro vuosi, force

local datasets tutk0110 tutk1119 tutk20 tutk21 tutk22 tutk23
foreach dataset of local datasets {
    merge 1:1 shnro vuosi using $`dataset', keepusing($tutk_vars) update

	drop _merge
}

sort shnro vuosi
duplicates report shnro vuosi
compress
save "$data\Tutk_1987-2023.dta", replace

*===============================================================================
* 3. Merge basic and degree data
*===============================================================================

use "$data\basic6090.dta", clear
sort shnro vuosi
merge m:1 shnro vuosi using "$data\Tutk_1987-2023.dta", keep(match master) nogen

duplicates drop shnro vuosi, force
* restrict to years of interest
keep if vuosi >= syntyv+15

compress
save "$data\basic_tutk6090.dta", replace

erase "$data\Tutk_1987-2023.dta"
erase "$data\basic6090.dta"

*===============================================================================
* 4. Variables
*===============================================================================

* gender 
destring sukup, replace
recode sukup (1=0) (2=1), gen (female)
lab def female 0 "male" 1 "female"
lab val female female
drop sukup
bysort shnro(vuosi): carryforward female, replace

* education
sort shnro vuosi
ren koulk ktutk_0
destring ktutk_*, replace
destring yotutk, replace
recode yotutk (4 = 1) (0 = 0), gen(gensec)

* collapse into 9-category variable
forvalues i=0/4 { 	
		gen edu`i'dig3= int(ktutk_`i'/1000) // Collapse koulk variable into 3-digit format
	
		recode edu`i'dig3 (311/499=2 "voc sec") (301/309=3 "gen sec") (511/599 613 628 653 654 =4 "opisto") (611 621 631 651 652 661 671 681 691 =5 "poly") (612 622/627 629 632/634 639 642 649 655 659 662 672 682 692 699 =6 "bach uni") (711 721 731 750 761 771 781 791 =7 "mast poly") (712 719 722/729 732/739 742 749 751 754 759 762 772 775 782 792 799 =8 "mast uni") (811/899=9 "lic/doct"), gen(edulvl`i')
		replace edulvl`i'=4 if inlist(ktutk_`i', 662551, 662552, 662599, 672651) // adapt type-definition from length-defined source
		replace edulvl`i'=4 if inlist(ktutk_`i', 682401, 682499) // same as above
		replace edulvl`i'=4 if inlist(ktutk_`i', 613952, 719952, 719953) // same as above
 }
label var edulvl0 "Highest completed degree"
drop edu*dig3 ktutk* kaste

ren edulvl0 highestdegreeannual
egen edulvl0 = max(highestdegreeannual), by(shnro)
egen suorv_0 = max(suorv), by(shnro)
ren suorv degreeyearannual

* fill in missing info based on being a resident in Finland and age
destring kunta yotutk, replace
replace edulvl0 = 1 if edulvl0 ==. & kunta !=. & yotutk==0 // no gymnasium
replace edulvl0=3 if edulvl0==. & kunta !=. & yotutk==4 // high school graduates
replace suorv_0=syntyv+15 if edulvl0==1 & suorv_0==. 

replace highestdegreeannual = 1 if highestdegreeannual ==. & kunta !=. & yotutk==0 // no gymnasium
replace highestdegreeannual=3 if highestdegreeannual==. & kunta !=. & yotutk==4 // high school graduates
replace degreeyearannual=syntyv+15 if highestdegreeannual==1 & degreeyearannual==. // 

gsort shnro -vuosi
bysort shnro: replace highestdegreeannual = highestdegreeannual[_n-1] if highestdegreeannual == .
sort shnro vuosi
bysort shnro: replace highestdegreeannual = highestdegreeannual[_n-1] if highestdegreeannual == .
ta degreeyearannual, m

order shnro vuosi syntyv highestdegreeannual degreeyearannual edulvl0 suorv_0 edulvl1 suorv_1 edulvl2 suorv_2 edulvl3 suorv_3 edulvl4 suorv_4
sort shnro vuosi
by shnro: carryforward gensec edulvl0 edulvl1 edulvl2 edulvl3 edulvl4, replace
by shnro: carryforward suorv_0 suorv_1 suorv_2 suorv_3 suorv_4, replace
gsort shnro -vuosi
by shnro: carryforward gensec edulvl0 edulvl1 edulvl2 edulvl3 edulvl4, replace
by shnro: carryforward suorv_0 suorv_1 suorv_2 suorv_3 suorv_4, replace
sort shnro vuosi
compress
save "$data\basic_tutk.dta", replace
gen degreeannual_age = degreeyearannual - syntyv
ta degreeannual_age, m
drop if degreeannual_age < 15

destring edulvl* suorv_*, replace

* check for coding errors
tab1 suorv_*, m
forvalues i=0/4 { 
	replace suorv_`i' = . if suorv_`i' < 1975
}	

lab def edutag 1 "basic/unknown" 2 "voc. sec." 3 "gen. sec." 4 "lowest tert." 5 "poly. ba" 6 "uni BA" 7 "poly MA" 8 "uni MA" 9 "lic/PhD"
lab val edulvl0 edutag
lab val edulvl1 edutag
lab val edulvl2 edutag
lab val edulvl3 edutag
lab val edulvl4 edutag

* tidy up
keep shnro vuosi syntyv edulvl* suorv* gensec female
compress
save "$data\basic_tutk6090.dta", replace


* fill in missing years
ren ch_shnro shnro
ren ch_syntyv syntyv
egen id = group(shnro)
xtset id vuosi, yearly
/*
Panel variable: id (unbalanced)
 Time variable: vuosi, 1975 to 2021, but with gaps
         Delta: 1 year
*/
sum vuosi
tsset id vuosi
tsfill, full

by id (vuosi), sort: replace shnro = shnro[_n-1] if missing(shnro)
by id (vuosi), sort: replace syntyv = syntyv[_n-1] if missing(syntyv)

sort shnro vuosi
by shnro: carryforward female, replace
by shnro: carryforward shnro, replace
by shnro: carryforward syntyv, replace

gsort shnro -vuosi
by shnro: carryforward female, replace
by shnro: carryforward shnro, replace
by shnro: carryforward syntyv, replace

sort shnro vuosi
ds edulvl*
foreach var of varlist `r(varlist)' {
		by id (vuosi), sort: replace `var' = `var'[_n-1] if missing(`var') 
	}
ds suorv*
foreach var of varlist `r(varlist)' {
		by id (vuosi), sort: replace `var' = `var'[_n-1] if missing(`var') 
	}

drop if vuosi<syntyv // (54,249,406 observations deleted)
drop m_id f_id m_kunta f_kunta m_koulk f_koulk m_edu_3digit f_edu_3digit m_edu f_edu m_edua f_edua
save "$data\basic_tutk6090.dta", replace

*===============================================================================
* 5. application data
*===============================================================================

* Creating the globals
global uni "D:\e17\custom-made\u1054_al6_kkhaku\Harek_1992_2014"
global khak "D:\e17\custom-made\u1054_al6_kkhaku\kkhaku_2015_2021"

	global uni9298 "${uni}\kkhaku_1992_1998.dta"
	global uni99 "${uni}\kkhaku_1999.dta"
	global uni00 "${uni}\kkhaku_2000.dta"
	global uni01 "${uni}\kkhaku_2001.dta"
	global uni02 "${uni}\kkhaku_2002.dta"
	global uni03 "${uni}\kkhaku_2003.dta"
	global uni04 "${uni}\kkhaku_2004.dta"
	global uni05 "${uni}\kkhaku_2005.dta"
	global uni06 "${uni}\kkhaku_2006.dta"
	global uni07 "${uni}\kkhaku_2007.dta"
	global uni08 "${uni}\kkhaku_2008.dta"
	global uni09 "${uni}\kkhaku_2009.dta"
	global uni10 "${uni}\kkhaku_2010.dta"
	global uni11 "${uni}\kkhaku_2011.dta"
	global uni12 "${uni}\kkhaku_2012.dta"
	global uni13 "${uni}\kkhaku_2013.dta"
	global uni14 "${uni}\kkhaku_2014.dta"
	global khak15 "${khak}\kkhaku_2015.dta"
	global khak16 "${khak}\kkhaku_2016.dta"
	global khak17 "${khak}\kkhaku_2017.dta"
	global khak18 "${khak}\kkhaku_2018.dta"
	global khak19 "${khak}\kkhaku_2019.dta"
	global khak20 "${khak}\kkhaku_2020.dta"
	global khak21 "${khak}\kkhaku_2021.dta"

global temp "W:\Lotta Lintunen\statatemp"
****************************************************
* 1992-1998
use "$uni9298", clear
keep shnro hvuosi hyv
drop if shnro=="" // (6,240 observations deleted)
destring, replace
ren hvuosi vuosi
gen unirec=.
replace unirec= 1 if hyv==1
replace unirec= 0 if hyv==2
lab def unirec 1 "received" 0 "disqualified"
lab val unirec unirec
ta vuosi unirec, row m
keep shnro vuosi unirec
save "$data\yohaku9298.dta", replace

* 1999-2003
use "$uni99", clear
keep shnro hvuosi hyv vahv kirjo pkoul
ren hvuosi vvuosi
destring, replace
save "$data\yohaku99.dta", replace
use "$uni00", clear
keep shnro vvuosi hyv vahv kirjo pkoul
destring, replace
save "$data\yohaku00.dta", replace
use "$uni01", clear
keep shnro vvuosi hyv vahv kirjo pkoul
destring, replace
save "$data\yohaku01.dta", replace
use "$uni02", clear
keep shnro vvuosi hyv vahv kirjo pkoul
destring, replace
save "$data\yohaku02.dta", replace
use "$uni03", clear
keep shnro vvuosi hyv vahv kirjo pkoul
destring, replace
save "$data\yohaku03.dta", replace

use "$data\yohaku99.dta", clear
append using "$data\yohaku00.dta"
append using "$data\yohaku01.dta"
append using "$data\yohaku02.dta"
append using "$data\yohaku03.dta"

sort shnro vvuosi
recode pkoul (1 2 3 4 5 6 = 1 "yotutk") (else = 0 "muu pohjakoulutus"), gen(baseedu)
ta vvuosi baseedu, row m
drop pkoul
ren vvuosi vuosi
order shnro vuosi baseedu hyv vahv kirjo
count if shnro=="" // missing id
drop if shnro=="" // (11,409 observations deleted)
save "$data\baseedu19992003_incldupl.dta", replace
erase "$data\yohaku99.dta"
erase "$data\yohaku00.dta"
erase "$data\yohaku01.dta"
erase "$data\yohaku02.dta"
erase "$data\yohaku03.dta"

* 2004-2009
use "$uni04", clear
keep shnro vvuosi vtulos vahv kirjo hakuper
destring, replace
save "$data\yohaku04.dta", replace
use "$uni05", clear
keep shnro vvuosi vtulos vahv kirjo hakuper
destring, replace
save "$data\yohaku05.dta", replace
use "$uni06", clear
keep shnro vvuosi vtulos vahv kirjo hakuper
destring, replace
save "$data\yohaku06.dta", replace
use "$uni07", clear
keep shnro vvuosi vtulos vahv kirjo hakuper
destring, replace
save "$data\yohaku07.dta", replace
use "$uni08", clear
keep shnro vvuosi vtulos vahv kirjo hakuper
destring, replace
save "$data\yohaku08.dta", replace
use "$uni09", clear
keep shnro vvuosi vtulos vahv kirjo hakuper
destring, replace
save "$data\yohaku09.dta", replace

use "$data\yohaku04.dta", clear
append using "$data\yohaku05.dta"
append using "$data\yohaku06.dta"
append using "$data\yohaku07.dta"
append using "$data\yohaku08.dta"
append using "$data\yohaku09.dta"

ren hakuper pkoul
ren vtulos hyv

sort shnro vvuosi
ta vvuosi pkoul, row m // 2009: 85.91% coded as 0-->1, .94% coded as 1-->3, 0.06% coded as 3--> 4
recode pkoul (0 1 2 3 4 5 6 = 1 "yotutk") (else = 0 "muu pohjakoulutus"), gen(baseedu) // 1-6 yo, pohj. yo, ib, rb, eb, abi 
ta vvuosi baseedu, row m
drop pkoul
ren vvuosi vuosi
order shnro vuosi baseedu hyv vahv kirjo
count if shnro=="" // missing id
drop if shnro=="" // (57,095 observations deleted)
save "$data\baseedu20042009_incldupl.dta", replace
erase "$data\yohaku04.dta"
erase "$data\yohaku05.dta"
erase "$data\yohaku06.dta"
erase "$data\yohaku07.dta"
erase "$data\yohaku08.dta"
erase "$data\yohaku09.dta"


use "$data\baseedu19992003_incldupl.dta", clear
append using "$data\baseedu20042009_incldupl.dta"
sort shnro vuosi

ta vuosi hyv, row m
ta vuosi vahv, row m
ta vuosi kirjo, row m
ta vuosi baseedu, row m

*** APPLIED
gen applied = 0
replace applied = 1 if baseedu == 1

*** RECEIVED for years when baseedu !missing
ta vuosi hyv, row m
gen unirec2=.
replace unirec2= 1 if hyv==1| hyv==4 & applied==1
replace unirec2= 0 if hyv==2 | hyv==3 | hyv==0 & applied==1
lab def unirec 1 "received" 0 "disqualified"
lab val unirec2 unirec
ta vuosi unirec2, row m

*** ACCEPTED for years when baseedu !missing
ta vuosi vahv, row m
gen uniaccept2=.
replace uniaccept2= 1 if vahv==1 | vahv==8 & applied==1
replace uniaccept2= 0 if vahv==0 | vahv==2 | vahv==3 | vahv==4 | vahv==5 | vahv==6 | vahv==7 | vahv==8 & applied==1
lab def uniaccept 1 "accepted" 0 "did not accept"
lab val uniaccept2 uniaccept
ta uniaccept2, m
ta vuosi uniaccept2, row m
ta unirec uniaccept2, row
bysort vuosi:  ta unirec uniaccept2, row 

*** ENROLLED for years when baseedu !missing
ta vuosi kirjo, row m
gen enrolled2=.
replace enrolled2 = 0 if kirjo==0 & vuosi<=2001 | kirjo==0 & vuosi>2001 | kirjo==3 & vuosi>2001 & applied==1
replace enrolled2 = 1 if kirjo==1 | kirjo==6 & vuosi>2001 | kirjo==4 | kirjo==5 & applied==1
replace enrolled2 = 2 if kirjo==7 & applied==1
lab def enrolled 0 "did not enrol" 1 "enrolled" 2 "absent"
lab val enrolled2 enrolled
ta enrolled2, m
ta unirec enrolled2, row m // very few cases enrolled2 as absent, recode as enrolled2
recode enrolled2(0=0) (1 2 =1) // (667 changes made to unienrol)
replace enrolled2 = 1 if uniaccept2 == 1 & enrolled2 ==. // (31,467 real changes made)

*** RECEIVED
ta vuosi hyv, row m
gen unirec=.
replace unirec= 1 if hyv==1| hyv==4 
replace unirec= 0 if hyv==2 | hyv==3 | hyv==0
lab val unirec unirec
ta vuosi unirec, row m

*** ACCEPTED 
ta vuosi vahv, row m
gen uniaccept=.
replace uniaccept= 1 if vahv==1 | vahv==8
replace uniaccept= 0 if vahv==0 | vahv==2 | vahv==3 | vahv==4 | vahv==5 | vahv==6 | vahv==7 | vahv==8 
lab val uniaccept uniaccept
ta uniaccept, m
ta vuosi uniaccept, row m
ta unirec uniaccept, row
bysort vuosi:  ta unirec uniaccept, row 

*** ENROLLED
ta vuosi kirjo, row m
gen enrolled=.
replace enrolled = 0 if kirjo==0 & vuosi<=2001 | kirjo==0 & vuosi>2001 | kirjo==3 & vuosi>2001 
replace enrolled = 1 if kirjo==1 | kirjo==6 & vuosi>2001 | kirjo==4 | kirjo==5
replace enrolled = 2 if kirjo==7
lab val enrolled enrolled
ta enrolled, m
ta unirec enrolled, row m // very few cases enrolled as absent, recode as enrolled
recode enrolled(0=0) (1 2 =1) // (667 changes made to unienrol)
replace enrolled = 1 if uniaccept == 1 & enrolled ==. // (31,467 real changes made)

ta unirec unirec2, row m // 2 only if applied with YO
ta uniaccept uniaccept2, row m // 2 only if applied with YO
ta enrolled enrolled2, row m // 2 only if applied with YO

keep shnro vuosi baseedu unirec* uniaccept* enrolled*
order shnro vuosi baseedu unirec* uniaccept* enrolled*
save "$data\baseedu19992009_incldupl.dta", replace

* 2010-2014
*hakuper/pkoul = baseedu missing from 2010 onwards
use "$uni10", clear
keep shnro vvuosi vtulos vahv kirjo
destring, replace
save "$data\yohaku10.dta", replace
use "$uni11", clear
keep shnro vvuosi vtulos vahv kirjo
destring, replace
save "$data\yohaku11.dta", replace
use "$uni12", clear
keep shnro vvuosi vtulos vahv kirjo
destring, replace
save "$data\yohaku12.dta", replace
use "$uni13", clear
keep shnro vvuosi vtulos vahv kirjo
destring, replace
save "$data\yohaku13.dta", replace
use "$uni14", clear
keep shnro vvuosi vtulos vahv kirjo
destring, replace
save "$data\yohaku14.dta", replace

use "$data\yohaku10.dta", clear
append using "$data\yohaku11.dta"
append using "$data\yohaku12.dta"
append using "$data\yohaku13.dta"
append using "$data\yohaku14.dta"
ren vvuosi vuosi
ren vtulos hyv

*** RECEIVED
ta vuosi hyv, row m
gen unirec=.
replace unirec= 1 if hyv==1| hyv==4
replace unirec= 0 if hyv==2 | hyv==3 | hyv==0
lab def unirec 1 "received" 0 "disqualified"
lab val unirec unirec
ta vuosi unirec, row m

*** ACCEPTED 
ta vuosi vahv, row m
gen uniaccept=.
replace uniaccept= 1 if vahv==1 | vahv==8
replace uniaccept= 0 if vahv==0 | vahv==2 | vahv==3 | vahv==4 | vahv==5 | vahv==6 | vahv==7 | vahv==8 
lab def uniaccept 1 "accepted" 0 "did not accept"
lab val uniaccept uniaccept
ta uniaccept, m
ta vuosi uniaccept, row m
ta unirec uniaccept, row
bysort vuosi:  ta unirec uniaccept, row 

*** ENROLLED
ta vuosi kirjo, row m
gen enrolled=.
replace enrolled = 0 if kirjo==0 & vuosi<=2001 | kirjo==0 & vuosi>2001 | kirjo==3 & vuosi>2001
replace enrolled = 1 if kirjo==1 | kirjo==6 & vuosi>2001 | kirjo==4 | kirjo==5
replace enrolled = 2 if kirjo==7 
lab def unienrol 0 "did not enrol" 1 "enrolled" 2 "absent"
lab val enrolled unienrol
ta enrolled, m
ta unirec enrolled, row m // very few cases enrolled as absent, recode as enrolled
recode enrolled(0=0) (1 2 =1) // (316 changes made to unienrol)
replace enrolled = 1 if uniaccept == 1 & enrolled ==. // (16,340 real changes made)
keep shnro vuosi unirec uniaccept enrolled
order shnro vuosi unirec uniaccept enrolled
save "$data\baseedu20102014_incldupl.dta", replace

erase "$data\yohaku10.dta"
erase "$data\yohaku11.dta"
erase "$data\yohaku12.dta"
erase "$data\yohaku13.dta"
erase "$data\yohaku14.dta"

* 2015-2018
* the following raw files include both uni and poly applicants: opmast 62=amk, 63=alempi kk-tutkinto, 71=ylempi amk, 72=ylemppi kk-tutkinto
use "$khak15", clear
keep shnro hakuvuosi valinnan_tilatk vastaanoton_tilatk ilmoittautumisen_tilatk opmast 
destring, replace
keep if opmast==63 | opmast==72
ren hakuvuosi vuosi
save "$data\yohaku15.dta", replace
use "$khak16", clear
keep shnro hakuvuosi VALINNAN_TILATK VASTAANOTON_TILATK ILMOITTAUTUMISEN_TILATK opmast
destring, replace
recode opmast (62 = 62) (63 = 63) (71 = 71) (72 = 72) (else = .)
keep if opmast==63 | opmast==72
ren hakuvuosi vuosi
ren VALINNAN_TILATK valinnan_tilatk
ren VASTAANOTON_TILATK vastaanoton_tilatk
ren ILMOITTAUTUMISEN_TILATK ilmoittautumisen_tilatk
save "$data\yohaku16.dta", replace
use "$khak17", clear
keep shnro  hakuvuosi valinnan_tilatk vastaanoton_tilatk ilmoittautumisen_tilatk opmast
destring, replace
recode opmast (62 = 62) (63 = 63) (71 = 71) (72 = 72) (else = .)
keep if opmast==63 | opmast==72
ren hakuvuosi vuosi
save "$data\yohaku17.dta", replace
use "$khak18", clear
keep shnro hakuvuosi valinnan_tilatk vastaanoton_tilatk ilmoittautumisen_tilatk opmast
destring, replace
recode opmast (62 = 62) (63 = 63) (71 = 71) (72 = 72) (else = .)
keep if opmast==63 | opmast==72
ren hakuvuosi vuosi
save "$data\yohaku18.dta", replace

use "$data\yohaku15.dta", clear
append using "$data\yohaku16.dta"
append using "$data\yohaku17.dta"
append using "$data\yohaku18.dta"

*** RECEIVED
gen unirec=.
replace unirec= 1 if valinnan_tilatk==1 | valinnan_tilatk==7
replace unirec= 0 if valinnan_tilatk==2 | valinnan_tilatk==3 | valinnan_tilatk==4 | valinnan_tilatk==5 | valinnan_tilatk==6
lab def unirec 1 "received" 0 "disqualified"
lab val unirec unirec
ta vuosi unirec, row m

*** ACCEPTED
gen uniaccept=.
replace uniaccept= 1 if vastaanoton_tilatk==1 | vastaanoton_tilatk==7 | vastaanoton_tilatk==8
replace uniaccept= 0 if vastaanoton_tilatk==2 | vastaanoton_tilatk==3 | vastaanoton_tilatk==4 | vastaanoton_tilatk==5 | vastaanoton_tilatk==6 | vastaanoton_tilatk==9
lab def uniaccept 1 "accepted" 0 "did not accept"
lab val uniaccept uniaccept
ta uniaccept, m
ta vuosi uniaccept, row m
ta unirec uniaccept, row

*** ENROLLED
gen enrolled=.
replace enrolled = 0 if ilmoittautumisen_tilatk==7 | ilmoittautumisen_tilatk==8 | ilmoittautumisen_tilatk==9 
replace enrolled = 1 if ilmoittautumisen_tilatk==1 | ilmoittautumisen_tilatk==2 | ilmoittautumisen_tilatk==3
replace enrolled = 1 if ilmoittautumisen_tilatk==4 | ilmoittautumisen_tilatk==5 | ilmoittautumisen_tilatk==6
lab def unienrol 0 "did not enrol" 1 "enrolled" 2 "absent"
lab val enrolled unienrol
ta enrolled, m
recode enrolled(0=0) (1 2 =1) // 
replace enrolled = 1 if uniaccept == 1 & enrolled ==. // 
keep shnro vuosi unirec uniaccept enrolled
order shnro vuosi unirec uniaccept enrolled
save "$data\baseedu20152018_incldupl.dta", replace

use "$data\baseedu20102014_incldupl.dta", clear
append using "$data\baseedu20152018_incldupl.dta"
save "$data\baseedu20102018_incldupl.dta", replace

erase "$data\yohaku15.dta"
erase "$data\yohaku16.dta"
erase "$data\yohaku17.dta"
erase "$data\yohaku18.dta"
erase "$data\baseedu20102014_incldupl.dta"
erase "$data\baseedu20152018_incldupl.dta"

use "$data\baseedu19992009_incldupl.dta", clear
append using "$data\baseedu20102018_incldupl.dta", force
sort shnro vuosi
count if shnro=="" // missing id
drop if shnro=="" // (112,596 observations deleted)
duplicates drop // (1,850,211 observations deleted)
compress
save "$data\yohaku_19992018_incldupl.dta", replace

* create a filter to select one (first) person-year
use "$data\yohaku9298.dta", clear
append using "$data\yohaku_19992018_incldupl.dta", force
sort shnro vuosi
* keep only one observation per year/person: 1992-2018 only unirec, 1999-2018 all
gen filter = 0

*1992-2018 priority chain
forvalues yr = 1992/2018 {
	by shnro: gen already_selected = sum(filter) > 0
	by shnro: replace filter = 1 if vuosi==`yr' & enrolled==1 & !already_selected
	drop already_selected
	
	by shnro: gen already_selected = sum(filter) > 0
	by shnro: replace filter = 1 if vuosi==`yr' & enrolled==. & uniaccept==. & unirec==1 & !already_selected
	drop already_selected
}
ta filter

* variables for years when first applied, first received, first enrolled
gen applied=1
order shnro vuosi baseedu applied
sort shnro vuosi
bysort shnro (vuosi): egen year_applied = min(cond(applied==1, vuosi, .))
bysort shnro (vuosi): egen year_received = min(cond(unirec==1, vuosi, .))
bysort shnro (vuosi): egen year_accepted = min(cond(uniaccept==1, vuosi, .))
bysort shnro (vuosi): egen year_enrolled = min(cond(enrolled==1, vuosi, .))
save "$data\yohaku_19922018_incldupl.dta", replace

use "$data\yohaku_19922018_incldupl.dta", clear
merge m:m shnro using "$data\EYUG_1980.dta", keepusing(YO year_YO MA year_MA) 
duplicates report shnro vuosi
* keep only one observation per person with complete data of the first successful transitions
sort shnro vuosi
gen tier = cond(YO==1 & _merge==3, 5, /// tier 5: YO & in the target cohorts
		cond(!mi(year_enrolled), 4, ///  tier 4: all transitions successful
		cond(!mi(year_accepted), 3, /// tier 3: missing enrolled
		cond(!mi(year_received), 2, /// tier 2: missing received
		cond(!mi(year_applied), 1, 0))))) // tier 1: only applied exists
gsort shnro -tier vuosi
* keep highest tier record		
by shnro: keep if _n==1

drop unirec uniaccept enrolled
order shnro vuosi baseedu applied year_applied year_received year_accepted year_enrolled
save "$data\yohaku_19922018_nodupl.dta", replace

*===============================================================================
* 6. Parental data
*===============================================================================
* match children to parents
merge m:1 shnro using "D:\e17\custom-made\muut_aineistot\lapset_yhdetvanhemmat_18.dta", keep(match master) nogen 

gen vuosi=cohort+15
*family id 
sort shnro vuosi
drop if aiti_shnro=="" | aiti_shnro=="" & isa_shnro=="" 
replace isa_shnro="9999" if isa_shnro=="" // (1,205 real changes made) no father in the data
egen famid = group(aiti_shnro isa_shnro) // family id for kids 

ren shnro ch_shnro		
ren aiti_shnro m_shnro
ren isa_shnro f_shnro
save "$EYUG_survival1980_par.dta", replace

* Basic info from census
use shnro vuosi syntyv kuolv kunta ktutk using "$census", clear 
duplicates drop shnro vuosi, force // (2,721 observations deleted)
ren ktutk koulk
destring, replace
save "$data\vl7085.dta", replace
	merge 1:1 shnro vuosi using "$folk\folk_19872000_tua_perus22tot_1.dta", ///
	keepusing(syntyv kuolv yotutk kunta) keep(match master match_update) update nogen force
	merge 1:1 shnro vuosi using "$folk\folk_20012010_tua_perus22tot_1.dta", ///
	keepusing(syntyv kuolv yotutk kunta) keep(match master match_update) update nogen force
	merge 1:1 shnro vuosi using "$folk\folk_20112020_tua_perus22tot_1.dta", ///
	keepusing(syntyv kuolv yotutk kunta) keep(match master match_update) update nogen force
destring, replace
compress
save "$data\parents80.dta", replace

* Parental education
	merge m:1 shnro vuosi using "$tutk\folk_19872000_tua_tutk21tot_1.dta", ///
	keepusing(koulk) keep(match master) update nogen force
	merge m:1 shnro vuosi using "$tutk\folk_20012010_tua_tutk21tot_1.dta", ///
	keepusing(koulk) keep(match master match_update) update nogen force
	merge m:1 shnro vuosi using "$tutk\folk_20112019_tua_tutk21tot_1.dta", ///
	keepusing(koulk) keep(match master match_update) update nogen force


* fill in missing data for parental syntyv kuolv  
sort ch_shnro vuosi
by ch_shnro: carryforward m_syntyv m_kuolv m_yotutk m_kunta f_syntyv f_kuolv f_yotutk f_kunta, replace
gsort ch_shnro -vuosi
by ch_shnro: carryforward m_syntyv m_kuolv m_yotutk m_kunta f_syntyv f_kuolv f_yotutk f_kunta, replace
sort ch_shnro vuosi

ta ch_syntyv if m_syntyv== . & vuosi==ch_syntyv+15 // mothers year of birth missing on average in 600 cohort-year-cases
	
destring, replace

* mothers education
gen m_edu_3digit= int(m_koulk/1000) // Collapse koulk variable into 3-digit format
recode m_edu_3digit (311/499=2 "voc sec") (301/309=3 "gen sec") (511/599 613 628 653 654 =4 ///
"opisto") (611 621 631 651 652 661 671 681 691 =5 "poly") (612 622/627 629 632/634 639 ///
642 649 655 659 662 672 682 692 699 =6 "bach uni") (711 721 731 750 761 771 781 791 =7 ///
"mast poly") (712 719 722/729 732/739 742 749 751 754 759 762 772 775 782 792 799 =8 ///
"mast uni") (811/899=9 "lic/doct"), gen(m_edu)
replace m_edu=1 if m_edu==. & vuosi>=m_syntyv+16 & m_kuolv>vuosi // 1=no degrees after compulsory schooling, which ends at age 16
replace m_edu=4 if inlist(m_koulk, 662551, 662552, 662599, 672651) // errors in the original code
replace m_edu=4 if inlist(m_koulk, 682401, 682499) // errors in the original code
replace m_edu=4 if inlist(m_koulk, 613952, 719952, 719953) // errors in the original code
recode m_edu 1=1 2 417/487=2 3=3 4=4 5=5 6=6 7=7 8=8 9=9 // special vocational degrees
lab var m_edu "Highest completed degree"

* fathers education
gen f_edu_3digit= int(f_koulk/1000) // Collapse koulk variable into 3-digit format
recode f_edu_3digit (311/499=2 "voc sec") (301/309=3 "gen sec") (511/599 613 628 653 654 =4 ///
"opisto") (611 621 631 651 652 661 671 681 691 =5 "poly") (612 622/627 629 632/634 639 ///
642 649 655 659 662 672 682 692 699 =6 "bach uni") (711 721 731 750 761 771 781 791 =7 ///
"mast poly") (712 719 722/729 732/739 742 749 751 754 759 762 772 775 782 792 799 =8 ///
"mast uni") (811/899=9 "lic/doct"), gen(f_edu)
replace f_edu=1 if f_edu==. & vuosi>=f_syntyv+16 & f_kuolv>vuosi // 1=no degrees after compulsory schooling, which ends at age 16
replace f_edu=4 if inlist(f_koulk, 662551, 662552, 662599, 672651) // errors in the original code
replace f_edu=4 if inlist(f_koulk, 682401, 682499) // errors in the original code
replace f_edu=4 if inlist(f_koulk, 613952, 719952, 719953) // errors in the original code
recode f_edu 1=1 2 417/487=2 3=3 4=4 5=5 6=6 7=7 8=8 9=9 // special vocational degrees
lab var f_edu "Highest completed degree"

* add basic education: define as "basic/unknown" if no qualification in educational register, but resident in Finland in given year
foreach i in m f { // only highest and most recent other than highest
	gen `i'_edua = `i'_edu
	replace `i'_edua=1 if `i'_edua==. & `i'_kunta !=. & `i'_yotutk==0 // no gymnasium
	replace `i'_edua=3 if `i'_edua==. & `i'_kunta !=. & `i'_yotutk==4  // high school graduates
 } 

* add the age-related basic education (assuming almost 100% graduate from basic edu) and forward education NOTE! many missing parental year of birth!!
gen m_edub=m_edua // 
recode m_edub (.=1) if vuosi>=m_syntyv+15 & m_syntyv != . // (10394025 changes made to m_edub)
gen f_edub=f_edua // 
recode f_edub (.=1) if vuosi>=f_syntyv+15 & f_syntyv != . // (1697571 changes made to f_edub)

ta ch_syntyv m_edub, row m
ta ch_syntyv f_edub, row m
ta ch_syntyv if m_edub==. | f_edub==.

bysort m_shnro vuosi: carryforward m_edub, replace //  (243 real changes made)
bysort f_shnro vuosi: carryforward f_edub, replace // (672 real changes made)

lab def edu_b 1 "basic/unknown" 2 "voc. sec." 3 "gen. sec." 4 "lowest tert." 5 "poly. ba" 6 "uni BA" 7 "poly MA" 8 "uni MA" 9 "lic/PhD"
lab val m_edub edu_b
lab val f_edub edu_b

sort ch_shnro vuosi
by ch_shnro: carryforward m_edub, replace // (2503961 real changes made)
by ch_shnro: carryforward f_edub, replace // (2577233 real changes made)

egen paredu_yearly=rowmax(m_edub f_edub)
lab val paredu_yearly edu_b

* create paredu, dominance approach
egen paredu=rowmax(m_edub f_edub) if vuosi==ch_syntyv+15
lab def paredu 1 "no degree" 2 "voc sec" 3 "gen sec" 4 "lowest tert." 5 "BA poly" 6 "BA uni" 7 "MA poly" 8 "MA uni" 9 "lic/doct"
lab val paredu paredu
lab var paredu "Highest parental education"
ta paredu, m //

recode paredu (1=4 "no degree") (2/3=3 "sec edu") (4/6=2 "low tert.") (7/9=1 "high tert."), gen(pedu4cat)
lab var pedu4cat "Highest parental education"
ta pedu4cat, m //

* carry forward & backward paredu pedu4cat
sort ch_shnro vuosi
bysort ch_shnro (vuosi): carryforward paredu, replace // (29791847 real changes made)
bysort ch_shnro (vuosi): carryforward pedu4cat, replace // (29791847 real changes made)
gsort ch_shnro - vuosi
carryforward paredu, replace // (14,281,535 real changes made)
carryforward pedu4cat, replace // (14,281,535 real changes made)

*keep vuosi *shnro *syntyv *kuolv ika id ika_suorv edu_b famid *koulk *edub
save "$data\basic_tutk_parents6090.dta", replace


*===============================================================================
* 7. Prepare EYUG data
*===============================================================================
use "$data\basic_tutk_parents6090.dta", clear
ren ch_shnro shnro
ren ch_syntyv syntyv
sort shnro vuosi

* generate dummies for each educational outcome
gen year_MA=.
forvalues i=0/4 {
	replace year_MA=suorv_`i' if edulvl`i'==8 & year_MA==. // Eka maisterintutkinto
}
replace year_MA =. if year_MA==2091
gen MA = 0
replace MA = 1 if year_MA != .

gen year_YO=.
forvalues i=0/4 {
	replace year_YO=suorv_`i' if edulvl`i'==3 & year_YO==. // Eka yotutkintovuosi
}
gen YO = 0
replace YO = 1 if year_YO != .

ta syntyv year_YO, row m
ta syntyv year_MA, row m

gen year_POLY=.
forvalues i=0/4 {
	replace year_POLY=suorv_`i' if edulvl`i'==5 & year_POLY==. // Eka amk-tutkinto
}
replace year_POLY =. if year_POLY==2091
gen POLY = 0
replace POLY = 1 if year_POLY != .

gen year_VOC=.
forvalues i=0/4 {
	replace year_VOC=suorv_`i' if edulvl`i'==2 & year_VOC==. // Eka ammattikoulututkinto
}
gen VOC = 0
replace VOC = 1 if year_VOC != .

gen year_TERT=.
forvalues i=0/4 {
	replace year_TERT=suorv_`i' if year_TERT==. & edulvl`i'==5 | edulvl`i'==8 // Eka amk-tutkinto tai eka yo maisterintutkinto
}
gen TERT = 0
replace TERT = 1 if year_TERT != .

tab1 year_POLY year_VOC year_TERT, m

* create age variables
gen age_gym = year_YO - cohort if YO==1
gen age_appl = year_applied - cohort if year_applied != .
gen age_enter = year_enrolled - cohort if year_enrolled != .
gen age_grad = year_MA - cohort if YO==1. 

* tidy up
keep shnro vuosi syntyv female YO year_YO MA year_MA VOC year_VOC POLY year_POLY TERT year_TERT ///
	age_gym age_appl age_enter age_grad ///
	paredu ulkom

order vuosi syntyv female YO year_YO VOC year_VOC POLY year_POLY MA year_MA TERT year_TERT paredu
destring, replace
*replace ulkom = 0 if ulkom==.

drop if syntyv==.
save "$data\EYUG_19601990.dta", replace

keep if syntyv == 1980
save "$data\EYUG_1980.dta", replace

* merge application data with basic & degree data 1980 cohort
use "$data\EYUG_1980.dta", clear
sort shnro vuosi
merge 1:1 shnro vuosi using "$data\yohaku_19922018_nodupl.dta", nogen

* fill in
drop if syntyv==.
drop if vuosi==.
foreach var of varlist baseedu applied year_applied year_received year_accepted year_enrolled tier paredu syntyv {
	bysort shnro (vuosi): replace `var' = `var'[_n-1] if missing(`var')
	gsort shnro -vuosi
	bysort shnro: replace `var' = `var'[_n-1] if missing(`var')
	sort shnro vuosi
}

* fill in
foreach var of varlist syntyv female YO year_YO VOC year_VOC POLY year_POLY MA year_MA TERT year_TERT paredu  {
	bysort shnro (vuosi): replace `var' = `var'[_n-1] if missing(`var')
	gsort shnro -vuosi
	bysort shnro: replace `var' = `var'[_n-1] if missing(`var')
	sort shnro vuosi
}
drop if female==. // changed legal gender within the observation period
compress
save "$data\EYUG_1980.dta", replace

* 1 observation per person
sort shnro vuosi
bysort shnro(vuosi): replace _merge = _merge[_n-1] if missing(_merge)
gsort shnro -vuosi
bysort shnro: replace _merge = _merge[_n-1] if missing(_merge)
sort shnro vuosi

ta syntyv if year_applied<year_YO & year_YO!=. & _merge!=.
ta syntyv YO if year_applied<year_YO & year_YO!=. & _merge!=.

ta syntyv if year_applied<(year_YO -1) & year_YO!=. & _merge!=.
ta syntyv YO if year_applied<(year_YO -1) & year_YO!=. & _merge!=.

sort shnro vuosi
bysort shnro: keep if _n==_N
duplicates report shnro vuosi
ta syntyv YO if year_applied<(year_YO -1) & year_YO!=.

recode paredu (1=1 "basic/unknown") (2 3=2 "secondary") (4 5=3 "low tert.") (6 7 8 9=4 "high tert."), gen(pedu)
ren syntyv cohort

* clean up
drop unirec2 uniaccept2 enrolled2 _merge tier filter vuosi

order shnro cohort female YO year_YO VOC year_VOC POLY year_POLY MA year_MA TERT year_TERT pedu
drop if cohort == . 
save "$data\EYUG_survival1980.dta", replace

use "$data\EYUG_19601990.dta", clear
* 1 observation per person
sort shnro vuosi
bysort shnro(vuosi): replace _merge = _merge[_n-1] if missing(_merge)
gsort shnro -vuosi
bysort shnro: replace _merge = _merge[_n-1] if missing(_merge)
sort shnro vuosi

ta syntyv if year_applied<year_YO & year_YO!=. & _merge!=.
ta syntyv YO if year_applied<year_YO & year_YO!=. & _merge!=.

ta syntyv if year_applied<(year_YO -1) & year_YO!=. & _merge!=.
ta syntyv YO if year_applied<(year_YO -1) & year_YO!=. & _merge!=.

sort shnro vuosi
bysort shnro: keep if _n==_N
duplicates report shnro vuosi
ta syntyv YO if year_applied<(year_YO -1) & year_YO!=.

recode paredu (1=1 "basic/unknown") (2 3=2 "secondary") (4 5=3 "low tert.") (6 7 8 9=4 "high tert."), gen(pedu)
ren syntyv cohort

* clean up
drop unirec2 uniaccept2 enrolled2 _merge tier filter vuosi

order shnro cohort female YO year_YO VOC year_VOC POLY year_POLY MA year_MA TERT year_TERT pedu
drop if cohort == . // (271 observations deleted)

save "$data\EYUG_survival19601990.dta", replace
********************************************

exit, clear