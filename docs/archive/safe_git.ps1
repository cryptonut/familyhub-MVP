# Safe Git Wrapper with Timeout and Retry Logic
# Usage: . .\safe_git.ps1 (dot-source to import functions)

function Invoke-SafeGit {
    <#
    .SYNOPSIS
    Executes Git commands with timeout and retry logic for network operations.
    
    .DESCRIPTION
    Safely executes Git commands with:
    - Timeout handling (default 60 seconds)
    - Automatic retry for network operations (push/pull/fetch)
    - No retry for destructive operations (commit, reset, etc.)
    - Progress reporting
    
    .PARAMETER Command
    The Git command to execute (without 'git' prefix)
    
    .PARAMETER TimeoutSeconds
    Maximum time to wait for command (default: 60)
    
    .PARAMETER RetryCount
    Number of retries for network operations (default: 2)
    
    .PARAMETER AllowRetry
    Force allow retry even for non-network operations (use with caution)
    
    .EXAMPLE
    Invoke-SafeGit "push origin develop"
    Invoke-SafeGit "pull origin develop" -TimeoutSeconds 120
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Command,
        
        [Parameter()]
        [int]$TimeoutSeconds = 60,
        
        [Parameter()]
        [int]$RetryCount = 2,
        
        [Parameter()]
        [switch]$AllowRetry = $false
    )
    
    # Commands that are safe to retry (network operations)
    $retryableCommands = @("push", "pull", "fetch", "clone", "ls-remote")
    
    # Commands that should NEVER be retried (destructive or state-changing)
    $noRetryCommands = @("commit", "reset", "rebase", "merge", "checkout", "branch", "tag")
    
    # Check if command is retryable
    $isRetryable = $AllowRetry -or ($retryableCommands | Where-Object { $Command -match "^$_" })
    $isNoRetry = $noRetryCommands | Where-Object { $Command -match "^$_" }
    
    if ($isNoRetry -and -not $AllowRetry) {
        Write-Host "[INFO] Executing Git command (no retry for safety): git $Command" -ForegroundColor Yellow
    }
    
    $attempt = 0
    $maxAttempts = if ($isRetryable) { $RetryCount + 1 } else { 1 }
    
    while ($attempt -lt $maxAttempts) {
        $attempt++
        
        if ($attempt -gt 1) {
            $waitTime = [math]::Min($attempt * 2, 10)  # Exponential backoff, max 10s
            Write-Host "[INFO] Retry attempt $attempt/$maxAttempts (waiting ${waitTime}s)..." -ForegroundColor Yellow
            Start-Sleep -Seconds $waitTime
        }
        
        try {
            # Execute with timeout
            $job = Start-Job -ScriptBlock {
                param($cmd)
                & git $cmd.Split(' ') 2>&1
            } -ArgumentList $Command
            
            $result = Wait-Job -Job $job -Timeout $TimeoutSeconds
            
            if ($result) {
                $output = Receive-Job -Job $job
                Remove-Job -Job $job -Force
                
                # Check exit code (Git doesn't set $LASTEXITCODE in jobs, check output)
                if ($output -match "error|fatal|failed" -and $output -notmatch "warning") {
                    if ($isRetryable -and $attempt -lt $maxAttempts) {
                        Write-Host "[WARN] Git command failed, will retry..." -ForegroundColor Yellow
                        continue
                    } else {
                        Write-Host "[ERROR] Git command failed: git $Command" -ForegroundColor Red
                        $output | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }
                        return $false
                    }
                }
                
                # Success
                $output | ForEach-Object { Write-Host $_ }
                return $true
            } else {
                # Timeout
                Stop-Job -Job $job -Force
                Remove-Job -Job $job -Force
                
                if ($isRetryable -and $attempt -lt $maxAttempts) {
                    Write-Host "[WARN] Git command timed out after ${TimeoutSeconds}s, will retry..." -ForegroundColor Yellow
                    continue
                } else {
                    Write-Host "[ERROR] Git command timed out after ${TimeoutSeconds}s: git $Command" -ForegroundColor Red
                    return $false
                }
            }
        } catch {
            if ($isRetryable -and $attempt -lt $maxAttempts) {
                Write-Host "[WARN] Git command error, will retry: $($_.Exception.Message)" -ForegroundColor Yellow
                continue
            } else {
                Write-Host "[ERROR] Git command error: $($_.Exception.Message)" -ForegroundColor Red
                return $false
            }
        }
    }
    
    Write-Host "[ERROR] Git command failed after $maxAttempts attempts: git $Command" -ForegroundColor Red
    return $false
}

# Export the function
Export-ModuleMember -Function Invoke-SafeGit

