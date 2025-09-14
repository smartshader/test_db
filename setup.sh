#!/bin/bash

# Test Database Setup Script
# Interactive script to setup database environments with selected sample databases

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to print header
print_header() {
    echo
    print_color $CYAN "=================================="
    print_color $CYAN "$1"
    print_color $CYAN "=================================="
    echo
}

# Function to cleanup existing containers and volumes
cleanup() {
    local engine=$1
    print_color $YELLOW "Cleaning up existing ${engine} environment..."
    
    if [ "$engine" = "mysql" ]; then
        docker-compose -f docker-compose.mysql.yml down -v 2>/dev/null || true
    elif [ "$engine" = "postgres" ]; then
        docker-compose -f docker-compose.postgres.yml down -v 2>/dev/null || true
    fi
    
    # Clean init directories
    rm -rf init/${engine}/*
}

# Function to generate MySQL initialization script
generate_mysql_init() {
    local databases=("$@")
    
    # Create a shell script that will be executed by Docker during initialization
    # This is the only way to handle the employees.sql file which uses 'source' commands
    local init_file="init/mysql/01-init-databases.sh"
    
    cat > "$init_file" << 'EOF'
#!/bin/bash
# Auto-generated MySQL initialization script for Docker
# This runs in the Docker entrypoint before MySQL starts accepting connections

echo "Starting database initialization..."

# Wait for MySQL to be available in the initialization context
until mysqladmin ping --silent; do
    echo "Waiting for MySQL to be ready..."
    sleep 2
done

EOF
    
    echo "# Generated on $(date)" >> "$init_file"
    echo "" >> "$init_file"
    
    for db in "${databases[@]}"; do
        case "$db" in
            "employees")
                print_color $BLUE "  → Adding MySQL employees database..."
                cat >> "$init_file" << 'EOF'

# Load employees database
echo "Loading employees database..."
mysql -u root -p"$MYSQL_ROOT_PASSWORD" < /databases/employees/mysql/employees.sql
echo "✓ Employees database loaded"

EOF
                ;;
            "sakila")
                print_color $BLUE "  → Adding Sakila database..."
                cat >> "$init_file" << 'EOF'

# Load Sakila database
echo "Loading Sakila database..."
mysql -u root -p"$MYSQL_ROOT_PASSWORD" < /databases/sakila/sakila-mv-schema.sql
mysql -u root -p"$MYSQL_ROOT_PASSWORD" < /databases/sakila/sakila-mv-data.sql
echo "✓ Sakila database loaded"

EOF
                ;;
        esac
    done
    
    cat >> "$init_file" << 'EOF'

echo "Database initialization completed successfully!"
EOF
    
    chmod +x "$init_file"
}

# Function to generate PostgreSQL initialization script
generate_postgres_init() {
    local databases=("$@")
    local init_file="init/postgres/01-init-databases.sql"
    
    echo "-- Auto-generated PostgreSQL initialization script" > "$init_file"
    echo "-- Generated on $(date)" >> "$init_file"
    echo "" >> "$init_file"
    
    for db in "${databases[@]}"; do
        case "$db" in
            "employees")
                print_color $BLUE "  → Adding PostgreSQL employees database..."
                cat >> "$init_file" << 'EOF'

-- Load employees database
\i /databases/employees/postgres/employees_postgres.sql
EOF
                
                # Create data loading script
                cat > "init/postgres/02-load-employees-data.sh" << 'EOF'
#!/bin/bash
# Load employees data into PostgreSQL

echo "Loading employees data into PostgreSQL..."

# Load data using psql
psql -U postgres -d postgres << 'EOSQL'
-- Load departments data
\copy departments FROM '/databases/employees/mysql/load_departments.dump' WITH (FORMAT csv, DELIMITER E'\t', NULL '\N');

-- Load employees data  
\copy employees FROM '/databases/employees/mysql/load_employees.dump' WITH (FORMAT csv, DELIMITER E'\t', NULL '\N');

-- Load dept_emp data
\copy dept_emp FROM '/databases/employees/mysql/load_dept_emp.dump' WITH (FORMAT csv, DELIMITER E'\t', NULL '\N');

-- Load dept_manager data
\copy dept_manager FROM '/databases/employees/mysql/load_dept_manager.dump' WITH (FORMAT csv, DELIMITER E'\t', NULL '\N');

-- Load titles data
\copy titles FROM '/databases/employees/mysql/load_titles.dump' WITH (FORMAT csv, DELIMITER E'\t', NULL '\N');

-- Load salaries data (split into 3 files)
\copy salaries FROM '/databases/employees/mysql/load_salaries1.dump' WITH (FORMAT csv, DELIMITER E'\t', NULL '\N');
\copy salaries FROM '/databases/employees/mysql/load_salaries2.dump' WITH (FORMAT csv, DELIMITER E'\t', NULL '\N');
\copy salaries FROM '/databases/employees/mysql/load_salaries3.dump' WITH (FORMAT csv, DELIMITER E'\t', NULL '\N');

-- Display statistics
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

EOSQL

echo "Employees data loading completed!"
EOF
                chmod +x "init/postgres/02-load-employees-data.sh"
                ;;
        esac
    done
    
    cat >> "$init_file" << 'EOF'

-- Display loaded databases and tables
\l
\dt
EOF
}

# Function to start database environment
start_environment() {
    local engine=$1
    
    print_color $GREEN "Starting ${engine} environment..."
    
    if [ "$engine" = "mysql" ]; then
        docker-compose -f docker-compose.mysql.yml up -d
        print_color $GREEN "✓ MySQL is starting up..."
        print_color $CYAN "  Database: mysql://root:root@localhost:3306/postgres"
        print_color $CYAN "  Web UI: http://localhost:8080 (Adminer)"
    elif [ "$engine" = "postgres" ]; then
        docker-compose -f docker-compose.postgres.yml up -d
        print_color $GREEN "✓ PostgreSQL is starting up..."
        print_color $CYAN "  Database: postgresql://postgres:postgres@localhost:5432/postgres"
        print_color $CYAN "  Web UI: http://localhost:8081 (pgAdmin)"
        print_color $CYAN "  pgAdmin login: admin@postgres.local / admin"
    fi
    
    echo
    print_color $YELLOW "Waiting for database to be ready..."
    sleep 5
    
    if [ "$engine" = "mysql" ]; then
        while ! docker exec mysql mysqladmin ping -h localhost -u root -proot --silent; do
            print_color $YELLOW "  Waiting for MySQL..."
            sleep 2
        done
    elif [ "$engine" = "postgres" ]; then
        while ! docker exec postgres pg_isready -U postgres -d postgres > /dev/null 2>&1; do
            print_color $YELLOW "  Waiting for PostgreSQL..."
            sleep 2
        done
    fi
    
    print_color $GREEN "✓ Database is ready!"
}

# Main script
main() {
    print_header "Test Database Setup"
    
    print_color $BLUE "This script will help you set up a database environment with sample databases."
    echo
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        print_color $RED "Error: Docker is not running. Please start Docker and try again."
        exit 1
    fi
    
    # Select database engine
    print_color $CYAN "Select database engine:"
    echo "1) MySQL"
    echo "2) PostgreSQL"
    echo
    read -p "Enter your choice (1-2): " engine_choice
    
    case $engine_choice in
        1)
            ENGINE="mysql"
            ;;
        2)
            ENGINE="postgres"
            ;;
        *)
            print_color $RED "Invalid choice. Exiting."
            exit 1
            ;;
    esac
    
    print_color $GREEN "✓ Selected: $ENGINE"
    echo
    
    # Select databases
    print_color $CYAN "Select sample databases to load (space-separated numbers):"
    echo "1) Employees Database (300k employees, 2.8M salary records)"
    echo "2) Sakila Database (DVD rental store sample)"
    echo
    read -p "Enter your choices (e.g., '1 2' for both): " db_choices
    
    # Parse database choices
    SELECTED_DBS=()
    for choice in $db_choices; do
        case $choice in
            1)
                SELECTED_DBS+=("employees")
                ;;
            2)
                SELECTED_DBS+=("sakila")
                ;;
            *)
                print_color $YELLOW "Warning: Ignoring invalid choice '$choice'"
                ;;
        esac
    done
    
    if [ ${#SELECTED_DBS[@]} -eq 0 ]; then
        print_color $RED "No valid databases selected. Exiting."
        exit 1
    fi
    
    print_color $GREEN "✓ Selected databases: ${SELECTED_DBS[*]}"
    echo
    
    # Confirm setup
    print_color $CYAN "Setup Summary:"
    print_color $BLUE "  Engine: $ENGINE"
    print_color $BLUE "  Databases: ${SELECTED_DBS[*]}"
    echo
    read -p "Proceed with setup? (y/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_color $YELLOW "Setup cancelled."
        exit 0
    fi
    
    # Cleanup existing environment
    cleanup "$ENGINE"
    
    # Generate initialization scripts
    print_color $CYAN "Generating initialization scripts..."
    if [ "$ENGINE" = "mysql" ]; then
        generate_mysql_init "${SELECTED_DBS[@]}"
    elif [ "$ENGINE" = "postgres" ]; then
        generate_postgres_init "${SELECTED_DBS[@]}"
    fi
    
    print_color $GREEN "✓ Initialization scripts generated"
    
    # Start environment
    start_environment "$ENGINE"
    
    # Final instructions
    print_header "Setup Complete!"
    print_color $GREEN "Your $ENGINE environment is ready with the following databases:"
    for db in "${SELECTED_DBS[@]}"; do
        print_color $BLUE "  → $db"
    done
    
    echo
    print_color $CYAN "Connection Information:"
    if [ "$ENGINE" = "mysql" ]; then
        print_color $BLUE "  CLI: mysql -h localhost -P 3306 -u root -proot"
        print_color $BLUE "  Web: http://localhost:8080"
    elif [ "$ENGINE" = "postgres" ]; then
        print_color $BLUE "  CLI: psql -h localhost -p 5432 -U postgres -d postgres"
        print_color $BLUE "  Web: http://localhost:8081"
    fi
    
    echo
    print_color $CYAN "Management Commands:"
    print_color $BLUE "  Stop: docker-compose -f docker-compose.${ENGINE}.yml down"
    print_color $BLUE "  Logs: docker-compose -f docker-compose.${ENGINE}.yml logs -f"
    print_color $BLUE "  Cleanup: docker-compose -f docker-compose.${ENGINE}.yml down -v"
    echo
}

# Run main function
main "$@"
