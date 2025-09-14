-- Sakila Database Integration Tests
-- This file contains SQL statements to validate that the database was loaded correctly

-- Test 1: Database exists
SELECT 'Sakila database exists' as test_name,
       CASE WHEN (SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name = 'sakila') > 0 
            THEN 'PASS' ELSE 'FAIL' END as result;

-- Test 2: Core tables exist
SELECT 'Core tables exist' as test_name,
       CASE WHEN (
           SELECT COUNT(*) FROM information_schema.tables 
           WHERE table_schema = 'sakila'
           AND table_name IN ('actor', 'film', 'customer', 'rental', 'inventory', 'store')
       ) >= 6 THEN 'PASS' ELSE 'FAIL' END as result;

-- Test 3: Actor data exists
SELECT 'Actor data loaded' as test_name,
       CASE WHEN COUNT(*) > 0 THEN 'PASS' 
            ELSE 'FAIL - No actors found' END as result
FROM sakila.actor;

-- Test 4: Film data exists  
SELECT 'Film data loaded' as test_name,
       CASE WHEN COUNT(*) > 0 THEN 'PASS'
            ELSE 'FAIL - No films found' END as result
FROM sakila.film;

-- Test 5: Customer data exists
SELECT 'Customer data loaded' as test_name,
       CASE WHEN COUNT(*) > 0 THEN 'PASS'
            ELSE 'FAIL - No customers found' END as result
FROM sakila.customer;

-- Test 6: Store data exists
SELECT 'Store data loaded' as test_name,
       CASE WHEN COUNT(*) > 0 THEN 'PASS'
            ELSE 'FAIL - No stores found' END as result
FROM sakila.store;

-- Test 7: Data integrity - films have categories
SELECT 'Data integrity - films have categories' as test_name,
       CASE WHEN (
           SELECT COUNT(*) FROM sakila.film f
           INNER JOIN sakila.film_category fc ON f.film_id = fc.film_id
       ) > 0 THEN 'PASS' ELSE 'FAIL' END as result;

-- Summary
SELECT '=== TEST SUMMARY ===' as test_name, '' as result
UNION ALL
SELECT 'Total tests run' as test_name, '7' as result;