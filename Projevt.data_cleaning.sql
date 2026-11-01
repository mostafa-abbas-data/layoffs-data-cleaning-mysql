-- Data Cleaning: world layoffs (MySQL)
-- Safe to run top to bottom more than once: every table is dropped and rebuilt.
-- Change the database name on the next line if you work in `portfolio`.
-- =====================================================================
USE world_layoffs;
 
-- Safe Update Mode off for this session (UPDATE / DELETE without a key in WHERE)
SET SQL_SAFE_UPDATES = 0;
 
-- 1. Remove duplicates
-- 2. Standardize the data
-- 3. Handle NULL and blank values
-- 4. Remove unnecessary rows and columns
 
 
-- =====================================================================
-- 1. REMOVE DUPLICATES
-- =====================================================================
 
-- staging copy: never touch the raw table
DROP TABLE IF EXISTS layoffs_staging;
CREATE TABLE layoffs_staging LIKE layoffs;
 
INSERT INTO layoffs_staging
SELECT *
FROM layoffs;
 
-- check: the two numbers must match (2361 in the course data)
SELECT COUNT(*) AS layoffs_count FROM layoffs;
SELECT COUNT(*) AS staging_count FROM layoffs_staging;

-- second staging table = staging + the row_num column
-- (a DELETE on a CTE is not allowed in MySQL, so row_num has to live in a real table)
DROP TABLE IF EXISTS layoffs_staging2;
CREATE TABLE `layoffs_staging2` (
  `company` text,
  `location` text,
  `industry` text,
  `total_laid_off` int DEFAULT NULL,
  `percentage_laid_off` text,
  `date` text,
  `stage` text,
  `country` text,
  `funds_raised_millions` int DEFAULT NULL,
  `row_num` INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
 
-- every column goes into PARTITION BY, so only fully identical rows count as duplicates
INSERT INTO layoffs_staging2
SELECT *,
       ROW_NUMBER() OVER (
           PARTITION BY company, location, industry, total_laid_off,
                        percentage_laid_off, `date`, stage, country, funds_raised_millions
       ) AS row_num
FROM layoffs_staging;
 
-- look first: these are the rows that will be deleted
SELECT *
FROM layoffs_staging2
WHERE row_num > 1;
 
DELETE
FROM layoffs_staging2
WHERE row_num > 1;
 
-- check: 2361 minus the duplicates you just saw (2356 if there were 5)
SELECT COUNT(*) AS staging2_count FROM layoffs_staging2;
 
 
-- =====================================================================
-- 2. STANDARDIZE THE DATA
-- =====================================================================
 
-- company: remove extra spaces
SELECT company, TRIM(company)
FROM layoffs_staging2;
 
UPDATE layoffs_staging2
SET company = TRIM(company);
 
-- industry: unify the Crypto variants
SELECT DISTINCT industry
FROM layoffs_staging2
ORDER BY industry;
 
UPDATE layoffs_staging2
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';
 
-- country: remove the trailing dot ("United States.")
SELECT DISTINCT country, TRIM(TRAILING '.' FROM country)
FROM layoffs_staging2
ORDER BY country;
 
UPDATE layoffs_staging2
SET country = TRIM(TRAILING '.' FROM country)
WHERE country LIKE 'United States%';
 
-- date: text -> DATE
-- a text value 'NULL' cannot be converted, make it a real NULL first (harmless if there is none)
UPDATE layoffs_staging2
SET `date` = NULL
WHERE `date` = 'NULL';
 
-- preview: every date must look right (12/16/2022 -> 2022-12-16)
SELECT `date`,
       STR_TO_DATE(`date`, '%m/%d/%Y') AS new_date
FROM layoffs_staging2;
 
UPDATE layoffs_staging2
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');
 
ALTER TABLE layoffs_staging2
MODIFY COLUMN `date` DATE;
 
 
-- =====================================================================
-- 3. HANDLE NULL AND BLANK VALUES
-- =====================================================================
 
-- blank '' -> real NULL, so one condition (IS NULL) catches both
UPDATE layoffs_staging2
SET industry = NULL
WHERE industry = '';
 
-- preview: the rows that can be filled from another row of the same company
SELECT t1.company, t1.industry AS missing_industry, t2.industry AS known_industry
FROM layoffs_staging2 t1
JOIN layoffs_staging2 t2
    ON t1.company = t2.company
    AND t1.location = t2.location
WHERE t1.industry IS NULL
AND t2.industry IS NOT NULL;
 
-- fill them (Self Join)
UPDATE layoffs_staging2 t1
JOIN layoffs_staging2 t2
    ON t1.company = t2.company
    AND t1.location = t2.location
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
AND t2.industry IS NOT NULL;
 
-- what is still missing? (only companies with a single row, e.g. Bally's Interactive)
SELECT *
FROM layoffs_staging2
WHERE industry IS NULL;
 
 
-- =====================================================================
-- 4. REMOVE UNNECESSARY ROWS AND COLUMNS
-- =====================================================================
 
-- look first: no layoff count and no percentage = useless for the analysis
SELECT *
FROM layoffs_staging2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;
 
DELETE
FROM layoffs_staging2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;
 
-- row_num was only needed for the duplicates
ALTER TABLE layoffs_staging2
DROP COLUMN row_num;
 
SELECT count(*)
FROM layoffs_staging2;
USE world_layoffs;       

SET SQL_SAFE_UPDATES = 0; 

 SELECT*
 FROM layoffs_staging2;
 