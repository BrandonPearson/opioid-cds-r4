library OpioidCDS_REC_10 version '0.1.0'

using FHIR version '4.0.0'

include FHIRHelpers version '4.0.0' called FHIRHelpers
include OpioidCDS_Common version '0.1.0' called Common

codesystem "V2 Interpretation Codes": 'http://hl7.org/fhir/v2/0078'

/*
** Recommendation #10
** Consider urine drug testing before starting opioid therapy and consider urine
** drug testing at least annually to assess for prescribed medications as well
** as other controlled prescription drugs and illicit drugs
*/

/*
  Trigger context:
    Primary care/ambulatory care
  Trigger event:
    Prescription of opioid with ambulatory care abuse potential
  Assumptions:
    Count only ambulatory prescriptions
  Inclusion criteria:
    Opioid Rx for at least 80 of the past 90 days
      AND
        (No Urine Screening in last 12 months
        OR Evidence of Opioids present
        OR Evidence of Illicit drugs present)
  Exclusion criteria (optional):
    Meds indicating end of life
    Conditions indicating end of life
  Notification:
    No Urine Screening in last 12 months - Patients on opioid therapy should have a urine drug test performed every 12 months.
    Evidence of Opioids - Opioid x present in urine screening
    Evidence of Illicit Drugs - Illicit drug x present in urine screening
    Ref: CDC Recommendation #10.
  EHR expectations:
    Have availability to snooze for 3 months

  Plan Definition:
	http://build.fhir.org/ig/cqframework/opioid-cds-r4/PlanDefinition-opioidcds-10.html
*/

code "Positive": 'POS' from "V2 Interpretation Codes"

parameter ContextPrescriptions List<MedicationRequest>

context Patient

define "Lookback Year":
  Interval[Today() - 12 months - 1 days, Today() - 1 day]

define "Validate Trigger Event":
  exists (
    ContextPrescriptions triggerScript
      where triggerScript.medication in Common."Opioids With Ambulatory Misuse Potential"
  )

define "Inclusion Criteria":
  AgeInYears() >= 18
    and "Validate Trigger Event"
    and not "Exclusion Criteria"
    and AnyTrue(Common.ProbableDaysInRange(Common."Active Ambulatory Opioid Rx", 90, 80))
    and
      ("No Urine Screening In Last 12 Months"
        or "Has Evidence of Opioids"
        or "Has Evidence of Illicit Drugs")

define "Exclusion Criteria":
  Common."End of Life Assessment"

define "Illicit Drug Urine Screenings in Last 12 Months":
  [Observation: "code" in Common."Illicit Drug Screening"] observation
    where date from observation.effective.value in day of "Lookback Year"
      sort by effective.value

define "Opioid Drug Urine Screenings in Last 12 Months":
  [Observation: "code" in Common."Opioid Drug Screening"] observation
    where date from observation.effective.value in day of "Lookback Year"
      sort by effective.value

define "Most Recent Illicit Drug Urine Screenings in Last 12 Months":
  Last( "Illicit Drug Urine Screenings in Last 12 Months" )

define "Most Recent Opioid Drug Urine Screenings in Last 12 Months":
  Last( "Opioid Drug Urine Screenings in Last 12 Months" )

define "No Urine Screening In Last 12 Months":
  "Most Recent Illicit Drug Urine Screenings in Last 12 Months" is null
    and "Most Recent Opioid Drug Urine Screenings in Last 12 Months" is null

define "Positive Illicit Drug Screening":
  "Most Recent Illicit Drug Urine Screenings in Last 12 Months" mostRecentScreening
    where
      exists (mostRecentScreening.interpretation interpretation where FHIRHelpers.ToConcept(interpretation) ~ "Positive")
      or exists
      (
        mostRecentScreening.component C
          where C.code in Common."Illicit Drug Screening"
            and exists (C.interpretation i where FHIRHelpers.ToConcept(i) ~ "Positive")
      )

define "Positive Illicit Drug Screening Qualifying Codes":
  "Positive Illicit Drug Screening" positiveScreening
    return
    (
      (
          if exists (positiveScreening.interpretation interpretation where FHIRHelpers.ToConcept(interpretation) ~ "Positive")
          then { positiveScreening.code }
          else {}
      )
      union
      (
        positiveScreening.component C
          where C.code in Common."Illicit Drug Screening"
            and exists (positiveScreening.interpretation interpretation where FHIRHelpers.ToConcept(interpretation) ~ "Positive")
          return C.code
      )
    )

define "Has Evidence of Illicit Drugs":
  "Positive Illicit Drug Screening" is not null

define "Positive Opioid Drug Screening":
  "Most Recent Opioid Drug Urine Screenings in Last 12 Months" mostRecentScreening
  where
    exists (mostRecentScreening.interpretation interpretation where FHIRHelpers.ToConcept(interpretation) ~ "Positive")
    or exists
    (
        mostRecentScreening.component C
          where C.code in Common."Opioid Drug Screening"
            and exists (C.interpretation i where FHIRHelpers.ToConcept(i) ~ "Positive")
    )

define "Positive Opioid Drug Screening Qualifying Codes":
  "Positive Opioid Drug Screening" positiveScreening
  return
  (
    (
      if exists (positiveScreening.interpretation interpretation where FHIRHelpers.ToConcept(interpretation) ~ "Positive")
      then { positiveScreening.code }
      else {}
    )
    union
    (
      positiveScreening.component C
        where C.code in Common."Opioid Drug Screening"
          and exists (positiveScreening.interpretation interpretation where FHIRHelpers.ToConcept(interpretation) ~ "Positive")
        return C.code
    )
  )

define "Has Evidence of Opioids":
  "Positive Opioid Drug Screening" is not null

define "No Screening In Last 12 Months Indicator":
  if "Inclusion Criteria"
    then 'warning'
  else null

define "Evidence of Opioids Indicator":
  if "Inclusion Criteria"
    then 'warning'
  else null

define "Evidence of Illicit Drugs Indicator":
  if "Inclusion Criteria"
    then 'warning'
  else null

define "No Screening In Last 12 Months Summary":
  if "Inclusion Criteria" and "No Urine Screening In Last 12 Months"
    then 'Annual Urine Screening Check'
  else null

define "Evidence of Opioids Summary":
  if "Inclusion Criteria" and "Has Evidence of Opioids"
    then 'Opioids Found In Urine Screening'
  else null

define "Evidence of Illicit Drugs Summary":
  if "Inclusion Criteria" and "Has Evidence of Illicit Drugs"
    then 'Illicit Drugs Found In Urine Screening'
  else null

define "No Screening In Last 12 Months Detail":
  if "Inclusion Criteria" and "No Urine Screening In Last 12 Months"
    then 'Patients on opioid therapy should have a urine drug test performed every 12 months.'
  else null

define "Evidence of Opioids Detail":
  if "Inclusion Criteria" and "Has Evidence of Opioids"
    then
      'Found the following opioid(s): ' +
        Combine(Common.CodeableConceptsToString("Positive Opioid Drug Screening Qualifying Codes"), ', ')
  else null

define "Evidence of Illicit Drugs Detail":
  "Positive Illicit Drug Screening Qualifying Codes" positiveScreening
    return
      if ("Inclusion Criteria" and "Has Evidence of Illicit Drugs")
        then
          'Found the following illicit drug(s) in urine drug screen: ' +
          (
            Combine(Common.CodeableConceptsToString(positiveScreening), ', ')
          )
      else null
