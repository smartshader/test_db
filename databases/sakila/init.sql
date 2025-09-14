-- Sakila Database Initialization  
-- This file specifies the files to load for the Sakila database
-- The setup script will process this file and resolve all source commands recursively

-- Load Sakila database schema
source sakila-mv-schema.sql;

-- Load Sakila database data
source sakila-mv-data.sql;