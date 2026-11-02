. "$PSScriptRoot/../../record-feedback-memory.ps1"

$folder = Join-Path ([IO.Path]::GetTempPath()) "record-feedback-memory-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Force $folder | Out-Null
$backlog = Join-Path $folder 'feedback-backlog.md'
$memoryPath = 'C:/Users/example/.claude/projects/C--src-example/memory/naming.md'

function New-Memory {
    param([string] $Type, [string] $Description = 'When you name a method, make the name cover what it does')

    return "---`nname: naming`ndescription: $Description`nmetadata:`n  type: $Type`n---`n`nThe body."
}

$cases = @(
    @{ Name = 'feedback memory adds an entry'; Input = @{ file_path = $memoryPath; content = (New-Memory -Type feedback) }; Expected = 'This feedback memory is now entry F' }
    @{ Name = 'same guidance again adds nothing'; Input = @{ file_path = $memoryPath; content = (New-Memory -Type feedback) }; Expected = $null }
    @{ Name = 'quoted description adds an entry'; Input = @{ file_path = $memoryPath; content = (New-Memory -Type feedback -Description '"When a test fails, read the output first"') }; Expected = 'This feedback memory is now entry F' }
    @{ Name = 'user memory adds nothing'; Input = @{ file_path = $memoryPath; content = (New-Memory -Type user -Description 'When the user asks, answer') }; Expected = $null }
    @{ Name = 'index file adds nothing'; Input = @{ file_path = 'C:/x/memory/MEMORY.md'; content = (New-Memory -Type feedback -Description 'Index') }; Expected = $null }
    @{ Name = 'file outside memory adds nothing'; Input = @{ file_path = 'C:/x/docs/note.md'; content = (New-Memory -Type feedback -Description 'Outside') }; Expected = $null }
)

$failures = 0
try {
    foreach ($case in $cases) {
        $actual = Add-FeedbackEntry -ToolInput ([pscustomobject] $case.Input) -Project 'example' -BacklogPath $backlog -Date '2026-01-15'
        $passed = if ($null -eq $case.Expected) { $null -eq $actual } else { $actual -and $actual.StartsWith($case.Expected) }
        if ($passed) {
            Write-Output "PASS  $($case.Name)"
        }
        else {
            Write-Output "FAIL  $($case.Name) -> $actual"
            $failures++
        }
    }

    $lines = @(Get-Content -LiteralPath $backlog)
    $shapeOk = $lines.Count -eq 2 -and ($lines | Where-Object { $_ -notmatch '^F[0-9a-f]{3} - \[ \] 2026-01-15 \(example\) — When' }).Count -eq 0
    if ($shapeOk -and $lines[1].EndsWith('read the output first')) {
        Write-Output 'PASS  backlog lines have the entry shape'
    }
    else {
        Write-Output "FAIL  backlog lines have the entry shape -> $($lines -join ' | ')"
        $failures++
    }
}
finally {
    Remove-Item -LiteralPath $folder -Recurse -Force
}
exit $failures
