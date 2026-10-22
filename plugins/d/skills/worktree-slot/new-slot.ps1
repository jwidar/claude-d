param(
    [Parameter(Mandatory)] [string] $Path
)

Import-Module (Join-Path $PSScriptRoot 'WorktreeSlot.psm1') -Force

function Main {
    $slotPath = [IO.Path]::GetFullPath($Path)
    $repoPath = Assert-SlotCanBeCreated -SlotPath $slotPath
    Invoke-Git -C $repoPath fetch -q origin
    $base = Resolve-DefaultBranch -RepoPath $repoPath
    Assert-NoTrackedFileInTheWay -SlotPath $slotPath -RepoPath $repoPath -Base $base
    Add-WorktreeInPlace -SlotPath $slotPath -RepoPath $repoPath -Base $base
    Copy-LocalClaudeFiles -From $repoPath -To $slotPath

    Write-Output "Slot $slotPath is ready as a worktree of $repoPath, parked on a detached $base."
    Write-Output 'Restart the Claude session in this folder, so that the project instructions and hooks load.'
}

function Assert-SlotCanBeCreated {
    param([string] $SlotPath)

    $copiedFrom = Get-CopiedWorktreeSource -Path $SlotPath
    if ($copiedFrom) {
        throw "$SlotPath is a copy of the worktree at $copiedFrom. Make an empty folder instead."
    }
    if (Test-Path -LiteralPath (Join-Path $SlotPath '.git')) {
        throw "$SlotPath is already a git repository or worktree."
    }

    $candidate = Get-SlotCandidate -Path $SlotPath
    if (-not $candidate) {
        throw "$SlotPath must be named <repo>.<number>, next to the main clone <repo>."
    }
    return $candidate.RepoPath
}

function Assert-NoTrackedFileInTheWay {
    param(
        [string] $SlotPath
        , [string] $RepoPath
        , [string] $Base
    )

    $existing = @(Get-ChildItem -LiteralPath $SlotPath -Recurse -File -Force |
        ForEach-Object { $_.FullName.Substring($SlotPath.Length + 1).Replace('\', '/') })
    if ($existing.Count -eq 0) {
        return
    }

    $tracked = @(Invoke-Git -C $RepoPath ls-tree -r --name-only $Base -- @existing)
    if ($tracked.Count -gt 0) {
        throw "These files in $SlotPath are tracked by git and would be overwritten: $($tracked -join ', ')"
    }
}

function Add-WorktreeInPlace {
    param(
        [string] $SlotPath
        , [string] $RepoPath
        , [string] $Base
    )

    $staging = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
    $stagedSlot = Join-Path $staging (Split-Path -Path $SlotPath -Leaf)
    try {
        Invoke-Git -C $RepoPath worktree add -q --no-checkout --detach $stagedSlot $Base | Out-Null
        Move-Item -LiteralPath (Join-Path $stagedSlot '.git') -Destination (Join-Path $SlotPath '.git')
        Invoke-Git -C $RepoPath worktree repair $SlotPath | Out-Null
    }
    finally {
        Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
    }
    Invoke-Git -C $SlotPath reset -q --hard | Out-Null
}

function Copy-LocalClaudeFiles {
    param(
        [string] $From
        , [string] $To
    )

    $sourceDir = Join-Path $From '.claude'
    if (-not (Test-Path -LiteralPath $sourceDir)) {
        return
    }

    $targetDir = Join-Path $To '.claude'
    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    foreach ($file in Get-ChildItem -LiteralPath $sourceDir -File -Filter '*.local.*') {
        $target = Join-Path $targetDir $file.Name
        if (Test-Path -LiteralPath $target) {
            continue
        }
        Copy-Item -LiteralPath $file.FullName -Destination $target
        Remove-AdoPatLine -Path $target
    }
}

function Remove-AdoPatLine {
    param([string] $Path)

    $lines = [IO.File]::ReadAllLines($Path)
    $kept = @($lines | Where-Object { $_ -notmatch '^\s*ado_pat\s*:' })
    if ($kept.Count -ne $lines.Count) {
        [IO.File]::WriteAllLines($Path, [string[]] $kept, (New-Object Text.UTF8Encoding $false))
    }
}

try {
    Main
}
catch {
    Write-Output "No slot was created: $($_.Exception.Message)"
    exit 1
}
