. "$PSScriptRoot/../../check-commit-message.ps1"

function New-FixtureRepo {
    $path = Join-Path ([IO.Path]::GetTempPath()) "check-commit-message-$([guid]::NewGuid().ToString('N'))"
    git init --quiet --initial-branch=master $path
    return $path
}

$repo = New-FixtureRepo
$heredoc = "git commit -m `"`$(cat <<'EOF'`nAdd export retry`n`nCo-Authored-By: Someone <someone@example.com>`nEOF`n)`""
$hereString = "git commit -m @'`nFixed the upload`n'@"

$cases = @(
    @{ Name = 'not a commit'; Command = 'git status'; Expected = $null }
    @{ Name = 'message in a short flag group'; Command = 'git commit -am "Added a test"'; Expected = 'deny: The commit subject' }
    @{ Name = 'good message in a short flag group'; Command = 'git commit -am "Add a test"'; Expected = $null }
    @{ Name = 'command form'; Command = 'git commit -m "Add export retry"'; Expected = $null }
    @{ Name = 'past tense'; Command = 'git commit -m "Added export retry"'; Expected = "deny: The commit subject 'Added export retry'" }
    @{ Name = 'ing form'; Command = 'git commit -m "Fixing the upload"'; Expected = "deny: The commit subject 'Fixing the upload'" }
    @{ Name = 'imperative word that ends like a past form'; Command = 'git commit -m "Embed the font"'; Expected = $null }
    @{ Name = 'heredoc with a trailer'; Command = $heredoc; Expected = $null }
    @{ Name = 'here-string in past tense'; Command = $hereString; Expected = "deny: The commit subject 'Fixed the upload'" }
    @{ Name = 'list in the body'; Command = 'git commit -m "Add export retry" -m "- one`n- two"'; Expected = "ask: Commit 'Add export retry'. The message has a list." }
    @{ Name = 'work item reference'; Command = 'git commit -m "Fix upload for #123"'; Expected = "ask: Commit 'Fix upload for #123'. The message refers to a work item" }
    @{ Name = 'amend on master'; Command = 'git commit --amend -m "Add export retry"'; Expected = "ask: Commit 'Add export retry'. This amends a commit on master." }
    @{ Name = 'message from a file'; Command = 'git commit -F message.txt'; Expected = $null }
    @{ Name = 'after git add'; Command = 'git add . && git commit -m "Updated docs"'; Expected = "deny: The commit subject 'Updated docs'" }
)

$failures = 0
try {
    foreach ($case in $cases) {
        $decision = Get-CommitDecision -Command $case.Command -WorkingDirectory $repo
        $actual = if ($decision) { "$($decision.Decision): $($decision.Reason)" } else { $null }
        $passed = if ($null -eq $case.Expected) { $null -eq $actual } else { $actual -and $actual.StartsWith($case.Expected) }
        if ($passed) {
            Write-Output "PASS  $($case.Name)"
        }
        else {
            Write-Output "FAIL  $($case.Name) -> $actual"
            $failures++
        }
    }
}
finally {
    Remove-Item -LiteralPath $repo -Recurse -Force
}
exit $failures
