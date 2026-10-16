function Main {
    [Console]::OutputEncoding = New-Object Text.UTF8Encoding $false
    $layout = Get-WorktreeLayout -Directory (Get-SessionDirectory)
    if ($null -eq $layout) {
        return
    }

    $report = Get-WorktreeSlotReport @layout
    if ($report) {
        [Console]::Out.WriteLine($report)
    }
}

function Get-SessionDirectory {
    if ($env:CLAUDE_PROJECT_DIR) {
        return $env:CLAUDE_PROJECT_DIR
    }
    return (Get-Location).Path
}

function Get-WorktreeLayout {
    param([string] $Directory)

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
