# Find large files and directories on C: drive
Write-Host "=== Finding Large Files/Directories ===" -ForegroundColor Cyan

$results = @()

# Check user directories
Write-Host "`nChecking user directories..." -ForegroundColor Yellow
$userDirs = @(
    "C:\Users\simon\AppData\Local",
    "C:\Users\simon\AppData\Roaming", 
    "C:\Users\simon\Documents",
    "C:\Users\simon\Downloads",
    "C:\Users\simon\Desktop"
)

foreach ($dir in $userDirs) {
    if (Test-Path $dir) {
        try {
            $size = (Get-ChildItem $dir -Recurse -ErrorAction SilentlyContinue -Force | 
                    Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum / 1GB
            if ($size -gt 0.1) {
                $results += [PSCustomObject]@{
                    Path = $dir
                    SizeGB = [math]::Round($size, 2)
                }
            }
        } catch {
            Write-Host "  Error checking $dir" -ForegroundColor Red
        }
    }
}

# Check AppData subdirectories in detail
Write-Host "`nChecking AppData subdirectories..." -ForegroundColor Yellow
$appDataDirs = @(
    "$env:LOCALAPPDATA\Android",
    "$env:LOCALAPPDATA\Pub",
    "$env:USERPROFILE\.gradle",
    "$env:LOCALAPPDATA\Microsoft\Windows\INetCache",
    "$env:LOCALAPPDATA\Temp",
    "$env:LOCALAPPDATA\Google",
    "$env:LOCALAPPDATA\Microsoft",
    "$env:APPDATA\Microsoft",
    "$env:APPDATA\Google"
)

foreach ($dir in $appDataDirs) {
    if (Test-Path $dir) {
        try {
            $size = (Get-ChildItem $dir -Recurse -ErrorAction SilentlyContinue -Force | 
                    Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum / 1GB
            if ($size -gt 0.1) {
                $results += [PSCustomObject]@{
                    Path = $dir
                    SizeGB = [math]::Round($size, 2)
                }
            }
        } catch {}
    }
}

# Sort and display
$results = $results | Sort-Object SizeGB -Descending

Write-Host "`n=== Large Directories Found ===" -ForegroundColor Cyan
foreach ($item in $results) {
    $color = if ($item.SizeGB -gt 10) { "Red" } elseif ($item.SizeGB -gt 5) { "Yellow" } else { "White" }
    Write-Host "$($item.SizeGB) GB - $($item.Path)" -ForegroundColor $color
}

# Save to file
$results | Export-Csv -Path ".\large_directories.csv" -NoTypeInformation
Write-Host "`nResults saved to large_directories.csv" -ForegroundColor Green

# Total
$total = ($results | Measure-Object -Property SizeGB -Sum).Sum
Write-Host "`nTotal found: $([math]::Round($total, 2)) GB" -ForegroundColor Cyan
