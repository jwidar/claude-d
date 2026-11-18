. "$PSScriptRoot/../../refresh-line-endings-after-commit.ps1"

$repo = Join-Path ([IO.Path]::GetTempPath()) "refresh-eol-$([guid]::NewGuid().ToString('N'))"
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

Set-Bytes -Name '.gitattributes' -Text "* text=auto`n*.sh text eol=lf`n"
Set-Bytes -Name 'base.md' -Text "one`r`n"
git -C $repo add -A 2>$null
git -C $repo commit --quiet -m 'Base'

Set-Bytes -Name 'whole-lf.md' -Text "one`ntwo`n"
Set-Bytes -Name 'mixed.md' -Text "one`r`ntwo`n"
Set-Bytes -Name 'script.sh' -Text "one`r`ntwo`r`n"
Set-Bytes -Name 'edited-after.md' -Text "one`ntwo`n"
git -C $repo add -A 2>$null
git -C $repo commit --quiet -m 'Change'
Set-Bytes -Name 'edited-after.md' -Text "one`ntwo`nthree`n"

$cases = @(
    @{ Name = 'whole-lf.md'; Expected = "one`r`ntwo`r`n" }
    @{ Name = 'mixed.md'; Expected = "one`r`ntwo`r`n" }
    @{ Name = 'script.sh'; Expected = "one`ntwo`n" }
    @{ Name = 'edited-after.md'; Expected = "one`ntwo`nthree`n" }
)

$failures = 0
try {
    Update-CommittedFiles -Directory $repo
    foreach ($case in $cases) {
        $actual = Get-Bytes -Name $case.Name
        if ($actual -ceq $case.Expected) {
            Write-Output "PASS  $($case.Name)"
        }
        else {
            Write-Output "FAIL  $($case.Name) -> $($actual -replace "`r", '\r' -replace "`n", '\n')"
            $failures++
        }
    }
    $status = git -C $repo status --porcelain
    if ($status -eq ' M edited-after.md') {
        Write-Output 'PASS  index unchanged'
    }
    else {
        Write-Output "FAIL  index unchanged -> $status"
        $failures++
    }
}
finally {
    Remove-Item -LiteralPath $repo -Recurse -Force
}
exit $failures
