/*
======================================================================
 Sepsis-Induced Coagulopathy (SIC) Label Engineering SQL Pipeline
 OVERVIEW
 ---------------------------------------------------------------------
 This SQL script constructs the complete pipeline used to derive the
 labels required for next-day SIC prediction. It produces:

   • sic_today       – Whether the patient meets SIC criteria today
   • sic_tomorrow    – SIC status on the next ICU day
   • sic_next_day    – Transition label used for ML prediction

 The output is merged back with the main feature table to produce the
 final dataset for model training.

 CLINICAL BACKGROUND — ISTH SIC Scoring System
 ---------------------------------------------------------------------
 The International Society on Thrombosis and Haemostasis (ISTH)
 created a scoring system to identify early coagulopathy in sepsis.
 SIC incorporates markers of coagulation dysfunction and organ
 failure. The score has three components:

   1. Platelet Count:
        - <50   → 2 points
        - 50–100 → 1 point
        - ≥100  → 0 points

   2. INR (PT-INR):
        - >1.4        → 2 points
        - 1.2–1.4     → 1 point
        - <1.2        → 0 points

   3. SOFA Score:
        - SOFA ≥2     → 1 point
        - <2          → 0 points

   Total SIC Score = Platelet Score + INR Score + SOFA Indicator

 A score of ≥4 indicates SIC positivity for a given ICU day.

 LABEL DEFINITIONS
 ---------------------------------------------------------------------
   • sic_today:
       Computed using ISTH scoring logic. Indicates if SIC criteria
       are met on the current ICU day.

   • sic_tomorrow:
       Uses LEAD(...) to capture SIC status on the next physiological
       ICU day. Required for next-day prediction.

   • sic_next_day:
       Transition label = 1 only when:
           (sic_today = 0) AND (sic_tomorrow = 1)
       This ensures we predict new SIC onset and avoid leakage from
       days where the patient is already SIC-positive.

 PIPELINE STRUCTURE
 ---------------------------------------------------------------------
   Step 1 — Build base table with clinical features
   Step 2 — Compute SIC_today using ISTH SIC logic
   Step 3 — Compute next-day SIC labels (sic_tomorrow, sic_next_day)
   Step 4 — Remove final ICU day (no next-day label available)
   Step 5 — Merge labels back into main feature table and filter for valid sic_tomorrow

*/


/*=====================================================================
 STEP 1 — Construct Base Table and Compute ISTH Component Scores
 =====================================================================*/

CREATE OR REPLACE TABLE `mlinhealthcaregroup4.temp.sic_with_labels_final_rework` AS
WITH base AS (
  SELECT
    subject_id,
    stay_id,
    chart_date,
    platelet_avg,
    inr_avg,
    average_sofa_score,

    /* ---------------- ISTH Platelet Score ---------------- */
    CASE
      WHEN platelet_avg IS NULL THEN NULL
      WHEN platelet_avg < 50 THEN 2
      WHEN platelet_avg < 100 THEN 1
      ELSE 0
    END AS platelet_score,

    /* ---------------- ISTH INR Score ---------------------- */
    CASE
      WHEN inr_avg IS NULL THEN NULL
      WHEN inr_avg > 1.4 THEN 2
      WHEN inr_avg >= 1.2 THEN 1
      ELSE 0
    END AS inr_score,

    /* ---------------- SOFA Indicator ----------------------- */
    CASE
      WHEN average_sofa_score IS NULL THEN NULL
      WHEN average_sofa_score >= 2 THEN 1
      ELSE 0
    END AS sofa_indicator
  FROM `mlinhealthcaregroup4.temp.rework14`
),


/*=====================================================================
 STEP 2 — Compute SIC_TODAY Based on ISTH Score Threshold (≥4)
 =====================================================================*/

sic_today_calc AS (
  SELECT
    *,
    CASE
      WHEN platelet_score IS NULL OR inr_score IS NULL OR sofa_indicator IS NULL THEN NULL
      WHEN (platelet_score + inr_score + sofa_indicator) >= 4 THEN 1
      ELSE 0
    END AS sic_today
  FROM base
),


/*=====================================================================
 STEP 3 — Compute Next-Day SIC Labels (SIC_tomorrow, SIC_next_day)
 =====================================================================*/

sic_next_day_calc AS (
  SELECT
    *,
    /* Next-day SIC status */
    LEAD(sic_today) OVER (
        PARTITION BY subject_id, stay_id
        ORDER BY chart_date
    ) AS sic_tomorrow,

    /* Transition event: patient goes from non-SIC → SIC */
    CASE
      WHEN LEAD(sic_today) OVER (
              PARTITION BY subject_id, stay_id
              ORDER BY chart_date
           ) IS NULL THEN NULL
      WHEN sic_today = 0
       AND LEAD(sic_today) OVER (
              PARTITION BY subject_id, stay_id
              ORDER BY chart_date
           ) = 1 THEN 1
      ELSE 0
    END AS sic_next_day
  FROM sic_today_calc
)


/*=====================================================================
 STEP 4 — Finalize Label Table (remove last-day rows)
 =====================================================================*/

SELECT
  subject_id,
  stay_id,
  chart_date,
  platelet_avg,
  inr_avg,
  average_sofa_score,
  platelet_score,
  inr_score,
  sofa_indicator,
  sic_today,
  sic_tomorrow,
  sic_next_day
FROM sic_next_day_calc
WHERE sic_tomorrow IS NOT NULL
ORDER BY stay_id, chart_date
;



/*=====================================================================
 STEP 5 — Merge SIC Labels Back to Full Feature Table and Filter Records with valid sic_tomorrow
 =====================================================================*/

CREATE OR REPLACE TABLE `mlinhealthcaregroup4.temp.rework_final_table_with_label` AS

SELECT 
  r.*,
  s.platelet_score,
  s.inr_score,
  s.sofa_indicator,
  s.sic_today,
  s.sic_tomorrow,
  s.sic_next_day 
FROM `mlinhealthcaregroup4.temp.rework14` r
LEFT JOIN `mlinhealthcaregroup4.temp.sic_with_labels_final_rework` s
  ON r.stay_id = s.stay_id
 AND r.subject_id = s.subject_id
 AND r.chart_date = s.chart_date
WHERE sic_tomorrow IS NOT NULL;
