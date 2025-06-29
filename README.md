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

This analysis examines patterns and causes of startup failures across various sectors from 1992 to 2024. By analyzing 890 failed startups, we identify common failure factors, sector-specific vulnerabilities, and relationships between funding, operational duration, and failure causes. The insights can help entrepreneurs, investors, and policymakers understand startup failure dynamics and make more informed decisions.

![startup counts](https://github.com/user-attachments/assets/a3054591-7364-4655-988e-4abf2ffdfeb4)

![count by startyear](https://github.com/user-attachments/assets/80486b8d-d74f-46f3-9623-3323baa463d4)

---

## 📂 Data Sources

* **Primary Source**: Kaggle – CB Insights' "Startup Failure Post-Mortem" dataset.
* **Coverage**: 1992 to May 2024.
* **Sectors**: Combined data from seven sector-specific tables: finance, health, information, retail, manufacturing, food, and othersectors.
* **Features**: Startup name, sector, operational years, funding details, and failure causes.

---

## 🛠 Tools Used

* **Database**: PostgreSQL for data processing and analysis
* **Languages**: SQL for data cleaning, transformation, and analysis
* **Platform**: Kaggle for data sourcing
* **Documentation**: GitHub for version control and project documentation

---

## 🧹 Data Cleaning/Preparation 

Key preprocessing steps executed through SQL:

* **Data consolidation**: Merged data across sectors using `UNION ALL` into a unified table `allsectors`.
* **Duplicates removed**: Applied `DISTINCT` to remove redundant entries.
* **Date extraction**:
  * Extracted `start_year` (4-digit year before hyphen) and `end_year` (4-digit year after hyphen) from textual `years_of_operation`.
  * Calculated `years_operated` using a COALESCE fallback for missing or malformed values.
```sql
---Extracting start_year, end_year and years_operated---
---start_year: 4-digit year before -, whether inside parentheses or not
---end_year: 4-digit year after -, same
---years_operated: Numeric value before the space (' ') if present; otherwise, calculate as end_year - start_year

SELECT 
    years_of_operation,
    CAST(substring(years_of_operation FROM '(\d{4})\s*-\s*\d{4}') 
        AS INTEGER) AS start_year,
    CAST(substring(years_of_operation FROM '\d{4}\s*-\s*(\d{4})') 
        AS INTEGER) AS end_year,
    COALESCE(
        CAST(NULLIF(substring(years_of_operation FROM '^(\d+)\s'), '') 
            AS INTEGER),
        CAST(substring(years_of_operation FROM '\d{4}\s*-\s*(\d{4})') 
            AS INTEGER) - 
        CAST(substring(years_of_operation FROM '(\d{4})\s*-\s*\d{4}') 
            AS INTEGER)) AS years_operated
FROM allsectors;
```
* **Null values**: Identified missing data in critical columns such as `amount_raised`, `budget_status`, and `failure_reason`.
* **Funding Information**:
  * Extracted `parent_company` from parentheses or after space
  * Parsed `amount_raised` with proper unit conversion (M=million, B=billion)
  * Identified magnitude (M/B) for each amount
```sql
---splits the how_much_they_raised column from the allsectors table into three new derived columns:
---parent_company: text inside parentheses or after a space.
---amount_raised: sum of valid numeric values (excluding anything in parentheses).
---magnitude: unit like M, B, etc., from each valid amount.

SELECT name, sector, how_much_they_raised,
    CASE WHEN how_much_they_raised ~ '\(.*\)' THEN 
            regexp_replace(how_much_they_raised, '.*\(([^)]*)\).*', '\1')
        WHEN how_much_they_raised LIKE '% %' THEN 
            split_part(how_much_they_raised, ' ', 2)
        ELSE NULL END AS parent_company,

    CASE WHEN how_much_they_raised ~* '\$0(\s|$)' THEN NULL
        ELSE regexp_replace(substring(how_much_they_raised FROM '\$[0-9.]+([MB])'),
                '\$[0-9.]+', '') END AS magnitude,

    CASE WHEN how_much_they_raised ~* '\$0(\s|$)' THEN 0
        ELSE (SELECT SUM(CASE 
                    WHEN match[2] = 'B' THEN match[1]::numeric * 1000000000
                    WHEN match[2] = 'M' THEN match[1]::numeric * 1000000
                    ELSE match[1]::numeric END)
            FROM (SELECT regexp_matches(
                    regexp_replace(how_much_they_raised, '\([^)]*\)', '', 'g'),
                    '\$([0-9.]+)([MB]?)',
                    'g') AS match
            ) AS amounts)
    END AS amount_raised
FROM allsectors
	WHERE how_much_they_raised IS NOT NULL
		ORDER BY amount_raised DESC;
```
* **Failure Analysis**:
  * Extracted primary `reason_why_they_failed` from text after semicolon
  * Extracted `key_takeaway` from text after semicolon
```sql
---using "position(';' IN why_they_failed)" to finds where the semicolon is.
---using "substring(... FROM position + 1)" to grabs everything after the semicolon.
---using "ltrim(...)" to trims any leading space after the semicolon.
---If no ; is found, it returns the original column value

SELECT 
    name, sector, why_they_failed,
    CASE WHEN position(';' IN why_they_failed) > 0 THEN 
            ltrim(substring(why_they_failed FROM position(';' IN why_they_failed) + 1))
        ELSE why_they_failed END AS reason_why_they_failed
FROM allsectors;

---using "position(';' IN takeaway)" to finds where the semicolon is.
---and others as above

SELECT 
    takeaway,
    CASE WHEN position(';' IN takeaway) > 0 THEN 
            ltrim(substring(takeaway FROM position(';' IN takeaway) + 1))
        ELSE takeaway END AS key_takeaway
FROM allsectors;
```
* **Data Enrichment**: Added new columns to the allsectors table:
  * `start_year`, `end_year`, `years_operated`
  * `parent_company`, `amount_raised`
  * `key_takeaway`, `reason_why_they_failed`
* **Data Pruning**: Removed original columns after extracting relevant information:
  * `years_of_operation`
  * `how_much_they_raised`
  * `why_they_failed`
  * `takeaway`
---

## 📊 Exploratory Data Analysis

Initial exploration covered:
* Frequency of failure by **industry sector**
* Funding and budget status distribution
* Number of years operated before failure
* Most cited failure reasons

![failure per year](https://github.com/user-attachments/assets/46c56c8d-215b-48b9-a989-896cddcecb2d)

* **Sector Distribution**:
  * Total of 890 failed startups analyzed
  * Information sector accounted for 42% of failures (highest among all sectors)
  * Retail, manufacturing, and health sectors followed in failure frequency
* **Operational Duration**:
  * Calculated average years of operation before failure by sector
  * Identified sectors with longest/shortest lifespans before failure
* **Funding Analysis**:
  * Extracted and standardized funding amounts across different notations
  * Identified top 10 most funded startups before failure
  * Analyzed relationship between funding and operational duration
* **Failure Causes**:
  Categorized and quantified primary failure reasons:
  * Competition
  * No budget
  * Stagnation
  * Trend shifts
  * Monetization failure
* **Analyzed sector-specific** patterns in failure causes

---

## 📈 Data Analysis
* **Sector Distribution**
```sql
SELECT 
  sector,
  COUNT(DISTINCT name) AS startup_count,
  ROUND(COUNT(DISTINCT name)::numeric / SUM(COUNT(DISTINCT name)) OVER(), 2) AS pct_startup
FROM allsectors
GROUP BY sector
ORDER BY startup_count DESC;
```
* **Funding vs. Longevity Correlation**
```sql
WITH funding AS (
  SELECT sector, ROUND(AVG(amount_raised), 2) AS avg_amount_raised
  FROM allsectors
  WHERE amount_raised IS NOT NULL
  GROUP BY sector
),
survival AS (
  SELECT sector, ROUND(AVG(years_operated), 2) AS avg_year_operation
  FROM allsectors
  WHERE years_operated IS NOT NULL
  GROUP BY sector
)
SELECT corr(f.avg_amount_raised, s.avg_year_operation) AS correlation 
FROM funding f
JOIN survival s ON f.sector = s.sector;
```
* **Failure Cause Analysis**
```sql
SELECT 
  ROUND(AVG(no_budget::int),2) pct_no_budget,
  ROUND(AVG(monetization_failure::int),2) pct_monetization_failure,
  ROUND(AVG(trend_shifts::int),2) pct_trend_shifts,
  ROUND(AVG(acquisition_stagnation::int),2) pct_acquisition_stagnation,
  ROUND(AVG(competition::int),2) pct_competition
FROM allsectors;
```
### 🔢 Summary Statistics

* **Total failed startups**: **890**
* **Timeframe**: 1992 to 2024
* **Avg. Years of Operation**: **8yrs**  
* **Top sectors by failure**:
  * **Information** sector: **42%** of failures
  * **Retail**, **Manufacturing**, **Food & Accommodation** follow.

![failure count by years_operated](https://github.com/user-attachments/assets/38c27499-5f61-4ea9-ae80-affa145f4d38)

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
Summary of Findings
1. **Information sector** is the most volatile with the highest failure rate.
2. **Funding improves survival**: Startups that raised more tend to operate longer.
3. **Budgeting is critical**: Lack of initial budget shows a strong negative correlation with survival and adaptability.
4. **Competition is the #1 killer**, cited by over half of failed startups.

* **Sector Concentration**:
  * 42% of startup failures occurred in the information sector
  * Retail, manufacturing, and health sectors also showed significant failure rates

* **Funding vs. Longevity**:
  * Weak positive correlation (19.8%) between amount raised and years of operation
  * Suggests that while more funding may slightly extend lifespan, it doesn't guarantee success

* **Budget Constraints**:
  * Negative correlation between no budget and stagnation (-20.3%)
  * Stronger negative correlation between no budget and competition (-36.2%)
  * 43% of startups failed due to budget constraints

* **Primary Failure Causes**:
  * Competition: 53% of failures
  * No budget: 43% of failures
  * Stagnation: 21% of failures
  * Trend shifts: 13% of failures
  * Monetization failure: 12% of failures

* **Sector-Specific Budget Issues**:
  * Retail: 69% started with no budget
  * Accommodation and food services: 54%
  * Manufacturing: 53%
  * Health: 38%
  * Information: 35%

---

## 💡 Recommendations
**Summary**
* **Build with a budget**: Startups should secure foundational capital before launch.
* **Market intelligence**: Deeply research competitors and maintain adaptive strategies.
* **Monitor product-market fit**: Address stagnation early with iterative product development.
* **Avoid trends-only models**: Long-term sustainability should be prioritized over short-term hype.
* **Monetization strategy**: Validate revenue models before scaling.

For Entrepreneurs:
  * Conduct thorough competitive analysis before launching (53% fail due to competition)
  * Secure adequate funding and maintain financial runway (43% fail due to budget issues)
  * Monitor industry trends continuously (13% fail due to trend shifts)
  * Develop clear monetization strategies early (12% fail due to monetization issues)

For Investors:
  * Pay particular attention to budget planning when evaluating information sector startups
  * Consider sector-specific risks (e.g., retail's high budget failure rate)
  * Recognize that more funding doesn't guarantee longer survival (low correlation)

For Accelerators/Incubators:
  * Provide more support for competitive positioning
  * Offer financial planning resources, especially for retail and manufacturing startups
  * Help startups develop trend-monitoring capabilities

---

## ⚠️ Limitations
**Summary**
* **Incomplete records**: Many rows had null values for key variables like funding or failure reasons.
* **Outliers**: A few records included parent company funding figures, inflating capital raised metrics.
* **Sector imbalance**: Some sectors are underrepresented, skewing comparisons.

Data Completeness:
  * Many records contain incomplete or null values
  * Some critical fields were missing for certain startups

Funding Data:
  * Parent company funding amounts are included for some startups, creating outliers
  * Inconsistent reporting formats for funding amounts

Time Period:
  * Data spans 1992-2024, but distribution across years are not even
  * Early years may have less complete records

Failure Cause Classification:
  * Reasons are often complex and multifaceted, but dataset simplifies to primary causes
  * Subjective classification of failure reasons

Survivorship Bias:
  * Only includes failed startups, without comparison to successful ones
  * Cannot directly compare characteristics of failed vs. successful startups

---

## 📚 References

* [CB Insights Startup Failure Post-Mortem](https://www.cbinsights.com/research/startup-failure-post-mortem/)
* [Kaggle Dataset - Startup Failure](https://www.kaggle.com/datasets/dagloxkankwanda/startup-failures/data)

