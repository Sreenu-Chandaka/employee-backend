#!/bin/bash

# Railway Laravel Project Deployment Script
# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_error() {
    echo -e "${RED}❌ ERROR: $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  WARNING: $1${NC}"
}

print_step() {
    echo -e "\n${BLUE}==>${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    print_step "Checking prerequisites..."
    
    local missing_deps=()
    
    if ! command_exists git; then
        missing_deps+=("git")
    fi
    
    if ! command_exists railway; then
        missing_deps+=("railway CLI")
    fi
    
    if ! command_exists php; then
        missing_deps+=("php")
    fi
    
    if ! command_exists composer; then
        missing_deps+=("composer")
    fi
    
    if ! command_exists curl; then
        missing_deps+=("curl")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        echo ""
        print_info "Install missing dependencies:"
        
        for dep in "${missing_deps[@]}"; do
            case $dep in
                git)
                    echo "  • Git: https://git-scm.com/downloads"
                    ;;
                "railway CLI")
                    echo "  • Railway CLI:"
                    echo "    npm i -g @railway/cli"
                    echo "    OR"
                    echo "    curl -fsSL https://railway.app/install.sh | sh"
                    ;;
                php)
                    echo "  • PHP: https://www.php.net/downloads"
                    echo "    OR brew install php (on macOS)"
                    ;;
                composer)
                    echo "  • Composer: https://getcomposer.org/download/"
                    ;;
                curl)
                    echo "  • cURL: Usually pre-installed, or brew install curl"
                    ;;
            esac
        done
        
        return 1
    fi
    
    print_success "All prerequisites are installed"
    return 0
}

# Check if Railway is logged in
check_railway_auth() {
    print_step "Checking Railway authentication..."
    
    if ! railway whoami >/dev/null 2>&1; then
        print_error "Not logged in to Railway"
        print_info "Please login to Railway by running:"
        echo "  railway login"
        return 1
    fi
    
    local user=$(railway whoami 2>/dev/null)
    print_success "Logged in as: $user"
    return 0
}

# Check if this is a Laravel project
check_laravel_project() {
    print_step "Checking Laravel project..."
    
    if [ ! -f "artisan" ] || [ ! -f "composer.json" ]; then
        print_error "This doesn't appear to be a Laravel project"
        print_info "Make sure you're in the Laravel project root directory"
        return 1
    fi
    
    if ! grep -q "laravel/framework" composer.json 2>/dev/null; then
        print_error "composer.json doesn't contain laravel/framework"
        return 1
    fi
    
    print_success "Laravel project detected"
    return 0
}

# Check if we're in a git repository
check_git_repo() {
    print_step "Checking Git repository..."
    
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        print_error "Not a git repository"
        print_info "Initialize git repository with:"
        echo "  git init"
        echo "  git add ."
        echo "  git commit -m 'Initial commit'"
        return 1
    fi
    
    # Check if there are uncommitted changes
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        print_warning "You have uncommitted changes"
        read -p "Do you want to commit them now? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git add .
            read -p "Enter commit message: " commit_msg
            git commit -m "$commit_msg"
            print_success "Changes committed"
        else
            print_info "Continuing with uncommitted changes..."
        fi
    fi
    
    print_success "Git repository OK"
    return 0
}

# Create Procfile for Laravel
create_procfile() {
    print_step "Setting up Procfile..."
    
    cat > Procfile << 'EOF'
web: chmod -R 775 storage bootstrap/cache && php artisan config:cache && php artisan route:cache && php artisan view:cache && php artisan migrate --force && php -S 0.0.0.0:$PORT -t public
EOF
    print_success "Procfile created/updated"
}

# Create nixpacks.toml for Laravel
create_nixpacks_config() {
    print_step "Setting up Nixpacks configuration..."
    
    cat > nixpacks.toml << 'EOF'
[phases.setup]
nixPkgs = ["php82", "php82Extensions.pdo", "php82Extensions.pdo_mysql", "php82Extensions.mysqli", "php82Extensions.mbstring", "php82Extensions.xml", "php82Extensions.curl", "php82Extensions.zip", "php82Extensions.bcmath", "php82Extensions.tokenizer", "nodejs"]

[phases.install]
cmds = ["composer install --no-dev --optimize-autoloader --no-interaction"]

[phases.build]
cmds = [
    "php artisan config:clear",
    "php artisan cache:clear"
]

[start]
cmd = "chmod -R 775 storage bootstrap/cache && php artisan config:cache && php artisan route:cache && php artisan view:cache && php artisan migrate --force && php -S 0.0.0.0:$PORT -t public"
EOF
    print_success "nixpacks.toml created/updated"
}

# Update .gitignore
update_gitignore() {
    print_step "Updating .gitignore..."
    
    if [ -f ".gitignore" ]; then
        # Add Railway-specific ignores if not present
        if ! grep -q ".railway" .gitignore 2>/dev/null; then
            echo -e "\n# Railway" >> .gitignore
            echo ".railway/" >> .gitignore
        fi
        print_success ".gitignore updated"
    else
        print_warning ".gitignore not found"
    fi
}

# Check environment configuration
check_env_config() {
    print_step "Checking environment configuration..."
    
    if [ ! -f ".env" ]; then
        if [ -f ".env.example" ]; then
            print_warning ".env file not found"
            print_info "Copy .env.example to .env and configure it"
            read -p "Create .env from .env.example now? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                cp .env.example .env
                print_success ".env created from .env.example"
                print_warning "You still need to configure .env with your settings"
            fi
        else
            print_error ".env and .env.example not found"
            return 1
        fi
    else
        print_success ".env file exists"
    fi
    
    # Check if APP_KEY is set
    if [ -f ".env" ] && ! grep -q "^APP_KEY=base64:" .env 2>/dev/null; then
        print_warning "APP_KEY not set in .env"
        print_info "Generating APP_KEY..."
        php artisan key:generate
        print_success "APP_KEY generated"
    fi
}

# Create railway.json
create_railway_json() {
    print_step "Setting up railway.json..."
    
    cat > railway.json << 'EOF'
{
  "$schema": "https://railway.app/railway.schema.json",
  "build": {
    "builder": "NIXPACKS"
  },
  "deploy": {
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 10
  }
}
EOF
    print_success "railway.json created/updated"
}

# Initialize or link Railway project
setup_railway_project() {
    print_step "Setting up Railway project..."
    
    if [ ! -f "railway.toml" ] && [ ! -d ".railway" ]; then
        print_info "No Railway project found."
        echo ""
        echo "Choose an option:"
        echo "  1) Link to existing Railway project"
        echo "  2) Create new Railway project"
        read -p "Enter choice (1 or 2): " -n 1 -r
        echo
        
        if [[ $REPLY == "1" ]]; then
            railway link
            if [ $? -ne 0 ]; then
                print_error "Failed to link Railway project"
                return 1
            fi
        else
            read -p "Enter project name (or press Enter for auto-generated): " project_name
            
            if [ -z "$project_name" ]; then
                railway init
            else
                railway init --name "$project_name"
            fi
            
            if [ $? -ne 0 ]; then
                print_error "Failed to initialize Railway project"
                print_info "Try: railway link (to link to existing project)"
                return 1
            fi
        fi
        
        print_success "Railway project configured"
    else
        print_success "Railway project already configured"
    fi
    
    return 0
}

# Add MySQL database
add_database() {
    print_step "Setting up MySQL database..."
    
    print_info "Adding MySQL database to your Railway project..."
    railway add --plugin mysql
    
    if [ $? -ne 0 ]; then
        print_warning "Database might already exist or failed to add"
        print_info "You can manually add MySQL from Railway dashboard"
    else
        print_success "MySQL database added"
        print_info "Waiting 5 seconds for database to initialize..."
        sleep 5
    fi
}

# Set Railway environment variables
set_railway_variables() {
    print_step "Setting Railway environment variables..."
    
    print_info "Setting Laravel environment variables..."
    
    # Generate APP_KEY locally to set it
    if [ -f ".env" ]; then
        local app_key=$(grep "^APP_KEY=" .env | cut -d '=' -f2)
        if [ ! -z "$app_key" ]; then
            railway variables --set "APP_KEY=$app_key" 2>/dev/null
            print_success "APP_KEY set in Railway"
        fi
    fi
    
    # Set basic Laravel variables
    railway variables --set "APP_ENV=production" 2>/dev/null
    railway variables --set "APP_DEBUG=false" 2>/dev/null
    railway variables --set "LOG_CHANNEL=stderr" 2>/dev/null
    railway variables --set "DB_CONNECTION=mysql" 2>/dev/null
    
    # Set database variables using Railway's MySQL service variables
    railway variables --set 'DB_HOST=${MYSQLHOST}' 2>/dev/null
    railway variables --set 'DB_PORT=${MYSQLPORT}' 2>/dev/null
    railway variables --set 'DB_DATABASE=${MYSQLDATABASE}' 2>/dev/null
    railway variables --set 'DB_USERNAME=${MYSQLUSER}' 2>/dev/null
    railway variables --set 'DB_PASSWORD=${MYSQLPASSWORD}' 2>/dev/null
    
    print_success "Environment variables configured"
}

# Deploy to Railway
deploy_project() {
    print_step "Deploying to Railway..."
    
    print_info "Starting deployment..."
    railway up
    
    if [ $? -ne 0 ]; then
        print_error "Deployment failed"
        print_info "Check the error messages above for details"
        return 1
    fi
    
    print_success "Deployment successful!"
    print_info "Waiting 10 seconds for service to start..."
    sleep 10
    return 0
}

# Get deployment URL
get_deployment_url() {
    print_step "Retrieving deployment URL..."
    
    local url=$(railway domain 2>/dev/null | grep -oE '[a-z0-9-]+\.up\.railway\.app' | head -1)
    
    if [ -z "$url" ]; then
        print_info "No domain configured yet. Generating domain..."
        railway domain
        sleep 2
        url=$(railway domain 2>/dev/null | grep -oE '[a-z0-9-]+\.up\.railway\.app' | head -1)
    fi
    
    if [ ! -z "$url" ]; then
        echo "$url"
    else
        echo ""
    fi
}

# Test API endpoints
test_apis() {
    local base_url=$1
    
    print_step "Testing API Endpoints..."
    
    if [ -z "$base_url" ]; then
        print_error "No deployment URL found. Cannot test APIs."
        return 1
    fi
    
    echo ""
    print_info "Base URL: https://$base_url"
    echo ""
    
    # Test 1: Root endpoint
    print_info "Test 1: Testing root endpoint (GET /)"
    local response=$(curl -s -o /dev/null -w "%{http_code}" "https://$base_url/" --max-time 10)
    if [ "$response" == "200" ]; then
        print_success "Root endpoint: ✓ (HTTP $response)"
    else
        print_warning "Root endpoint: HTTP $response"
    fi
    echo ""
    
    # Test 2: /test endpoint
    print_info "Test 2: Testing /test endpoint (GET /test)"
    local test_response=$(curl -s "https://$base_url/test" --max-time 10)
    local test_code=$(curl -s -o /dev/null -w "%{http_code}" "https://$base_url/test" --max-time 10)
    
    if [ "$test_code" == "200" ]; then
        print_success "/test endpoint: ✓ (HTTP $test_code)"
        echo "Response: $test_response"
    else
        print_error "/test endpoint: ✗ (HTTP $test_code)"
        if [ "$test_code" == "500" ]; then
            print_info "500 Error detected. Check logs with: railway logs"
        fi
    fi
    echo ""
    
    # Test 3: API employees list
    print_info "Test 3: Testing employees API (GET /api/employees)"
    local api_response=$(curl -s -w "\n%{http_code}" "https://$base_url/api/employees" --max-time 10)
    local api_body=$(echo "$api_response" | head -n -1)
    local api_code=$(echo "$api_response" | tail -n 1)
    
    if [ "$api_code" == "200" ]; then
        print_success "Employees API: ✓ (HTTP $api_code)"
        echo "Response: $api_body" | head -c 500
        if [ ${#api_body} -gt 500 ]; then
            echo "... (truncated)"
        fi
    else
        print_error "Employees API: ✗ (HTTP $api_code)"
        if [ "$api_code" == "500" ]; then
            print_info "Database connection might be failing"
        fi
    fi
    echo ""
    
    # Test 4: Check database connectivity (if test endpoint works)
    if [ "$test_code" == "200" ]; then
        print_info "Test 4: Checking database connectivity"
        
        # Try to create a test employee (POST)
        local create_response=$(curl -s -w "\n%{http_code}" -X POST "https://$base_url/api/employees" \
            -H "Content-Type: application/json" \
            -H "Accept: application/json" \
            -d '{"name":"Test Employee","email":"test@example.com","position":"Tester"}' \
            --max-time 10 2>/dev/null)
        
        local create_code=$(echo "$create_response" | tail -n 1)
        
        if [ "$create_code" == "201" ] || [ "$create_code" == "200" ]; then
            print_success "Database connectivity: ✓ (Employee created)"
        elif [ "$create_code" == "422" ]; then
            print_warning "Database seems OK, but validation failed (expected)"
        else
            print_warning "Database connectivity: Uncertain (HTTP $create_code)"
        fi
    fi
    
    echo ""
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    print_info "Test Summary:"
    echo "  • Root URL: https://$base_url"
    echo "  • Test endpoint: https://$base_url/test"
    echo "  • API endpoint: https://$base_url/api/employees"
    echo ""
    
    if [ "$test_code" != "200" ]; then
        print_warning "Some tests failed. Recommended actions:"
        echo "  1. Check logs: railway logs"
        echo "  2. Verify environment variables: railway variables"
        echo "  3. Check database is running: railway status"
        echo "  4. Enable debug mode temporarily:"
        echo "     railway variables --set APP_DEBUG=true"
        echo "     railway up"
    fi
}

# Show logs
show_logs() {
    print_step "Recent deployment logs:"
    railway logs --limit 50
}

# Post-deployment info
post_deployment_info() {
    echo ""
    echo -e "${YELLOW}╔════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║     Important Post-Deployment Info        ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════╝${NC}"
    echo ""
    print_info "Useful Railway commands:"
    echo "  • railway logs           - View application logs"
    echo "  • railway logs --follow  - Stream logs in real-time"
    echo "  • railway open           - Open Railway dashboard"
    echo "  • railway up             - Deploy again"
    echo "  • railway variables      - View/edit environment variables"
    echo "  • railway status         - Check service status"
    echo ""
    print_info "Debugging tips:"
    echo "  • If you see 500 errors, check: railway logs"
    echo "  • To see detailed errors temporarily:"
    echo "    railway variables --set APP_DEBUG=true"
    echo "    railway up"
    echo "  • To run artisan commands:"
    echo "    railway run php artisan migrate"
    echo "    railway run php artisan tinker"
}

# Main execution
main() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════╗"
    echo "║  Railway Laravel Deployment Script   ║"
    echo "╚═══════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Run all checks
    check_prerequisites || exit 1
    check_railway_auth || exit 1
    check_laravel_project || exit 1
    check_git_repo || exit 1
    check_env_config || exit 1
    
    # Setup configuration files
    create_procfile
    create_nixpacks_config
    create_railway_json
    update_gitignore
    
    # Setup Railway project
    setup_railway_project || exit 1
    
    # Ask if user wants to add database
    echo ""
    read -p "Do you want to add MySQL database? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        add_database
        set_railway_variables
    fi
    
    # Deploy
    echo ""
    read -p "Ready to deploy? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        deploy_project || exit 1
        
        # Get deployment URL
        deployment_url=$(get_deployment_url)
        
        if [ ! -z "$deployment_url" ]; then
            print_success "Your Laravel application is deployed at:"
            echo -e "${GREEN}🌍 https://$deployment_url${NC}"
            
            # Test APIs
            echo ""
            read -p "Do you want to test the API endpoints? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                test_apis "$deployment_url"
            fi
        fi
        
        # Show logs option
        echo ""
        read -p "Show deployment logs? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            show_logs
        fi
        
        post_deployment_info
    else
        print_info "Deployment cancelled. Run this script again when ready."
        exit 0
    fi
    
    echo ""
    print_success "Deployment complete! 🚀"
}

# Run main function
main