# World Layoffs Data Analysis: SQL Cleaning & EDA

## Table of Contents
- [Project Overview](#project-overview)
- [Tools & Skills Used](#tools--skills-used)
- [Key SQL Techniques](#key-sql-techniques)
- [Insights & Findings](#insights--findings)

---

## Project Overview

This project is a two-part end-to-end data analysis of global layoffs during the COVID-19 pandemic (2020-2023). The dataset contains over 2,000 records across 9 columns, capturing layoff events from companies around the world.

**Part 1 - Data Cleaning** focuses on preparing the raw dataset for analysis by resolving quality issues, including duplicates, inconsistent values, null entries, and improper data types.

**Part 2 - Exploratory Data Analysis (EDA)** leverages the cleaned dataset to surface meaningful patterns and trends related to the scale and distribution of global layoffs.

This project was completed in SQL Server Management Studio, following along with the tutorial series by Alex Freberg (Alex the Analyst), and extended with independent practice and exploration.

**Dataset:** World Layoffs (COVID-19 era, 2020-2023)  
**Tool:** SQL Server / SQL Server Management Studio
**Inspired by:** [Alex the Analyst - YouTube](https://www.youtube.com/@AlexTheAnalyst)

---

## Tools & Skills Used

| Category | Details |
|---|---|
| Database | SQL Server |
| IDE | SQL Server Management Studio |
| Key Skills | Data Cleaning, Exploratory Data Analysis, Window Functions, CTEs |
| Source Control | GitHub |

---

## Key SQL Techniques

### Part 1 - Data Cleaning

**1. Staging Table Creation**

A staging table was created as a copy of the original to preserve raw data integrity throughout the cleaning process.

```sql
CREATE TABLE layoffs_staging LIKE layoffs;
INSERT layoffs_staging SELECT * FROM layoffs;
```

**2. Duplicate Detection and Removal**

`ROW_NUMBER()` with `PARTITION BY` was used to flag duplicate rows. A secondary staging table was required to allow deletion since row numbers are generated dynamically.

```sql
WITH duplicate_cte AS (
  SELECT *, ROW_NUMBER() OVER(
    PARTITION BY company, location, industry, total_laid_off,
    percentage_laid_off, `date`, stage, country, funds_raised_millions
  ) AS row_num
  FROM layoffs_staging
)
SELECT * FROM duplicate_cte WHERE row_num > 1;
```

**3. Data Standardization**

Inconsistent values across key columns were corrected using `UPDATE` and `LIKE` statements. Date fields stored as text were converted to proper `DATE` format using `STR_TO_DATE()` and `ALTER TABLE`.

```sql
UPDATE layoffs_staging2
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';

UPDATE layoffs_staging2
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');

ALTER TABLE layoffs_staging2
MODIFY COLUMN `date` DATE;
```

**4. Handling Null and Blank Values**

Missing industry values were populated by self-referencing rows from the same company. Records where both `total_laid_off` and `percentage_laid_off` were null were removed as they held no analytical value.

```sql
DELETE FROM layoffs_staging2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;
```

**5. Column Cleanup**

The helper `row_num` column added during deduplication was dropped after it was no longer needed.

```sql
ALTER TABLE layoffs_staging2 DROP COLUMN row_num;
```

---

### Part 2 - Exploratory Data Analysis

**Aggregate Analysis**

Layoffs were aggregated by industry, country, and year to identify the most impacted segments.

```sql
SELECT industry, SUM(total_laid_off) AS total_laid_off
FROM layoffs_staging2
GROUP BY industry
ORDER BY 2 DESC;

SELECT YEAR(`date`), SUM(total_laid_off)
FROM layoffs_staging2
GROUP BY YEAR(`date`)
ORDER BY 1 DESC;
```

**Rolling Monthly Totals**

A rolling sum was built using `SUBSTRING()` on the date column to track cumulative layoffs month over month.

```sql
SELECT SUBSTRING(`date`, 1, 7) AS `month`, SUM(total_laid_off) AS total_laid_off
FROM layoffs_staging2
GROUP BY SUBSTRING(`date`, 1, 7)
ORDER BY 1;
```

**Company Rankings by Year**

`DENSE_RANK()` inside a CTE was used to identify the top 3 companies with the highest layoffs for each year.

```sql
WITH Company_Year AS (
  SELECT company, YEAR(`date`) AS `year`, SUM(total_laid_off) AS total_laid_off
  FROM layoffs_staging2
  GROUP BY company, YEAR(`date`)
),
Company_Year_Rank AS (
  SELECT *, DENSE_RANK() OVER(PARTITION BY `year` ORDER BY total_laid_off DESC) AS ranking
  FROM Company_Year
  WHERE `year` IS NOT NULL
)
SELECT * FROM Company_Year_Rank WHERE ranking <= 3;
```

---

## Insights & Findings

- **116 companies** laid off 100% of their workforce during this period, indicating full shutdowns or bankruptcy.
- The **Consumer and Retail industries** were the hardest hit, likely due to social restrictions reducing consumer spending.
- The **United States** accounted for the highest total layoffs by country, followed by India and the Netherlands.
- **The Netherlands** recorded the highest average layoffs per event among all countries.
- **2022** was the most severe year overall, with over 160,000 layoffs recorded.
- **January 2023** saw the single highest monthly layoff count, exceeding 84,000 employees in one month alone.

---

*This project is part of a broader data analytics portfolio. For more projects, visit my [GitHub profile](https://github.com/marcbenjake).*
