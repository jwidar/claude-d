param(
    [Parameter(Mandatory)] [string] $Path
)

Import-Module (Join-Path $PSScriptRoot 'WorktreeSlot.psm1') -Force

function Main {
    $slotPath = [IO.Path]::GetFullPath($Path)
    $mainClonePath = Assert-SlotCanBeClosed -SlotPath $slotPath
    $unpushedReport = Get-UnpushedCommitReport -SlotPath $slotPath

    Invoke-Git -C $slotPath fetch -q origin
    $base = Resolve-DefaultBranch -RepoPath $mainClonePath
    Write-Output (Set-SlotParked -SlotPath $slotPath -Base $base)
    if ($unpushedReport) {
        Write-Output $unpushedReport
    }
    Write-Output (Update-MainClone -MainClonePath $mainClonePath -Base $base)
}

function Assert-SlotCanBeClosed {
    param([string] $SlotPath)

    $copiedFrom = Get-CopiedWorktreeSource -Path $SlotPath
    if ($copiedFrom) {
        throw "$SlotPath is a copy of the worktree at $copiedFrom. Git here would change that worktree."
    }

    $gitDir, $commonDir = Invoke-Git -C $SlotPath rev-parse --path-format=absolute --git-dir --git-common-dir
    if ($gitDir -eq $commonDir) {
        throw "$SlotPath is not a worktree slot."
    }

    $changes = @(Invoke-Git -C $SlotPath status --porcelain)
    if ($changes.Count -gt 0) {
        throw "$SlotPath has $($changes.Count) changed or untracked file(s)."
    }

    $commitsOnNoBranch = @(Invoke-Git -C $SlotPath rev-list HEAD --not --branches --remotes)
    if ($commitsOnNoBranch.Count -gt 0) {
        throw "$SlotPath has $($commitsOnNoBranch.Count) commit(s) on a detached HEAD that no branch holds. Make a branch for them first."
    }

    return Split-Path -Path $commonDir -Parent
}

function Get-UnpushedCommitReport {
    param([string] $SlotPath)

    $branch = & git.exe -C $SlotPath symbolic-ref -q --short HEAD
    if (-not $branch) {
        return $null
    }

    $count = [int](Invoke-Git -C $SlotPath rev-list --count HEAD --not --remotes)
    if ($count -eq 0) {
        return $null
    }
    return "Branch $branch has $count commit(s) that are on no remote branch. The branch is kept."
}

function Set-SlotParked {
    param(
        [string] $SlotPath
        , [string] $Base
    )

    $from = Get-HeadDescription -RepoPath $SlotPath
    Invoke-Git -C $SlotPath switch -q --detach $Base | Out-Null
    $to = Invoke-Git -C $SlotPath rev-parse --short HEAD
    return "Slot $SlotPath is parked on a detached $Base at $to. It was on $from."
}

function Update-MainClone {
    param(
        [string] $MainClonePath
        , [string] $Base
    )

    $defaultBranch = $Base -replace '^origin/', ''
    $blocker = Get-FastForwardBlocker -MainClonePath $MainClonePath -DefaultBranch $defaultBranch
    if ($blocker) {
        return "Main clone $MainClonePath was not updated: $blocker"
    }

    $before = Invoke-Git -C $MainClonePath rev-parse --short HEAD
    try {
        Invoke-Git -C $MainClonePath merge -q --ff-only $Base | Out-Null
    }
    catch {
        return "Main clone $MainClonePath was not updated: $($_.Exception.Message) Run git status there."
    }
    $after = Invoke-Git -C $MainClonePath rev-parse --short HEAD

    if ($before -eq $after) {
        return "Main clone $MainClonePath is already current on $defaultBranch at $after."
    }
    return "Main clone $MainClonePath is fast-forwarded on $defaultBranch from $before to $after."
}

function Get-FastForwardBlocker {
    param(
        [string] $MainClonePath
        , [string] $DefaultBranch
    )

    $branch = & git.exe -C $MainClonePath symbolic-ref -q --short HEAD
    if ($branch -ne $DefaultBranch) {
        return "it is on $(Get-HeadDescription -RepoPath $MainClonePath), not on $DefaultBranch."
    }

    $changes = @(Invoke-Git -C $MainClonePath status --porcelain --untracked-files=no)
    if ($changes.Count -gt 0) {
        return "it has $($changes.Count) changed file(s)."
    }
    return $null
}

function Get-HeadDescription {
    param([string] $RepoPath)

    $branch = & git.exe -C $RepoPath symbolic-ref -q --short HEAD
    $commit = Invoke-Git -C $RepoPath rev-parse --short HEAD
    if ($branch) {
        return "branch $branch at $commit"
    }
    return "a detached HEAD at $commit"
}

try {
    Main
}
catch {
    Write-Output "The slot was not closed: $($_.Exception.Message)"
    exit 1
}
