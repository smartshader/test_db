#!/bin/bash

# Non-interactive version of setup.sh for automated testing
# This script takes command line arguments instead of prompting for input

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

# Function to generate PostgreSQL initialization script
generate_postgres_init() {
    local databases=("$@")
    
    mkdir -p init/postgres
    local init_file="init/postgres/01-init-databases.sql"
    
    echo "-- Auto-generated PostgreSQL initialization script" > "$init_file"
    echo "-- Generated on $(date)" >> "$init_file"
    echo "" >> "$init_file"
    
    for db in "${databases[@]}"; do
        case "$db" in
            "employees")
                cat >> "$init_file" << 'EOF'

-- Load employees database using standardized init.sql
\i /databases/employees/postgres/init.sql
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

# Function to generate MySQL initialization script (simplified for testing)
generate_mysql_init() {
    local databases=("$@")
    
    mkdir -p init/mysql
    local init_file="init/mysql/01-init-databases.sh"
    
    cat > "$init_file" << 'EOF'
#!/bin/bash
# Test MySQL initialization script

set -e
echo "Starting database initialization..."

# Wait for MySQL to be available
until mysqladmin ping --silent; do
    echo "Waiting for MySQL to be ready..."
    sleep 2
done

echo "MySQL is ready - loading databases..."

# Simple function to process SQL files
process_sql_file() {
    local input_file="$1"
    local output_file="$2"
    local base_dir="$(dirname "$input_file")"
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        if echo "$line" | grep -q "^[[:space:]]*source[[:space:]]"; then
            local source_file=$(echo "$line" | sed 's/^[[:space:]]*source[[:space:]]*//' | sed 's/[[:space:]]*;[[:space:]]*$//' | tr -d ' ')
            local full_source_path="$base_dir/$source_file"
            
            echo "-- Content from: $source_file" >> "$output_file"
            if [ -f "$full_source_path" ]; then
                local temp_file=$(mktemp)
                process_sql_file "$full_source_path" "$temp_file"
                cat "$temp_file" >> "$output_file"
                rm -f "$temp_file"
            else
                echo "-- WARNING: Source file not found: $full_source_path" >> "$output_file"
            fi
            echo "-- End of content from: $source_file" >> "$output_file"
        else
            echo "$line" >> "$output_file"
        fi
    done < "$input_file"
}

EOF

    for db in "${databases[@]}"; do
        case "$db" in
            "employees")
                cat >> "$init_file" << 'EOF'

# Load employees database
echo "Loading employees database..."
processed_file=$(mktemp)
process_sql_file "/databases/employees/mysql/init.sql" "$processed_file"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" < "$processed_file"
rm -f "$processed_file"
echo "✓ Employees database loaded"

EOF
                ;;
        esac
    done
    
    echo 'echo "Database initialization completed!"' >> "$init_file"
    chmod +x "$init_file"
}

# Function to start database environment
start_environment() {
    local engine=$1
    
    print_color $GREEN "Starting ${engine} environment..."
    
    if [ "$engine" = "mysql" ]; then
        docker-compose -f docker-compose.mysql.yml up -d
        print_color $GREEN "✓ MySQL is starting up..."
    elif [ "$engine" = "postgres" ]; then
        docker-compose -f docker-compose.postgres.yml up -d
        print_color $GREEN "✓ PostgreSQL is starting up..."
    fi
    
    print_color $YELLOW "Waiting for database to be ready..."
    sleep 5
    
    if [ "$engine" = "mysql" ]; then
        local attempts=0
        while ! docker exec mysql mysqladmin ping -h localhost -u root -proot --silent 2>/dev/null; do
            if [ $attempts -gt 30 ]; then
                print_color $RED "MySQL failed to start after 60 seconds"
                return 1
            fi
            print_color $YELLOW "  Waiting for MySQL... ($attempts/30)"
            sleep 2
            ((attempts++))
        done
    elif [ "$engine" = "postgres" ]; then
        local attempts=0
        while ! docker exec postgres pg_isready -U postgres -d postgres >/dev/null 2>&1; do
            if [ $attempts -gt 30 ]; then
                print_color $RED "PostgreSQL failed to start after 60 seconds"
                return 1
            fi
            print_color $YELLOW "  Waiting for PostgreSQL... ($attempts/30)"
            sleep 2
            ((attempts++))
        done
    fi
    
    print_color $GREEN "✓ Database is ready!"
}

# Non-interactive main function
main() {
    local engine_choice="${1:-1}"     # Default to MySQL
    local db_choices="${2:-1}"        # Default to employees
    local confirm="${3:-y}"           # Default to yes
    
    print_header "Test Database Setup (Automated)"
    
    print_color $BLUE "This is an automated setup for testing purposes."
    echo
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        print_color $RED "Error: Docker is not running. Please start Docker and try again."
        exit 1
    fi
    
    # Set engine based on choice
    case $engine_choice in
        1)
            ENGINE="mysql"
            ;;
        2)
            ENGINE="postgres"
            ;;
        *)
            print_color $RED "Invalid engine choice: $engine_choice"
            exit 1
            ;;
    esac
    
    print_color $GREEN "✓ Selected: $ENGINE"
    echo
    
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
        print_color $RED "No valid databases selected."
        exit 1
    fi
    
    print_color $GREEN "✓ Selected databases: ${SELECTED_DBS[*]}"
    echo
    
    # Show setup summary
    print_color $CYAN "Setup Summary:"
    print_color $BLUE "  Engine: $ENGINE"
    print_color $BLUE "  Databases: ${SELECTED_DBS[*]}"
    echo
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_color $YELLOW "Setup cancelled (confirm=$confirm)."
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

# Only run main if this script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi