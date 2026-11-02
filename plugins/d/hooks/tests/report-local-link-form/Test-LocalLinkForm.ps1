. "$PSScriptRoot/../../report-local-link-form.ps1"

$cases = @(
    @{ TermProgram = 'vscode'; Expected = 'vscode://file/' }
    @{ TermProgram = ''; Expected = 'file:///' }
    @{ TermProgram = 'WezTerm'; Expected = 'file:///' }
)

$failures = 0
foreach ($case in $cases) {
    $actual = Get-LocalLinkForm -TermProgram $case.TermProgram
    if ($actual.Contains("link to $($case.Expected)") -and $actual.Contains('Link every mention')) {
        Write-Output "PASS  TERM_PROGRAM='$($case.TermProgram)' -> $($case.Expected)"
    }
    else {
        Write-Output "FAIL  TERM_PROGRAM='$($case.TermProgram)' -> $actual"
        $failures++
    }
}
exit $failures
