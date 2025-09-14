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
    # This script processes SQL files and resolves 'source' commands
    local init_file="init/mysql/01-init-databases.sh"
    
    cat > "$init_file" << 'EOF'
#!/bin/bash
# Auto-generated MySQL initialization script for Docker
# This runs in the Docker entrypoint and processes SQL files with source commands

set -e

echo "Starting database initialization..."

# Wait for MySQL to be available in the initialization context
until mysqladmin ping --silent; do
    echo "Waiting for MySQL to be ready..."
    sleep 2
done

# Function to process SQL files and resolve 'source' commands
process_sql_file() {
    local input_file="$1"
    local output_file="$2"
    local base_dir="$(dirname "$input_file")"
    
    echo "Processing SQL file: $input_file"
    
    # Read the input file line by line
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Check if line contains a source command
        if echo "$line" | grep -q "^[[:space:]]*source[[:space:]]"; then
            # Extract the filename from the source command
            local source_file=$(echo "$line" | sed 's/^[[:space:]]*source[[:space:]]*//' | sed 's/[[:space:]]*;[[:space:]]*$//' | tr -d ' ')
            
            # Construct full path to the source file
            local full_source_path="$base_dir/$source_file"
            
            echo "  → Embedding content from: $source_file"
            
            # Add a comment about the embedded file
            echo "-- Content from: $source_file" >> "$output_file"
            
            if [ -f "$full_source_path" ]; then
                # Recursively process the sourced file (in case it has more source commands)
                local temp_file=$(mktemp)
                process_sql_file "$full_source_path" "$temp_file"
                cat "$temp_file" >> "$output_file"
                rm -f "$temp_file"
            else
                echo "-- WARNING: Source file not found: $full_source_path" >> "$output_file"
                echo "WARNING: Source file not found: $full_source_path"
            fi
            
            echo "-- End of content from: $source_file" >> "$output_file"
        else
            # Regular line, copy as-is
            echo "$line" >> "$output_file"
        fi
    done < "$input_file"
}

EOF
    
    echo "# Generated on $(date)" >> "$init_file"
    echo "" >> "$init_file"
    
    for db in "${databases[@]}"; do
        case "$db" in
            "employees")
                print_color $BLUE "  → Adding MySQL employees database..."
                cat >> "$init_file" << 'EOF'

# Load employees database using standardized init.sql
echo "Loading employees database..."
processed_file=$(mktemp)
process_sql_file "/databases/employees/mysql/init.sql" "$processed_file"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" < "$processed_file"
rm -f "$processed_file"
echo "✓ Employees database loaded with all data"

# Run integration tests
echo "Running employees database integration tests..."
mysql -u root -p"$MYSQL_ROOT_PASSWORD" < "/databases/employees/mysql/integration_tests.sql"
echo "✓ Employees database tests completed"

EOF
                ;;
            "sakila")
                print_color $BLUE "  → Adding Sakila database..."
                cat >> "$init_file" << 'EOF'

# Load Sakila database using standardized init.sql
echo "Loading Sakila database..."
processed_file=$(mktemp)
process_sql_file "/databases/sakila/init.sql" "$processed_file"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" < "$processed_file"
rm -f "$processed_file"
echo "✓ Sakila database loaded"

# Run integration tests
echo "Running Sakila database integration tests..."
mysql -u root -p"$MYSQL_ROOT_PASSWORD" < "/databases/sakila/integration_tests.sql"
echo "✓ Sakila database tests completed"

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

-- Load employees database using standardized init.sql
\i /databases/employees/postgres/init.sql
EOF
                
                # Create integration test script
                cat > "init/postgres/02-run-integration-tests.sql" << 'EOF'
-- Run integration tests for employees database
\echo 'Running employees database integration tests...'
\i /databases/employees/postgres/integration_tests.sql
\echo 'Employees database tests completed'
EOF
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
