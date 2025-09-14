# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Repository Overview

This is the MySQL employees sample database - a widely-used test database containing approximately 300,000 employee records with 2.8 million salary entries. The database serves as a realistic dataset for testing MySQL applications, performance testing, and learning SQL queries.

## Database Architecture

The database consists of 6 main tables with temporal relationships:

- `employees`: Core employee information (300,024 records)
- `departments`: Company departments (9 records) 
- `dept_emp`: Employee-department assignments with date ranges (331,603 records)
- `dept_manager`: Department manager assignments with date ranges (24 records)
- `titles`: Employee job titles with date ranges (443,308 records)
- `salaries`: Employee salary history with date ranges (2,844,047 records)

Key architectural features:
- Temporal data design with from_date/to_date ranges
- Referential integrity with foreign key constraints
- Views for current employee department assignments
- Data intentionally includes inconsistencies for data cleaning exercises

## Installation Commands

**Basic installation:**
```bash
mysql < employees.sql
```

**Installation with partitioned tables (for large-scale testing):**
```bash
mysql < employees_partitioned.sql
```

**MySQL 5.1 partitioned version:**
```bash
mysql < employees_partitioned_5.1.sql
```

## Testing Commands

**Test installation with MD5 checksums:**
```bash
mysql -t < test_employees_md5.sql
```

**Test installation with SHA checksums:**
```bash
mysql -t < test_employees_sha.sql
```

**Alternative testing with bash script:**
```bash
./sql_test.sh mysql
# or with specific connection parameters:
./sql_test.sh "mysql -u username -p -h hostname"
```

**Test across multiple MySQL versions (requires dbdeployer):**
```bash
./test_versions.sh
```

## Working with the Database

**Connect to the database:**
```bash
mysql employees
```

**Load additional sample data (Sakila subset):**
```bash
mysql < sakila/sakila-mv-schema.sql
mysql < sakila/sakila-mv-data.sql
```

**Query current employee departments:**
```sql
SELECT * FROM current_dept_emp LIMIT 10;
```

**View database objects:**
```bash
mysql -e "source objects.sql" employees
```

## Data Validation

The database includes built-in validation through checksums. Expected values:
- employees: 300,024 records
- departments: 9 records  
- dept_manager: 24 records
- dept_emp: 331,603 records
- titles: 443,308 records
- salaries: 2,844,047 records

Both MD5 and SHA1 checksums are provided for data integrity verification.

## File Structure

**Core database files:**
- `employees.sql` - Main database schema and data loader
- `employees_partitioned.sql` - Partitioned version for MySQL 5.5+
- `employees_partitioned_5.1.sql` - Partitioned version for MySQL 5.1

**Data dump files:**
- `load_*.dump` - Individual table data dumps

**Testing files:**
- `test_employees_md5.sql` - MD5-based validation
- `test_employees_sha.sql` - SHA1-based validation
- `sql_test.sh` - Bash-based testing script
- `test_versions.sh` - Multi-version testing script

**Docker development files:**
- `docker-compose.mysql.yml` - MySQL development environment with Adminer
- `docker-compose.postgres.yml` - PostgreSQL development environment with pgAdmin
- `employees_postgres.sql` - PostgreSQL-compatible schema
- `load_postgres_data.sql` - PostgreSQL data loading script

**Additional components:**
- `sakila/` - Subset of Sakila sample database
- `objects.sql` - Additional database objects (views, procedures, functions)
- `show_elapsed.sql` - Performance timing utilities

## Docker Development Environment

**Start MySQL development environment:**
```bash
docker-compose -f docker-compose.mysql.yml up -d
```

**Start PostgreSQL development environment:**
```bash
docker-compose -f docker-compose.postgres.yml up -d
```

**Connect to databases:**
```bash
# MySQL
mysql -h localhost -P 3306 -u root -proot employees

# PostgreSQL
psql -h localhost -p 5432 -U postgres -d postgres
```

**Access web administration interfaces:**
- MySQL (Adminer): http://localhost:8080
- PostgreSQL (pgAdmin): http://localhost:8081

**Stop and cleanup:**
```bash
# Stop MySQL environment
docker-compose -f docker-compose.mysql.yml down

# Stop PostgreSQL environment
docker-compose -f docker-compose.postgres.yml down

# Remove volumes (deletes all data)
docker-compose -f docker-compose.mysql.yml down -v
docker-compose -f docker-compose.postgres.yml down -v
```

**Check database status:**
```bash
# MySQL
docker-compose -f docker-compose.mysql.yml logs mysql

# PostgreSQL  
docker-compose -f docker-compose.postgres.yml logs postgres
```

## Prerequisites

**For native installation:**
Requires MySQL 5.0+ with the following privileges:
- SELECT, INSERT, UPDATE, DELETE
- CREATE, DROP, RELOAD, REFERENCES
- INDEX, ALTER, SHOW DATABASES
- CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE, CREATE VIEW

**For Docker development:**
Requires Docker and Docker Compose installed on your system.

## License and Disclaimer

Licensed under Creative Commons Attribution-Share Alike 3.0 Unported License. The data is fabricated and does not correspond to real people.