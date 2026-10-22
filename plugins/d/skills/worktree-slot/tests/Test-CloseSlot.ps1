$skillDir = Split-Path -Path $PSScriptRoot -Parent
$newSlot = Join-Path $skillDir 'new-slot.ps1'
$closeSlot = Join-Path $skillDir 'close-slot.ps1'
$root = Join-Path ([IO.Path]::GetTempPath()) "worktree-slot-test-$([guid]::NewGuid())"
$failures = 0

function Invoke-QuietGit {
    & git.exe -c user.name=test -c user.email=test@example.invalid @args *> $null
}

function Get-Head {
    param([string] $RepoPath)

    return & git.exe -C $RepoPath rev-parse HEAD
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
    Set-Content -LiteralPath (Join-Path $seed '.gitignore') -Value '.claude/*.local.*'
    Invoke-QuietGit -C $seed add README.md .gitignore
    Invoke-QuietGit -C $seed commit -m init
    Invoke-QuietGit clone --bare $seed (Join-Path $root 'origin.git')
    Invoke-QuietGit clone (Join-Path $root 'origin.git') (Join-Path $root 'Example')
    Invoke-QuietGit clone (Join-Path $root 'origin.git') (Join-Path $root 'upstream')

    $claudeDir = Join-Path $root 'Example\.claude'
    New-Item -ItemType Directory -Force -Path $claudeDir | Out-Null
    Set-Content -LiteralPath (Join-Path $claudeDir 'settings.local.json') -Value '{}'
}

function Add-Commit {
    param([string] $RepoPath, [string] $FileName)

    Set-Content -LiteralPath (Join-Path $RepoPath $FileName) -Value $FileName
    Invoke-QuietGit -C $RepoPath add $FileName
    Invoke-QuietGit -C $RepoPath commit -m $FileName
}

function Publish-UpstreamCommit {
    param([string] $FileName)

    $upstream = Join-Path $root 'upstream'
    Invoke-QuietGit -C $upstream pull -q
    Add-Commit -RepoPath $upstream -FileName $FileName
    Invoke-QuietGit -C $upstream push -q origin master
}

New-TestRepo
$main = Join-Path $root 'Example'
$slot = Join-Path $root 'Example.1'
New-Item -ItemType Directory -Force -Path $slot | Out-Null
powershell -NoProfile -File $newSlot -Path $slot | Out-Null

$output = powershell -NoProfile -File $closeSlot -Path $main
Assert-That 'close slot: main clone is refused' (($LASTEXITCODE -eq 1) -and (($output -join ' ') -like '*not a worktree slot*')) ($output -join ' ')

Add-Commit -RepoPath $slot -FileName 'orphan.txt'
$orphanHead = Get-Head -RepoPath $slot
$output = powershell -NoProfile -File $closeSlot -Path $slot
Assert-That 'close slot: commit on no branch is refused' (($LASTEXITCODE -eq 1) -and (($output -join ' ') -like '*no branch holds*')) ($output -join ' ')
Assert-That 'close slot: refused slot keeps its HEAD' ((Get-Head -RepoPath $slot) -eq $orphanHead) 'HEAD moved'
Invoke-QuietGit -C $slot switch -q --detach origin/master

Invoke-QuietGit -C $slot switch -q --no-track -c work origin/master
Set-Content -LiteralPath (Join-Path $slot 'new.txt') -Value 'untracked'
$output = powershell -NoProfile -File $closeSlot -Path $slot
Assert-That 'close slot: untracked file is refused' (($LASTEXITCODE -eq 1) -and (($output -join ' ') -like '*untracked*')) ($output -join ' ')
Assert-That 'close slot: refused slot stays on its branch' ((& git.exe -C $slot branch --show-current) -eq 'work') 'branch changed'
Remove-Item -LiteralPath (Join-Path $slot 'new.txt')

Add-Commit -RepoPath $slot -FileName 'work.txt'
Invoke-QuietGit -C $slot push -q -u origin work
Publish-UpstreamCommit -FileName 'merged.txt'
$output = powershell -NoProfile -File $closeSlot -Path $slot
$originMaster = & git.exe -C $main rev-parse origin/master
Assert-That 'close slot: pushed work closes' ($LASTEXITCODE -eq 0) ($output -join ' ')
Assert-That 'close slot: slot is parked on origin/master' (((Get-Head -RepoPath $slot) -eq $originMaster) -and -not (& git.exe -C $slot symbolic-ref -q HEAD)) ($output -join ' ')
Assert-That 'close slot: main clone is fast-forwarded' ((Get-Head -RepoPath $main) -eq $originMaster) ($output -join ' ')
Assert-That 'close slot: report names the fast-forward' (($output -join ' ') -like '*fast-forwarded on master*') ($output -join ' ')
Assert-That 'close slot: work branch is kept' ([bool](& git.exe -C $main rev-parse -q --verify refs/heads/work)) 'branch deleted'
Assert-That 'close slot: pushed work gives no warning' (-not (($output -join ' ') -like '*on no remote branch*')) ($output -join ' ')

Invoke-QuietGit -C $slot switch -q --no-track -c local-only origin/master
Add-Commit -RepoPath $slot -FileName 'local.txt'
Publish-UpstreamCommit -FileName 'later.txt'
$mainBefore = Get-Head -RepoPath $main
Set-Content -LiteralPath (Join-Path $main 'README.md') -Value 'edited'
$output = powershell -NoProfile -File $closeSlot -Path $slot
Assert-That 'close slot: unpushed work still closes' ($LASTEXITCODE -eq 0) ($output -join ' ')
Assert-That 'close slot: unpushed commit is reported' (($output -join ' ') -like '*local-only has 1 commit(s) that are on no remote branch*') ($output -join ' ')
Assert-That 'close slot: dirty main clone is skipped' (($output -join ' ') -like '*was not updated: it has 1 changed file(s)*') ($output -join ' ')
Assert-That 'close slot: dirty main clone keeps its HEAD' ((Get-Head -RepoPath $main) -eq $mainBefore) 'main clone moved'

Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
exit $failures
