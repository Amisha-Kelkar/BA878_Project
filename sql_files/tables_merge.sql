/*
===============================================================================
 REPRESENTATIVE MERGES FOR DATASET CREATION (Final table: rework14)
 This file contains the key SQL merges used to construct the unified 
 patient-day dataset "mlinhealthcaregroup4.temp.rework14" from MIMIC-IV.

 The full build includes 17+ tables; only the core representative components 
 are included here, as the complete raw SQL is too long and repetitive.

 These illustrate the methodology: 
   - Daily aggregation
   - Alignment by stay_id + chart_date
   - Use of stay_id bridges for hospital tables
===============================================================================
*/


--------------------------------------------------------------------------------
-- 1. DAILY VITALS × SEPSIS ANCHOR TABLE
--------------------------------------------------------------------------------

CREATE OR REPLACE TABLE `mlinhealthcaregroup4.temp.sepsis_vitals_daily` AS
WITH daily_vitals AS (
  SELECT
    subject_id,
    stay_id,
    DATE(charttime) AS chart_date,
    MAX(heart_rate) AS max_heart_rate,
    MIN(mbp) AS min_mbp,
    MAX(resp_rate) AS max_resp_rate,
    MIN(spo2) AS min_spo2,
    MAX(temperature) AS max_temperature,
    AVG(heart_rate) AS mean_heart_rate,
    AVG(mbp) AS mean_mbp,
    AVG(resp_rate) AS mean_resp_rate,
    AVG(spo2) AS mean_spo2,
    AVG(temperature) AS mean_temperature
  FROM `mlinhealthcaregroup4.derived_data.vitalsign`
  WHERE charttime IS NOT NULL
  GROUP BY subject_id, stay_id, DATE(charttime)
),
joined AS (
  SELECT
    s.subject_id,
    s.stay_id,
    s.suspected_infection_time,
    DATE(s.suspected_infection_time) AS infection_date,
    s.sofa_score,
    d.chart_date,
    DATE_DIFF(d.chart_date, DATE(s.suspected_infection_time), DAY) AS sepsis_day,
    d.*
  FROM `mlinhealthcaregroup4.derived_data.sepsis3` s
  INNER JOIN daily_vitals d
    ON s.subject_id = d.subject_id
   AND s.stay_id = d.stay_id
  WHERE s.sepsis3 = TRUE
)
SELECT *
FROM joined
WHERE sepsis_day >= 0
ORDER BY subject_id, stay_id, sepsis_day;


--------------------------------------------------------------------------------
-- 2. MERGING DAILY VITALS × VENTILATOR SETTINGS
--------------------------------------------------------------------------------

CREATE OR REPLACE TABLE `mlinhealthcaregroup4.temp.sepsis_vitals_vent_daily` AS
WITH daily_vent AS (
  SELECT
    subject_id,
    stay_id,
    DATE(charttime) AS chart_date,
    AVG(fio2) AS mean_fio2,
    AVG(peep) AS mean_peep,
    AVG(tidal_volume_set) AS mean_tidal_volume,
    AVG(minute_volume) AS mean_minute_volume
  FROM `mlinhealthcaregroup4.derived_data.ventilator_setting`
  GROUP BY subject_id, stay_id, DATE(charttime)
),
joined AS (
  SELECT
    v.*,
    vent.mean_fio2,
    vent.mean_peep,
    vent.mean_tidal_volume,
    vent.mean_minute_volume
  FROM `mlinhealthcaregroup4.temp.sepsis_vitals_daily` v
  LEFT JOIN daily_vent vent
    ON v.subject_id = vent.subject_id
   AND v.stay_id = vent.stay_id
   AND v.chart_date = vent.chart_date
)
SELECT *
FROM joined
ORDER BY subject_id, stay_id, chart_date;


--------------------------------------------------------------------------------
-- 3. CHARLSON COMORBIDITY SUMMARY (HADM_ID → STAY_ID)
--------------------------------------------------------------------------------

CREATE OR REPLACE TABLE temp.CHARLSON_SUMMARY AS
WITH mapped AS (
  SELECT
    i.stay_id,
    c.*
  FROM `physionet-data.mimiciv_3_1_derive.charlson` c
  LEFT JOIN `mimic_core.icustays` i
    ON c.subject_id = i.subject_id
   AND c.hadm_id = i.hadm_id
  WHERE i.stay_id IS NOT NULL
)
SELECT
  stay_id,
  MAX(myocardial_infarct) AS mi,
  MAX(congestive_heart_failure) AS chf,
  MAX(malignant_cancer) AS malignant_cancer,
  MAX(metastatic_solid_tumor) AS metastatic_solid_tumor,
  MAX(severe_liver_disease) AS severe_liver_disease,
  MAX(chronic_pulmonary_disease) AS chronic_pulmonary_disease,
  MAX(mild_liver_disease) AS mild_liver_disease,
  MAX(diabetes_with_cc) AS diabetes_with_cc,
  MAX(diabetes_without_cc) AS diabetes_without_cc,
  MAX(renal_disease) AS renal_disease,
  MAX(cerebrovascular_disease) AS stroke
FROM mapped
GROUP BY stay_id;


--------------------------------------------------------------------------------
-- 4. BLOOD GAS DAILY AGGREGATION
--------------------------------------------------------------------------------

CREATE OR REPLACE TABLE mlnhealthcaregroup4.temp.BG_DAILY AS
SELECT
  stay_id,
  subject_id,
  DATE(charttime) AS chart_date,
  AVG(po2) AS po2_avg,
  AVG(pco2) AS pco2_avg,
  AVG(fio2) AS fio2_avg,
  AVG(aado2) AS aado2_avg,
  AVG(pao2fio2ratio) AS pao2fio2ratio_avg,
  AVG(ph) AS ph_avg,
  AVG(lactate) AS lactate_avg,
  AVG(glucose) AS glucose_avg,
  AVG(temperature) AS temperature_avg
FROM mlnhealthcaregroup4.temp.BG_MAPPED
GROUP BY stay_id, subject_id, chart_date;


--------------------------------------------------------------------------------
-- NOTE: 
-- The final dataset mlinhealthcaregroup4.temp.rework14 was created by 
-- incrementally merging all representative tables plus additional 
-- labs, chemistry, anthropometrics, GCS, RRT, vasopressors, comorbidities.
--------------------------------------------------------------------------------
