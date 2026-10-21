Import-Module (Join-Path $PSScriptRoot '..\skills\worktree-slot\WorktreeSlot.psm1') -Force

function Main {
    [Console]::OutputEncoding = New-Object Text.UTF8Encoding $false
    $report = Get-SessionReport -Directory (Get-SessionDirectory)
    if ($report) {
        [Console]::Out.WriteLine($report)
    }
}

function Get-SessionReport {
    param([string] $Directory)

    $copiedFrom = Get-CopiedWorktreeSource -Path $Directory
    if ($copiedFrom) {
        return Get-CopiedFolderReport -Directory $Directory -CopiedFrom $copiedFrom
    }

    $layout = Get-WorktreeLayout -Directory $Directory
    if ($layout) {
        return Get-WorktreeSlotReport @layout
    }

    $candidate = Get-SlotCandidate -Path $Directory
    if ($candidate) {
        return Get-SlotCandidateReport -Directory $Directory -RepoPath $candidate.RepoPath -SlotNumber $candidate.SlotNumber
    }
    return $null
}

function Get-CopiedFolderReport {
    param(
        [string] $Directory
        , [string] $CopiedFrom
    )

    return "Copied slot folder: $Directory has a .git file that belongs to the worktree at $CopiedFrom. " +
        'Git commands here act on that other worktree. Tell the user, do not run git here, and follow the d:worktree-slot skill.'
}

function Get-SlotCandidateReport {
    param(
        [string] $Directory
        , [string] $RepoPath
        , [string] $SlotNumber
    )

    return "Empty slot folder: $Directory can become slot $SlotNumber of $RepoPath. " +
        "If the user says 'new worktree', follow the d:worktree-slot skill."
}

function Get-SessionDirectory {
    if ($env:CLAUDE_PROJECT_DIR) {
        return $env:CLAUDE_PROJECT_DIR
    }
    return (Get-Location).Path
}

function Get-WorktreeLayout {
    param([string] $Directory)

    # Windows PowerShell throws on redirected git stderr under Stop, for example outside a repo.
    $ErrorActionPreference = 'Continue'
    $paths = @(git -C $Directory rev-parse --path-format=absolute --git-dir --git-common-dir --show-toplevel 2>$null)
    if ($LASTEXITCODE -ne 0 -or $paths.Count -ne 3) {
        return $null
    }

    $branch = git -C $Directory symbolic-ref --short -q HEAD 2>$null
    $worktreeCount = @(git -C $Directory worktree list --porcelain 2>$null | Where-Object { $_ -like 'worktree *' }).Count

    return @{
        GitDir        = $paths[0]
        CommonDir     = $paths[1]
        TopLevel      = $paths[2]
        Branch        = [string] $branch
        WorktreeCount = $worktreeCount
    }
}

function Get-WorktreeSlotReport {
    param(
        [string] $GitDir
        , [string] $CommonDir
        , [string] $TopLevel
        , [string] $Branch
        , [int] $WorktreeCount
    )

    $topLevelPath = ConvertTo-WindowsPath -Path $TopLevel
    $mainClonePath = Split-Path -Path (ConvertTo-WindowsPath -Path $CommonDir) -Parent
    $isLinkedWorktree = (ConvertTo-WindowsPath -Path $GitDir) -ne (ConvertTo-WindowsPath -Path $CommonDir)

    if ($isLinkedWorktree) {
        $head = if ($Branch) { "branch '$Branch'" } else { 'detached HEAD' }
        return "Worktree slot: this session runs in slot '$(Split-Path -Path $topLevelPath -Leaf)' of $mainClonePath, on $head. " +
            'Follow the d:worktree-slot skill before you create or switch a branch, commit, stash, or park the slot.'
    }

    if ($WorktreeCount -gt 1) {
        return "Main clone with worktree slots: $topLevelPath has $($WorktreeCount - 1) slot(s). " +
            'Follow the d:worktree-slot skill before you edit, switch a branch, or change a worktree here.'
    }

    return $null
}

function ConvertTo-WindowsPath {
    param([string] $Path)

    return $Path.Replace('/', '\').TrimEnd('\')
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $ErrorActionPreference = 'Stop'
        Main
    }
    catch {
        # A failure here must never block the session start.
    }
    exit 0
}
