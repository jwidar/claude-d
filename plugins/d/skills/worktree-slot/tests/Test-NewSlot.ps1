$skillDir = Split-Path -Path $PSScriptRoot -Parent
$newSlot = Join-Path $skillDir 'new-slot.ps1'
$hook = Join-Path $skillDir '..\..\hooks\report-worktree-slot.ps1'
$root = Join-Path ([IO.Path]::GetTempPath()) "worktree-slot-test-$([guid]::NewGuid())"
$failures = 0

function Invoke-QuietGit {
    & git.exe -c user.name=test -c user.email=test@example.invalid @args *> $null
}

function Get-HookReport {
    param([string] $Directory)

    $env:CLAUDE_PROJECT_DIR = $Directory
    return (powershell -NoProfile -File $hook) -join ' '
}

function Assert-That {
    param([string] $Name, [bool] $Condition, [string] $Detail)

    if ($Condition) {
        Write-Output "PASS  $Name"
    }
    else {
        Write-Output "FAIL  $Name -> $Detail"
        $script:failures++
    }
}

function New-TestRepo {
    $seed = Join-Path $root 'seed'
    New-Item -ItemType Directory -Force -Path $seed | Out-Null
    Invoke-QuietGit -C $seed init -b master
    Set-Content -LiteralPath (Join-Path $seed 'README.md') -Value 'test'
    Invoke-QuietGit -C $seed add README.md
    Invoke-QuietGit -C $seed commit -m init
    Invoke-QuietGit clone --bare $seed (Join-Path $root 'origin.git')
    Invoke-QuietGit clone (Join-Path $root 'origin.git') (Join-Path $root 'Example')

    $claudeDir = Join-Path $root 'Example\.claude'
    New-Item -ItemType Directory -Force -Path $claudeDir | Out-Null
    Set-Content -LiteralPath (Join-Path $claudeDir 'monitor-devops.local.md') -Value @('---', 'ado_project: Example', 'ado_pat: secret', '---')
}

New-TestRepo

$slot = Join-Path $root 'Example.3'
New-Item -ItemType Directory -Force -Path (Join-Path $slot '.claude') | Out-Null
Set-Content -LiteralPath (Join-Path $slot '.claude\settings.local.json') -Value '{ "kept": true }'
$report = Get-HookReport -Directory $slot
Assert-That 'hook: empty folder is a slot candidate' ($report -like "Empty slot folder:*slot 3 of*Example.*") $report

$output = powershell -NoProfile -File $newSlot -Path $slot
Assert-That 'new slot: succeeds' ($LASTEXITCODE -eq 0) ($output -join ' ')
Assert-That 'new slot: files checked out' (Test-Path -LiteralPath (Join-Path $slot 'README.md')) 'README.md missing'
Assert-That 'new slot: HEAD is detached' (-not (& git.exe -C $slot symbolic-ref -q HEAD)) 'HEAD is on a branch'
Assert-That 'new slot: existing local file kept' ((Get-Content -LiteralPath (Join-Path $slot '.claude\settings.local.json')) -eq '{ "kept": true }') 'settings.local.json changed'
$devops = Get-Content -LiteralPath (Join-Path $slot '.claude\monitor-devops.local.md')
Assert-That 'new slot: local file copied without ado_pat' (($devops -contains 'ado_project: Example') -and -not ($devops -match 'ado_pat')) ($devops -join ' | ')
$report = Get-HookReport -Directory $slot
Assert-That 'hook: new slot is reported as a slot' ($report -like "Worktree slot:*slot 'Example.3'*detached HEAD*") $report

$copy = Join-Path $root 'Example.4'
Copy-Item -LiteralPath $slot -Destination $copy -Recurse
$report = Get-HookReport -Directory $copy
Assert-That 'hook: copied folder is reported as a copy' ($report -like "Copied slot folder:*Example.3*") $report
$output = powershell -NoProfile -File $newSlot -Path $copy
Assert-That 'new slot: copied folder is refused' (($LASTEXITCODE -eq 1) -and (($output -join ' ') -like '*is a copy of*')) ($output -join ' ')

$blocked = Join-Path $root 'Example.5'
New-Item -ItemType Directory -Force -Path $blocked | Out-Null
Set-Content -LiteralPath (Join-Path $blocked 'README.md') -Value 'local'
$output = powershell -NoProfile -File $newSlot -Path $blocked
Assert-That 'new slot: tracked file in the way is refused' (($LASTEXITCODE -eq 1) -and (($output -join ' ') -like '*README.md*')) ($output -join ' ')
Assert-That 'new slot: refused folder is not a worktree' (-not (Test-Path -LiteralPath (Join-Path $blocked '.git'))) '.git exists'

$orphan = Join-Path $root 'Other.1'
New-Item -ItemType Directory -Force -Path $orphan | Out-Null
$output = powershell -NoProfile -File $newSlot -Path $orphan
Assert-That 'new slot: folder without main clone is refused' (($LASTEXITCODE -eq 1) -and (($output -join ' ') -like '*must be named*')) ($output -join ' ')
Assert-That 'hook: folder without main clone is silent' ([string]::IsNullOrEmpty((Get-HookReport -Directory $orphan))) 'hook reported something'

Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
exit $failures
