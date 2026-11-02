$CommitPattern = '(^|[\s;&|(])git(\s+(-C\s+(?<repo>"[^"]+"|\S+)|-c\s+\S+|--[\w-]+(=\S+)?))*\s+commit\b'
$EolEntryPattern = '^i/(?<index>\S*)\s+w/(?<working>\S*)\s+attr/(?<attributes>.*?)\s*\t(?<path>.+)$'
$AllBytes = [Text.Encoding]::GetEncoding(28591)
$PathsPerGitCall = 100

function Main {
    [Console]::InputEncoding = New-Object Text.UTF8Encoding $false
    [Console]::OutputEncoding = New-Object Text.UTF8Encoding $false
    $hookInput = [Console]::In.ReadToEnd() | ConvertFrom-Json
    $directory = Get-CommitDirectory -Command ([string] $hookInput.tool_input.command) -WorkingDirectory $hookInput.cwd
    if ($directory) {
        Repair-ChangedFiles -Directory $directory
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

function Repair-ChangedFiles {
    param([string] $Directory)

    # Windows PowerShell throws on redirected git stderr under Stop, for example outside a repo.
    $ErrorActionPreference = 'Continue'
    $root = git -C $Directory rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0) {
        return
    }

    $autoCrlf = git -C $root config core.autocrlf
    $coreEol = git -C $root config core.eol
    foreach ($entry in Get-ChangedFileEntries -Root $root) {
        $match = [regex]::Match($entry, $EolEntryPattern)
        if (-not $match.Success) {
            continue
        }
        $wanted = Get-WantedEnding -Index $match.Groups['index'].Value -Working $match.Groups['working'].Value `
            -Attributes $match.Groups['attributes'].Value -AutoCrlf $autoCrlf -CoreEol $coreEol
        if ($wanted -and $wanted -ne $match.Groups['working'].Value) {
            Convert-LineEndings -Path (Join-Path $root $match.Groups['path'].Value) -Ending $wanted
        }
    }
}

function Get-ChangedFileEntries {
    param([string] $Root)

    $paths = @(Get-ChangedPaths -Root $Root)
    for ($start = 0; $start -lt $paths.Count; $start += $PathsPerGitCall) {
        $batch = $paths[$start..([Math]::Min($start + $PathsPerGitCall, $paths.Count) - 1)]
        Split-GitPaths -Output (git --literal-pathspecs -C $Root ls-files --eol -z --cached --others --exclude-standard -- @batch 2>$null)
    }
}

function Get-ChangedPaths {
    param([string] $Root)

    $output = @(
        git -C $Root diff --name-only -z HEAD 2>$null
        git -C $Root diff --name-only -z --cached 2>$null
        git -C $Root ls-files -z --others --exclude-standard 2>$null
    )
    return @(Split-GitPaths -Output $output | Sort-Object -Unique)
}

function Split-GitPaths {
    param($Output)

    return @(($Output -join "`0") -split "`0" | Where-Object { $_ })
}

function Get-WantedEnding {
    param(
        [string] $Index
        , [string] $Working
        , [string] $Attributes
        , [string] $AutoCrlf
        , [string] $CoreEol
    )

    # Git does not normalize a file stored with CRLF, so a change here would show as a whole-file diff.
    if ($Working -notin 'lf', 'crlf', 'mixed' -or $Index -notin '', 'lf', 'none') {
        return $null
    }
    if ($Attributes -match '(^|\s)-text') {
        return $null
    }
    if ($Attributes -match 'eol=(?<ending>crlf|lf)') {
        return $Matches['ending']
    }
    if ($AutoCrlf -eq 'true') {
        return 'crlf'
    }
    if ($AutoCrlf -eq 'input') {
        return 'lf'
    }
    if ($Attributes -notmatch '(^|\s)text') {
        return $null
    }
    if ($CoreEol -in 'crlf', 'lf') {
        return $CoreEol
    }
    return $(if ([Environment]::NewLine -eq "`r`n") { 'crlf' } else { 'lf' })
}

function Convert-LineEndings {
    param([string] $Path, [string] $Ending)

    $newLine = if ($Ending -eq 'crlf') { "`r`n" } else { "`n" }
    $text = [IO.File]::ReadAllText($Path, $AllBytes)
    [IO.File]::WriteAllText($Path, ($text -replace "`r?`n", $newLine), $AllBytes)
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $ErrorActionPreference = 'Stop'
        Main
    }
    catch {
        # A failure here must never block the commit.
    }
    exit 0
}
