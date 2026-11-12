. "$PSScriptRoot/../../gate-destructive-git-push.ps1"

$cases = @(
    @{ Name = 'unrelated command'; Command = 'git status'; Expected = $null }
    @{ Name = 'push text in a log search'; Command = 'git log --grep=push'; Expected = $null }
    @{ Name = 'plain push'; Command = 'git push'; Expected = $null }
    @{ Name = 'new remote branch'; Command = 'git push -u origin feat'; Expected = $null }
    @{ Name = 'push in a compound command'; Command = 'git add . && git push origin master'; Expected = $null }
    @{ Name = 'force in a second push of a compound command'; Command = 'git push origin a; git push -f origin b'; Expected = 'ask: Force push' }
    @{ Name = 'force inside bash -c'; Command = 'bash -c "git push -f"'; Expected = 'ask: Force push' }
    @{ Name = 'force inside pwsh -c'; Command = "pwsh -c 'git push --force'"; Expected = 'ask: Force push' }
    @{ Name = 'force text in a heredoc'; Command = "cat <<'EOF'`ngit push -f`nEOF"; Expected = $null }
    @{ Name = 'force wins over a delete'; Command = 'git push -d origin a && git push -f origin b'; Expected = 'ask: Force push' }
    @{ Name = 'force flag'; Command = 'git push --force origin master'; Expected = 'ask: Force push: git push --force origin master. It can overwrite' }
    @{ Name = 'short force flag'; Command = 'git push -f'; Expected = 'ask: Force push' }
    @{ Name = 'force refspec'; Command = 'git push origin +master'; Expected = 'ask: Force push' }
    @{ Name = 'force after a config option'; Command = 'git -c core.quotepath=off push --force-with-lease'; Expected = 'ask: Force push' }
    @{ Name = 'force in a short flag group, first'; Command = 'git push -fu origin master'; Expected = 'ask: Force push' }
    @{ Name = 'force in a short flag group, last'; Command = 'git push -uf origin master'; Expected = 'ask: Force push' }
    @{ Name = 'quoted force refspec'; Command = 'git push origin "+master"'; Expected = 'ask: Force push' }
    @{ Name = 'mirror'; Command = 'git push --mirror origin'; Expected = 'ask: Force push' }
    @{ Name = 'force with includes'; Command = 'git push --force-if-includes origin feat'; Expected = 'ask: Force push' }
    @{ Name = 'delete flag'; Command = 'git push --delete origin feat'; Expected = 'ask: Delete refs on the remote: git push --delete origin feat.' }
    @{ Name = 'short delete flag'; Command = 'git push -d origin feat'; Expected = 'ask: Delete refs on the remote' }
    @{ Name = 'delete refspec'; Command = 'git push origin :feat'; Expected = 'ask: Delete refs on the remote' }
    @{ Name = 'prune'; Command = 'git push --prune origin'; Expected = 'ask: Delete refs on the remote' }
    @{ Name = 'all branches'; Command = 'git push --all origin'; Expected = $null }
    @{ Name = 'all tags'; Command = 'git push --tags'; Expected = $null }
    @{ Name = 'matching refs'; Command = 'git push origin :'; Expected = $null }
    @{ Name = 'several refs'; Command = 'git push origin master feat'; Expected = $null }
    @{ Name = 'refspec with a colon is not a delete'; Command = 'git push origin master:master'; Expected = $null }
    @{ Name = 'git.exe'; Command = 'git.exe push --force'; Expected = 'ask: Force push' }
    @{ Name = 'git by full path'; Command = '"C:\Program Files\Git\bin\git.exe" push --force'; Expected = 'ask: Force push' }
    @{ Name = 'option with a separate value'; Command = 'git --git-dir .git push --force'; Expected = 'ask: Force push' }
    @{ Name = 'config with a quoted value'; Command = 'git -c "a.b=c d" push --force'; Expected = 'ask: Force push' }
    @{ Name = 'word in a path is not git'; Command = 'mygit push'; Expected = $null }
    @{ Name = 'pull request command'; Command = 'gh pr create --title Export'; Expected = $null }
)

$failures = 0
foreach ($case in $cases) {
    $decision = Get-GateDecision -Command $case.Command
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
exit $failures
