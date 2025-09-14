# Test Database Project Makefile
# Provides convenient commands for development and testing

.PHONY: help test test-quick test-integration clean setup mysql postgres stop logs

# Default target
help:
	@echo "Test Database Project"
	@echo "Available commands:"
	@echo ""
	@echo "  make setup           - Run interactive setup script"
	@echo "  make mysql          - Quick start MySQL with employees database"
	@echo "  make postgres       - Quick start PostgreSQL with employees database"
	@echo ""
	@echo "  make test           - Run full test suite"
	@echo "  make test-quick     - Run quick tests only"
	@echo "  make test-integration - Run integration tests only"
	@echo ""
	@echo "  make logs           - Show database logs"
	@echo "  make stop           - Stop all running databases"
	@echo "  make clean          - Clean up test environment"
	@echo ""
	@echo "  make validate       - Validate project structure"
	@echo "  make help           - Show this help message"

# Interactive setup
setup:
	@./setup.sh

# Quick start commands
mysql:
	@echo "Starting MySQL with employees database..."
	@echo -e "1\n1\ny" | ./setup.sh

postgres:
	@echo "Starting PostgreSQL with employees database..."
	@echo -e "2\n1\ny" | ./setup.sh

# Test commands
test:
	@echo "Running full test suite..."
	@./test_setup.sh

test-quick:
	@echo "Running quick tests..."
	@./test_setup.sh --quick

test-integration:
	@echo "Running integration tests..."
	@./test_setup.sh 2>/dev/null | grep -E "(PASS|FAIL|TEST:|MySQL Setup|PostgreSQL Setup|Performance)" || true

# Management commands
logs:
	@if docker ps | grep test_db_mysql >/dev/null 2>&1; then \
		echo "MySQL logs:"; \
		docker-compose -f docker-compose.mysql.yml logs --tail=50 mysql; \
	fi
	@if docker ps | grep test_db_postgres >/dev/null 2>&1; then \
		echo "PostgreSQL logs:"; \
		docker-compose -f docker-compose.postgres.yml logs --tail=50 postgres; \
	fi

stop:
	@echo "Stopping all database containers..."
	@docker-compose -f docker-compose.mysql.yml down 2>/dev/null || true
	@docker-compose -f docker-compose.postgres.yml down 2>/dev/null || true
	@echo "All database containers stopped."

clean:
	@echo "Cleaning up test environment..."
	@./test_setup.sh --clean
	@echo "Test environment cleaned."

# Validation commands
validate:
	@echo "Validating project structure..."
	@./test_setup.sh --quick
	@echo ""
	@echo "Validating Docker Compose files..."
	@docker-compose -f docker-compose.mysql.yml config >/dev/null && echo "✓ MySQL compose file is valid"
	@docker-compose -f docker-compose.postgres.yml config >/dev/null && echo "✓ PostgreSQL compose file is valid"
	@echo ""
	@echo "Checking script permissions..."
	@test -x setup.sh && echo "✓ setup.sh is executable" || echo "✗ setup.sh is not executable"
	@test -x test_setup.sh && echo "✓ test_setup.sh is executable" || echo "✗ test_setup.sh is not executable"

# Status command
status:
	@echo "Database Status:"
	@echo "================"
	@if docker ps | grep test_db_mysql >/dev/null 2>&1; then \
		echo "✓ MySQL is running"; \
		echo "  Connection: mysql -h localhost -P 3306 -u root -proot"; \
		echo "  Web UI: http://localhost:8080"; \
	else \
		echo "✗ MySQL is not running"; \
	fi
	@if docker ps | grep test_db_postgres >/dev/null 2>&1; then \
		echo "✓ PostgreSQL is running"; \
		echo "  Connection: psql -h localhost -p 5432 -U postgres -d test_db"; \
		echo "  Web UI: http://localhost:8081"; \
	else \
		echo "✗ PostgreSQL is not running"; \
	fi

# Development commands
dev-mysql:
	@echo "Starting MySQL development environment..."
	@docker-compose -f docker-compose.mysql.yml up -d
	@echo "MySQL started. Use 'make logs' to see startup progress."

dev-postgres:
	@echo "Starting PostgreSQL development environment..."
	@docker-compose -f docker-compose.postgres.yml up -d
	@echo "PostgreSQL started. Use 'make logs' to see startup progress."

# CI/CD helpers
ci-test:
	@echo "Running CI tests..."
	@./test_setup.sh --quick

# Install development dependencies (if needed)
install:
	@echo "Checking dependencies..."
	@command -v docker >/dev/null 2>&1 || (echo "❌ Docker not installed" && exit 1)
	@command -v docker-compose >/dev/null 2>&1 || (echo "❌ Docker Compose not installed" && exit 1)
	@echo "✅ All dependencies are installed"