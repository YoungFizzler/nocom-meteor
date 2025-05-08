# Split-Blocks.ps1

# 1) Configuration
$input     = 'D:\nocom\blocks.sql\blocks.sql'
$outDir    = 'D:\nocom\blocks.sql'
$baseName  = 'blocks.sql.part'
$maxBytes  = 1690 * 1024 * 1024    # ~1.69 GiB
$enc       = [System.Text.Encoding]::UTF8

# 2) Helper to open a new writer for part N
function New-Writer([int]$part) {
    $fn = Join-Path $outDir ("{0}{1:000}.sql" -f $baseName, $part)
    return [System.IO.File]::CreateText($fn)
}

# 3) Open the input and first output
$reader       = [System.IO.File]::OpenText($input)
$partIndex    = 0
$writer       = New-Writer $partIndex
$currentBytes = 0

try {
    while (($line = $reader.ReadLine()) -ne $null) {
        # count this line + newline in bytes
        $bytes = $enc.GetByteCount($line + "`n")
        
        # if adding it would overflow, roll to the next part
        if ($currentBytes + $bytes -gt $maxBytes) {
            $writer.Close()
            $partIndex++
            $writer       = New-Writer $partIndex
            $currentBytes = 0
        }
        
        # write the line and update the counter
        $writer.WriteLine($line)
        $currentBytes += $bytes
    }
}
finally {
    $reader.Close()
    $writer.Close()
}

Write-Output "Split complete: created $($partIndex+1) files in $outDir"

#Set-ExecutionPolicy -Scope Process Bypass -Force
#& 'D:\nocom\Split-Blocks.ps1'
