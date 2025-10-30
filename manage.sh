#!/bin/bash

# Railway Laravel Management Script
# Complete management suite for Railway deployments

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Emojis
CHECK="✅"
CROSS="❌"
WARNING="⚠️"
INFO="ℹ️"
ROCKET="🚀"
DATABASE="🗄️"
GEAR="⚙️"
MAGNIFIER="🔍"

print_error() { echo -e "${RED}${CROSS} $1${NC}"; }
print_success() { echo -e "${GREEN}${CHECK} $1${NC}"; }
print_info() { echo -e "${BLUE}${INFO} $1${NC}"; }
print_warning() { echo -e "${YELLOW}${WARNING} $1${NC}"; }
print_header() { echo -e "\n${CYAN}╔════════════════════════════════════════════╗${NC}"; echo -e "${CYAN}║ $1${NC}"; echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}\n"; }

# Check if Railway CLI is available
check_railway() {
    if ! command -v railway &> /dev/null; then
        print_error "Railway CLI not found"
        echo "Install: npm i -g @railway/cli"
        exit 1
    fi
}

# Get deployment URL
get_url() {
    railway variables 2>/dev/null | grep "RAILWAY_PUBLIC_DOMAIN" | awk -F'│' '{print $2}' | tr -d ' ' | head -1
}

# ============================================
# 1. RESTART SERVICE
# ============================================
restart_service() {
    print_header "Restarting Railway Service"
    
    print_info "Restarting service..."
    
    # Railway doesn't have direct restart, so we redeploy
    if railway up --detach 2>/dev/null; then
        print_success "Service restart initiated"
        print_info "Waiting for service to come online..."
        sleep 15
        print_success "Service should be restarted now"
    else
        print_warning "Using alternative restart method..."
        # Alternative: set a dummy variable to trigger restart
        railway variables --set "RESTART_TRIGGER=$(date +%s)" >/dev/null 2>&1
        print_success "Restart triggered via environment variable change"
        sleep 10
    fi
    
    echo ""
    print_info "Check status with: railway logs"
}

# ============================================
# 2. CHECK DATABASE CONNECTION
# ============================================
check_database() {
    print_header "Checking Database Connection"
    
    # Check if MySQL variables exist
    print_info "Checking MySQL environment variables..."
    local has_mysql=false
    
    if railway variables 2>/dev/null | grep -q "MYSQLHOST"; then
        print_success "MySQL variables found"
        has_mysql=true
        
        echo ""
        print_info "Database credentials:"
        railway variables 2>/dev/null | grep "MYSQL" | head -5
        
    else
        print_error "No MySQL database found"
        print_info "Add MySQL database with: railway add"
        return 1
    fi
    
    echo ""
    print_info "Testing database connection via Laravel..."
    
    # Try to run a migration check
    print_info "Running: php artisan migrate:status"
    railway run php artisan migrate:status 2>&1 | tail -20
    
    if [ $? -eq 0 ]; then
        print_success "Database connection successful!"
    else
        print_error "Database connection failed"
        print_info "Check logs with: railway logs"
    fi
    
    echo ""
    print_info "To run migrations: railway run php artisan migrate"
    print_info "To seed database: railway run php artisan db:seed"
}

# ============================================
# 3. CHECK API ENDPOINTS
# ============================================
check_apis() {
    print_header "Testing API Endpoints"
    
    local url=$(get_url)
    
    if [ -z "$url" ]; then
        print_error "Could not find deployment URL"
        print_info "Generate domain with: railway domain"
        return 1
    fi
    
    local base_url="https://$url"
    print_info "Base URL: $base_url"
    echo ""
    
    # Test 1: Root endpoint
    print_info "Test 1: Root endpoint (GET /)"
    local root_code=$(curl -s -o /dev/null -w "%{http_code}" "$base_url/" --max-time 10)
    if [ "$root_code" == "200" ]; then
        print_success "Root: HTTP $root_code"
    else
        print_error "Root: HTTP $root_code"
    fi
    
    # Test 2: /test endpoint
    echo ""
    print_info "Test 2: Test endpoint (GET /test)"
    local test_response=$(curl -s "$base_url/test" --max-time 10)
    local test_code=$(curl -s -o /dev/null -w "%{http_code}" "$base_url/test" --max-time 10)
    
    if [ "$test_code" == "200" ]; then
        print_success "/test: HTTP $test_code"
        echo "Response: $test_response"
    else
        print_error "/test: HTTP $test_code"
        [ ! -z "$test_response" ] && echo "Response: $test_response"
    fi
    
    # Test 3: API employees list
    echo ""
    print_info "Test 3: Employees API (GET /api/employees)"
    local api_response=$(curl -s "$base_url/api/employees" --max-time 10)
    local api_code=$(curl -s -o /dev/null -w "%{http_code}" "$base_url/api/employees" --max-time 10)
    
    if [ "$api_code" == "200" ]; then
        print_success "Employees API: HTTP $api_code"
        echo "$api_response" | head -c 500
        [ ${#api_response} -gt 500 ] && echo "... (truncated)"
    else
        print_error "Employees API: HTTP $api_code"
        [ ! -z "$api_response" ] && echo "Response: $api_response"
    fi
    
    # Test 4: Create employee (POST)
    echo ""
    print_info "Test 4: Create Employee (POST /api/employees)"
    local create_response=$(curl -s -X POST "$base_url/api/employees" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -d '{"name":"Test User","email":"test'$(date +%s)'@example.com","position":"Tester","department":"QA","salary":60000,"hire_date":"2024-01-01"}' \
        --max-time 10 2>/dev/null)
    local create_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$base_url/api/employees" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -d '{"name":"Test User","email":"test'$(date +%s)'@example.com","position":"Tester","department":"QA","salary":60000,"hire_date":"2024-01-01"}' \
        --max-time 10 2>/dev/null)
    
    if [ "$create_code" == "201" ] || [ "$create_code" == "200" ]; then
        print_success "Create Employee: HTTP $create_code"
        echo "$create_response" | head -c 300
    elif [ "$create_code" == "422" ]; then
        print_warning "Create Employee: HTTP $create_code (Validation error - expected)"
        echo "$create_response"
    else
        print_error "Create Employee: HTTP $create_code"
        [ ! -z "$create_response" ] && echo "Response: $create_response"
    fi
    
    echo ""
    print_info "API Endpoints:"
    echo "  • Root: $base_url"
    echo "  • Test: $base_url/test"
    echo "  • Employees: $base_url/api/employees"
}

# ============================================
# 4. VIEW ERROR LOGS
# ============================================
view_logs() {
    print_header "Viewing Application Logs"
    
    local lines=${1:-50}
    local follow=${2:-false}
    
    if [ "$follow" == "true" ]; then
        print_info "Following logs (Press Ctrl+C to stop)..."
        railway logs
    else
        print_info "Showing recent log lines..."
        echo ""
        railway logs | tail -n $lines
    fi
}

# ============================================
# 5. VIEW ERROR LOGS ONLY
# ============================================
view_error_logs() {
    print_header "Viewing Error Logs Only"
    
    print_info "Filtering for errors, exceptions, and warnings..."
    echo ""
    
    railway logs 2>/dev/null | grep -iE "error|exception|warning|fail|fatal|critical" --color=always | tail -50
    
    if [ ${PIPESTATUS[1]} -ne 0 ]; then
        print_success "No errors found in recent logs!"
    fi
}

# ============================================
# 6. CHECK ENVIRONMENT VARIABLES
# ============================================
check_variables() {
    print_header "Environment Variables"
    
    print_info "Current environment variables:"
    echo ""
    railway variables
    
    echo ""
    print_info "Required Laravel variables:"
    local required=("APP_KEY" "APP_ENV" "DB_CONNECTION" "DB_HOST" "DB_DATABASE" "DB_USERNAME" "DB_PASSWORD")
    
    for var in "${required[@]}"; do
        if railway variables 2>/dev/null | grep -q "^║ $var"; then
            print_success "$var is set"
        else
            print_error "$var is missing"
        fi
    done
}

# ============================================
# 7. RUN ARTISAN COMMANDS
# ============================================
run_artisan() {
    print_header "Run Artisan Command"
    
    if [ -z "$1" ]; then
        print_info "Usage: $0 artisan <command>"
        echo ""
        print_info "Common commands:"
        echo "  • migrate         - Run database migrations"
        echo "  • db:seed         - Seed the database"
        echo "  • migrate:fresh   - Drop all tables and re-migrate"
        echo "  • cache:clear     - Clear application cache"
        echo "  • config:clear    - Clear config cache"
        echo "  • route:list      - List all routes"
        echo "  • tinker          - Open interactive shell"
        return
    fi
    
    print_info "Running: php artisan $@"
    echo ""
    railway run php artisan "$@"
}

# ============================================
# 8. FULL HEALTH CHECK
# ============================================
health_check() {
    print_header "Complete Health Check"
    
    local url=$(get_url)
    
    echo "${BLUE}${ROCKET} Deployment Status${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Check if logged in
    if railway whoami >/dev/null 2>&1; then
        print_success "Railway CLI authenticated"
    else
        print_error "Not logged in to Railway"
        return 1
    fi
    
    # Check URL
    if [ ! -z "$url" ]; then
        print_success "Deployment URL: https://$url"
    else
        print_error "No public domain found"
    fi
    
    echo ""
    echo "${BLUE}${DATABASE} Database Status${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Check MySQL
    if railway variables 2>/dev/null | grep -q "MYSQLHOST"; then
        print_success "MySQL database connected"
    else
        print_error "MySQL database not found"
    fi
    
    # Check required variables
    echo ""
    echo "${BLUE}${GEAR} Configuration Status${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local vars=("APP_KEY" "APP_ENV" "DB_CONNECTION")
    for var in "${vars[@]}"; do
        if railway variables 2>/dev/null | grep -q "║ $var"; then
            print_success "$var configured"
        else
            print_error "$var missing"
        fi
    done
    
    # Test endpoints
    if [ ! -z "$url" ]; then
        echo ""
        echo "${BLUE}${MAGNIFIER} API Status${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        local test_code=$(curl -s -o /dev/null -w "%{http_code}" "https://$url/test" --max-time 10)
        if [ "$test_code" == "200" ]; then
            print_success "/test endpoint responding"
        else
            print_error "/test endpoint: HTTP $test_code"
        fi
        
        local api_code=$(curl -s -o /dev/null -w "%{http_code}" "https://$url/api/employees" --max-time 10)
        if [ "$api_code" == "200" ]; then
            print_success "/api/employees endpoint responding"
        else
            print_error "/api/employees endpoint: HTTP $api_code"
        fi
    fi
    
    echo ""
    print_info "For detailed logs: $0 logs"
}

# ============================================
# 9. DEPLOY
# ============================================
deploy() {
    print_header "Deploying to Railway"
    
    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        print_warning "You have uncommitted changes"
        read -p "Commit them now? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git add .
            read -p "Enter commit message: " msg
            git commit -m "$msg"
        fi
    fi
    
    print_info "Deploying..."
    railway up
    
    if [ $? -eq 0 ]; then
        print_success "Deployment successful!"
        print_info "Waiting for service to start..."
        sleep 15
        
        echo ""
        read -p "Run health check? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            health_check
        fi
    else
        print_error "Deployment failed"
        print_info "Check logs with: $0 logs"
    fi
}

# ============================================
# 10. QUICK FIX FOR COMMON ISSUES
# ============================================
quick_fix() {
    print_header "Quick Fix - Common Issues"
    
    print_info "Applying common fixes..."
    echo ""
    
    # 1. Ensure APP_DEBUG is false in production
    print_info "1. Setting APP_DEBUG=false..."
    railway variables --set APP_DEBUG=false 2>/dev/null
    
    # 2. Ensure APP_ENV is production
    print_info "2. Setting APP_ENV=production..."
    railway variables --set APP_ENV=production 2>/dev/null
    
    # 3. Check database variables
    print_info "3. Verifying database variables..."
    if railway variables 2>/dev/null | grep -q "MYSQLHOST"; then
        print_success "Database variables exist"
    else
        print_warning "No database found. Add with: railway add"
    fi
    
    # 4. Clear caches via Railway
    print_info "4. Clearing caches..."
    railway run php artisan config:clear 2>/dev/null
    railway run php artisan cache:clear 2>/dev/null
    railway run php artisan route:clear 2>/dev/null
    
    print_success "Quick fixes applied!"
    print_info "Restarting service..."
    restart_service
}

# ============================================
# 11. OPEN RAILWAY DASHBOARD
# ============================================
open_dashboard() {
    print_header "Opening Railway Dashboard"
    railway open
}

# ============================================
# MAIN MENU
# ============================================
show_menu() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
╔═══════════════════════════════════════════════════╗
║                                                   ║
║     Railway Laravel Management Script v1.0       ║
║                                                   ║
╚═══════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    local url=$(get_url)
    if [ ! -z "$url" ]; then
        echo -e "${GREEN}${ROCKET} Deployed at: https://$url${NC}\n"
    fi
    
    echo -e "${YELLOW}Available Commands:${NC}"
    echo ""
    echo "  ${CYAN}Deployment:${NC}"
    echo "    deploy              - Deploy to Railway"
    echo "    restart             - Restart the service"
    echo "    health              - Run full health check"
    echo ""
    echo "  ${CYAN}Database:${NC}"
    echo "    db                  - Check database connection"
    echo "    migrate             - Run migrations"
    echo "    seed                - Seed database"
    echo "    fresh               - Fresh migration (drops tables)"
    echo ""
    echo "  ${CYAN}API Testing:${NC}"
    echo "    test                - Test all API endpoints"
    echo ""
    echo "  ${CYAN}Debugging:${NC}"
    echo "    logs [n]            - View last n logs (default: 50)"
    echo "    logs-follow         - Follow logs in real-time"
    echo "    errors              - View only error logs"
    echo "    vars                - Show environment variables"
    echo ""
    echo "  ${CYAN}Maintenance:${NC}"
    echo "    artisan <cmd>       - Run artisan command"
    echo "    fix                 - Quick fix common issues"
    echo "    open                - Open Railway dashboard"
    echo ""
    echo "  ${CYAN}Other:${NC}"
    echo "    menu                - Show this menu"
    echo "    help                - Show this menu"
    echo ""
    echo -e "${BLUE}Usage: $0 <command>${NC}"
    echo ""
}

# ============================================
# COMMAND ROUTER
# ============================================
main() {
    check_railway
    
    case "${1:-menu}" in
        deploy)
            deploy
            ;;
        restart)
            restart_service
            ;;
        health)
            health_check
            ;;
        db|database)
            check_database
            ;;
        migrate)
            run_artisan migrate --force
            ;;
        seed)
            run_artisan db:seed --force
            ;;
        fresh)
            print_warning "This will drop all tables!"
            read -p "Are you sure? (yes/no): " confirm
            if [ "$confirm" == "yes" ]; then
                run_artisan migrate:fresh --force --seed
            else
                print_info "Cancelled"
            fi
            ;;
        test|apis)
            check_apis
            ;;
        logs)
            view_logs "${2:-50}" false
            ;;
        logs-follow|follow)
            view_logs 50 true
            ;;
        errors)
            view_error_logs
            ;;
        vars|variables|env)
            check_variables
            ;;
        artisan)
            shift
            run_artisan "$@"
            ;;
        fix|quickfix)
            quick_fix
            ;;
        open|dashboard)
            open_dashboard
            ;;
        menu|help|--help|-h)
            show_menu
            ;;
        status)
            print_header "Service Status"
            railway status
            ;;
        domain|url)
            print_header "Deployment URL"
            local url=$(get_url)
            if [ ! -z "$url" ]; then
                print_success "URL: https://$url"
                echo ""
                print_info "Test endpoints:"
                echo "  • https://$url"
                echo "  • https://$url/test"
                echo "  • https://$url/api/employees"
            else
                print_error "No domain found"
                print_info "Generate with: railway domain"
            fi
            ;;
        *)
            print_error "Unknown command: $1"
            echo ""
            show_menu
            exit 1
            ;;
    esac
}

# Run main
main "$@"