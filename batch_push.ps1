# Target batch size: 1 GB in bytes
$BatchSizeLimit = 1000 * 1024 * 1024
$CurrentBatchSize = 0
$BatchCounter = 1
$FilesToAdd = [System.Collections.Generic.List[string]]::new()

# Get all untracked or modified files
$Files = git status --porcelain | ForEach-Object {
    if ($_ -match '^\?\?\s+(.*)$' -or $_ -match '^\sM\s+(.*)$') {
        $Matches[1].Trim('"')
    }
}

if ($null -eq $Files -or $Files.Count -eq 0) {
    Write-Host "No files to push!" -ForegroundColor Yellow
    exit
}

Write-Host "Found $($Files.Count) files to process. Starting batching..." -ForegroundColor Cyan

foreach ($FilePath in $Files) {
    if (-not (Test-Path -Path $FilePath -PathType Leaf)) { continue }
    $FileSize = (Get-Item $FilePath).Length

    # If adding this file exceeds the 1GB batch limit, push the current batch
    if (($CurrentBatchSize + $FileSize -gt $BatchSizeLimit) -and ($FilesToAdd.Count -gt 0)) {
        $ApproxMB = [Math]::Round($CurrentBatchSize / 1MB)
        Write-Host "`n--- Pushing Batch #$BatchCounter (Approx. $ApproxMB MB) ---" -ForegroundColor Green
        
        # Stage, Commit, and Push
        git add $FilesToAdd
        git commit -m "Deploy assets batch #$BatchCounter"
        git push origin main

        if ($LASTEXITCODE -ne 0) {
            Write-Host "Push failed! Stopping script to prevent errors." -ForegroundColor Red
            exit
        }

        $BatchCounter++
        $FilesToAdd.Clear()
        $CurrentBatchSize = 0
    }

    $FilesToAdd.Add($FilePath)
    $CurrentBatchSize += $FileSize
}

# Push any remaining files
if ($FilesToAdd.Count -gt 0) {
    $ApproxMB = [Math]::Round($CurrentBatchSize / 1MB)
    Write-Host "`n--- Pushing Final Batch #$BatchCounter (Approx. $ApproxMB MB) ---" -ForegroundColor Green
    git add $FilesToAdd
    git commit -m "Deploy assets batch #$BatchCounter"
    git push origin main
}

Write-Host "`n All batches successfully pushed to GitHub!" -ForegroundColor Cyan
