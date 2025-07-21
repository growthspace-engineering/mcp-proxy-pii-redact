#!/bin/bash

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://github.com/your-org/redact-mcp-proxy.git"  # Update this to your actual repo URL
INSTALL_DIR="$HOME/Development/redact-mcp-proxy"
SERVICE_NAME="mcp-proxy"
LAUNCHD_PLIST="$HOME/Library/LaunchAgents/com.yourcompany.mcp-proxy.plist"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if running on macOS
check_os() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_error "This script is designed for macOS. For Linux, you'll need to modify the startup service configuration."
        exit 1
    fi
}

# Check if Node.js is installed
check_nodejs() {
    print_step "Checking Node.js installation..."
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed. Please install Node.js first:"
        print_error "Visit: https://nodejs.org/ or use: brew install node"
        exit 1
    fi
    print_status "Node.js found: $(node --version)"
}

# Clone or update repository
setup_repository() {
    print_step "Setting up repository..."
    
    if [ -d "$INSTALL_DIR" ]; then
        print_status "Repository exists. Updating..."
        cd "$INSTALL_DIR"
        git pull
    else
        print_status "Cloning repository..."
        mkdir -p "$(dirname "$INSTALL_DIR")"
        git clone "$REPO_URL" "$INSTALL_DIR"
        cd "$INSTALL_DIR"
    fi
}

# Install correct mcp-remote version
install_mcp_remote() {
    print_step "Installing mcp-remote@0.1.17..."
    npm install -g mcp-remote@0.1.17
    print_status "mcp-remote@0.1.17 installed successfully"
}

# Make mcp-proxy executable
setup_executable() {
    print_step "Making mcp-proxy executable..."
    if [ ! -f "$INSTALL_DIR/mcp-proxy" ]; then
        print_error "mcp-proxy executable not found in $INSTALL_DIR"
        print_error "Please ensure the repository contains the mcp-proxy binary"
        exit 1
    fi
    
    chmod +x "$INSTALL_DIR/mcp-proxy"
    print_status "mcp-proxy is now executable"
}

# Run OAuth flow
setup_oauth() {
    print_step "Setting up OAuth authentication..."
    print_status "This will open your browser for Atlassian authentication."
    print_status "Please approve the MCP access when prompted."
    
    # Check if already authenticated
    if [ -d "$HOME/.mcp-auth" ] && find "$HOME/.mcp-auth" -name "*.json" -type f | grep -q .; then
        read -p "OAuth tokens already exist. Re-authenticate? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Skipping OAuth setup"
            return
        fi
    fi
    
    echo
    print_status "Starting OAuth flow..."
    print_status "A browser window will open. Please complete the authentication."
    
    # Run OAuth flow with timeout
    timeout 120 npx -y mcp-remote@0.1.17 https://mcp.atlassian.com/v1/sse 51328 --debug || {
        print_warning "OAuth flow timed out or was interrupted."
        print_warning "You can run it manually later with:"
        print_warning "npx -y mcp-remote@0.1.17 https://mcp.atlassian.com/v1/sse 51328 --debug"
    }
}

# Create launchd service for auto-startup
create_startup_service() {
    print_step "Creating startup service..."
    
    # Stop existing service if running
    if launchctl list | grep -q "com.yourcompany.mcp-proxy"; then
        print_status "Stopping existing service..."
        launchctl unload "$LAUNCHD_PLIST" 2>/dev/null || true
    fi
    
    # Create launchd plist
    cat > "$LAUNCHD_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.yourcompany.mcp-proxy</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>$INSTALL_DIR/mcp-proxy</string>
        <string>-config</string>
        <string>$INSTALL_DIR/config.json</string>
    </array>
    
    <key>WorkingDirectory</key>
    <string>$INSTALL_DIR</string>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>KeepAlive</key>
    <true/>
    
    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/mcp-proxy.log</string>
    
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/mcp-proxy-error.log</string>
    
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:$HOME/.nvm/versions/node/$(node --version | tr -d 'v')/bin</string>
    </dict>
</dict>
</plist>
EOF

    # Load the service
    launchctl load "$LAUNCHD_PLIST"
    
    # Start the service
    launchctl start "com.yourcompany.mcp-proxy"
    
    print_status "Startup service created and started"
    print_status "Service will automatically start on login"
    print_status "Logs available at: $HOME/Library/Logs/mcp-proxy.log"
}

# Test the installation
test_installation() {
    print_step "Testing installation..."
    
    # Wait a moment for service to start
    sleep 3
    
    # Test if proxy is responding
    if curl -s --max-time 5 http://localhost:8083 >/dev/null 2>&1; then
        print_status "✅ MCP Proxy is running and responding on http://localhost:8083"
    else
        print_warning "⚠️  MCP Proxy may not be fully started yet. Check logs:"
        print_warning "tail -f $HOME/Library/Logs/mcp-proxy.log"
    fi
}

# Print final instructions
print_final_instructions() {
    print_step "Setup Complete!"
    echo
    print_status "🎉 MCP Proxy is now installed and configured to start automatically!"
    echo
    print_status "Next steps:"
    echo "  1. Add to Cursor configuration:"
    echo '     "mcp-proxy-atlassian": {'
    echo '       "command": "npx",'
    echo '       "args": ["mcp-remote", "http://localhost:8083/atlassian/"],'
    echo '       "description": "MCP Proxy with PII redaction for Atlassian services"'
    echo '     }'
    echo
    print_status "Useful commands:"
    echo "  • View logs:      tail -f $HOME/Library/Logs/mcp-proxy.log"
    echo "  • Stop service:   launchctl stop com.yourcompany.mcp-proxy"
    echo "  • Start service:  launchctl start com.yourcompany.mcp-proxy"
    echo "  • Remove service: launchctl unload $LAUNCHD_PLIST && rm $LAUNCHD_PLIST"
    echo "  • Test proxy:     curl http://localhost:8083"
    echo
    print_status "The MCP Proxy will automatically start when you log in to your computer."
}

# Main execution
main() {
    echo -e "${BLUE}==================================${NC}"
    echo -e "${BLUE}    MCP Proxy Setup Script       ${NC}"
    echo -e "${BLUE}==================================${NC}"
    echo
    
    check_os
    check_nodejs
    setup_repository
    install_mcp_remote
    setup_executable
    setup_oauth
    create_startup_service
    test_installation
    print_final_instructions
}

# Handle interruption
trap 'print_error "Setup interrupted"; exit 1' INT

# Run main function
main "$@" 