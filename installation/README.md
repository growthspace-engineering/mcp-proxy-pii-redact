# MCP Proxy for Atlassian - Automated Setup

This repository contains an MCP (Model Context Protocol) proxy that provides PII redaction capabilities for Atlassian services (Jira and Confluence).

## One-Command Setup

For developers who want to get up and running immediately:

```bash
curl -fsSL https://raw.githubusercontent.com/your-org/redact-mcp-proxy/main/setup-mcp-proxy.sh | bash
```

Or download and run manually:

```bash
wget https://raw.githubusercontent.com/your-org/redact-mcp-proxy/main/setup-mcp-proxy.sh
chmod +x setup-mcp-proxy.sh
./setup-mcp-proxy.sh
```

## What the Setup Script Does

1. ✅ **Checks prerequisites** (Node.js, macOS)
2. ✅ **Downloads/updates the repository** to `~/Development/redact-mcp-proxy`
3. ✅ **Installs the correct mcp-remote version** (0.1.17 - important due to a bug in 0.1.18)
4. ✅ **Makes the mcp-proxy executable**
5. ✅ **Runs OAuth authentication** with Atlassian (opens browser)
6. ✅ **Sets up auto-startup service** using macOS launchd
7. ✅ **Tests the installation**

After running the script, the MCP proxy will:
- Start automatically when you log in
- Run in the background on `http://localhost:8083`
- Provide both Atlassian and barbecue-event endpoints
- Log to `~/Library/Logs/mcp-proxy.log`

## Adding to Cursor

After setup, add this to your Cursor MCP configuration:

```json
{
  "mcpServers": {
    "mcp-proxy-atlassian": {
      "command": "npx",
      "args": [
        "mcp-remote", 
        "http://localhost:8083/atlassian/"
      ],
      "description": "MCP Proxy with PII redaction for Atlassian services"
    },
    "mcp-proxy-barbecue-event": {
      "command": "npx",
      "args": [
        "mcp-remote",
        "http://localhost:8083/barbecue-event/"
      ]
    }
  }
}
```

## Manual Setup (if you prefer)

<details>
<summary>Click to expand manual setup instructions</summary>

1. **Install the correct mcp-remote version:**
   ```bash
   npm install -g mcp-remote@0.1.17
   ```

2. **Run OAuth setup:**
   ```bash
   npx -y mcp-remote@0.1.17 https://mcp.atlassian.com/v1/sse 51328 --debug
   ```

3. **Make executable:**
   ```bash
   chmod +x ./mcp-proxy
   ```

4. **Run manually:**
   ```bash
   ./mcp-proxy -config config.json
   ```

</details>

## Service Management

After installation, you can manage the service with these commands:

```bash
# View logs
tail -f ~/Library/Logs/mcp-proxy.log

# Stop service
launchctl stop com.yourcompany.mcp-proxy

# Start service
launchctl start com.yourcompany.mcp-proxy

# Remove service (uninstall)
launchctl unload ~/Library/LaunchAgents/com.yourcompany.mcp-proxy.plist
rm ~/Library/LaunchAgents/com.yourcompany.mcp-proxy.plist

# Test if running
curl http://localhost:8083
```

## Troubleshooting

**Service won't start:**
- Check logs: `tail -f ~/Library/Logs/mcp-proxy-error.log`
- Ensure OAuth was completed: Look for `~/.mcp-auth` directory

**"Could not convert argument of type symbol to string" error:**
- You're using mcp-remote 0.1.18. Run: `npm install -g mcp-remote@0.1.17`

**OAuth fails:**
- Manually run: `npx -y mcp-remote@0.1.17 https://mcp.atlassian.com/v1/sse 51328 --debug`
- Ensure you have access to your Atlassian instance

**Port 8083 already in use:**
- Check what's using it: `lsof -i :8083`
- Kill the process or change the port in `config.json`

## Requirements

- macOS (Darwin)
- Node.js 18+
- Git
- Valid Atlassian Cloud account with appropriate permissions

## Features

- **PII Redaction**: Automatically redacts sensitive information
- **Atlassian Integration**: Full access to Jira and Confluence via MCP
- **Auto-startup**: Runs automatically on login
- **Logging**: Comprehensive logging for debugging
- **OAuth Security**: Secure authentication with Atlassian 