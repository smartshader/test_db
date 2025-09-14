#!/bin/bash

# Test Database Setup Script - Unit Testing Framework
# Comprehensive tests for setup.sh functionality

set -e

# Test configuration
TEST_DIR="$(dirname "$0")"
SETUP_SCRIPT="$TEST_DIR/setup.sh"
TEST_RESULTS_FILE="/tmp/test_db_results.log"
FAILED_TESTS=0
TOTAL_TESTS=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to print test header
print_test_header() {
    echo
    print_color $CYAN "=========================================="
    print_color $CYAN "TEST: $1"
    print_color $CYAN "=========================================="
    echo
}

# Function to log test results
log_test_result() {
    local test_name="$1"
    local result="$2"
    local message="$3"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [ "$result" = "PASS" ]; then
        print_color $GREEN "✓ PASS: $test_name"
        echo "PASS: $test_name - $message" >> "$TEST_RESULTS_FILE"
    else
        print_color $RED "✗ FAIL: $test_name"
        echo "FAIL: $test_name - $message" >> "$TEST_RESULTS_FILE"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    
    if [ -n "$message" ]; then
        echo "  $message"
    fi
}

# Function to cleanup test environment
cleanup_test_env() {
    print_color $YELLOW "Cleaning up test environment..."
    
    # Stop and remove containers
    docker-compose -f docker-compose.mysql.yml down -v 2>/dev/null || true
    docker-compose -f docker-compose.postgres.yml down -v 2>/dev/null || true
    
    # Clean init directories
    rm -rf init/mysql/* init/postgres/* 2>/dev/null || true
    
    # Remove any dangling containers
    docker container prune -f 2>/dev/null || true
    docker volume prune -f 2>/dev/null || true
    
    sleep 2
}

# Test 1: Verify setup script exists and is executable
test_setup_script_exists() {
    print_test_header "Setup Script Existence and Permissions"
    
    if [ -f "$SETUP_SCRIPT" ]; then
        if [ -x "$SETUP_SCRIPT" ]; then
            log_test_result "setup_script_executable" "PASS" "Setup script exists and is executable"
        else
            log_test_result "setup_script_executable" "FAIL" "Setup script exists but is not executable"
        fi
    else
        log_test_result "setup_script_exists" "FAIL" "Setup script does not exist"
    fi
}

# Test 2: Verify Docker is available
test_docker_available() {
    print_test_header "Docker Availability"
    
    if command -v docker >/dev/null 2>&1; then
        if docker info >/dev/null 2>&1; then
            log_test_result "docker_running" "PASS" "Docker is installed and running"
        else
            log_test_result "docker_running" "FAIL" "Docker is installed but not running"
        fi
    else
        log_test_result "docker_installed" "FAIL" "Docker is not installed"
    fi
}

# Test 3: Verify directory structure
test_directory_structure() {
    print_test_header "Directory Structure"
    
    local required_dirs=(
        "databases"
        "databases/employees"
        "databases/employees/mysql"
        "databases/employees/postgres"
        "databases/sakila"
        "init"
        "init/mysql"
        "init/postgres"
    )
    
    local missing_dirs=()
    
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            missing_dirs+=("$dir")
        fi
    done
    
    if [ ${#missing_dirs[@]} -eq 0 ]; then
        log_test_result "directory_structure" "PASS" "All required directories exist"
    else
        log_test_result "directory_structure" "FAIL" "Missing directories: ${missing_dirs[*]}"
    fi
}

# Test 4: Verify required database files exist
test_database_files() {
    print_test_header "Database Files Existence"
    
    local required_files=(
        "databases/employees/mysql/employees.sql"
        "databases/employees/mysql/load_departments.dump"
        "databases/employees/mysql/load_employees.dump"
        "databases/employees/postgres/employees_postgres.sql"
        "databases/sakila/sakila-mv-schema.sql"
        "databases/sakila/sakila-mv-data.sql"
    )
    
    local missing_files=()
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            missing_files+=("$file")
        fi
    done
    
    if [ ${#missing_files[@]} -eq 0 ]; then
        log_test_result "database_files" "PASS" "All required database files exist"
    else
        log_test_result "database_files" "FAIL" "Missing files: ${missing_files[*]}"
    fi
}

# Test 5: Verify Docker Compose files
test_docker_compose_files() {
    print_test_header "Docker Compose Files"
    
    local compose_files=(
        "docker-compose.mysql.yml"
        "docker-compose.postgres.yml"
    )
    
    local missing_files=()
    
    for file in "${compose_files[@]}"; do
        if [ ! -f "$file" ]; then
            missing_files+=("$file")
        else
            # Test if the compose file is valid
            if ! docker-compose -f "$file" config >/dev/null 2>&1; then
                missing_files+=("$file (invalid syntax)")
            fi
        fi
    done
    
    if [ ${#missing_files[@]} -eq 0 ]; then
        log_test_result "docker_compose_files" "PASS" "All Docker Compose files exist and are valid"
    else
        log_test_result "docker_compose_files" "FAIL" "Issues with files: ${missing_files[*]}"
    fi
}

# Test 6: Test MySQL container health
test_mysql_container_health() {
    print_test_header "MySQL Container Health Test"
    
    cleanup_test_env
    
    # Start MySQL environment without full setup
    if docker-compose -f docker-compose.mysql.yml up -d >/dev/null 2>&1; then
        sleep 30  # Wait longer for initialization
        
        # Check if container is running and not restarting
        local container_status=$(docker inspect test_db_mysql --format='{{.State.Status}}' 2>/dev/null || echo "not_found")
        local restart_count=$(docker inspect test_db_mysql --format='{{.RestartCount}}' 2>/dev/null || echo "999")
        
        if [ "$container_status" = "running" ] && [ "$restart_count" -lt 3 ]; then
            # Check for error patterns in logs
            local error_logs=$(docker logs test_db_mysql 2>&1 | grep -i "error\|fail\|abort" | wc -l)
            
            if [ "$error_logs" -gt 5 ]; then
                local sample_errors=$(docker logs test_db_mysql 2>&1 | grep -i "error" | tail -3)
                log_test_result "mysql_container_health" "FAIL" "Container has $error_logs errors. Sample: $sample_errors"
            else
                log_test_result "mysql_container_health" "PASS" "Container is healthy (status: $container_status, restarts: $restart_count)"
            fi
        else
            local logs=$(docker logs test_db_mysql 2>&1 | tail -5)
            log_test_result "mysql_container_health" "FAIL" "Container unhealthy (status: $container_status, restarts: $restart_count). Logs: $logs"
        fi
    else
        log_test_result "mysql_container_health" "FAIL" "Failed to start MySQL container"
    fi
    
    cleanup_test_env
}

# Test 7: Test MySQL environment setup (automated)
test_mysql_setup() {
    print_test_header "MySQL Setup Test"
    
    cleanup_test_env
    
    # Create test input for the setup script
    local test_input="1\n1\ny\n"  # MySQL, employees database, confirm
    
    print_color $YELLOW "Running automated MySQL setup test..."
    
    # Run setup script with test input
    if echo -e "$test_input" | timeout 300 "$SETUP_SCRIPT" >/dev/null 2>&1; then
        sleep 15  # Wait for database to be fully ready
        
        # First check container health
        local container_status=$(docker inspect test_db_mysql --format='{{.State.Status}}' 2>/dev/null || echo "not_found")
        local restart_count=$(docker inspect test_db_mysql --format='{{.RestartCount}}' 2>/dev/null || echo "999")
        
        if [ "$container_status" != "running" ] || [ "$restart_count" -gt 2 ]; then
            log_test_result "mysql_setup" "FAIL" "MySQL container unhealthy (status: $container_status, restarts: $restart_count)"
        else
            # Test database connection
            if docker exec test_db_mysql mysql -u root -proot -e "SHOW DATABASES;" >/dev/null 2>&1; then
                # Check if employees database exists
                if docker exec test_db_mysql mysql -u root -proot -e "USE employees; SHOW TABLES;" >/dev/null 2>&1; then
                    # Check if data was loaded
                    local employee_count=$(docker exec test_db_mysql mysql -u root -proot -e "USE employees; SELECT COUNT(*) FROM employees;" 2>/dev/null | tail -n1)
                    
                    if [ "$employee_count" -gt 100000 ]; then
                        log_test_result "mysql_setup" "PASS" "MySQL setup completed successfully with $employee_count employees"
                    else
                        log_test_result "mysql_setup" "FAIL" "MySQL setup completed but data not loaded correctly (only $employee_count employees)"
                    fi
                else
                    log_test_result "mysql_setup" "FAIL" "MySQL setup completed but employees database not created"
                fi
            else
                log_test_result "mysql_setup" "FAIL" "MySQL setup completed but database connection failed"
            fi
        fi
    else
        log_test_result "mysql_setup" "FAIL" "Setup script failed to complete"
    fi
    
    cleanup_test_env
}

# Test 7: Test PostgreSQL environment setup (automated)
test_postgres_setup() {
    print_test_header "PostgreSQL Setup Test"
    
    cleanup_test_env
    
    # Create test input for the setup script
    local test_input="2\n1\ny\n"  # PostgreSQL, employees database, confirm
    
    print_color $YELLOW "Running automated PostgreSQL setup test..."
    
    # Run setup script with test input
    if echo -e "$test_input" | timeout 300 "$SETUP_SCRIPT" >/dev/null 2>&1; then
        sleep 15  # Wait for database to be fully ready (PostgreSQL takes longer)
        
        # Test database connection
        if docker exec test_db_postgres psql -U postgres -d test_db -c "\\l" >/dev/null 2>&1; then
            # Check if employees tables exist
            if docker exec test_db_postgres psql -U postgres -d test_db -c "\\dt" >/dev/null 2>&1; then
                # Check if data was loaded
                local employee_count=$(docker exec test_db_postgres psql -U postgres -d test_db -t -c "SELECT COUNT(*) FROM employees;" 2>/dev/null | xargs)
                
                if [ "$employee_count" -gt 100000 ]; then
                    log_test_result "postgres_setup" "PASS" "PostgreSQL setup completed successfully with $employee_count employees"
                else
                    log_test_result "postgres_setup" "FAIL" "PostgreSQL setup completed but data not loaded correctly (only $employee_count employees)"
                fi
            else
                log_test_result "postgres_setup" "FAIL" "PostgreSQL setup completed but employees tables not created"
            fi
        else
            log_test_result "postgres_setup" "FAIL" "PostgreSQL setup completed but database connection failed"
        fi
    else
        log_test_result "postgres_setup" "FAIL" "Setup script failed to complete"
    fi
    
    cleanup_test_env
}

# Test 8: Test cleanup functionality
test_cleanup_functionality() {
    print_test_header "Cleanup Functionality Test"
    
    # Start a simple MySQL environment
    if docker-compose -f docker-compose.mysql.yml up -d >/dev/null 2>&1; then
        sleep 5
        
        # Verify container is running
        if docker ps | grep test_db_mysql >/dev/null; then
            # Test cleanup
            if docker-compose -f docker-compose.mysql.yml down -v >/dev/null 2>&1; then
                sleep 2
                
                # Verify container is stopped
                if ! docker ps | grep test_db_mysql >/dev/null; then
                    log_test_result "cleanup_functionality" "PASS" "Cleanup successfully stopped and removed containers"
                else
                    log_test_result "cleanup_functionality" "FAIL" "Cleanup did not properly stop containers"
                fi
            else
                log_test_result "cleanup_functionality" "FAIL" "Cleanup command failed"
            fi
        else
            log_test_result "cleanup_functionality" "FAIL" "Could not start test container for cleanup test"
        fi
    else
        log_test_result "cleanup_functionality" "FAIL" "Could not start Docker Compose for cleanup test"
    fi
}

# Test 9: Test initialization script generation and validation
test_init_script_generation() {
    print_test_header "Initialization Script Generation"
    
    cleanup_test_env
    
    # Test MySQL init script generation
    local test_input="1\n1\ny\n"  # MySQL, employees database, confirm
    
    if echo -e "$test_input" | timeout 60 "$SETUP_SCRIPT" >/dev/null 2>&1; then
        if [ -f "init/mysql/01-init-databases.sh" ]; then
            if [ -x "init/mysql/01-init-databases.sh" ]; then
                # Check for proper patterns in init script
                if ! grep -q "until mysqladmin ping" "init/mysql/01-init-databases.sh"; then
                    log_test_result "mysql_init_script" "FAIL" "MySQL initialization script missing wait-for-ready check (will cause connection errors)"
                elif grep -q "mysql -u root" "init/mysql/01-init-databases.sh" && ! grep -q "until mysqladmin ping" "init/mysql/01-init-databases.sh"; then
                    log_test_result "mysql_init_script" "FAIL" "MySQL initialization script tries to connect without waiting for MySQL to be ready"
                else
                    log_test_result "mysql_init_script" "PASS" "MySQL initialization script generated and valid"
                fi
            else
                log_test_result "mysql_init_script" "FAIL" "MySQL initialization script generated but not executable"
            fi
        else
            log_test_result "mysql_init_script" "FAIL" "MySQL initialization script not generated"
        fi
    else
        log_test_result "mysql_init_script" "FAIL" "Setup failed during init script generation test"
    fi
    
    cleanup_test_env
}

# Test 10: Performance test (quick database startup)
test_performance() {
    print_test_header "Performance Test"
    
    cleanup_test_env
    
    local test_input="1\n1\ny\n"  # MySQL, employees database, confirm
    
    print_color $YELLOW "Testing setup performance (should complete in <5 minutes)..."
    local start_time=$(date +%s)
    
    if timeout 300 bash -c "echo -e '$test_input' | '$SETUP_SCRIPT' >/dev/null 2>&1"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        if [ $duration -lt 300 ]; then  # Less than 5 minutes
            log_test_result "performance" "PASS" "Setup completed in ${duration} seconds"
        else
            log_test_result "performance" "FAIL" "Setup took too long: ${duration} seconds"
        fi
    else
        log_test_result "performance" "FAIL" "Setup timed out after 300 seconds"
    fi
    
    cleanup_test_env
}

# Main test runner
run_all_tests() {
    print_color $CYAN "========================================"
    print_color $CYAN "Test Database Setup - Test Suite"
    print_color $CYAN "========================================"
    echo
    
    # Initialize test results file
    echo "Test Database Setup - Test Results" > "$TEST_RESULTS_FILE"
    echo "Started: $(date)" >> "$TEST_RESULTS_FILE"
    echo "----------------------------------------" >> "$TEST_RESULTS_FILE"
    
    # Run all tests
    test_setup_script_exists
    test_docker_available
    test_directory_structure
    test_database_files
    test_docker_compose_files
    test_init_script_generation
    test_cleanup_functionality
    
    # Skip database setup tests if Docker is not available
    if docker info >/dev/null 2>&1; then
        print_color $YELLOW "Running integration tests (this may take several minutes)..."
        test_mysql_container_health
        test_mysql_setup
        test_postgres_setup
        test_performance
    else
        print_color $YELLOW "Skipping integration tests (Docker not available)"
        TOTAL_TESTS=$((TOTAL_TESTS + 4))  # Account for skipped tests
    fi
    
    # Final cleanup
    cleanup_test_env
    
    # Print summary
    echo
    print_color $CYAN "========================================"
    print_color $CYAN "TEST SUMMARY"
    print_color $CYAN "========================================"
    
    local passed_tests=$((TOTAL_TESTS - FAILED_TESTS))
    
    print_color $GREEN "Passed: $passed_tests"
    print_color $RED "Failed: $FAILED_TESTS"
    print_color $BLUE "Total:  $TOTAL_TESTS"
    
    echo
    echo "Detailed results saved to: $TEST_RESULTS_FILE"
    
    if [ $FAILED_TESTS -eq 0 ]; then
        print_color $GREEN "🎉 All tests passed!"
        exit 0
    else
        print_color $RED "❌ Some tests failed!"
        exit 1
    fi
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --quick, -q    Run only quick tests (skip integration tests)"
        echo "  --clean, -c    Clean test environment and exit"
        echo ""
        echo "This script runs comprehensive tests for the setup.sh script."
        exit 0
        ;;
    --quick|-q)
        print_color $YELLOW "Running quick tests only..."
        test_setup_script_exists
        test_docker_available
        test_directory_structure
        test_database_files
        test_docker_compose_files
        ;;
    --clean|-c)
        print_color $YELLOW "Cleaning test environment..."
        cleanup_test_env
        print_color $GREEN "Test environment cleaned"
        exit 0
        ;;
    *)
        run_all_tests
        ;;
esac