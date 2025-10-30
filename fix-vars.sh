#!/bin/bash

# Fix Railway Database Variables Script
# This script fixes the literal ${MYSQL...} variable references

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_error() { echo -e "${RED}❌ $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════╗"
echo "║   Fix Railway Database Variables     ║"
echo "╚═══════════════════════════════════════╝"
echo -e "${NC}"

# Check Railway CLI
if ! command -v railway &> /dev/null; then
    print_error "Railway CLI not found"
    exit 1
fi

print_info "Checking current variables..."
echo ""

# Show current problematic variables
echo "Current DB variables:"
railway variables 2>/dev/null | grep "DB_"

echo ""
print_warning "The problem: Variables are set to literal strings like '\${MYSQLHOST}'"
print_info "Solution: We need to set them as references to actual MYSQL variables"
echo ""

# Check if MYSQL variables exist
print_info "Checking if MySQL service variables exist..."
if ! railway variables 2>/dev/null | grep -q "MYSQLHOST"; then
    print_error "MySQL service not found!"
    print_info "Add MySQL database first with: railway add"
    exit 1
fi

print_success "MySQL service found"
echo ""

# The correct way with current Railway CLI
print_info "Step 1: Removing old DB variables..."
echo ""

# Note: Railway CLI uses -- for setting, not subcommands
# We'll set them correctly by overwriting

print_info "Step 2: Setting correct database variables..."
echo ""

# Set APP_ENV and APP_DEBUG
print_info "Setting Laravel environment..."
railway variables --set APP_ENV=production 2>/dev/null
railway variables --set APP_DEBUG=false 2>/dev/null
railway variables --set LOG_CHANNEL=stderr 2>/dev/null
railway variables --set DB_CONNECTION=mysql 2>/dev/null

print_success "Laravel environment configured"
echo ""

# The trick: We need to set these WITHOUT the ${} wrapper
# Railway should interpret them as references automatically
print_info "Setting database connection variables..."

# Try method 1: Direct reference format
railway variables --set 'DB_HOST=$MYSQLHOST' 2>/dev/null && print_success "DB_HOST set" || print_warning "DB_HOST might need manual setting"
railway variables --set 'DB_PORT=$MYSQLPORT' 2>/dev/null && print_success "DB_PORT set" || print_warning "DB_PORT might need manual setting"
railway variables --set 'DB_DATABASE=$MYSQLDATABASE' 2>/dev/null && print_success "DB_DATABASE set" || print_warning "DB_DATABASE might need manual setting"
railway variables --set 'DB_USERNAME=$MYSQLUSER' 2>/dev/null && print_success "DB_USERNAME set" || print_warning "DB_USERNAME might need manual setting"
railway variables --set 'DB_PASSWORD=$MYSQLPASSWORD' 2>/dev/null && print_success "DB_PASSWORD set" || print_warning "DB_PASSWORD might need manual setting"

echo ""
print_info "Verifying variables..."
echo ""
railway variables 2>/dev/null | grep "DB_"

echo ""
echo -e "${YELLOW}╔════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║            IMPORTANT NEXT STEPS            ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════════╝${NC}"
echo ""

print_warning "If the script couldn't set variables correctly, you MUST use Railway Dashboard:"
echo ""
echo "1. Go to: https://railway.app/dashboard"
echo "2. Open: gregarious-forgiveness project"
echo "3. Click: Your service"
echo "4. Click: 'Variables' tab"
echo "5. For EACH DB variable (DB_HOST, DB_PORT, etc):"
echo "   - Click the variable"
echo "   - Click the '\$' (reference) icon"
echo "   - Select the corresponding MYSQL variable from dropdown"
echo "   - Example: DB_HOST should reference MYSQLHOST"
echo ""

read -p "Press Enter to trigger service restart..." 

print_info "Triggering service restart..."
railway up --detach 2>/dev/null || print_info "Deploy with: railway up"

echo ""
print_success "Script complete!"
echo ""
print_info "Wait 30 seconds, then test with:"
echo "  curl https://gregarious-forgiveness-production.up.railway.app/test"
echo ""
print_info "Check logs with:"
echo "  railway logs"