# D:\nocom\extract_shulkers_parallel.ps1

# 1) Allow unsigned scripts in this session
Set-ExecutionPolicy -Scope Process Bypass -Force

# 2) Configuration
$InputDir  = 'D:\nocom\blocks.sql'
$Pattern   = 'blocks.sql.part*.sql'
$FinalCsv  = 'D:\nocom\blocks.sql\shulker_placements.csv'
$Throttle  = 4     # how many files to scan in parallel
$Enc       = [System.Text.Encoding]::UTF8

# precompute the numeric state range:
$minState = 219 * 16          # 3504 (shulker range)
$maxState = 234 * 16 + 15     # 3759

# 3) Prep output
Remove-Item "$InputDir\*.out.csv" -ErrorAction SilentlyContinue
"X,Y,Z,block_state,created_at,dimension,server_id" |
  Out-File $FinalCsv -Encoding UTF8

# 4) Parallel scan/stream
Get-ChildItem -Path $InputDir -Filter $Pattern |
  Sort-Object Name |
  ForEach-Object -Parallel {
    # temp file for this part
    $partName = $_.BaseName
    $tempOut  = "$Using:InputDir\$partName.out.csv"

    Write-Host " [PID $PID] Scanning $partName…" -ForegroundColor Cyan
    Remove-Item $tempOut -ErrorAction SilentlyContinue

    $sr = [System.IO.File]::OpenText($_.FullName)
    while (-not $sr.EndOfStream) {
      $line = $sr.ReadLine()
      # only data lines start with '-' or digit
      if ($line -match '^[\-\d]') {
        $cols = $line -split "`t"
        if ($cols.Count -eq 7) {
          $id = $cols[3] -as [int]
          # NEW: test correct shulker state range
          if ($id -ge $Using:minState -and $id -le $Using:maxState) {
            ($cols -join ',') |
              Out-File -FilePath $tempOut -Append -Encoding UTF8
          }
        }
      }
    }
    $sr.Close()

    Write-Host " [PID $PID] Done $partName" -ForegroundColor Green
  } -ThrottleLimit $Throttle

# 5) Merge all part outputs
Get-ChildItem "$InputDir\*.out.csv" |
  Sort-Object Name |
  ForEach-Object {
    Get-Content $_.FullName | Add-Content $FinalCsv
  }

Write-Host " Extraction complete!  Master CSV at $FinalCsv" -ForegroundColor Yellow

#pwsh D:\nocom\FilterShulkers.ps1

# "D:\nocom\blocks.sql\shulker_placements.csv"
