-- MySQL Employees Database Integration Tests
-- This file contains SQL statements to validate that the database was loaded correctly

-- Test 1: Database exists
SELECT 'Database exists' as test_name, 
       CASE WHEN DATABASE() = 'employees' THEN 'PASS' ELSE 'FAIL' END as result;

-- Test 2: All required tables exist
SELECT 'All tables exist' as test_name,
       CASE WHEN (
           SELECT COUNT(*) FROM information_schema.tables 
           WHERE table_schema = 'employees' 
           AND table_name IN ('employees', 'departments', 'dept_emp', 'dept_manager', 'titles', 'salaries')
       ) = 6 THEN 'PASS' ELSE 'FAIL' END as result;

-- Test 3: Employee count is correct
SELECT 'Employee count' as test_name,
       CASE WHEN COUNT(*) = 300024 THEN 'PASS' 
            ELSE CONCAT('FAIL - Expected 300024, got ', COUNT(*)) END as result
FROM employees;

-- Test 4: Department count is correct
SELECT 'Department count' as test_name,
       CASE WHEN COUNT(*) = 9 THEN 'PASS'
            ELSE CONCAT('FAIL - Expected 9, got ', COUNT(*)) END as result  
FROM departments;

-- Test 5: Salary records count is correct
SELECT 'Salary records count' as test_name,
       CASE WHEN COUNT(*) = 2844047 THEN 'PASS'
            ELSE CONCAT('FAIL - Expected 2844047, got ', COUNT(*)) END as result
FROM salaries;

-- Test 6: Title records count is correct  
SELECT 'Title records count' as test_name,
       CASE WHEN COUNT(*) = 443308 THEN 'PASS'
            ELSE CONCAT('FAIL - Expected 443308, got ', COUNT(*)) END as result
FROM titles;

-- Test 7: Department employee assignments count is correct
SELECT 'Dept-employee assignments count' as test_name,
       CASE WHEN COUNT(*) = 331603 THEN 'PASS'
            ELSE CONCAT('FAIL - Expected 331603, got ', COUNT(*)) END as result
FROM dept_emp;

-- Test 8: Department manager assignments count is correct
SELECT 'Dept-manager assignments count' as test_name,
       CASE WHEN COUNT(*) = 24 THEN 'PASS'
            ELSE CONCAT('FAIL - Expected 24, got ', COUNT(*)) END as result
FROM dept_manager;

-- Test 9: Views exist and work
SELECT 'Views exist and functional' as test_name,
       CASE WHEN (
           SELECT COUNT(*) FROM information_schema.views 
           WHERE table_schema = 'employees'
           AND table_name IN ('current_dept_emp', 'dept_emp_latest_date')
       ) = 2 AND (SELECT COUNT(*) FROM current_dept_emp LIMIT 1) >= 0
       THEN 'PASS' ELSE 'FAIL' END as result;

-- Test 10: Data integrity - employees have valid departments
SELECT 'Data integrity - employees in valid departments' as test_name,
       CASE WHEN (
           SELECT COUNT(*) FROM dept_emp de 
           LEFT JOIN departments d ON de.dept_no = d.dept_no 
           WHERE d.dept_no IS NULL
       ) = 0 THEN 'PASS' ELSE 'FAIL' END as result;

-- Summary
SELECT '=== TEST SUMMARY ===' as test_name, '' as result
UNION ALL
SELECT 'Total tests run' as test_name, '10' as result;