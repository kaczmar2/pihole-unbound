#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}Pi-hole v6 + Unbound Password Setup Script${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Function to show usage
show_usage() {
    echo "Usage: $0 [password]"
    echo ""
    echo "Options:"
    echo "  password    Optional: Provide password as argument (not recommended for security)"
    echo "              If not provided, you'll be prompted securely"
    echo ""
    echo "Examples:"
    echo "  $0                    # Interactive password prompt (recommended)"
    echo "  $0 mypassword        # Direct password (less secure)"
    echo ""
}

# Check for help flag
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    show_usage
    exit 0
fi

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${RED}Error: .env file not found in current directory.${NC}"
    echo -e "${YELLOW}Please make sure you're running this script from your pihole-unbound directory.${NC}"
    exit 1
fi

# Check if docker-compose.yml exists
if [ ! -f docker-compose.yml ]; then
    echo -e "${RED}Error: docker-compose.yml not found in current directory.${NC}"
    echo -e "${YELLOW}Please make sure you're running this script from your pihole-unbound directory.${NC}"
    exit 1
fi

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Error: Docker is not running or not accessible.${NC}"
    echo -e "${YELLOW}Please start Docker and try again.${NC}"
    exit 1
fi

# Prompt for password if not provided
if [ -z "$1" ]; then
    echo -e "${BLUE}Enter your desired Pi-hole admin password:${NC}"
    echo -n "Password: "
    read -s password
    echo
    echo -n "Confirm password: "
    read -s password_confirm
    echo
    
    if [ "$password" != "$password_confirm" ]; then
        echo -e "${RED}Passwords do not match!${NC}"
        exit 1
    fi
else
    password="$1"
    echo -e "${YELLOW}Warning: Password provided as command line argument.${NC}"
    echo -e "${YELLOW}This may be visible in command history.${NC}"
fi

# Validate password
if [ -z "$password" ]; then
    echo -e "${RED}Password cannot be empty!${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}Setting up Pi-hole password...${NC}"

# Step 1: Comment out the password environment variable in docker-compose.yml
echo -e "${YELLOW}Step 1: Temporarily disabling password env variable in docker-compose.yml...${NC}"
cp docker-compose.yml docker-compose.yml.backup
echo -e "${YELLOW}Created backup: docker-compose.yml.backup${NC}"

# Check if FTLCONF_webserver_api_pwhash exists and what state it's in
if grep -q "^[[:space:]]*FTLCONF_webserver_api_pwhash" docker-compose.yml; then
    # Line exists and is uncommented - comment it out
    sed -i.tmp 's/^[[:space:]]*FTLCONF_webserver_api_pwhash/#      FTLCONF_webserver_api_pwhash/' docker-compose.yml && rm docker-compose.yml.tmp
    echo -e "${GREEN}Commented out FTLCONF_webserver_api_pwhash in docker-compose.yml${NC}"
    PASSWORD_LINE_WAS_UNCOMMENTED=true
elif grep -q "#.*FTLCONF_webserver_api_pwhash" docker-compose.yml; then
    # Line exists but is already commented
    echo -e "${GREEN}FTLCONF_webserver_api_pwhash already commented out${NC}"
    PASSWORD_LINE_WAS_UNCOMMENTED=false
else
    # Line doesn't exist at all
    echo -e "${RED}Error: FTLCONF_webserver_api_pwhash not found in docker-compose.yml${NC}"
    echo -e "${YELLOW}Please make sure your docker-compose.yml includes this line in the pihole environment section:${NC}"
    echo -e "${BLUE}      FTLCONF_webserver_api_pwhash: \${WEB_PWHASH}${NC}"
    echo ""
    echo -e "${YELLOW}You can add it and run this script again, or set it up manually.${NC}"
    rm docker-compose.yml.backup
    exit 1
fi

# Step 2: Restart containers to pick up the docker-compose change
echo -e "${YELLOW}Step 2: Restarting containers to disable env override...${NC}"
docker compose down
docker compose up -d pihole

# Wait for Pi-hole to be ready
echo "Waiting for Pi-hole to be ready..."
for i in {1..30}; do
    if docker exec pihole pihole status > /dev/null 2>&1; then
        break
    fi
    sleep 2
    echo -n "."
done
echo ""
sleep 5

# Step 3: Set password in container (will now write to TOML)
echo -e "${YELLOW}Step 3: Setting password in Pi-hole container...${NC}"
if ! docker exec pihole pihole setpassword "$password"; then
    echo -e "${RED}Failed to set password in Pi-hole container${NC}"
    # Restore docker-compose.yml on failure
    cp docker-compose.yml.backup docker-compose.yml
    exit 1
fi

# Wait for the password to be written to TOML
sleep 3

# Step 4: Get the hash from the container
echo -e "${YELLOW}Step 4: Retrieving password hash from pihole.toml...${NC}"
hash_line=$(docker exec pihole grep -E "^[[:space:]]*pwhash[[:space:]]*=" /etc/pihole/pihole.toml || true)
if [ -z "$hash_line" ]; then
    echo -e "${RED}Failed to retrieve password hash from /etc/pihole/pihole.toml${NC}"
    echo -e "${YELLOW}The password was set, but automatic hash extraction failed.${NC}"
    echo -e "${YELLOW}This may indicate an issue with Pi-hole v6 or the container setup.${NC}"
    # Restore docker-compose.yml on failure
    cp docker-compose.yml.backup docker-compose.yml
    exit 1
fi

# Extract hash from pihole.toml format - handle leading whitespace, spaces around =, and comments
hash_value=$(echo "$hash_line" | sed -E 's/^[[:space:]]*pwhash[[:space:]]*=[[:space:]]*//' | sed 's/[[:space:]]*###.*$//' | tr -d '"')

if [ -z "$hash_value" ]; then
    echo -e "${RED}Failed to extract password hash from TOML line${NC}"
    echo -e "${YELLOW}Found line: $hash_line${NC}"
    # Restore docker-compose.yml on failure
    cp docker-compose.yml.backup docker-compose.yml
    exit 1
fi

echo -e "${GREEN}Successfully extracted password hash from pihole.toml${NC}"

# Step 5: Update .env file
echo -e "${YELLOW}Step 5: Updating .env file with password hash...${NC}"
# Backup .env file
cp .env .env.backup
echo -e "${YELLOW}Created backup: .env.backup${NC}"

if grep -q "WEB_PWHASH=" .env; then
    # Replace existing line (handle both commented and uncommented versions)
    sed -i.tmp "s|^[[:space:]]*#*[[:space:]]*WEB_PWHASH=.*|WEB_PWHASH='$hash_value'|" .env && rm .env.tmp
    echo -e "${GREEN}Updated existing WEB_PWHASH in .env${NC}"
else
    # Add new line
    echo "" >> .env
    echo "# Pi-hole admin password hash (auto-generated)" >> .env
    echo "WEB_PWHASH='$hash_value'" >> .env
    echo -e "${GREEN}Added WEB_PWHASH to .env${NC}"
fi

# Step 6: Uncomment the password environment variable in docker-compose.yml
echo -e "${YELLOW}Step 6: Re-enabling password env variable in docker-compose.yml...${NC}"
if grep -q "#.*FTLCONF_webserver_api_pwhash" docker-compose.yml; then
    # Line is commented - uncomment it
    sed -i.tmp 's/^[[:space:]]*#[[:space:]]*FTLCONF_webserver_api_pwhash/      FTLCONF_webserver_api_pwhash/' docker-compose.yml && rm docker-compose.yml.tmp
    echo -e "${GREEN}Uncommented FTLCONF_webserver_api_pwhash in docker-compose.yml${NC}"
elif grep -q "^[[:space:]]*FTLCONF_webserver_api_pwhash" docker-compose.yml; then
    # Line is already uncommented
    echo -e "${GREEN}FTLCONF_webserver_api_pwhash already uncommented${NC}"
else
    # Line doesn't exist (this shouldn't happen since we checked in Step 1)
    echo -e "${RED}Warning: FTLCONF_webserver_api_pwhash line not found${NC}"
    echo -e "${YELLOW}The .env file has been updated, but you'll need to manually add:${NC}"
    echo -e "${BLUE}      FTLCONF_webserver_api_pwhash: \${WEB_PWHASH}${NC}"
    echo -e "${BLUE}to your docker-compose.yml pihole environment section${NC}"
fi

echo ""
echo -e "${GREEN}Password setup complete!${NC}"
echo -e "${YELLOW}Step 7: Final restart with new configuration...${NC}"

# Final restart with both the hash in .env and env variable enabled
docker compose down
if ! docker compose up -d; then
    echo -e "${RED}Failed to start containers!${NC}"
    echo -e "${YELLOW}Restoring backups...${NC}"
    cp .env.backup .env
    cp docker-compose.yml.backup docker-compose.yml
    exit 1
fi

echo ""
echo -e "${GREEN}✓ Setup completed successfully!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Your Pi-hole admin interface is now available at:${NC}"
echo -e "${BLUE}http://$(hostname -I | awk '{print $1}')/admin${NC}"
echo -e "${BLUE}or http://localhost/admin (if running locally)${NC}"
echo ""
echo -e "${YELLOW}Login with the password you just set.${NC}"
echo ""
echo -e "${GREEN}Cleanup: You can safely delete the backup files when you're sure everything works:${NC}"
echo -e "${BLUE}rm .env.backup docker-compose.yml.backup${NC}"