/*
================================================================================
          JAAM DIC LABEL ENGINEERING PIPELINE (FINAL — USED FOR MODELING)
================================================================================

 BACKGROUND
 --------------------------------------------------------------------------------
 During the project, we initially tried to label DIC using the ISTH scoring
 system. However, ISTH proved impractical for machine learning because:

   • Only 142 ICU-day rows had complete ISTH DIC scores.
   • Only **4** SIC → DIC transition events existed.
   • This dataset was far too small and imbalanced for training any 
     predictive model.

 After reviewing clinical literature, we switched to the **JAAM DIC criteria**,
 which are known to be more sensitive and more suitable for early detection of
 DIC in sepsis. JAAM uses:

   ✔ SIRS burden  
   ✔ Platelet threshold  
   ✔ INR elevation  
   ✔ (Optional) FDP/D-dimer

 JAAM identifies significantly more coagulopathy cases, giving us enough 
 positive labels and transitions to build a proper ML model.

================================================================================
               CLINICAL LOGIC USED IN THIS SQL
--------------------------------------------------------------------------------
 1. SIRS score (0–4):
       • HR > 90 → 1
       • RR > 20 → 1
       • Temp <36 or >38 → 1
       • WBC <4k or >12k → 1

 2. Platelet score:
       • <80 → 3
       • 80–119 → 1
       • ≥120 → 0

 3. INR score:
       • ≥1.2 → 1
       • <1.2 → 0

 JAAM = SIRS + Platelet + INR  
 JAAM DIC Today = 1 when score ≥ 4  
 Transition = 0 → 1 next-day switch

*/


/*------------------------------------------------------------------------------
 STEP 1 — Compute SIRS components for each ICU day
------------------------------------------------------------------------------*/

CREATE OR REPLACE TABLE `mlinhealthcaregroup4.temp.rework_final_table_with_jaam_dic` AS

WITH sirs_calc AS (
    SELECT
        t.*,

        /* ---------------- SIRS Components ---------------- */
        CASE WHEN mean_heart_rate > 90 THEN 1 ELSE 0 END AS sirs_hr,
        CASE WHEN mean_resp_rate > 20 THEN 1 ELSE 0 END AS sirs_rr,
        CASE WHEN max_temperature < 36 OR max_temperature > 38 THEN 1 ELSE 0 END AS sirs_temp,
        CASE WHEN wbc_avg < 4000 OR wbc_avg > 12000 THEN 1 ELSE 0 END AS sirs_wbc,

        /* ---------------- Total SIRS Score ---------------- */
        (
          CASE WHEN mean_heart_rate > 90 THEN 1 ELSE 0 END +
          CASE WHEN mean_resp_rate > 20 THEN 1 ELSE 0 END +
          CASE WHEN max_temperature < 36 OR max_temperature > 38 THEN 1 ELSE 0 END +
          CASE WHEN wbc_avg < 4000 OR wbc_avg > 12000 THEN 1 ELSE 0 END
        ) AS sirs_score

    FROM `mlinhealthcaregroup4.temp.rework_final_table_with_label` t
),


/*------------------------------------------------------------------------------
 STEP 2 — Compute JAAM Platelet + INR Components
------------------------------------------------------------------------------*/

jaam_components AS (
    SELECT
        s.*,

        /* ---------------- JAAM Platelet Score ---------------- */
        CASE
            WHEN platelet_avg IS NULL THEN NULL
            WHEN platelet_avg < 80 THEN 3
            WHEN platelet_avg < 120 THEN 1
            ELSE 0
        END AS jaam_platelet_score,

        /* ---------------- JAAM INR Score --------------------- */
        CASE
            WHEN inr_avg IS NULL THEN NULL
            WHEN inr_avg >= 1.2 THEN 1
            ELSE 0
        END AS jaam_inr_score

        /* NOTE: Modified JAAM used — no D-dimer column available */
    FROM sirs_calc s
),


/*------------------------------------------------------------------------------
 STEP 3 — Compute JAAM Total Score
------------------------------------------------------------------------------*/

jaam_scoring AS (
    SELECT
        *,
        CASE
            WHEN jaam_platelet_score IS NULL
              OR jaam_inr_score IS NULL
              OR sirs_score IS NULL
            THEN NULL
            ELSE (
                jaam_platelet_score +
                jaam_inr_score +
                sirs_score
            )
        END AS jaam_score
    FROM jaam_components
),


/*------------------------------------------------------------------------------
 STEP 4 — JAAM DIC Today
------------------------------------------------------------------------------*/

jaam_final_score AS (
    SELECT
        *,
        CASE
            WHEN jaam_score IS NULL THEN NULL
            WHEN jaam_score >= 4 THEN 1
            ELSE 0
        END AS jaam_dic_today
    FROM jaam_scoring
),


/*------------------------------------------------------------------------------
 STEP 5 — JAAM DIC Tomorrow (lead by one day)
------------------------------------------------------------------------------*/

jaam_future AS (
    SELECT
        j.*,
        LEAD(jaam_dic_today) OVER (
            PARTITION BY subject_id, stay_id
            ORDER BY chart_date
        ) AS jaam_dic_tomorrow
    FROM jaam_final_score j
),


/*------------------------------------------------------------------------------
 STEP 6 — Identify JAAM DIC Progression (0 → 1)
------------------------------------------------------------------------------*/

final AS (
    SELECT
        *,
        CASE
            WHEN jaam_dic_tomorrow IS NULL THEN NULL
            WHEN jaam_dic_today = 0 AND jaam_dic_tomorrow = 1 THEN 1
            ELSE 0
        END AS jaam_dic_progression
    FROM jaam_future
)

SELECT *
FROM final;



/*------------------------------------------------------------------------------
 STEP 7 — Filter patients having SIC and valid jaam_dic_progression values
------------------------------------------------------------------------------*/

CREATE TABLE IF NOT EXISTS 
  `mlinhealthcaregroup4.temp.rework_final_table_with_jaam_dic_labels_with_filter` AS

SELECT 
    * 
FROM `mlinhealthcaregroup4.temp.rework_final_table_with_jaam_dic`
WHERE sic_today = 1 
  AND jaam_dic_progression IS NOT NULL;


/*
================================================================================
 - JAAM criteria provide a clinically valid + statistically usable label
 - This JAAM-based DIC progression label is used for all ML modeling
================================================================================
*/
