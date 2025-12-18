# Enhanced PowerShell script to push a commit, update firewall rules, and capture ALL possible logs on SIMPC1
# WARNING: This may log sensitive information like tokens or passwords. Review and secure the log file!

$LOG_FILE = "simpc1_full_logs_including_auth.txt"

# Start logging everything to file and console
Start-Transcript -Path $LOG_FILE -Append

Write-Host "=== Script Start: $(Get-Date) ==="
Write-Host "Hostname: $env:COMPUTERNAME"
Write-Host "User: $env:USERNAME"
Write-Host "Current directory: $(Get-Location)"
Write-Host "OS Version:"
Get-ComputerInfo | Select-Object WindowsVersion, WindowsProductName, OsHardwareAbstractionLayer
Write-Host "Git Version: $(git --version)"
Write-Host "`n=== Environment Variables (full) ==="
Get-ChildItem Env: | Sort-Object Name | Format-Table -AutoSize

# Network diagnostics
Write-Host "`n=== Network Diagnostics ==="
Write-Host "IP Configuration:"
Get-NetIPAddress | Format-Table
Get-NetIPConfiguration | Format-List
Write-Host "DNS Configuration:"
Get-DnsClientServerAddress | Format-Table
Write-Host "Hosts File:"
Get-Content $env:SystemRoot\System32\drivers\etc\hosts
Write-Host "Network Connections:"
Get-NetTCPConnection | Where-Object {$_.State -eq 'Established'} | Select-Object -First 20 | Format-Table
Write-Host "Ping to github.com:"
Test-Connection -ComputerName github.com -Count 4
Test-Connection -ComputerName api.github.com -Count 4
Write-Host "Curl test to github.com:"
curl.exe -v https://api.github.com 2>&1

# Proxy settings
Write-Host "`n=== Proxy Settings ==="
Write-Host "HTTP Proxy: $env:http_proxy"
Write-Host "HTTPS Proxy: $env:https_proxy"
Write-Host "NO Proxy: $env:no_proxy"
netsh winhttp show proxy

# SSH diagnostics if using SSH
$gitRemotes = git remote -v
if ($gitRemotes -match 'git@github.com') {
    Write-Host "`n=== SSH Diagnostics (Detailed) ==="
    Write-Host "SSH Config:"
    if (Test-Path "$env:USERPROFILE\.ssh\config") {
        Get-Content "$env:USERPROFILE\.ssh\config"
    } else {
        Write-Host "No SSH config file"
    }
    Write-Host "SSH Known Hosts (github entries):"
    if (Test-Path "$env:USERPROFILE\.ssh\known_hosts") {
        Get-Content "$env:USERPROFILE\.ssh\known_hosts" | Select-String "github"
    } else {
        Write-Host "No known_hosts file"
    }
    Write-Host "SSH Keys (public only):"
    Get-ChildItem "$env:USERPROFILE\.ssh\*.pub" -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Host "$($_.Name):"
        Get-Content $_.FullName
    }
    Write-Host "SSH Agent Keys:"
    ssh-add -l 2>&1
    Write-Host "SSH Connection Test (debug):"
    ssh -vvvT git@github.com 2>&1
}

# Git repository info (detailed)
Write-Host "`n=== Git Repository Info ==="
Write-Host "Git Config (local):"
git config --local --list --show-origin
Write-Host "Git Config (global):"
git config --global --list --show-origin
Write-Host "Git Config (system):"
git config --system --list --show-origin
Write-Host "Git Remotes:"
git remote -v
Write-Host "Git Status (detailed):"
git status --long -vv
Write-Host "Git Log (recent):"
git log -n 10 --pretty=fuller
Write-Host "Git Refs:"
git show-ref

# Auth/Token Diagnostics - POTENTIALLY SENSITIVE!
Write-Host "`n=== Auth/Token Diagnostics (SENSITIVE - Review Log Security) ==="
Write-Host "Git Credential Helper:"
git config --get credential.helper
git config --get-all credential.helper
Write-Host "Credential Manager Entries (GitHub related):"
cmdkey /list | Select-String -Pattern "git|github"
Write-Host "Stored Git Credentials (if using 'store' helper):"
if (Test-Path "$env:USERPROFILE\.git-credentials") {
    Write-Host "File exists - reviewing structure (not showing full content):"
    Get-Content "$env:USERPROFILE\.git-credentials" | Measure-Object -Line
} else {
    Write-Host "No ~/.git-credentials file"
}
Write-Host "Netrc File:"
if (Test-Path "$env:USERPROFILE\_netrc") {
    Write-Host "File exists"
} else {
    Write-Host "No _netrc file"
}
Write-Host "GitHub CLI Config (if installed):"
if (Get-Command gh -ErrorAction SilentlyContinue) {
    gh config list
    if (Test-Path "$env:USERPROFILE\.config\gh\hosts.yml") {
        Get-Content "$env:USERPROFILE\.config\gh\hosts.yml"
    } else {
        Write-Host "No gh hosts.yml"
    }
} else {
    Write-Host "GitHub CLI not installed"
}
Write-Host "Environment Vars for Auth:"
Get-ChildItem Env: | Where-Object {$_.Name -match 'token|pass|auth|key|secret|github'} | Format-Table

# Windows Credential Manager - detailed check
Write-Host "`n=== Windows Credential Manager ==="
Write-Host "All Git/GitHub related credentials:"
cmdkey /list | Select-String -Pattern "git|github"
Write-Host "Generic Credentials (may contain Git credentials):"
cmdkey /list | Select-String -Pattern "Generic"

# Add changes (detailed)
Write-Host "`n=== Adding Changes ==="
git add -v .

# Commit with verbose
$COMMIT_MESSAGE = "Test commit for full auth troubleshooting"
Write-Host "=== Committing: $COMMIT_MESSAGE ==="
git commit -m "$COMMIT_MESSAGE" -v

# Push with maximum tracing
Write-Host "`n=== Pushing to Remote (Max Trace) ==="
$env:GIT_TRACE = "2"
$env:GIT_TRACE_PACKET = "1"
$env:GIT_TRACE_PERFORMANCE = "1"
$env:GIT_TRACE_SETUP = "1"
$env:GIT_CURL_VERBOSE = "1"
git push -vvv 2>&1

# Firewall updates and status
Write-Host "`n=== Windows Firewall Status ==="
Get-NetFirewallProfile | Format-Table
Write-Host "Firewall Rules (GitHub/Git related):"
Get-NetFirewallRule | Where-Object {$_.DisplayName -match 'git|github'} | Format-Table
Write-Host "Outbound Rules (Port 443, 22):"
Get-NetFirewallRule | Where-Object {$_.Direction -eq 'Outbound' -and ($_.LocalPort -eq 443 -or $_.LocalPort -eq 22)} | Format-Table

# Process list for related processes
Write-Host "`n=== Related Processes ==="
Get-Process | Where-Object {$_.ProcessName -match 'git|ssh|curl|http'} | Format-Table

# Event Logs (recent errors)
Write-Host "`n=== Event Logs (Recent Errors/Warnings) ==="
Get-EventLog -LogName System -After (Get-Date).AddHours(-1) -EntryType Error,Warning | Select-Object -First 20 | Format-Table
Get-EventLog -LogName Application -After (Get-Date).AddHours(-1) -EntryType Error,Warning | Select-Object -First 20 | Format-Table

Write-Host "`n=== Script End: $(Get-Date) ==="
Write-Host "All logs (including potential sensitive auth data) saved to $LOG_FILE"
Write-Host "WARNING: Secure or delete $LOG_FILE after use as it may contain tokens/passwords!"

Stop-Transcript

