# Layoffs Data Cleaning (MySQL)

Cleaning a raw dataset of company layoffs with pure SQL, so it is ready for analysis.

> This project follows the guided tutorial *Data Cleaning in MySQL* by Alex The Analyst.
> I rebuilt it from scratch on my own, and documented the problems I hit and how I fixed them.

## Goal

Turn a messy layoffs table into a clean, consistent one: no duplicates, standardized values,
proper data types, and no rows that are useless for analysis.

## Tools

- MySQL 8
- MySQL Workbench

## Dataset

- Source: [https://www.youtube.com/redirect?event=video_description&redir_token=QUlxb01IWVUwbUhKdXNxZXBtT3pOQmJZZm5GdXxBSTVJdTVzQlp4b2lFOExKV2NSdU50SWlxSDdnczctS2t3bjZaUV83MkNER21DZEx0SUdKU21KSkExdnNudVNMcUl6YmRyMEFhM1hJREhUd0V1d3c4YmY3Y2d1ZHk2MHBJYWtC&q=https%3A%2F%2Fgithub.com%2FAlexTheAnalyst%2FMySQL-YouTube-Series&v=4UltKCnnnTA
]
- Raw table: `layoffs` (2,361 rows, 9 columns)
- Columns: `company`, `location`, `industry`, `total_laid_off`, `percentage_laid_off`, `date`, `stage`, `country`, `funds_raised_millions`

## Files

| File | What it is |
|---|---|
| `data_cleaning.sql` | The full cleaning script, runs top to bottom and can be re-run safely |
| `layoffs_raw.csv` | The original data |

## Method

The raw table is never modified. All work is done on staging copies (`layoffs_staging`, `layoffs_staging2`).

### 1. Remove duplicates
- Numbered identical rows with `ROW_NUMBER() OVER (PARTITION BY ...)` over **all** columns.
- Rows with `row_num > 1` are duplicates; previewed them with a `SELECT`, then deleted them.
- MySQL does not allow `DELETE` on a CTE, so the row numbers are stored in a real table (`layoffs_staging2`).

### 2. Standardize the data
- `TRIM()` to remove extra spaces from company names.
- Unified industry variants (`Crypto`, `Crypto Currency`, ...) into one value.
- `TRIM(TRAILING '.' FROM country)` to fix `United States.`
- Converted `date` from text to a real `DATE` with `STR_TO_DATE(`date`, '%m/%d/%Y')` and `ALTER TABLE ... MODIFY COLUMN`.

### 3. Handle NULL and blank values
- Converted blank strings in `industry` to real `NULL`.
- Filled missing industries with a **self join** on the same company and location
  (for example Airbnb → `Travel`, Carvana → `Transportation`, Juul → `Consumer`).
- One company (Bally's Interactive) has a single row, so there is nothing to copy the industry from.
  It stays `NULL` on purpose instead of guessing.

### 4. Remove unnecessary rows and columns
- Deleted rows where both `total_laid_off` and `percentage_laid_off` are `NULL`
  (no layoff information, so no value for the analysis).
- Dropped the helper column `row_num`.

## Result

| Stage | Rows |
|---|---|
| Raw `layoffs` | 2,361 |
| After cleaning (`layoffs_staging2`) | 1,995 |

- Duplicates removed: 5
- Rows with no layoff data removed: 361
- `date` is now a `DATE` column.

## Problems I ran into (and what I learned)

- **Rows multiplied after running an `INSERT` more than once.** `INSERT` adds rows, it never replaces them.
  Fix: rebuild the tables with `DROP TABLE IF EXISTS` + `CREATE` + `INSERT` in one block.
- **`Error 1288` on `DELETE` from a CTE.** Fix: keep `row_num` in a real table and delete from it.
- **`Error 1175` (Safe Update Mode).** Fix: `SET SQL_SAFE_UPDATES = 0` while cleaning, back to `1` after.
- **`Error 1146` (table doesn't exist).** The active database was not `world_layoffs`. Fix: always start with `USE`.
- **Wrong date format.** `%y` reads a 2-digit year, the data has 4-digit years, so the format must be `%Y`.

## Skills shown

`CTE` · `ROW_NUMBER()` and `PARTITION BY` · self join · `TRIM` · `STR_TO_DATE` · `UPDATE` / `DELETE` with previews · `ALTER TABLE` · data validation with row counts

## How to run

1. Import `layoffs_raw.csv` into a schema called `world_layoffs` as a table named `layoffs`.
2. Open `data_cleaning.sql` in MySQL Workbench.
3. Run the whole file (`Ctrl + A`, then `Ctrl + Shift + Enter`).
4. Check the counts: `layoffs` = 2361, `layoffs_staging` = 2361, `layoffs_staging2` = 1995.

## Next step

Exploratory data analysis on the cleaned table (industries and companies with the most layoffs, trends over time).
