-- It's always a best practice to create a new table and copy all data from the raw table to the new table.
-- This is done so because I will be doing the cleaning on the new table, and if I make a mistake or something goes wrong, I'd still have the original raw table available, similar to working in real work environment. 
-- Using the raw table, I create a copy of the table and insert the values into the new table and rename the table as 'layoffs_staging'.
USE layoffs;
GO
SELECT *
INTO layoffs_staging
FROM layoffs;

--Removing Duplicates (Using ROW_NUMBER on all columns and deleting the duplicates
WITH cte AS (
SELECT *,
	ROW_NUMBER() OVER(PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, date, stage, country, funds_raised_millions ORDER BY date) AS row_num
FROM layoffs_staging
)
DELETE
FROM cte
WHERE row_num > 1;

--Standardizing Data
--TRIM
SELECT
	company, TRIM(company)
FROM layoffs_staging

UPDATE layoffs_staging
SET company = TRIM(company)

-- Standardizing 'Crypto' Industry
UPDATE layoffs_staging
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';

--Standardizing 'United States' Country
UPDATE layoffs_staging
SET country = 'United States'
WHERE country LIKE 'United States%';

-- In the 'industry' column, there are some rows for companies that appear twice; however, one row has industry filled out, while the other has NULL.
-- I have to fill that NULL row with the correct industry type by looking up that company and adding that respective industry name.
-- Preview what will be updated
SELECT 
    t1.company,
    t1.industry AS current_industry,
    t2.industry AS replacement_industry
FROM layoffs_staging t1
JOIN layoffs_staging t2
    ON t1.company = t2.company
WHERE (t1.industry IS NULL OR t1.industry = '')
    AND t2.industry IS NOT NULL
    AND t2.industry != '';

-- Running the update
UPDATE t1
SET t1.industry = t2.industry
FROM layoffs_staging t1
JOIN layoffs_staging t2
    ON t1.company = t2.company
WHERE (t1.industry IS NULL OR t1.industry = '')
    AND t2.industry IS NOT NULL
    AND t2.industry != '';

-- I am eliminating the NULL rows of 'total_laid_off' and 'percentage_laid_off' columns because they don't give any necessary information, plus there are multiple rows with null values.
-- Had there been a column of 'total_employees', I would have been able to calculate the values, but because it is unavailable, it is better to discard them.
SELECT *
FROM layoffs_staging
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;

DELETE
FROM layoffs_staging
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;


--EXPLORATORY DATA ANALYSIS


--Max and Min laid off
SELECT MAX(total_laid_off), MAX(percentage_laid_off)
FROM layoffs_staging;

--Companies that folded (100% lad-off)
SELECT *
FROM layoffs_staging
WHERE percentage_laid_off = 1
ORDER BY funds_raised_millions DESC

--Companies with the most layoffs
SELECT 
company, SUM(total_laid_off)
FROM layoffs_staging
GROUP BY company
ORDER BY 2 DESC

--Dates with Max and Min layoffs
SELECT 
    MIN(date),
    MAX(date)
FROM layoffs_staging

--Industries with the most layoffs
SELECT 
industry, SUM(total_laid_off)
FROM layoffs_staging
GROUP BY industry
ORDER BY 2 DESC

--Countries with the most layoffs
SELECT 
country, SUM(total_laid_off)
FROM layoffs_staging
GROUP BY country
ORDER BY 2 DESC

--Year with most layoffs
SELECT 
YEAR(date), SUM(total_laid_off)
FROM layoffs_staging
GROUP BY YEAR(date)
ORDER BY 1 DESC

--Stage of companies with the most layoffs
SELECT 
stage, SUM(total_laid_off)
FROM layoffs_staging
GROUP BY stage
ORDER BY 1 ASC

--Year and month of layoffs in ascending order
SELECT 
    FORMAT(date, 'yyyy-MM') AS year_month,
    SUM(total_laid_off) AS monthly_total
FROM layoffs_staging
GROUP BY FORMAT(date, 'yyyy-MM')
ORDER BY 1;


--Rolling total of layoffs
WITH monthly AS (
    SELECT 
        DATEFROMPARTS(YEAR(date), MONTH(date), 1) AS month_start,
        SUM(total_laid_off) AS monthly_total
    FROM layoffs_staging
    GROUP BY DATEFROMPARTS(YEAR(date), MONTH(date), 1)
)
SELECT 
    FORMAT(month_start, 'yyyy-MM') AS year_month,
    monthly_total,
    SUM(monthly_total) OVER (
        ORDER BY month_start
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS rolling_total
FROM monthly
ORDER BY month_start;

--Running total by company per year
SELECT
    company,
    YEAR(date) AS year,
    MONTH(date) AS month,
    SUM(total_laid_off) AS monthly_total,
    SUM(SUM(total_laid_off)) OVER (
        PARTITION BY company, YEAR(date)
        ORDER BY YEAR(date), MONTH(date)
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_total
FROM layoffs_staging
GROUP BY company, YEAR(date), MONTH(date)
ORDER BY company ASC;

--Ranking by which year each company laid off the most
WITH company_year_totals AS (
    SELECT
        company,
        YEAR(date) AS year,
        SUM(total_laid_off) AS total_laid_off
    FROM layoffs_staging
    GROUP BY company, YEAR(date)
)

SELECT
    *,
    DENSE_RANK() OVER (
        PARTITION BY year
        ORDER BY total_laid_off DESC
    ) AS layoff_rank
FROM company_year_totals
ORDER BY company DESC;
