. "$PSScriptRoot/../../gate-git-push.ps1"

function New-FixtureRepo {
    $path = Join-Path ([IO.Path]::GetTempPath()) "gate-git-push-$([guid]::NewGuid().ToString('N'))"
    git init --quiet --initial-branch=master $path
    git -C $path config user.name 'Fixture'
    git -C $path config user.email 'fixture@example.com'
    git -C $path remote add origin 'https://example.com/fixture.git'
    Add-FixtureCommit -Path $path -Message 'Base'
    git -C $path update-ref refs/remotes/origin/master HEAD
    git -C $path config branch.master.remote origin
    git -C $path config branch.master.merge refs/heads/master
    return $path
}

function Add-FixtureCommit {
    param([string] $Path, [string] $Message)

    git -C $Path commit --quiet --allow-empty -m $Message
}

$repo = New-FixtureRepo
$elsewhere = [IO.Path]::GetTempPath()

$cases = @(
    @{ Name = 'unrelated command'; Command = 'git status'; Expected = $null }
    @{ Name = 'push text in a log search'; Command = 'git log --grep=push'; Expected = $null }
    @{ Name = 'push in a compound command'; Command = 'git add . && git push origin master'; Expected = 'deny: This command runs git push together' }
    @{ Name = 'pull request in a compound command'; Command = 'echo done; gh pr create'; Expected = 'deny: This command runs the pull request command together' }
    @{ Name = 'force flag'; Command = 'git push --force origin master'; Expected = 'deny: A force push' }
    @{ Name = 'short force flag'; Command = 'git push -f'; Expected = 'deny: A force push' }
    @{ Name = 'force refspec'; Command = 'git push origin +master'; Expected = 'deny: A force push' }
    @{ Name = 'force after a config option'; Command = 'git -c core.quotepath=off push --force-with-lease'; Expected = 'deny: A force push' }
    @{ Name = 'gh pull request'; Command = 'gh pr create --title "Fix a; b" --base master'; Expected = "ask: Open a pull request 'Fix a; b' from the current branch into 'master'" }
    @{ Name = 'az pull request'; Command = 'az repos pr create --title Export --source-branch feat --target-branch master'; Expected = "ask: Open a pull request 'Export' from 'feat' into 'master'" }
    @{ Name = 'up to date'; Command = 'git push'; Expected = "ask: Nothing new to push: 'master'" }
    @{ Name = 'commits ahead of upstream'; Setup = { Add-FixtureCommit -Path $repo -Message 'One'; Add-FixtureCommit -Path $repo -Message 'Two' }; Command = 'git push'; Expected = "ask: Push 'master' to origin/master: 2 new commit(s)" }
    @{ Name = 'named remote and branch'; Command = 'git push origin master'; Expected = "ask: Push 'master' to origin/master: 2 new commit(s)" }
    @{ Name = 'explicit repo path'; Command = "git -C `"$repo`" push"; WorkingDirectory = $elsewhere; Expected = "ask: Push 'master' to origin/master: 2 new commit(s)" }
    @{ Name = 'new branch without upstream'; Setup = { git -C $repo switch --quiet -c feat; Add-FixtureCommit -Path $repo -Message 'Feature' }; Command = 'git push'; Expected = "ask: Push 'feat': it has no upstream branch" }
    @{ Name = 'new remote branch'; Command = 'git push -u origin feat'; Expected = "ask: Push 'feat' to origin as a new branch 'feat': 3 commit(s) not on any remote yet" }
    @{ Name = 'opt-out skips a plain push'; Setup = { New-Item -ItemType Directory -Force (Join-Path $repo '.claude') | Out-Null; Set-Content -LiteralPath (Join-Path $repo '.claude/settings.local.json') -Value '{ "env": { "D_PUSH_WITHOUT_ASKING": "1" } }' }; Command = 'git push -u origin feat'; Expected = $null }
    @{ Name = 'opt-out still stops a force push'; Command = 'git push --force origin feat'; Expected = 'deny: A force push' }
    @{ Name = 'opt-out still asks for a pull request'; Command = 'gh pr create'; Expected = 'ask: Open a pull request with no title' }
)

$failures = 0
try {
    foreach ($case in $cases) {
        if ($case.Setup) {
            & $case.Setup
        }
        $workingDirectory = if ($case.WorkingDirectory) { $case.WorkingDirectory } else { $repo }
        $decision = Get-GateDecision -Command $case.Command -WorkingDirectory $workingDirectory
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
