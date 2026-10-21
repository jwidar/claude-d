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

Export-ModuleMember -Function Get-SlotCandidate, Get-CopiedWorktreeSource
