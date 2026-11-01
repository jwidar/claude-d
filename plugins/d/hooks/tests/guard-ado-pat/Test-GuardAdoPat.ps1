. "$PSScriptRoot/../../guard-ado-pat.ps1"

$settingsPath = 'C:\work\app\.claude\monitor-devops.local.md'

$writeCases = @(
    @{ Name = 'write with a PAT line'; ToolInput = @{ file_path = $settingsPath; content = "---`nado_org_url: https://example.com`nado_pat: abc123`n---" }; Expected = $true }
    @{ Name = 'write without a PAT line'; ToolInput = @{ file_path = $settingsPath; content = "---`nado_org_url: https://example.com`n---" }; Expected = $false }
    @{ Name = 'edit that adds a PAT line'; ToolInput = @{ file_path = $settingsPath; old_string = 'ado_team: Core'; new_string = "ado_team: Core`nado_pat: abc123" }; Expected = $true }
    @{ Name = 'edit that removes a PAT line'; ToolInput = @{ file_path = $settingsPath; old_string = "ado_team: Core`nado_pat: abc123"; new_string = 'ado_team: Core' }; Expected = $false }
    @{ Name = 'PAT line in another file'; ToolInput = @{ file_path = 'C:\work\app\notes.md'; content = 'ado_pat: is the key name' }; Expected = $false }
)

$failures = 0
foreach ($case in $writeCases) {
    $actual = Test-WritesPatLine -ToolInput ([pscustomobject] $case.ToolInput)
    if ($actual -eq $case.Expected) {
        Write-Output "PASS  $($case.Name)"
    }
    else {
        Write-Output "FAIL  $($case.Name) -> $actual"
        $failures++
    }
}

$project = Join-Path ([IO.Path]::GetTempPath()) "guard-ado-pat-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Force (Join-Path $project '.claude') | Out-Null
try {
    $sessionCases = @(
        @{ Name = 'session start without a settings file'; Content = $null; Expected = $false }
        @{ Name = 'session start with a PAT line'; Content = "---`nado_project: App`nado_pat: abc123`n---"; Expected = $true }
        @{ Name = 'session start without a PAT line'; Content = "---`nado_project: App`n---"; Expected = $false }
    )
    foreach ($case in $sessionCases) {
        if ($case.Content) {
            Set-Content -LiteralPath (Join-Path $project ".claude\$SettingsFileName") -Value $case.Content
        }
        $actual = [bool] (Get-SessionReport -Directory $project)
        if ($actual -eq $case.Expected) {
            Write-Output "PASS  $($case.Name)"
        }
        else {
            Write-Output "FAIL  $($case.Name) -> $actual"
            $failures++
        }
    }
}
finally {
    Remove-Item -LiteralPath $project -Recurse -Force
}
exit $failures
