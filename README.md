# BA878_Project
## Dynamic Prediction of Sepsis-Induced Coagulopathy and Progression to Disseminated  Intravascular Coagulation Using MIMIC-IV
**Contributors: Amisha Kelkar, Chaitali Deshmukh, Pratik Mahajan, Rinaldo Brendon Patel**<br>

This repository contains the code and workflow for a two-stage predictive modeling framework designed to identify:<br>
1. Sepsis-Induced Coagulopathy (SIC) using ISTH SIC criteria, and<br>
2. Progression to Disseminated Intravascular Coagulation (DIC) within 24 hours using JAAM DIC criteria.

The project uses the MIMIC-IV database and aims to support earlier recognition of coagulopathy in sepsis.

### 1. Study Overview<br>
The analytic pipeline is structured at the patient-day level. For each ICU day, features are derived from the preceding 24 hours, and predictions target the next ICU day. The modeling mirrors the clinical trajectory from early coagulopathy (SIC) to more severe dysfunction (DIC). <br>
* SIC labels are assigned using ISTH SIC criteria, which combine platelet count, INR/PT, and SOFA components.
* DIC labels are assigned using JAAM criteria, selected because transitions to ISTH-defined DIC were too infrequent to support predictive modeling.

Both prediction tasks are treated as supervised binary classification problems.

### 2. Data and Feature Construction<br>

The cohort was built from MIMIC-IV v2.2 and filtered for adult ICU patients with suspected infection. Features include:

* Vital signs and ventilator parameters
* Laboratory values (platelets, INR/PT, lactate, metabolic markers)
* SOFA components and other organ-dysfunction indicators
* Short-term temporal trends (lagged values and deltas)
* Patient-level splitting was used to avoid data leakage.

### 3. Modeling Approach<br>

The following models were implemented:<br>
* Logistic Regression
* XGBoost
* LightGBM
* CatBoost

CatBoost served as the primary model for both tasks. Evaluation metrics include AUROC, AUPRC, sensitivity, specificity, F1 score, and calibration. SHAP was used for model interpretability.

### 4. Key Results

**SIC Prediction (ISTH):**
* CatBoost achieved strong performance, with high AUROC and AUPRC and excellent negative predictive value, indicating reliable early identification of SIC risk.

**DIC Progression (JAAM):**
* Although based on a smaller SIC-positive cohort, the CatBoost model demonstrated meaningful predictive signal, identifying platelet decline, INR rise, lactate, renal markers, and oxygenation parameters as key contributors.

Fairness checks showed no systematic differences across demographic groups.

### 5. Limitations
* JAAM was used for DIC definition because transitions to ISTH DIC were too rare for modeling.
* Missingness in coagulation labs reflects real ICU practice and introduces uncertainty.
* The models are trained on data from a single center and require external validation.

### 7. Summary

This project shows that both SIC and subsequent progression to DIC can be predicted in advance using routinely collected ICU data. A two-stage approach grounded in ISTH and JAAM criteria provides a practical framework for early-warning systems aimed at supporting clinical management of sepsis-associated coagulopathy.
    
