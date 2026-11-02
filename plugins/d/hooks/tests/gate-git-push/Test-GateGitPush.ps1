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
$goodBody = "Links from the old service showed an error. Now they open.`n`n## Checked by Claude`n- An old link: opens.`n`n/claude code"
$heredocPullRequest = "gh pr create --title `"Open old links`" --body `"`$(cat <<'EOF'`nLinks showed a `"temporarily unavailable`" error. Now they open.`n`n## Manually tested`n- An old link: opens.`n`n/claude code`nEOF`n)`""

$cases = @(
    @{ Name = 'unrelated command'; Command = 'git status'; Expected = $null }
    @{ Name = 'push text in a log search'; Command = 'git log --grep=push'; Expected = $null }
    @{ Name = 'push in a compound command'; Command = 'git add . && git push origin master'; Expected = 'deny: This command runs git push together' }
    @{ Name = 'pull request in a compound command'; Command = 'echo done; gh pr create'; Expected = 'deny: This command runs the pull request command together' }
    @{ Name = 'force flag'; Command = 'git push --force origin master'; Expected = 'deny: A force push' }
    @{ Name = 'short force flag'; Command = 'git push -f'; Expected = 'deny: A force push' }
    @{ Name = 'force refspec'; Command = 'git push origin +master'; Expected = 'deny: A force push' }
    @{ Name = 'force after a config option'; Command = 'git -c core.quotepath=off push --force-with-lease'; Expected = 'deny: A force push' }
    @{ Name = 'force in a short flag group, first'; Command = 'git push -fu origin master'; Expected = 'deny: A force push' }
    @{ Name = 'force in a short flag group, last'; Command = 'git push -uf origin master'; Expected = 'deny: A force push' }
    @{ Name = 'quoted force refspec'; Command = 'git push origin "+master"'; Expected = 'deny: A force push' }
    @{ Name = 'delete flag'; Command = 'git push --delete origin feat'; Expected = 'deny: This push can delete' }
    @{ Name = 'short delete flag'; Command = 'git push -d origin feat'; Expected = 'deny: This push can delete' }
    @{ Name = 'delete refspec'; Command = 'git push origin :feat'; Expected = 'deny: This push can delete' }
    @{ Name = 'mirror'; Command = 'git push --mirror origin'; Expected = 'deny: This push can delete' }
    @{ Name = 'prune'; Command = 'git push --prune origin'; Expected = 'deny: This push can delete' }
    @{ Name = 'all branches'; Command = 'git push --all origin'; Expected = 'ask: Push more than one branch or tag' }
    @{ Name = 'all tags'; Command = 'git push --tags'; Expected = 'ask: Push more than one branch or tag' }
    @{ Name = 'matching refs'; Command = 'git push origin :'; Expected = 'ask: Push more than one branch or tag' }
    @{ Name = 'several refs'; Command = 'git push origin master feat'; Expected = 'ask: Push more than one branch or tag' }
    @{ Name = 'refspec with a colon is not a delete'; Command = 'git push origin master:master'; Expected = "ask: Nothing new to push: 'master'" }
    @{ Name = 'git.exe'; Command = 'git.exe push --force'; Expected = 'deny: A force push' }
    @{ Name = 'git by full path'; Command = '"C:\Program Files\Git\bin\git.exe" push --force'; Expected = 'deny: A force push' }
    @{ Name = 'option with a separate value'; Command = 'git --git-dir .git push --force'; Expected = 'deny: A force push' }
    @{ Name = 'config with a quoted value'; Command = 'git -c "a.b=c d" push --force'; Expected = 'deny: A force push' }
    @{ Name = 'word in a path is not git'; Command = 'mygit push'; Expected = $null }
    @{ Name = 'gh pull request'; Command = "gh pr create --title `"Fix a; b`" --base master --body `"$goodBody`""; Expected = "ask: Open a pull request 'Fix a; b' from the current branch into 'master'" }
    @{ Name = 'az pull request'; Command = "az repos pr create --title Export --source-branch feat --target-branch master --description `"$goodBody`""; Expected = "ask: Open a pull request 'Export' from 'feat' into 'master'" }
    @{ Name = 'pull request body in a heredoc with quotes'; Command = $heredocPullRequest; Expected = "ask: Open a pull request 'Open old links'" }
    @{ Name = 'pull request without a description'; Command = 'gh pr create --title Export'; Expected = 'deny: Rewrite the pull request: It has no description.' }
    @{ Name = 'pull request with a Summary header'; Command = "gh pr create --title Export --body `"## Summary`n$goodBody`""; Expected = 'deny: Rewrite the pull request: The description has a "Summary" header.' }
    @{ Name = 'pull request without the footer'; Command = "gh pr create --title Export --body `"Text.`n`n## Checked by Claude`n- A case: works.`""; Expected = 'deny: Rewrite the pull request: The description does not end with /claude code' }
    @{ Name = 'pull request title with a work item'; Command = "gh pr create --title `"Export #123`" --body `"$goodBody`""; Expected = 'deny: Rewrite the pull request: The title has a #1234 work item reference.' }
    @{ Name = 'up to date'; Command = 'git push'; Expected = "ask: Nothing new to push: 'master'" }
    @{ Name = 'commits ahead of upstream'; Setup = { Add-FixtureCommit -Path $repo -Message 'One'; Add-FixtureCommit -Path $repo -Message 'Two' }; Command = 'git push'; Expected = "ask: Push 'master' to origin/master: 2 new commit(s)" }
    @{ Name = 'named remote and branch'; Command = 'git push origin master'; Expected = "ask: Push 'master' to origin/master: 2 new commit(s)" }
    @{ Name = 'explicit repo path'; Command = "git -C `"$repo`" push"; WorkingDirectory = $elsewhere; Expected = "ask: Push 'master' to origin/master: 2 new commit(s)" }
    @{ Name = 'new branch without upstream'; Setup = { git -C $repo switch --quiet -c feat; Add-FixtureCommit -Path $repo -Message 'Feature' }; Command = 'git push'; Expected = "ask: Push 'feat': it has no upstream branch" }
    @{ Name = 'new remote branch'; Command = 'git push -u origin feat'; Expected = "ask: Push 'feat' to origin as a new branch 'feat': 3 commit(s) not on any remote yet" }
    @{ Name = 'opt-out skips a plain push'; Setup = { New-Item -ItemType Directory -Force (Join-Path $repo '.claude') | Out-Null; Set-Content -LiteralPath (Join-Path $repo '.claude/settings.local.json') -Value '{ "env": { "D_PUSH_WITHOUT_ASKING": "1" } }' }; Command = 'git push -u origin feat'; Expected = $null }
    @{ Name = 'opt-out still stops a force push'; Command = 'git push --force origin feat'; Expected = 'deny: A force push' }
    @{ Name = 'opt-out still stops a force in a flag group'; Command = 'git push -fu origin feat'; Expected = 'deny: A force push' }
    @{ Name = 'opt-out still stops a delete'; Command = 'git push -d origin feat'; Expected = 'deny: This push can delete' }
    @{ Name = 'opt-out still asks for all branches'; Command = 'git push --all origin'; Expected = 'ask: Push more than one branch or tag' }
    @{ Name = 'opt-out still asks for a pull request'; Command = "gh pr create --body `"$goodBody`""; Expected = 'ask: Open a pull request with no title' }
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
