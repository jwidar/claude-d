function Get-SlotCandidate {
    param([string] $Path)

    $leaf = Split-Path -Path $Path -Leaf
    if ($leaf -notmatch '^(?<repo>.+)\.(?<number>\d+)$') {
        return $null
    }

    $repoPath = Join-Path (Split-Path -Path $Path -Parent) $Matches.repo
    $slotNumber = $Matches.number
    if (-not (Test-Path -LiteralPath (Join-Path $repoPath '.git') -PathType Container)) {
        return $null
    }

    return [pscustomobject]@{
        RepoPath   = $repoPath
        SlotNumber = $slotNumber
    }
}

function Get-CopiedWorktreeSource {
    param([string] $Path)

    $dotGit = Join-Path $Path '.git'
    if (-not (Test-Path -LiteralPath $dotGit -PathType Leaf)) {
        return $null
    }

    $link = Get-Content -LiteralPath $dotGit -TotalCount 1
    if ($link -notmatch '^gitdir:\s*(?<adminDir>.+)$') {
        return $null
    }

    $adminDir = Resolve-LinkedPath -Path $Matches.adminDir.Trim() -RelativeTo $Path
    $backLink = Join-Path $adminDir 'gitdir'
    if (-not (Test-Path -LiteralPath $backLink -PathType Leaf)) {
        return $adminDir
    }

    $ownerDotGit = Resolve-LinkedPath -Path (Get-Content -LiteralPath $backLink -TotalCount 1).Trim() -RelativeTo $adminDir
    if ((ConvertTo-ComparablePath -Path $ownerDotGit) -eq (ConvertTo-ComparablePath -Path $dotGit)) {
        return $null
    }

    return Split-Path -Path $ownerDotGit -Parent
}

function Resolve-LinkedPath {
    param([string] $Path, [string] $RelativeTo)

    if ([IO.Path]::IsPathRooted($Path)) {
        return [IO.Path]::GetFullPath($Path)
    }
    return [IO.Path]::GetFullPath((Join-Path $RelativeTo $Path))
}

function ConvertTo-ComparablePath {
    param([string] $Path)

    return [IO.Path]::GetFullPath($Path).Replace('/', '\').TrimEnd('\').ToLowerInvariant()
}

function Resolve-DefaultBranch {
    param([string] $RepoPath)

    $base = & git.exe -C $RepoPath symbolic-ref -q --short refs/remotes/origin/HEAD
    if (-not $base) {
        Invoke-Git -C $RepoPath remote set-head origin --auto | Out-Null
        $base = Invoke-Git -C $RepoPath symbolic-ref --short refs/remotes/origin/HEAD
    }
    return $base
}

function Invoke-Git {
    $output = & git.exe @args 2>&1
    $stderr = @($output | Where-Object { $_ -is [Management.Automation.ErrorRecord] })
    if ($LASTEXITCODE -ne 0) {
        $detail = ($stderr -join ' ') -replace '://[^/\s@]+@', '://***@'
        throw "git $($args -join ' ') failed with exit code $LASTEXITCODE. $detail"
    }
    $output | Where-Object { $_ -isnot [Management.Automation.ErrorRecord] }
}

Export-ModuleMember -Function Get-SlotCandidate, Get-CopiedWorktreeSource, Resolve-DefaultBranch, Invoke-Git
