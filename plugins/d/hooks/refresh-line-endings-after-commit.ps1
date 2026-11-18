$CommitPattern = '(^|[\s;&|(])git(\s+(-C\s+(?<repo>"[^"]+"|\S+)|-c\s+\S+|--[\w-]+(=\S+)?))*\s+commit\b'
$PathsPerGitCall = 100

function Main {
    [Console]::InputEncoding = New-Object Text.UTF8Encoding $false
    $hookInput = [Console]::In.ReadToEnd() | ConvertFrom-Json
    $directory = Get-CommitDirectory -Command ([string] $hookInput.tool_input.command) -WorkingDirectory $hookInput.cwd
    if ($directory) {
        Update-CommittedFiles -Directory $directory
    }
}

function Get-CommitDirectory {
    param([string] $Command, [string] $WorkingDirectory)

    $match = [regex]::Match($Command, $CommitPattern)
    if (-not $match.Success) {
        return $null
    }
    if (-not $match.Groups['repo'].Success) {
        return $WorkingDirectory
    }
    $explicit = $match.Groups['repo'].Value.Trim('"')
    if ([IO.Path]::IsPathRooted($explicit)) {
        return $explicit
    }
    return Join-Path $WorkingDirectory $explicit
}

function Update-CommittedFiles {
    param([string] $Directory)

    # Git skips a file that its index calls up to date, so only a file out of the
    # index gets its line endings from the attributes on checkout.
    # Windows PowerShell throws on redirected git stderr under Stop, for example outside a repo.
    $ErrorActionPreference = 'Continue'
    $root = git -C $Directory rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0) {
        return
    }

    $paths = @(Get-UnchangedCommittedPaths -Root $root)
    for ($start = 0; $start -lt $paths.Count; $start += $PathsPerGitCall) {
        $batch = $paths[$start..([Math]::Min($start + $PathsPerGitCall, $paths.Count) - 1)]
        git --literal-pathspecs -C $root rm -q --cached -- @batch 2>$null
        git --literal-pathspecs -C $root checkout HEAD -- @batch 2>$null
        if ($LASTEXITCODE -ne 0) {
            git --literal-pathspecs -C $root reset -q HEAD -- @batch 2>$null
        }
    }
}

function Get-UnchangedCommittedPaths {
    param([string] $Root)

    # A checkout from HEAD overwrites the file, so a file with changes after the commit stays as it is.
    $committed = Split-GitPaths -Output (git -C $Root diff-tree --root --no-commit-id --name-only -r -z --diff-filter=d HEAD 2>$null)
    $changed = Split-GitPaths -Output (git -C $Root diff --name-only -z HEAD 2>$null)
    return @($committed | Where-Object { $changed -notcontains $_ })
}

function Split-GitPaths {
    param($Output)

    return @(($Output -join "`0") -split "`0" | Where-Object { $_ })
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $ErrorActionPreference = 'Stop'
        Main
    }
    catch {
        # A failure here must never disturb the session; the next commit tries again.
    }
    exit 0
}
