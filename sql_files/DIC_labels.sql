/*
===============================================================================
 DIC Label Engineering Pipeline (ISTH Criteria)

 OVERVIEW
 -------------------------------------------------------------------------------
 This SQL script computes DIC labels using the ISTH scoring method and prepares 
 the dataset for predicting progression from Sepsis-Induced Coagulopathy (SIC) 
 to Disseminated Intravascular Coagulation (DIC).

 However, during model development we found that:

   • Using ISTH DIC criteria produced **only 142 labeled ICU-day rows**  
   • Of these, **only 4 rows showed SIC → DIC transition events**

 This dataset size is **too small for any machine learning model** to learn a 
 meaningful pattern, and does not allow proper train/validation splits.

 After reviewing the clinical literature, we identified that the **JAAM DIC 
 criteria are more sensitive**, producing significantly more cases and providing
 a viable sample size for modeling. Thus, the ISTH pipeline is included for 
 documentation, but the final modeling uses **JAAM-based DIC labels**.

 CLINICAL BACKGROUND — ISTH DIC SCORING
 -------------------------------------------------------------------------------
 The ISTH scoring system identifies overt DIC using four components:

   1. Platelet Count:
        < 50       → 2 points
        50–100     → 1 point
        ≥ 100      → 0 points

   2. Prothrombin Time (PT prolongation):
        ≥ 6 sec over control → 2 points
        3–6 sec over control → 1 point
        < 3 sec              → 0 points

   3. Fibrinogen:
        < 100 mg/dL → 1 point
        ≥ 100 mg/dL → 0 points

   4. D-dimer (or FDPs):
        Strong increase → 3 points
        Moderate        → 2 points
        Mild/Normal     → 0 points

 Total ISTH DIC Score ≥ 5 → DIC Today.

 LIMITATION OF ISTH FOR OUR DATA
 -------------------------------------------------------------------------------
 When applied to our derived ICU-day dataset:

   • Very few patients met full ISTH criteria daily.
   • This resulted in only 142 analyzable day pairs.
   • Only 4 SIC → DIC next-day transitions existed.

 These are insufficient for predictive modeling, especially with imbalanced 
 data and temporal dependencies. Therefore, we transitioned to **JAAM 
 criteria**, which literature shows are more sensitive for early DIC and SIC 
 progression in sepsis.

 The SQL below generates ISTH-based labels for documentation and comparison.
===============================================================================
*/



/*==============================================================================
 STEP 1 — Compute Platelet, PT, Fibrinogen, and D-dimer Component Scores
==============================================================================*/

CREATE OR REPLACE TABLE `mlinhealthcaregroup4.temp.rework_final_table_with_label_dic` AS

WITH with_dic_components AS (
    SELECT
        t.*,

        /* ---------------- Platelet score (ISTH) ---------------- */
        CASE
            WHEN t.platelet_avg IS NULL THEN NULL
            WHEN t.platelet_avg < 50 THEN 2
            WHEN t.platelet_avg < 100 THEN 1
            ELSE 0
        END AS dic_platelet_score,

        /* ---------------- PT score (ISTH) ---------------------- */
        CASE
            WHEN t.pt_avg IS NULL THEN NULL
            WHEN t.pt_avg - 12 >= 6 THEN 2
            WHEN t.pt_avg - 12 >= 3 THEN 1
            ELSE 0
        END AS dic_pt_score,

        /* ---------------- Fibrinogen score --------------------- */
        CASE
            WHEN t.fibrinogen_avg IS NULL THEN NULL
            WHEN t.fibrinogen_avg < 100 THEN 1
            ELSE 0
        END AS dic_fibrinogen_score,

        /* ---------------- D-dimer score ------------------------ */
        CASE
            WHEN t.d_dimer_avg IS NULL THEN NULL
            WHEN t.d_dimer_avg > 5000 THEN 3
            WHEN t.d_dimer_avg >= 500 THEN 2
            ELSE 0
        END AS dic_d_dimer_score

    FROM `mlinhealthcaregroup4.temp.rework_final_table_with_label` t
),


/*==============================================================================
 STEP 2 — Compute Total ISTH DIC Score
==============================================================================*/

with_dic_score AS (
    SELECT
        *,
        CASE
            WHEN dic_platelet_score IS NULL
              OR dic_pt_score IS NULL
              OR dic_fibrinogen_score IS NULL
              OR dic_d_dimer_score IS NULL
              THEN NULL
            ELSE (
                dic_platelet_score +
                dic_pt_score +
                dic_fibrinogen_score +
                dic_d_dimer_score
            )
        END AS dic_score
    FROM with_dic_components
),


/*==============================================================================
 STEP 3 — Determine DIC_today (ISTH ≥ 5)
==============================================================================*/

with_dic_today AS (
    SELECT
        *,
        CASE
            WHEN dic_score IS NULL THEN NULL
            WHEN dic_score >= 5 THEN 1
            ELSE 0
        END AS dic_today
    FROM with_dic_score
),


/*==============================================================================
 STEP 4 — Compute DIC_tomorrow
==============================================================================*/

with_dic_tomorrow AS (
    SELECT
        *,
        LEAD(dic_today) OVER (
            PARTITION BY subject_id, stay_id
            ORDER BY chart_date
        ) AS dic_tomorrow
    FROM with_dic_today
),


/*==============================================================================
 STEP 5 — Compute DIC_next_day Transition Label
==============================================================================*/

final AS (
    SELECT
        *,
        CASE
            WHEN dic_tomorrow IS NULL THEN NULL
            WHEN dic_today = 0 AND dic_tomorrow = 1 THEN 1
            ELSE 0
        END AS dic_next_day
    FROM with_dic_tomorrow
)


/*==============================================================================
 STEP 6 — Output ISTH DIC Label Table
==============================================================================*/

SELECT *
FROM final;



/*==============================================================================
 STEP 7 — Extract SIC Patients and Identify SIC → DIC Progression
    NOTE: Only 4 transitions found using ISTH → insufficient for ML.
==============================================================================*/

CREATE OR REPLACE TABLE `mlinhealthcaregroup4.temp.model_ready_sic_to_dic` AS
WITH base AS (
    SELECT
        *
    FROM `mlinhealthcaregroup4.temp.rework_final_table_with_label_dic`
),

sic_patients AS (
    SELECT
        *
    FROM base
    WHERE sic_today = 1
      AND dic_next_day IS NOT NULL
)

SELECT *
FROM sic_patients;


/*
===============================================================================
 NOTE: Due to severe class scarcity, final modeling uses JAAM DIC criteria,
 which provide substantially more positive cases and transition events.
===============================================================================
*/
