# PostToolUse hook: apply .editorconfig formatting to a .cs file immediately
# after Write or Edit creates or modifies it.
#
# Contract:
#   - Receives JSON on stdin with tool_name, tool_input, tool_response.
#   - Extracts file path from tool_input.file_path (Write/Edit) or
#     tool_response.filePath (Edit fallback).
#   - No-ops unless the file is .cs and the repo has an .editorconfig.
#   - Never blocks and never fails: always exits 0.

$ErrorActionPreference = 'SilentlyContinue'

$json = [Console]::In.ReadToEnd() | ConvertFrom-Json

$filePath = $json.tool_input.file_path
if (-not $filePath) { $filePath = $json.tool_response.filePath }
if (-not $filePath) { exit 0 }

if ([IO.Path]::GetExtension($filePath) -ne '.cs') { exit 0 }
if (-not (Test-Path $filePath)) { exit 0 }

$root = (& git rev-parse --show-toplevel 2>$null)
if (-not $root) { exit 0 }
if (-not (Test-Path (Join-Path $root '.editorconfig'))) { exit 0 }

$target = $null
$sln = Get-ChildItem -Path $root -Filter *.sln -File -ErrorAction SilentlyContinue | Select-Object -First 1
if ($sln) {
    $target = $sln.FullName
}
else {
    $proj = Get-ChildItem -Path $root -Recurse -Filter *.csproj -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($proj) { $target = $proj.FullName }
}
if (-not $target) { exit 0 }

$sw = [Diagnostics.Stopwatch]::StartNew()
& dotnet format $target --include $filePath --no-restore 2>$null
$sw.Stop()

$sessionId = $json.session_id
if ($sessionId) {
    $timingFile = Join-Path $env:TEMP "claude-format-$sessionId.txt"
    "$($sw.ElapsedMilliseconds)`t$filePath" | Out-File -Append -FilePath $timingFile -Encoding utf8
}

exit 0
