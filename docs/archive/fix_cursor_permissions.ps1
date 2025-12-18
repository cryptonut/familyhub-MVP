# Fix Cursor permissions on C: drive
# Run as Administrator

Write-Host "`n[INFO] Fixing Cursor permissions on C: drive..." -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "[ERROR] This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

# Directories that need write permissions
$directories = @(
    "$env:APPDATA\Cursor",
    "$env:USERPROFILE\.cursor\extensions"
)

foreach ($dir in $directories) {
    Write-Host "[INFO] Checking: $dir" -ForegroundColor Yellow
    
    # Create directory if it doesn't exist
    if (-not (Test-Path $dir)) {
        Write-Host "   Creating directory..." -ForegroundColor Gray
        try {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Host "   [OK] Directory created" -ForegroundColor Green
        } catch {
            Write-Host "   [ERROR] Failed to create directory: $_" -ForegroundColor Red
            continue
        }
    }
    
    # Fix permissions - give current user full control
    Write-Host "   Setting permissions..." -ForegroundColor Gray
    try {
        $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        $acl = Get-Acl $dir
        
        # Remove any existing rules that might block access
        $acl.SetAccessRuleProtection($false, $false)
        
        # Grant full control to current user
        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $currentUser,
            "FullControl",
            "ContainerInherit,ObjectInherit",
            "None",
            "Allow"
        )
        $acl.SetAccessRule($accessRule)
        
        # Apply the ACL
        Set-Acl -Path $dir -AclObject $acl
        
        Write-Host "   [OK] Permissions set for: $currentUser" -ForegroundColor Green
    } catch {
        Write-Host "   [ERROR] Failed to set permissions: $_" -ForegroundColor Red
    }
    
    # Verify write access
    Write-Host "   Testing write access..." -ForegroundColor Gray
    $testFile = Join-Path $dir "test_write_$(Get-Date -Format 'yyyyMMddHHmmss').tmp"
    try {
        "test" | Out-File -FilePath $testFile -Force
        Remove-Item $testFile -Force
        Write-Host "   [OK] Write access verified" -ForegroundColor Green
    } catch {
        Write-Host "   [WARN] Write test failed: $_" -ForegroundColor Yellow
    }
    
    Write-Host ""
}

Write-Host "[OK] Permission fix complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Restart Cursor" -ForegroundColor Gray
Write-Host "2. Open workspace from: C:\Users\Simon\Documents\familyhub-MVP" -ForegroundColor Gray
Write-Host "   OR open: C:\Users\Simon\Documents\familyhub-MVP\familyhub-MVP.code-workspace" -ForegroundColor Gray
Write-Host ""

