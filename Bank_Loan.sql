CREATE DATABASE bank_loan_project;
USE bank_loan_project;

SELECT * FROM financial_loan;
SELECT COUNT(*) FROM financial_loan;

ALTER TABLE financial_loan RENAME COLUMN `ï»¿id` to `id`;
SELECT COUNT(DISTINCT id) FROM financial_loan;

# Check Missing Values
SELECT 
COUNT(*) - COUNT(address_state) AS state_nulls,
COUNT(*) - COUNT(emp_length) AS emp_length_nulls,
COUNT(*) - COUNT(home_ownership) AS home_nulls,
COUNT(*) - COUNT(loan_status) AS loan_status_nulls
FROM financial_loan;

SET SQL_SAFE_UPDATES = 0;


# Remove Duplicates
DELETE FROM financial_loan
WHERE id NOT IN (
    SELECT * FROM (
        SELECT MIN(id)
        FROM financial_loan
        GROUP BY id
    ) temp
);

# Standardize Text Columns
UPDATE financial_loan
SET address_state = UPPER(address_state),
home_ownership = UPPER(home_ownership),
loan_status = UPPER(loan_status),
verification_status = UPPER(verification_status);

# Clean Employment Length
UPDATE financial_loan
SET emp_length = REPLACE(emp_length,'+ years','');

UPDATE financial_loan
SET emp_length = REPLACE(emp_length,' years','');

UPDATE financial_loan
SET emp_length = REPLACE(emp_length,' year','');

UPDATE financial_loan
SET emp_length = REPLACE(emp_length,'< ','');

# Convert Employment to Numeric
ALTER TABLE financial_loan
ADD emp_length_num INT;

UPDATE financial_loan
SET emp_length_num = CAST(emp_length AS UNSIGNED);

# Convert Dates
ALTER TABLE financial_loan
ADD issue_date_clean DATE;

UPDATE financial_loan
SET issue_date_clean = STR_TO_DATE(issue_date,'%d-%m-%Y');

ALTER TABLE financial_loan
ADD last_payment_date_clean DATE;

UPDATE financial_loan
SET last_payment_date_clean =
STR_TO_DATE(last_payment_date,'%d-%m-%Y');


# Handle Missing Values
UPDATE financial_loan
SET emp_length_num = (
    SELECT avg_val 
    FROM (
        SELECT ROUND(AVG(emp_length_num)) avg_val 
        FROM financial_loan
    ) temp
)
WHERE emp_length_num IS NULL;


# Feature Engineering — Loan Risk
ALTER TABLE financial_loan
ADD COLUMN loan_risk VARCHAR(20);

UPDATE financial_loan
SET loan_risk =
CASE
WHEN loan_status = 'CHARGED OFF' THEN 'HIGH RISK'
WHEN loan_status = 'FULLY PAID' THEN 'LOW RISK'
ELSE 'MEDIUM RISK'
END;

# Income Category
ALTER TABLE financial_loan
ADD COLUMN income_category VARCHAR(20);

UPDATE financial_loan
SET income_category =
CASE
WHEN annual_income < 40000 THEN 'LOW'
WHEN annual_income BETWEEN 40000 AND 80000 THEN 'MEDIUM'
ELSE 'HIGH'
END;


# Interest Category
ALTER TABLE financial_loan
ADD COLUMN interest_category VARCHAR(20);

UPDATE financial_loan
SET interest_category =
CASE
WHEN int_rate < 0.08 THEN 'LOW'
WHEN int_rate BETWEEN 0.08 AND 0.15 THEN 'MEDIUM'
ELSE 'HIGH'
END;


# Clean emp_title
UPDATE financial_loan
SET emp_title = 'UNKNOWN'
WHERE emp_title IS NULL OR emp_title = '';

UPDATE financial_loan
SET emp_title = TRIM(emp_title);

UPDATE financial_loan
SET emp_title = UPPER(emp_title);


# Create Clean View
CREATE VIEW loan_cleaned AS
SELECT 
id,
address_state,
emp_length_num,
home_ownership,
loan_status,
loan_amount,
term,
int_rate,
annual_income,
loan_risk,
income_category,
issue_date_clean,
last_payment_date_clean,
interest_category
FROM financial_loan;

# Window Functions
-- Rank Loans
SELECT *,
RANK() OVER(ORDER BY loan_amount DESC) loan_rank
FROM financial_loan;

-- Top Loan per State
SELECT *
FROM (
SELECT *,
ROW_NUMBER() OVER(PARTITION BY address_state 
ORDER BY loan_amount DESC) rn
FROM financial_loan
) t
WHERE rn = 1;


# Running Total
SELECT
issue_date_clean,
loan_amount,
SUM(loan_amount) OVER(ORDER BY issue_date_clean) running_total
FROM financial_loan;


# Default Rate
SELECT
COUNT(CASE WHEN loan_status='CHARGED OFF' THEN 1 END)
/ COUNT(*) *100 AS default_rate
FROM financial_loan;


# KPI Queries
SELECT SUM(loan_amount) total_loan FROM financial_loan;

SELECT AVG(int_rate) avg_interest FROM financial_loan;

SELECT COUNT(*) total_customers FROM financial_loan;


# Loan Status Distribution
SELECT loan_status, COUNT(*)
FROM financial_loan
GROUP BY loan_status;

# State Wise Loan Analysis
SELECT
address_state,
COUNT(*) total_loans,
SUM(loan_amount) total_amount,
AVG(int_rate) avg_interest
FROM financial_loan
GROUP BY address_state
ORDER BY total_amount DESC;


# Employment vs Loan
SELECT
emp_length_num,
COUNT(*) total_loans,
AVG(loan_amount) avg_loan
FROM financial_loan
GROUP BY emp_length_num
ORDER BY emp_length_num;


# CTE Query
WITH loan_cte AS (
SELECT
address_state,
SUM(loan_amount) total_amount
FROM financial_loan
GROUP BY address_state
)

SELECT *
FROM loan_cte
ORDER BY total_amount DESC;


# High Risk Customers
SELECT *
FROM financial_loan
WHERE loan_risk = 'HIGH RISK'
AND annual_income < 50000;