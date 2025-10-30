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
    
    if [ ! -f "Procfile" ]; then
        cat > Procfile << 'EOF'
web: php artisan migrate --force && php artisan config:cache && php artisan route:cache && php artisan view:cache && php -S 0.0.0.0:$PORT -t public
EOF
        print_success "Procfile created"
    else
        print_success "Procfile already exists"
    fi
}

# Create nixpacks.toml for Laravel
create_nixpacks_config() {
    print_step "Setting up Nixpacks configuration..."
    
    if [ ! -f "nixpacks.toml" ]; then
        cat > nixpacks.toml << 'EOF'
[phases.setup]
nixPkgs = ["php82", "php82Extensions.pdo", "php82Extensions.pdo_mysql", "php82Extensions.mysqli", "php82Extensions.mbstring", "php82Extensions.xml", "php82Extensions.curl", "php82Extensions.zip", "php82Extensions.bcmath", "php82Extensions.tokenizer", "nodejs"]

[phases.install]
cmds = ["composer install --no-dev --optimize-autoloader --no-interaction"]

[phases.build]
cmds = [
    "php artisan config:clear",
    "php artisan cache:clear",
    "npm install --production=false",
    "npm run build"
]

[start]
cmd = "php artisan migrate --force && php artisan config:cache && php artisan route:cache && php artisan view:cache && php -S 0.0.0.0:$PORT -t public"
EOF
        print_success "nixpacks.toml created"
    else
        print_success "nixpacks.toml already exists"
    fi
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
    
    if [ ! -f "railway.json" ]; then
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
        print_success "railway.json created"
    else
        print_success "railway.json already exists"
    fi
}

# Initialize or link Railway project
setup_railway_project() {
    print_step "Setting up Railway project..."
    
    if [ ! -f "railway.toml" ] && [ ! -d ".railway" ]; then
        print_info "No Railway project found. Creating new project..."
        
        read -p "Enter project name (or press Enter for auto-generated): " project_name
        
        if [ -z "$project_name" ]; then
            railway init
        else
            railway init --name "$project_name"
        fi
        
        if [ $? -ne 0 ]; then
            print_error "Failed to initialize Railway project"
            return 1
        fi
        
        print_success "Railway project initialized"
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
    fi
    
    print_info "Configure these in Railway environment variables:"
    echo "  APP_KEY=<will be generated>"
    echo "  APP_ENV=production"
    echo "  APP_DEBUG=false"
    echo "  DB_CONNECTION=mysql"
    echo "  DB_HOST=\${MYSQLHOST}"
    echo "  DB_PORT=\${MYSQLPORT}"
    echo "  DB_DATABASE=\${MYSQLDATABASE}"
    echo "  DB_USERNAME=\${MYSQLUSER}"
    echo "  DB_PASSWORD=\${MYSQLPASSWORD}"
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
    print_info "You can view/edit variables with: railway variables"
}

# Deploy to Railway
deploy_project() {
    print_step "Deploying to Railway..."
    
    print_info "Starting deployment..."
    railway up
    
    if [ $? -ne 0 ]; then
        print_error "Deployment failed"
        print_info "Check the error messages above for details"
        print_info "Common issues:"
        echo "  • Missing environment variables (APP_KEY, DB credentials)"
        echo "  • Syntax errors in code"
        echo "  • composer.json issues"
        echo "  • Missing PHP extensions"
        echo "  • Database connection issues"
        return 1
    fi
    
    print_success "Deployment successful!"
    return 0
}

# Get deployment URL
get_deployment_url() {
    print_step "Retrieving deployment URL..."
    
    local url=$(railway domain 2>/dev/null)
    
    if [ -z "$url" ]; then
        print_info "No domain configured yet. Generating domain..."
        railway domain
        url=$(railway domain 2>/dev/null)
    fi
    
    if [ ! -z "$url" ]; then
        print_success "Your Laravel application is deployed at:"
        echo -e "${GREEN}🌍 https://$url${NC}"
    fi
}

# Show logs
show_logs() {
    print_step "Recent deployment logs:"
    railway logs --limit 30
}

# Post-deployment checks
post_deployment_info() {
    echo ""
    echo -e "${YELLOW}╔════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║     Important Post-Deployment Steps       ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════╝${NC}"
    echo ""
    print_info "1. Make sure APP_URL is set in Railway variables:"
    echo "   railway variables --set APP_URL=https://your-domain.railway.app"
    echo ""
    print_info "2. Check if migrations ran successfully in the logs"
    echo ""
    print_info "3. If you have a frontend (React/Vue), build it:"
    echo "   npm run build"
    echo ""
    print_info "4. For storage/public files, you may need to:"
    echo "   php artisan storage:link (in Railway)"
    echo ""
    print_info "5. Check your deployment:"
    echo "   railway logs"
    echo "   railway open"
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
        sleep 2
        set_railway_variables
    fi
    
    # Deploy
    echo ""
    read -p "Ready to deploy? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        deploy_project || exit 1
        get_deployment_url
        
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
    print_info "Useful commands:"
    echo "  • railway logs          - View logs"
    echo "  • railway open          - Open dashboard"
    echo "  • railway up            - Deploy again"
    echo "  • railway variables     - Manage environment variables"
    echo "  • railway run <cmd>     - Run artisan commands"
}

# Run main function
main