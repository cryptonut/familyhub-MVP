# Script to diagnose and push changes to GitHub
cd "d:\Users\Simon\Documents\familyhub-MVP"

Write-Host "=== Current Git Status ===" -ForegroundColor Cyan
git status

Write-Host "`n=== Checking for uncommitted changes ===" -ForegroundColor Cyan
$hasChanges = $false
if (-not (git diff --quiet)) {
    Write-Host "Unstaged changes detected" -ForegroundColor Yellow
    $hasChanges = $true
}
if (-not (git diff --cached --quiet)) {
    Write-Host "Staged changes detected" -ForegroundColor Yellow
    $hasChanges = $true
}

if ($hasChanges) {
    Write-Host "`n=== Staging all changes ===" -ForegroundColor Cyan
    git add -A
    
    Write-Host "`n=== Committing changes ===" -ForegroundColor Cyan
    git commit -m "Update: Calendar, dashboard, games, and service improvements"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Commit successful!" -ForegroundColor Green
        
        Write-Host "`n=== Pushing to origin/develop ===" -ForegroundColor Cyan
        git push origin develop
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Push successful!" -ForegroundColor Green
        } else {
            Write-Host "Push failed with exit code: $LASTEXITCODE" -ForegroundColor Red
            Write-Host "This might be an authentication issue. Check your GitHub credentials." -ForegroundColor Yellow
        }
    } else {
        Write-Host "Commit failed with exit code: $LASTEXITCODE" -ForegroundColor Red
    }
} else {
    Write-Host "No changes to commit" -ForegroundColor Yellow
}

Write-Host "`n=== Final Status ===" -ForegroundColor Cyan
git status

Write-Host "`n=== Recent commits ===" -ForegroundColor Cyan
git log --oneline -3

Write-Host "`n=== Commits ahead of origin ===" -ForegroundColor Cyan
git log --oneline origin/develop..HEAD
