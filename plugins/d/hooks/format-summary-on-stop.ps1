$ErrorActionPreference = 'SilentlyContinue'

$json = [Console]::In.ReadToEnd() | ConvertFrom-Json
$sessionId = $json.session_id
if (-not $sessionId) { exit 0 }

$timingFile = Join-Path $env:TEMP "claude-format-$sessionId.txt"
if (-not (Test-Path $timingFile)) { exit 0 }

$lines = @(Get-Content $timingFile | Where-Object { $_ })
Remove-Item $timingFile -Force

$totalMs = 0
foreach ($line in $lines) {
    $ms = ($line -split "`t", 2)[0]
    $totalMs += [int]$ms
}

if ($lines.Count -eq 0) { exit 0 }

$sec = [math]::Round($totalMs / 1000, 1)
$msg = "editorconfig: formatted $($lines.Count) file(s), ${sec}s"
$out = @{ systemMessage = $msg } | ConvertTo-Json -Compress
[Console]::Out.Write($out)

exit 0
