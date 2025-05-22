# 🚫 **Startup Failure Analysis Report**

## 📌 Table of Contents

1. [Project Overview](#project-overview)
2. [Data Sources](#data-sources)
3. [Tools](#tools-used)
4. [Data Cleaning/Preparation](#data-cleaningpreparation)
5. [Exploratory Data Analysis](#exploratory-data-analysis)
6. [Data Analysis](#data-analysis)
7. [Results/Findings](#resultsfindings)
8. [Recommendations](#recommendations)
9. [Limitations](#limitations)
10. [References](#references)

---

## 🧾 Project Overview

This analysis examines patterns and causes of startup failures across various sectors from 1992 to 2024. By analyzing 914 failed startups, we identify common failure factors, sector-specific vulnerabilities, and relationships between funding, operational duration, and failure causes. The insights can help entrepreneurs, investors, and policymakers understand startup failure dynamics and make more informed decisions.

---

## 📂 Data Sources

* **Primary Source**: Kaggle – CB Insights' "Startup Failure Post-Mortem" dataset.
* **Coverage**: 1992 to May 2024.
* **Features**: Startup name, sector, operational years, funding details, and failure causes.

---

## 🛠 Tools Used

* **Database**: PostgreSQL
* **Languages**: SQL
* **Platform**: Kaggle
* **Analysis & Documentation**: Jupyter Notebook / GitHub

---

## 🧹 Data Cleaning/Preparation

Key preprocessing steps executed through SQL:

* **Data consolidation**: Merged data across sectors using `UNION ALL` into a unified table `allsectors`.
* **Duplicates removed**: Applied `DISTINCT` to remove redundant entries.
* **Date extraction**:

  * Extracted `start_year` and `end_year` from textual `years_of_operation`.
  * Calculated `years_operated` using a COALESCE fallback for missing or malformed values.
* **Null values**: Identified missing data in critical columns such as `amount_raised`, `budget_status`, and `failure_reason`.

```sql
-- Extracting start_year and end_year
SELECT 
    CAST(SUBSTRING(years_of_operation FROM '(\\d{4})\\s*-') AS INTEGER) AS start_year,
    CAST(SUBSTRING(years_of_operation FROM '-\\s*(\\d{4})') AS INTEGER) AS end_year,
    COALESCE(end_year - start_year, years_operated) AS years_operated
FROM allsectors;
```

---

## 📊 Exploratory Data Analysis

Initial exploration covered:

* Frequency of failure by **industry sector**
* Funding and budget status distribution
* Number of years operated before failure
* Most cited failure reasons

---

## 📈 Data Analysis

### 🔢 Summary Statistics

* **Total failed startups**: **914**
* **Timeframe**: 1992 to 2024
* **Top sectors by failure**:

  * **Information** sector: **42%** of failures
  * **Retail**, **Manufacturing**, **Food & Accommodation** follow.

### 📉 Correlation Insights

* **+19.8%** between amount raised and years operated.
* **-20.3%** between lack of budget and stagnation.
* **-36.2%** between lack of budget and competition.

### 📌 Major Failure Reasons

* **53%** – Competition
* **43%** – No budget
* **21%** – Stagnation
* **13%** – Trend shifts
* **12%** – Inability to monetize

### 💸 Budget Status by Sector (No Budget Cases)

* **Retail**: 69%
* **Accommodation & Food Services**: 54%
* **Manufacturing**: 53%
* **Health**: 38%
* **Information**: 35%

---

## 📌 Results/Findings

1. **Information sector** is the most volatile with the highest failure rate.
2. **Funding improves survival**: Startups that raised more tend to operate longer.
3. **Budgeting is critical**: Lack of initial budget shows a strong negative correlation with survival and adaptability.
4. **Competition is the #1 killer**, cited by over half of failed startups.

---

## 💡 Recommendations

* **Build with a budget**: Startups should secure foundational capital before launch.
* **Market intelligence**: Deeply research competitors and maintain adaptive strategies.
* **Monitor product-market fit**: Address stagnation early with iterative product development.
* **Avoid trends-only models**: Long-term sustainability should be prioritized over short-term hype.
* **Monetization strategy**: Validate revenue models before scaling.

---

## ⚠️ Limitations

* **Incomplete records**: Many rows had null values for key variables like funding or failure reasons.
* **Outliers**: A few records included parent company funding figures, inflating capital raised metrics.
* **Sector imbalance**: Some sectors are underrepresented, skewing comparisons.

---

## 📚 References

* [CB Insights Startup Failure Post-Mortem](https://www.cbinsights.com/research/startup-failure-post-mortem/)
* [Kaggle Dataset - Startup Failure Post-Mortem](https://www.kaggle.com/datasets/cbinsights/startup-failure-post-mortem)

