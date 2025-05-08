Add-Type -AssemblyName System.Windows.Forms

function Read-Path($prompt) {
    $input = Read-Host $prompt
    return $input.Trim('"','(',')')
}

function Read-Double($prompt) {
    while ($true) {
        $s   = Read-Host $prompt
        $val = 0.0
        if ([double]::TryParse($s, [ref]$val)) { return $val }
        Write-Host "Invalid number. Please enter a valid numeric value." -ForegroundColor Yellow
    }
}

function Read-Int($prompt) {
    while ($true) {
        $s   = Read-Host $prompt
        $val = 0
        if ([int]::TryParse($s, [ref]$val)) { return $val }
        Write-Host "Invalid integer. Please enter a valid whole number." -ForegroundColor Yellow
    }
}

function Choose-Preset {
    Write-Host ""
    Write-Host "Select filter preset:"
    Write-Host " 1) Lone   – exactly 1 per 16×16 chunk"
    Write-Host " 2) Tiny   – cluster size 4–10"
    Write-Host " 3) Base   – cluster size 10–5000"
    Write-Host " 4) Custom – custom min/max cluster size"
    Write-Host " 5) All    – all within horizontal radius"
    while ($true) {
        $choice = Read-Host "Enter 1–5"
        switch ($choice) {
            '1' { return @{ Name='Lone';  Min=1;     Max=1     } }
            '2' { return @{ Name='Tiny';  Min=4;     Max=10    } }
            '3' { return @{ Name='Base';  Min=10;    Max=5000  } }
            '4' {
                $mn = Read-Int "Custom Min cluster size"
                $mx = Read-Int "Custom Max cluster size"
                return @{ Name='Custom'; Min=$mn; Max=$mx }
            }
            '5' { return @{ Name='All';   Min=$null; Max=$null } }
        }
        Write-Host "Please enter a number from 1 to 5." -ForegroundColor Yellow
    }
}

function Get-Clusters {
    param([array]$pts, [double]$r)
    $n        = $pts.Count
    $visited  = New-Object bool[] $n
    $clusters = @{}
    $cid      = 0

    for ($i = 0; $i -lt $n; $i++) {
        if ($visited[$i]) { continue }
        $cid++
        $clusters[$cid] = @()
        $queue = [Collections.Generic.Queue[int]]::new()
        $queue.Enqueue($i)
        while ($queue.Count -gt 0) {
            $j = $queue.Dequeue()
            if ($visited[$j]) { continue }
            $visited[$j] = $true
            $clusters[$cid] += $j
            $pj = $pts[$j]
            for ($k = 0; $k -lt $n; $k++) {
                if (-not $visited[$k]) {
                    $pk = $pts[$k]
                    $dx = $pj.X - $pk.X
                    $dz = $pj.Z - $pk.Z
                    if ([math]::Sqrt($dx*$dx + $dz*$dz) -le $r) {
                        $queue.Enqueue($k)
                    }
                }
            }
        }
    }
    return $clusters
}

# ─────────────────────────────────────────────────────────────────────────────
# 1) Ask only for the CSV path
# ─────────────────────────────────────────────────────────────────────────────
$csvPath = Read-Path "Full path to shulker_placements.csv"
if (-not (Test-Path $csvPath)) {
    Write-Host "ERROR: File not found: $csvPath" -ForegroundColor Red
    exit 1
}
$folder = Split-Path $csvPath

# embed your mw$default_2.txt header
$tplLines = @(
    '#'
    '#waypoint:name:initials:x:y:z:color:disabled:type:set:rotate_on_tp:tp_yaw:visibility_type:destination'
    '#'
)

# ─────────────────────────────────────────────────────────────────────────────
# 2) Ask spatial parameters
# ─────────────────────────────────────────────────────────────────────────────
$centerX   = Read-Double "Center X coordinate (number)"
$centerZ   = Read-Double "Center Z coordinate (number)"
$horRadius = Read-Double "Horizontal Radius — distance from center (number)"
$cluRadius = Read-Double "Cluster Radius — proximity clustering (number)"

# ─────────────────────────────────────────────────────────────────────────────
# 3) Load CSV once (integer coords)
# ─────────────────────────────────────────────────────────────────────────────
Write-Host "`nLoading CSV..." -ForegroundColor Cyan
$data = Import-Csv $csvPath | ForEach-Object {
    [PSCustomObject]@{
        X           = [int][double]$_.X
        Y           = [int][double]$_.Y
        Z           = [int][double]$_.Z
        block_state = $_.block_state
        created_at  = $_.created_at
        dimension   = $_.dimension
        server_id   = $_.server_id
    }
}
Write-Host "Loaded $($data.Count) entries.`n" -ForegroundColor Cyan

# ─────────────────────────────────────────────────────────────────────────────
# 4) Filter & export loop
# ─────────────────────────────────────────────────────────────────────────────
do {
    $preset = Choose-Preset
    if ($preset.Min -ne $null) {
        $rangeInfo = " (Min=$($preset.Min), Max=$($preset.Max))"
    } else {
        $rangeInfo = ""
    }
    Write-Host "`nPreset: $($preset.Name)$rangeInfo" -ForegroundColor Cyan

    # horizontal filter
    $filtered = $data | Where-Object {
        $dx = $_.X - $centerX; $dz = $_.Z - $centerZ
        [math]::Sqrt($dx*$dx + $dz*$dz) -le $horRadius
    }
    Write-Host "After horizontal filter: $($filtered.Count) entries.`n" -ForegroundColor Cyan

    switch ($preset.Name) {
        'Lone' {
            $grouped = $filtered |
                Group-Object `
                  @{Expression={ [math]::Floor($_.X/16) }}, `
                  @{Expression={ [math]::Floor($_.Z/16) }}
            $results = $grouped |
                Where-Object Count -eq 1 |
                ForEach-Object Group
        }
        'All' {
            $results = $filtered
        }
        default {
            $clusters = Get-Clusters -pts $filtered -r $cluRadius
            $results  = foreach ($cid in $clusters.Keys) {
                $members = $clusters[$cid]; $sz = $members.Count
                if ($sz -ge $preset.Min -and $sz -le $preset.Max) {
                    $pts  = $filtered[$members]
                    $avgX = [int][math]::Round((($pts | Measure-Object -Prop X -Average).Average))
                    $avgY = [int][math]::Round((($pts | Measure-Object -Prop Y -Average).Average))
                    $avgZ = [int][math]::Round((($pts | Measure-Object -Prop Z -Average).Average))
                    [PSCustomObject]@{
                        CentroidX    = $avgX
                        CentroidY    = $avgY
                        CentroidZ    = $avgZ
                        ShulkerCount = $sz
                    }
                }
            }
        }
    }

    # filenames
    $baseName = "{0}_{1}_h{2}_c{3}" -f $centerX,$centerZ,$horRadius,$cluRadius
    $rangePart = ($preset.Min -ne $null) ? "_$($preset.Min)-$($preset.Max)" : ""
    $namePart  = "${baseName}${rangePart}_$($preset.Name)"

    # CSV
    $outCsv = Join-Path $folder "shulker_results_${namePart}.csv"
    Write-Host "Saving $($results.Count) → $outCsv" -ForegroundColor Cyan
    $results | Export-Csv -NoTypeInformation -Path $outCsv -Encoding UTF8

    # TXT
    $outTxt = Join-Path $folder "mw`$default_2_${namePart}.txt"
    Write-Host "Writing TXT waypoints → $outTxt" -ForegroundColor Cyan
    $tplLines | Out-File -FilePath $outTxt -Encoding UTF8

    $i = 0
    foreach ($row in $results) {
        $i++
        if ($row.PSObject.Properties.Name -contains 'CentroidX') {
            $x=$row.CentroidX; $y=$row.CentroidY; $z=$row.CentroidZ
        } else {
            $x=$row.X; $y=$row.Y; $z=$row.Z
        }
        $color = Get-Random -Minimum 1 -Maximum 16
        $line  = "waypoint:shulker${i}:S:${x}:${y}:${z}:${color}:false:0:gui.xaero_default:false:0:0:false"
        Add-Content -Path $outTxt -Value $line
    }

    $again = Read-Host "`nRun another filter? (Y/N)"
    if ($again -match '^[Yy]$') {
        $adj = Read-Host "Adjust radii? (Y/N)"
        if ($adj -match '^[Yy]$') {
            $horRadius = Read-Double "New Horizontal Radius (number)"
            $cluRadius = Read-Double "New Cluster Radius (number)"
        }
    }
} while ($again -match '^[Yy]$')

Write-Host "`n✅ Done! Files in $folder." -ForegroundColor Green


#pwsh D:\nocom\FilterShulkers.ps1

#"D:\nocom\blocks.sql\shulker_placements.csv"

#"D:\nocom\blocks.sql"