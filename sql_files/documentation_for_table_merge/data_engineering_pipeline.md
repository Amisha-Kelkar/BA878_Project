# Data Engineering Pipeline — Final Dataset (rework14)

This document describes how 17+ MIMIC-IV raw and derived tables were merged into
the final daily patient-level dataset:

**`mlinhealthcaregroup4.temp.rework14`**

containing **106 features** across vitals, ventilator settings, labs, blood gas,
organ dysfunction flags, comorbidities, demographics, anthropometrics, urine
output, and support therapies.

---

# 1. Guiding Principles

### Daily aggregation to `chart_date`  
All timestamped variables were aggregated to the day level to ensure uniform
sampling across modalities.

### ICU-centric joins  
Everything is aligned on `stay_id` — the fundamental key for ICU episodes.

### Mapping hospital tables → ICU stays  
Tables with `(subject_id, hadm_id)` were linked to ICU stays using `icustays`.

### No temporal leakage  
Only same-day or prior information is included for each row.

---

# 2. Merge Stages

## **Stage 1 — Sepsis Anchoring + Daily Vitals**
Builds `sepsis_vitals_daily` containing:
- suspected infection time  
- SOFA score  
- HR, RR, MBP, SpO₂, temperature  

(Representative SQL provided in `sql/representative_merges.sql`.)

---

## **Stage 2 — Ventilator Settings**
Joins FiO₂, PEEP, tidal volume, minute volume, plateau pressure per day.

---

## **Stage 3 — Daily Labs (CBC, Coagulation, Chemistry)**
Includes:
- platelet, INR, PT, PTT  
- fibrinogen, D-dimer  
- electrolytes, liver enzymes, renal markers  
- total protein, albumin, globulin  

All aggregated via AVG.

---

## **Stage 4 — Blood Gas Integration**
Adds:
- PO₂, PCO₂  
- FiO₂  
- A-a gradient  
- PAO₂/FiO₂ ratio  
- pH, bicarbonate, lactate  

---

## **Stage 5 — Comorbidities**
Charlson index mapped via `(hadm_id → stay_id)`.

---

## **Stage 6 — Demographics**
race, admission_type, gender, age.

---

## **Stage 7 — Anthropometrics**
height, weight, BMI.

---

## **Stage 8 — SOFA Organ Dysfunction Flags**
respiratory, liver, renal, CNS, cardiovascular, total SOFA.

---

## **Stage 9 — Renal & Hemodynamic Support**
- urine_output_avg  
- rrt  
- vasopressor_use  
- vasopressin_use  

---

## **Stage 10 — Final Merge, Cleaning, Standardization**
Removed:
- columns with >95% nulls  
- duplicate stay_date rows  

Created final unified table: **rework14**

---

# Final Output Summary

`rework14` is the master feature table for:
- SIC label creation  
- ISTH DIC label creation  
- JAAM DIC label creation  

It contains **106 clinically meaningful, quality-controlled features**.

