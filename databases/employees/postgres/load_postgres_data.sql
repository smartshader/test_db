-- Load data into PostgreSQL from MySQL dump files
-- This script processes the MySQL dump files and loads them into PostgreSQL

-- Set PostgreSQL-specific settings for data loading
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET default_tablespace = '';
SET default_with_oids = false;

-- Function to convert MySQL dumps to PostgreSQL-compatible format
-- Note: This assumes the dump files have been pre-processed or will be loaded via COPY commands

-- Load departments data
\echo 'Loading departments...'
\copy departments FROM '/docker-entrypoint-initdb.d/load_departments.dump' WITH (FORMAT csv, DELIMITER E'\t', NULL '\\N');

-- Load employees data  
\echo 'Loading employees...'
\copy employees FROM '/docker-entrypoint-initdb.d/load_employees.dump' WITH (FORMAT csv, DELIMITER E'\t', NULL '\\N');

-- Load dept_emp data
\echo 'Loading dept_emp...'
\copy dept_emp FROM '/docker-entrypoint-initdb.d/load_dept_emp.dump' WITH (FORMAT csv, DELIMITER E'\t', NULL '\\N');

-- Load dept_manager data
\echo 'Loading dept_manager...'
\copy dept_manager FROM '/docker-entrypoint-initdb.d/load_dept_manager.dump' WITH (FORMAT csv, DELIMITER E'\t', NULL '\\N');

-- Load titles data
\echo 'Loading titles...'
\copy titles FROM '/docker-entrypoint-initdb.d/load_titles.dump' WITH (FORMAT csv, DELIMITER E'\t', NULL '\\N');

-- Load salaries data (split into 3 files)
\echo 'Loading salaries (part 1/3)...'
\copy salaries FROM '/docker-entrypoint-initdb.d/load_salaries1.dump' WITH (FORMAT csv, DELIMITER E'\t', NULL '\\N');

\echo 'Loading salaries (part 2/3)...'
\copy salaries FROM '/docker-entrypoint-initdb.d/load_salaries2.dump' WITH (FORMAT csv, DELIMITER E'\t', NULL '\\N');

\echo 'Loading salaries (part 3/3)...'
\copy salaries FROM '/docker-entrypoint-initdb.d/load_salaries3.dump' WITH (FORMAT csv, DELIMITER E'\t', NULL '\\N');

-- Update sequences to current max values
SELECT setval('employees_emp_no_seq', (SELECT MAX(emp_no) FROM employees));

-- Display loading completion message
SELECT 'PostgreSQL data loading completed' as info;

-- Display basic statistics
SELECT 
    'employees' as table_name, 
    count(*) as record_count 
FROM employees
UNION ALL
SELECT 
    'departments' as table_name, 
    count(*) as record_count 
FROM departments
UNION ALL
SELECT 
    'dept_emp' as table_name, 
    count(*) as record_count 
FROM dept_emp
UNION ALL
SELECT 
    'dept_manager' as table_name, 
    count(*) as record_count 
FROM dept_manager
UNION ALL
SELECT 
    'titles' as table_name, 
    count(*) as record_count 
FROM titles
UNION ALL
SELECT 
    'salaries' as table_name, 
    count(*) as record_count 
FROM salaries
ORDER BY table_name;