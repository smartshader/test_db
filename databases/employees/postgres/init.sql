-- PostgreSQL Employees Database Initialization
-- This file specifies the files to load for the employees database
-- The setup script will process this file and resolve all source commands recursively

-- Load the PostgreSQL-compatible employees database schema
source employees_postgres.sql;

-- Note: Data loading for PostgreSQL is handled by the load_postgres_data.sql script
-- which processes the MySQL dump files and loads them into PostgreSQL
source load_postgres_data.sql;