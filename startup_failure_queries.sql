---- Data preparation and cleaning -----
---- appended all datasets and removed duplicates
CREATE TABLE allsectors AS 
SELECT DISTINCT * FROM (SELECT * FROM finance
	UNION ALL
		SELECT * FROM health
	UNION ALL
		SELECT * FROM information
	UNION ALL
		SELECT * FROM retail
	UNION ALL
		SELECT * FROM manufacturing
	UNION ALL
		SELECT * FROM othersectors
	UNION ALL
		SELECT * FROM food);
		
SELECT * FROM allsectors
---------------------------------------------------------------------------------------------------------
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

----------------------------------------------------------------------------------------------------------
---splits the how_much_they_raised column from the allsectors table into three new derived columns:
---parent_company: text inside parentheses or after a space.
---amount_raised: sum of valid numeric values (excluding anything in parentheses).
---magnitude: unit like M, B, etc., from each valid amount.

SELECT name, sector, how_much_they_raised,
    CASE 
        WHEN how_much_they_raised ~ '\(.*\)' THEN 
            regexp_replace(how_much_they_raised, '.*\(([^)]*)\).*', '\1')
        WHEN how_much_they_raised LIKE '% %' THEN 
            split_part(how_much_they_raised, ' ', 2)
        ELSE NULL
    END AS parent_company,

    CASE 
        WHEN how_much_they_raised ~* '\$0(\s|$)' THEN NULL
        ELSE regexp_replace(substring(how_much_they_raised FROM '\$[0-9.]+([MB])'),
                '\$[0-9.]+', '')
    END AS magnitude,

    CASE 
        WHEN how_much_they_raised ~* '\$0(\s|$)' THEN 0
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
----------------------------------------------------------------------------------------------------------

---using "position(';' IN why_they_failed)" to finds where the semicolon is.
---using "substring(... FROM position + 1)" to grabs everything after the semicolon.
---using "ltrim(...)" to trims any leading space after the semicolon.
---If no ; is found, it returns the original column value.
SELECT 
    name, sector, why_they_failed,
    CASE 
        WHEN position(';' IN why_they_failed) > 0 THEN 
            ltrim(substring(why_they_failed FROM position(';' IN why_they_failed) + 1))
        ELSE 
            why_they_failed
    END AS reason_why_they_failed
FROM allsectors;

---------------------------------------------------------------------------------------
---using "position(';' IN takeaway)" to finds where the semicolon is.
---and others as above
SELECT 
    takeaway,
    CASE 
        WHEN position(';' IN takeaway) > 0 THEN 
            ltrim(substring(takeaway FROM position(';' IN takeaway) + 1))
        ELSE 
            takeaway
    END AS key_takeaway
FROM allsectors;

--------------------------------------------------------------------------------------

----Updating table with newly created fields

ALTER TABLE allsectors
ADD COLUMN start_year INTEGER,
ADD COLUMN end_year INTEGER,
ADD COLUMN years_operated INTEGER,
ADD COLUMN parent_company TEXT,
ADD COLUMN amount_raised NUMERIC,
ADD COLUMN key_takeaway TEXT,
ADD COLUMN reason_why_they_failed TEXT;


UPDATE allsectors
SET 
    start_year = CAST(
        substring(years_of_operation FROM '(\d{4})\s*-\s*\d{4}') AS INTEGER),
    end_year = CAST(
        substring(years_of_operation FROM '\d{4}\s*-\s*(\d{4})') AS INTEGER),
    years_operated = COALESCE(
        CAST(NULLIF(substring(years_of_operation FROM '^(\d+)\s'), '') AS INTEGER),
        CAST(substring(years_of_operation FROM '\d{4}\s*-\s*(\d{4})') AS INTEGER) -
        CAST(substring(years_of_operation FROM '(\d{4})\s*-\s*\d{4}') AS INTEGER)),
	parent_company = CASE 
        WHEN how_much_they_raised ~ '\(.*\)' THEN 
            regexp_replace(how_much_they_raised, '.*\(([^)]*)\).*', '\1')
        WHEN how_much_they_raised LIKE '% %' THEN 
            split_part(how_much_they_raised, ' ', 2)
        ELSE NULL END,
	amount_raised = CASE 
        WHEN how_much_they_raised ~* '\$0(\s|$)' THEN 0
        ELSE (SELECT SUM(
                CASE 
                    WHEN match[2] = 'B' THEN match[1]::numeric * 1000000000
                    WHEN match[2] = 'M' THEN match[1]::numeric * 1000000
                    ELSE match[1]::numeric END)
            FROM (SELECT regexp_matches(
                    regexp_replace(how_much_they_raised, '\([^)]*\)', '', 'g'),
                    '\$([0-9.]+)([MB]?)',
                    'g'
                ) AS match
            ) AS amounts)END,
	key_takeaway = CASE 
    	WHEN position(';' IN takeaway) > 0 THEN 
        	ltrim(substring(takeaway FROM position(';' IN takeaway) + 1))
    	ELSE takeaway END,
	reason_why_they_failed = CASE 
        WHEN position(';' IN why_they_failed) > 0 THEN 
            ltrim(substring(why_they_failed FROM position(';' IN why_they_failed) + 1))
        ELSE why_they_failed END;
---------------------------------------------------------------------------------------------------------------------

----Deleting all irrelevant fields

ALTER TABLE allsectors
DROP COLUMN years_of_operation;

ALTER TABLE allsectors
DROP COLUMN how_much_they_raised,
DROP COLUMN why_they_failed,
DROP COLUMN takeaway;

------Data Analysis Begins-------------

SELECT *
	FROM allsectors
		
 
----How many startups are in each sector?
SELECT sector, 
	COUNT(DISTINCT name) AS startup_count, 
	SUM(COUNT (DISTINCT name)) OVER()
FROM allsectors
	GROUP BY sector
		ORDER BY startup_count DESC; 

---counts distinct startups per sector
WITH sector_counts AS (
  SELECT 
    sector, 
    COUNT(DISTINCT name) AS startup_count
  FROM allsectors
  GROUP BY sector
),
---calculates the sum across all sectors
total_count AS (
  SELECT SUM(startup_count) AS total_startups FROM sector_counts
)
---joins both to compute % of startups per sector
SELECT 
  sc.sector,
  sc.startup_count,
  tc.total_startups, 
  ROUND(sc.startup_count::numeric / tc.total_startups, 2) AS pct_startup
FROM sector_counts sc
CROSS JOIN total_count tc	
ORDER BY sc.startup_count DESC;


----Average years of operation before failure
SELECT 
		sector, 
		ROUND(AVG(years_operated),2) AS Avg_year_operation 
	FROM allsectors
		GROUP BY sector
			ORDER BY Avg_year_operation DESC;
		
----Average amount raised by sector
SELECT sector, ROUND(AVG(amount_raised),2) AS Avg_amount_raised
	FROM allsectors
		WHERE amount_raised IS NOT NULL
			GROUP BY sector
				ORDER BY Avg_amount_raised DESC;

----Failure Analysis-----

----Does higher funding correlate with longer survival?
WITH funding AS (
		SELECT sector, ROUND(AVG(amount_raised), 2) AS avg_amount_raised
			FROM allsectors
				WHERE amount_raised IS NOT NULL
					GROUP BY sector),
	survival AS (
		SELECT sector, ROUND(AVG(years_operated), 2) AS avg_year_operation
			FROM allsectors
				WHERE years_operated IS NOT NULL
					GROUP BY sector)
----Correlations between "Amount Raised" and "Years of Operation"
SELECT corr(f.avg_amount_raised, s.avg_year_operation) AS correlation 
	FROM funding f
		JOIN survival s ON f.sector = s.sector;
		
----Is there any correlation between "No Budget" and "acquisition_stagnation" and "competition"?

----Correlations between "acquisition_stagnation" and "No Budget" 
SELECT corr(acquisition_stagnation::int, no_budget::int) 
	FROM allsectors;
		
----Correlations between "competition" and "No Budget" 
SELECT corr(competition::int, no_budget::int) 
	FROM allsectors;

SELECT * FROM allsectors

----How often were factors like "No budget", "Monetization Failure", "Trend Shifts", "Stagnation", etc, the reason for failure	

SELECT 
		ROUND(AVG(no_budget::int),2) pct_no_budget, ----Percentage of startup with no budget
		ROUND(AVG(monetization_failure::int),2) pct_monetization_failure, ----Percentage of startup with monetization_failure
		ROUND(AVG(trend_shifts::int),2) pct_trend_shifts,  --- Percentage of startup affected by trend_shifts 
		ROUND(AVG(acquisition_stagnation::int),2) pct_acquisition_stagnation, --- Percentage of startup affected by stagnation
		ROUND(AVG(competition::int),2) pct_competition ----Percentage of startup that failed due to competition
	FROM allsectors;  

----Distribution of failure causes across sectors----

----Percentage of startup with no budget by sector
SELECT sector, ROUND(AVG(no_budget::int),2) pct_no_budget 
	FROM allsectors
		WHERE no_budget IS NOT NULL
		GROUP BY sector
			ORDER BY pct_no_budget DESC;

----Percentage of startup with monetization_failure by sector
SELECT sector, ROUND(AVG(monetization_failure::int),2) pct_monetization_failure 
	FROM allsectors
		WHERE monetization_failure IS NOT NULL
			GROUP BY sector
				ORDER BY pct_monetization_failure DESC;

--- Percentage of startup affected by trend_shifts 
SELECT sector, ROUND(AVG(trend_shifts ::int),2) pct_trend_shifts 
	FROM allsectors
		WHERE trend_shifts  IS NOT NULL
		GROUP BY sector
			ORDER BY pct_trend_shifts  DESC;

--- Percentage of startup affected by stagnation
SELECT sector, ROUND(AVG(acquisition_stagnation::int),2) pct_acquisition_stagnation
	FROM allsectors
		WHERE acquisition_stagnation IS NOT NULL
		GROUP BY sector
			ORDER BY pct_acquisition_stagnation DESC;

----Percentage of startup that failed due to competition
SELECT sector, ROUND(AVG(competition::int),2) pct_competition 
	FROM allsectors
		WHERE competition IS NOT NULL
			GROUP BY sector
		ORDER BY pct_competition DESC;
			 
---Top 10 of the most funded startups by total equity
SELECT name, amount_raised
	FROM allsectors
		WHERE amount_raised IS NOT NULL 
			GROUP BY name, amount_raised
		ORDER BY amount_raised DESC
	LIMIT 10

---Checking yearly distribution
SELECT start_year, COUNT(*) AS failures_per_year
	FROM allsectors
		WHERE start_year BETWEEN '1992' AND '2024'
	GROUP BY start_year
ORDER BY start_year;

----Count of startup failure per year
SELECT end_year, COUNT(*) AS failures_per_year
	FROM allsectors
		WHERE end_year BETWEEN '1992' AND '2024'
	GROUP BY end_year
ORDER BY end_year;

---checking distribution of startup failures based on how long they survived
SELECT years_operated, COUNT(*) AS failures_by_years_operated
	FROM allsectors
	GROUP BY years_operated
ORDER BY years_operated;

----expressing the distribution of startup failures based on how long they survived by percentage

SELECT 
  years_operated,
  COUNT(*) AS failures,
  ROUND(COUNT(*)::numeric / SUM(COUNT(*)) OVER(), 4) AS pct_of_total
FROM allsectors
GROUP BY years_operated
ORDER BY years_operated;

