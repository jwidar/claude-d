. "$PSScriptRoot/../../repair-line-endings-before-commit.ps1"

$repo = Join-Path ([IO.Path]::GetTempPath()) "repair-eol-$([guid]::NewGuid().ToString('N'))"
git init --quiet --initial-branch=master $repo
git -C $repo config user.name 'Fixture'
git -C $repo config user.email 'fixture@example.com'
git -C $repo config core.autocrlf true
git -C $repo config core.safecrlf false

function Set-Bytes {
    param([string] $Name, [string] $Text)

    [IO.File]::WriteAllText((Join-Path $repo $Name), $Text, [Text.Encoding]::GetEncoding(28591))
}

function Get-Bytes {
    param([string] $Name)

    return [IO.File]::ReadAllText((Join-Path $repo $Name), [Text.Encoding]::GetEncoding(28591))
}

Set-Bytes -Name '.gitattributes' -Text "* text=auto`n*.ps1 text eol=crlf`n*.sh text eol=lf`n*.raw -text`n"
Set-Bytes -Name 'tracked.md' -Text "one`r`ntwo`r`n"
Set-Bytes -Name 'untouched.md' -Text "one`r`ntwo`r`n"
Set-Bytes -Name 'tracked.raw' -Text "one`ntwo`n"
git -C $repo add -A 2>$null
git -C $repo commit --quiet -m 'Base'

Set-Bytes -Name 'tracked.md' -Text "one`r`ntwo`r`nthree`n"
Set-Bytes -Name 'new.ps1' -Text "one`ntwo`n"
Set-Bytes -Name 'new.sh' -Text "one`r`ntwo`r`n"
Set-Bytes -Name 'staged.md' -Text "one`ntwo`n"
git -C $repo add staged.md 2>$null
Set-Bytes -Name 'tracked.raw' -Text "one`ntwo`r`nthree`n"
Set-Bytes -Name 'utf8.md' -Text "$([char] 0xC3)$([char] 0xA5)`n"
Set-Bytes -Name 'untouched.md' -Text "one`r`ntwo`r`n"

$cases = @(
    @{ Name = 'mixed tracked file becomes CRLF'; File = 'tracked.md'; Expected = "one`r`ntwo`r`nthree`r`n" }
    @{ Name = 'new file with eol=crlf becomes CRLF'; File = 'new.ps1'; Expected = "one`r`ntwo`r`n" }
    @{ Name = 'new file with eol=lf becomes LF'; File = 'new.sh'; Expected = "one`ntwo`n" }
    @{ Name = 'staged LF file becomes CRLF'; File = 'staged.md'; Expected = "one`r`ntwo`r`n" }
    @{ Name = '-text file stays as it is'; File = 'tracked.raw'; Expected = "one`ntwo`r`nthree`n" }
    @{ Name = 'non-ASCII bytes survive'; File = 'utf8.md'; Expected = "$([char] 0xC3)$([char] 0xA5)`r`n" }
)

$wantedCases = @(
    @{ Name = 'stored CRLF is left alone'; Index = 'crlf'; Working = 'mixed'; Attributes = 'text=auto'; AutoCrlf = 'true'; Expected = $null }
    @{ Name = 'binary is left alone'; Index = ''; Working = '-text'; Attributes = 'text=auto'; AutoCrlf = 'true'; Expected = $null }
    @{ Name = 'no attribute and no autocrlf is left alone'; Index = ''; Working = 'mixed'; Attributes = ''; AutoCrlf = 'false'; Expected = $null }
    @{ Name = 'no attribute with autocrlf true'; Index = 'lf'; Working = 'lf'; Attributes = ''; AutoCrlf = 'true'; Expected = 'crlf' }
    @{ Name = 'autocrlf input'; Index = 'lf'; Working = 'crlf'; Attributes = 'text=auto'; AutoCrlf = 'input'; Expected = 'lf' }
)

$commandCases = @(
    @{ Name = 'plain commit'; Command = 'git commit -m "Add"'; Expected = 'C:\work' }
    @{ Name = 'explicit repo'; Command = 'git -C "C:\other" commit -m "Add"'; Expected = 'C:\other' }
    @{ Name = 'add then commit'; Command = 'git add . && git commit -m "Add"'; Expected = 'C:\work' }
    @{ Name = 'not a commit'; Command = 'git log --grep=commit'; Expected = $null }
)

$failures = 0
function Write-Result {
    param([string] $Name, [bool] $Passed, $Actual)

    if ($Passed) {
        Write-Output "PASS  $Name"
    }
    else {
        Write-Output "FAIL  $Name -> $Actual"
        $script:failures++
    }
}

try {
    $beforeBlobs = git -C $repo ls-files --stage untouched.md
    $untouchedBefore = (Get-Item (Join-Path $repo 'untouched.md')).LastWriteTimeUtc
    Repair-ChangedFiles -Directory $repo

    foreach ($case in $cases) {
        $actual = Get-Bytes -Name $case.File
        Write-Result -Name $case.Name -Passed ($actual -ceq $case.Expected) -Actual ($actual -replace "`r", '\r' -replace "`n", '\n')
    }
    Write-Result -Name 'unchanged file is not rewritten' -Passed ((Get-Item (Join-Path $repo 'untouched.md')).LastWriteTimeUtc -eq $untouchedBefore) -Actual 'rewritten'
    Write-Result -Name 'index is not changed' -Passed ((git -C $repo ls-files --stage untouched.md) -eq $beforeBlobs) -Actual 'changed'
    $mixed = @(git -C $repo ls-files --eol --cached --others --exclude-standard | Where-Object { $_ -match 'w/mixed' -and $_ -notmatch 'tracked\.raw' })
    Write-Result -Name 'no mixed file remains' -Passed ($mixed.Count -eq 0) -Actual ($mixed -join ' | ')

    foreach ($case in $wantedCases) {
        $actual = Get-WantedEnding -Index $case.Index -Working $case.Working -Attributes $case.Attributes -AutoCrlf $case.AutoCrlf -CoreEol ''
        Write-Result -Name $case.Name -Passed ($actual -eq $case.Expected) -Actual $actual
    }
    foreach ($case in $commandCases) {
        $actual = Get-CommitDirectory -Command $case.Command -WorkingDirectory 'C:\work'
        Write-Result -Name $case.Name -Passed ($actual -eq $case.Expected) -Actual $actual
    }
}
finally {
    Remove-Item -LiteralPath $repo -Recurse -Force
}
exit $failures
