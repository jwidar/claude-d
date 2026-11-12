. "$PSScriptRoot/../../check-pull-request-text.ps1"

$goodBody = "Links from the old service showed an error. Now they open.`n`n## Checked by Claude`n- An old link: opens.`n`n/claude code"
$badBody = "## Summary`n$goodBody"
$heredocPullRequest = "gh pr create --title `"Open old links`" --body `"`$(cat <<'EOF'`nLinks showed a `"temporarily unavailable`" error. Now they open.`n`n## Manually tested`n- An old link: opens.`n`n/claude code`nEOF`n)`""
$twoHeredocs = "gh pr create --title A --body `"`$(cat <<'EOF'`n$goodBody`nEOF`n)`" && gh pr create --title B --body `"`$(cat <<'EOF'`n$badBody`nEOF`n)`""
$bodyFileFromHeredoc = "gh pr create --title Export --body-file - <<'EOF'`n$goodBody`nEOF"
$monitorDevOps = 'mcp__plugin_devops_devops__'

$cases = @(
    @{ Name = 'unrelated command'; Command = 'git status'; Expected = $null }
    @{ Name = 'gh pull request'; Command = "gh pr create --title `"Fix a; b`" --base master --body `"$goodBody`""; Expected = $null }
    @{ Name = 'az pull request'; Command = "az repos pr create --title Export --source-branch feat --target-branch master --description `"$goodBody`""; Expected = $null }
    @{ Name = 'gh draft flag is not a description'; Command = "gh pr create -d --title Export --body `"$goodBody`""; Expected = $null }
    @{ Name = 'body in a heredoc with quotes'; Command = $heredocPullRequest; Expected = $null }
    @{ Name = 'body file from a heredoc'; Command = $bodyFileFromHeredoc; Expected = $null }
    @{ Name = 'pull request in a compound command'; Command = "git push -u origin feat && gh pr create --title Export --body `"$goodBody`""; Expected = $null }
    @{ Name = 'second of two heredoc bodies is bad'; Command = $twoHeredocs; Expected = 'Rewrite the pull request: The description has a "Summary" header.' }
    @{ Name = 'no description'; Command = 'gh pr create --title Export'; Expected = 'Rewrite the pull request: It has no description.' }
    @{ Name = 'Summary header'; Command = "gh pr create --title Export --body `"$badBody`""; Expected = 'Rewrite the pull request: The description has a "Summary" header.' }
    @{ Name = 'no footer'; Command = "gh pr create --title Export --body `"Text.`n`n## Checked by Claude`n- A case: works.`""; Expected = 'Rewrite the pull request: The description does not end with /claude code' }
    @{ Name = 'title with a work item'; Command = "gh pr create --title `"Export #123`" --body `"$goodBody`""; Expected = 'Rewrite the pull request: The title has a #1234 work item reference.' }
    @{ Name = 'gh edit of the title only'; Command = 'gh pr edit 7 --title Export'; Expected = $null }
    @{ Name = 'gh edit with a bad body'; Command = "gh pr edit 7 --body `"$badBody`""; Expected = 'Rewrite the pull request: The description has a "Summary" header.' }
    @{ Name = 'az update of the title'; Command = 'az repos pr update --id 7 --title "Export #12"'; Expected = 'Rewrite the pull request: The title has a #1234 work item reference.' }
    @{ Name = 'MCP create with good text'; ToolName = "${monitorDevOps}create_pull_request"; ToolInput = @{ title = 'Export'; description = $goodBody }; Expected = $null }
    @{ Name = 'MCP create with a bad description'; ToolName = "${monitorDevOps}create_pull_request"; ToolInput = @{ title = 'Export'; description = $badBody }; Expected = 'Rewrite the pull request: The description has a "Summary" header.' }
    @{ Name = 'MCP create with no description'; ToolName = "${monitorDevOps}create_pull_request"; ToolInput = @{ title = 'Export' }; Expected = 'Rewrite the pull request: It has no description.' }
    @{ Name = 'MCP update of the draft flag only'; ToolName = "${monitorDevOps}update_pull_request"; ToolInput = @{ isDraft = $false }; Expected = $null }
    @{ Name = 'MCP update of a title with a work item'; ToolName = "${monitorDevOps}update_pull_request"; ToolInput = @{ title = 'Export #123' }; Expected = 'Rewrite the pull request: The title has a #1234 work item reference.' }
    @{ Name = 'GitHub MCP create with a body'; ToolName = 'mcp__github__create_pull_request'; ToolInput = @{ title = 'Export'; body = $badBody }; Expected = 'Rewrite the pull request: The description has a "Summary" header.' }
    @{ Name = 'MCP review is not a pull request text'; ToolName = 'mcp__github__create_pull_request_review'; ToolInput = @{ body = 'Fine.' }; Expected = $null }
)

$failures = 0
foreach ($case in $cases) {
    $toolName = if ($case.ToolName) { $case.ToolName } else { 'Bash' }
    $toolInput = if ($case.ToolInput) { [pscustomobject] $case.ToolInput } else { [pscustomobject] @{ command = $case.Command } }
    $problems = @(Get-TextProblemsOfCall -ToolName $toolName -ToolInput $toolInput -WorkingDirectory $PSScriptRoot)
    $actual = if ($problems.Count -gt 0) { "Rewrite the pull request: $($problems -join ' ')" } else { $null }
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
