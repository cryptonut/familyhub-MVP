# Safe Project Move Script
# Moves familyhub-MVP from OneDrive to a better location

Write-Host "=== Family Hub MVP - Safe Project Move ===" -ForegroundColor Cyan
Write-Host ""

# Current location
$currentPath = "C:\Users\simon\OneDrive\Desktop\familyhub-MVP"
$currentPathExists = Test-Path $currentPath

if (-not $currentPathExists) {
    Write-Host "Current path not found: $currentPath" -ForegroundColor Yellow
    Write-Host "Please update the script with your actual current path" -ForegroundColor Yellow
    exit 1
}

Write-Host "Current location: $currentPath" -ForegroundColor Yellow
Write-Host ""

# Destination options
Write-Host "Choose destination:" -ForegroundColor Green
Write-Host "1. C:\Users\simon\Documents\familyhub-MVP (Recommended)"
Write-Host "2. C:\dev\familyhub-MVP"
Write-Host "3. Custom path"
Write-Host ""
$choice = Read-Host "Enter choice (1, 2, or 3)"

switch ($choice) {
    "1" { $destination = "C:\Users\simon\Documents\familyhub-MVP" }
    "2" { 
        $destination = "C:\dev\familyhub-MVP"
        # Create dev folder if it doesn't exist
        if (-not (Test-Path "C:\dev")) {
            Write-Host "Creating C:\dev folder..." -ForegroundColor Cyan
            New-Item -ItemType Directory -Path "C:\dev" -Force | Out-Null
        }
    }
    "3" { 
        $customPath = Read-Host "Enter custom destination path"
        $destination = $customPath.TrimEnd('\')
    }
    default { 
        Write-Host "Invalid choice. Using Documents folder." -ForegroundColor Yellow
        $destination = "C:\Users\simon\Documents\familyhub-MVP"
    }
}

Write-Host ""
Write-Host "Destination: $destination" -ForegroundColor Green

# Check if destination already exists
if (Test-Path $destination) {
    Write-Host "⚠️  Destination already exists: $destination" -ForegroundColor Red
    $overwrite = Read-Host "Overwrite? (yes/no)"
    if ($overwrite -ne "yes") {
        Write-Host "Move cancelled." -ForegroundColor Yellow
        exit 0
    }
    Write-Host "Removing existing destination..." -ForegroundColor Yellow
    Remove-Item -Path $destination -Recurse -Force -ErrorAction SilentlyContinue
}

# Check for running processes
Write-Host ""
Write-Host "Checking for running Flutter/Dart processes..." -ForegroundColor Cyan
$flutterProcesses = Get-Process -Name "dart","flutter" -ErrorAction SilentlyContinue
if ($flutterProcesses) {
    Write-Host "⚠️  Found running Flutter/Dart processes:" -ForegroundColor Yellow
    $flutterProcesses | ForEach-Object { Write-Host "  - $($_.ProcessName) (PID: $($_.Id))" }
    $stop = Read-Host "Stop these processes? (yes/no)"
    if ($stop -eq "yes") {
        $flutterProcesses | Stop-Process -Force
        Start-Sleep -Seconds 2
    } else {
        Write-Host "Please close Flutter processes manually and run this script again." -ForegroundColor Yellow
        exit 1
    }
}

# Move the project
Write-Host ""
Write-Host "Moving project from OneDrive to new location..." -ForegroundColor Cyan
Write-Host "This may take a few minutes..."

try {
    # Create parent directory if needed
    $parentDir = Split-Path -Parent $destination
    if (-not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }
    
    # Move the entire folder
    Move-Item -Path $currentPath -Destination $destination -Force -ErrorAction Stop
    
    Write-Host "✅ Project moved successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "New location: $destination" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Open VS Code/Cursor in the new location: $destination"
    Write-Host "2. Run: flutter clean"
    Write-Host "3. Run: flutter pub get"
    Write-Host "4. Run: flutter run"
    Write-Host ""
    Write-Host "Git remote and all project files are preserved." -ForegroundColor Cyan
    
    # Optionally open the new location
    $open = Read-Host "Open new location in Explorer? (yes/no)"
    if ($open -eq "yes") {
        Start-Process explorer.exe -ArgumentList $destination
    }
    
} catch {
    Write-Host "❌ Error moving project: $_" -ForegroundColor Red
    Write-Host "Please move manually or check permissions." -ForegroundColor Yellow
    exit 1
}

