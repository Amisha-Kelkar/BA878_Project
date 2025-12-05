# Column Provenance — Final Dataset (rework14)

This file documents the origin, aggregation, and meaning of all **106 columns**
in the final merged dataset used for SIC and DIC prediction modeling.

---

# 1. Identifiers & Time Anchors

| Column | Source | Notes |
|--------|--------|-------|
| subject_id | icustays | ICU patient ID |
| stay_id | icustays | ICU stay ID |
| chart_date | derived | daily aggregation anchor |
| suspected_infection_time | sepsis3 | timestamp |
| infection_date | sepsis3 | DATE(suspected_infection_time) |
| sepsis_day | computed | chart_date − infection_date |

---

# 2. Vitals (Daily Aggregated)

| Column |
|--------|
| max_heart_rate |
| min_mbp |
| max_resp_rate |
| min_spo2 |
| max_temperature |
| mean_heart_rate |
| mean_mbp |
| mean_resp_rate |

Source: `vitalsign`  
Aggregation: MAX, MIN, AVG

---

# 3. Ventilator Features

| Column |
|--------|
| mean_fio2 |
| max_fio2 |
| min_fio2 |
| mean_peep |
| max_peep |
| min_peep |
| mean_tidal_volume |
| max_tidal_volume |
| min_tidal_volume |
| mean_minute_volume |
| max_minute_volume |
| min_minute_volume |
| plateau_pressure_avg |

Source: `ventilator_setting`  
Aggregation: AVG, MIN, MAX

---

# 4. Blood Gas Features

| Column |
|--------|
| aado2_avg |
| so2_avg |
| po2_avg |
| pco2_avg |
| fio2_avg |
| bg_aado2_avg |
| pao2fio2ratio_avg |
| ph_avg |
| baseexcess_avg |
| bicarbonate_avg |
| totalco2_avg |
| bg_hematocrit_avg |
| bg_hemoglobin_avg |
| bg_chloride_avg |
| bg_calcium_avg |
| bg_temperature_avg |
| bg_potassium_avg |
| bg_sodium_avg |
| bg_lactate_avg |
| bg_glucose_avg |

Source: `blood gas`  
Aggregation: AVG

---

# 5. CBC / Hematology

| Column |
|--------|
| mch_avg |
| mchc_avg |
| mcv_avg |
| platelet_avg |
| rbc_avg |
| rdw_avg |
| rdwsd_avg |
| wbc_avg |

Source: labs  
Aggregation: AVG

---

# 6. Chemistry Panel

| Column |
|--------|
| albumin_avg |
| globulin_avg |
| total_protein_avg |
| aniongap_avg |
| bun_avg |
| creatinine_avg |
| d_dimer_avg |
| fibrinogen_avg |
| thrombin_avg |
| inr_avg |
| pt_avg |
| ptt_avg |
| alt_avg |
| alp_avg |
| ast_avg |
| bilirubin_total_avg |

---

# 7. Comorbidity Index (Charlson)

| Column |
|--------|
| mi |
| chf |
| malignant_cancer |
| metastatic_solid_tumor |
| severe_liver_disease |
| chronic_pulmonary_disease |
| mild_liver_disease |
| diabetes_with_cc |
| diabetes_without_cc |
| renal_disease |
| stroke |

Source: `charlson`  
Mapping: `(subject_id, hadm_id)` → stay_id  
Aggregation: MAX

---

# 8. SOFA / Organ Failure Flags

| Column |
|--------|
| sw_respiration |
| sw_liver |
| sw_cardiovascular |
| sw_cns |
| sw_renal |
| sw_sofa |
| sw_weight |
| average_sofa_score |
| avg_sofa_score_daily |

---

# 9. Demographics

| Column |
|--------|
| race |
| admission_type |
| age |
| gender |

Source: admissions, icustay_detail, derived.age

---

# 10. Support Therapy

| Column |
|--------|
| vasopressor_use |
| vasopressin_use |
| urine_output_avg |
| rrt |

---

# 11. Anthropometrics

| Column |
|--------|
| height |
| weight_daily |
| height_final |
| weight_final |
| bmi |

Source: derived.height, first_day_weight

---

# This table contains all 106 features.

