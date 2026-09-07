# Shared helper: resolve a path to the casing the filesystem actually stores.
#
# Dot-sourced by two callers, which is why it lives in its own file rather than
# being written twice:
#   - hooks/warn-noncanonical-cwd.ps1, via $PSScriptRoot
#   - the PowerShell profile block that setup.ps1 generates, via the repo path
#     baked in at install time
#
# Windows paths are case-insensitive but case-PRESERVING, so the only way to
# learn a path's real casing is to ask each parent directory for its child's
# name. That is what the loop below does.

function Get-TrueCasePath {
    <#
    .SYNOPSIS
        Returns $Path with the casing the filesystem stores, or $null.
    .DESCRIPTION
        Handles files and directories, absolute and relative. Returns $null when
        the path does not exist, is not a filesystem path, or cannot be resolved
        for any other reason, so every caller decides its own fallback.

        Uses Convert-Path, not [System.IO.Path]::GetFullPath: .NET resolves a
        relative path against the PROCESS working directory, which in PowerShell
        is not the same as Get-Location, so GetFullPath('myproject') silently
        resolves against the wrong base.
    #>
    param([string] $Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    if (-not (Test-Path -LiteralPath $Path)) { return $null }

    try {
        $full = Convert-Path -LiteralPath $Path -ErrorAction Stop
        $leaf = $null

        if (Test-Path -LiteralPath $full -PathType Leaf) {
            $file = New-Object System.IO.FileInfo($full)
            $match = $file.Directory.GetFiles($file.Name)
            if ($match.Count -eq 0) { return $null }
            $leaf = $match[0].Name
            $full = $file.DirectoryName
        }

        $dir = New-Object System.IO.DirectoryInfo($full)
        $segments = @()
        while ($null -ne $dir.Parent) {
            $match = $dir.Parent.GetDirectories($dir.Name)
            if ($match.Count -eq 0) { return $null }
            $segments = , $match[0].Name + $segments
            $dir = $dir.Parent
        }

        # $dir is now the root (e.g. "C:\"); drives are conventionally upper-case.
        $result = $dir.Name.ToUpperInvariant().TrimEnd('\') + '\' + ($segments -join '\')
        if ($null -ne $leaf) { $result = Join-Path $result $leaf }
        return $result
    } catch {
        return $null
    }
}
