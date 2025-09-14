#!/bin/bash

# Debug script to test setup.sh input handling

echo "=== Testing setup.sh input handling ==="
echo

# Test 1: Check if setup.sh exists and is executable
if [ ! -f "./setup.sh" ]; then
    echo "❌ setup.sh not found"
    exit 1
fi

if [ ! -x "./setup.sh" ]; then
    echo "❌ setup.sh not executable"
    chmod +x ./setup.sh
    echo "✅ Made setup.sh executable"
fi

# Test 2: Test with verbose input
echo "=== Test 2: Running setup with verbose output ==="
echo "Input sequence: MySQL (1) -> Employees DB (1) -> Confirm (y)"
echo

# Clean environment first
docker-compose -f docker-compose.mysql.yml down -v >/dev/null 2>&1
rm -rf init/mysql/* 2>/dev/null

# Helper function for cross-platform timeout
run_with_timeout() {
    local timeout_duration="$1"
    shift
    
    if command -v timeout >/dev/null 2>&1; then
        timeout "$timeout_duration" "$@"
    elif command -v gtimeout >/dev/null 2>&1; then
        gtimeout "$timeout_duration" "$@"
    else
        # Fallback for macOS without coreutils
        "$@" &
        local pid=$!
        (
            sleep "$timeout_duration"
            kill -TERM "$pid" 2>/dev/null
            sleep 5
            kill -KILL "$pid" 2>/dev/null
        ) &
        local timeout_pid=$!
        wait "$pid" 2>/dev/null
        local exit_code=$?
        kill -TERM "$timeout_pid" 2>/dev/null
        return $exit_code
    fi
}

# Test multiple input methods
echo "=== Method 1: Echo with newlines ==="
echo -e "1\n1\ny\n" | run_with_timeout 20 ./setup.sh 2>&1 | head -20

echo
echo "=== Method 2: Here-doc approach ==="
run_with_timeout 20 ./setup.sh 2>&1 <<EOF | head -20
1
1
y
EOF

echo
echo "=== Method 3: Process input ==="
{
    echo "1"  # MySQL
    echo "1"  # Employees database
    echo "y"  # Confirm
} | run_with_timeout 20 ./setup.sh 2>&1 | head -20

echo
echo "=== Checking results ==="

# Check if init script was generated
if [ -f "init/mysql/01-init-databases.sh" ]; then
    echo "✅ MySQL init script generated"
    echo "Script size: $(wc -l < init/mysql/01-init-databases.sh) lines"
    
    # Check for key patterns
    if grep -q "process_sql_file" "init/mysql/01-init-databases.sh"; then
        echo "✅ Contains source processing function"
    else
        echo "❌ Missing source processing function"
    fi
    
    if grep -q "until mysqladmin ping" "init/mysql/01-init-databases.sh"; then
        echo "✅ Contains MySQL readiness check"
    else
        echo "❌ Missing MySQL readiness check"
    fi
else
    echo "❌ MySQL init script NOT generated"
fi

# Check if Docker containers are running
if docker ps | grep -q "test_db_mysql"; then
    echo "✅ MySQL container is running"
    
    # Test connection
    if docker exec test_db_mysql mysqladmin -u root -proot ping >/dev/null 2>&1; then
        echo "✅ MySQL is responding"
        
        # Check if employees database exists
        if docker exec test_db_mysql mysql -u root -proot -e "USE employees; SELECT COUNT(*) FROM employees;" 2>/dev/null | tail -n1 | grep -q '[0-9]'; then
            local count=$(docker exec test_db_mysql mysql -u root -proot -e "USE employees; SELECT COUNT(*) FROM employees;" 2>/dev/null | tail -n1)
            echo "✅ Employees database loaded with $count records"
        else
            echo "❌ Employees database not loaded or accessible"
        fi
    else
        echo "❌ MySQL not responding"
    fi
else
    echo "❌ MySQL container not running"
fi

echo
echo "=== Container logs (last 10 lines) ==="
docker logs test_db_mysql 2>&1 | tail -10 || echo "No container logs available"

echo
echo "=== Cleanup ==="
docker-compose -f docker-compose.mysql.yml down -v >/dev/null 2>&1
echo "✅ Cleaned up test environment"