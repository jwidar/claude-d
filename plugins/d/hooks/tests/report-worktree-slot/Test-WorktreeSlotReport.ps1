. "$PSScriptRoot/../../report-worktree-slot.ps1"

$cases = @(
    @{
        Name     = 'slot on a branch'
        Layout   = @{ GitDir = 'C:/src/Example/.git/worktrees/2'; CommonDir = 'C:/src/Example/.git'; TopLevel = 'C:/src/Example.wt/2'; Branch = 'feature/x'; WorktreeCount = 3 }
        Expected = "slot '2' of C:\src\Example, on branch 'feature/x'"
    }
    @{
        Name     = 'parked slot'
        Layout   = @{ GitDir = 'C:/src/Example/.git/worktrees/1'; CommonDir = 'C:/src/Example/.git'; TopLevel = 'C:/src/Example.wt/1'; Branch = ''; WorktreeCount = 3 }
        Expected = 'on detached HEAD'
    }
    @{
        Name     = 'main clone with slots'
        Layout   = @{ GitDir = 'C:/src/Example/.git'; CommonDir = 'C:/src/Example/.git'; TopLevel = 'C:/src/Example'; Branch = 'master'; WorktreeCount = 3 }
        Expected = 'C:\src\Example has 2 slot(s)'
    }
    @{
        Name     = 'plain clone'
        Layout   = @{ GitDir = 'C:/src/Example/.git'; CommonDir = 'C:/src/Example/.git'; TopLevel = 'C:/src/Example'; Branch = 'master'; WorktreeCount = 1 }
        Expected = $null
    }
)

$failures = 0
foreach ($case in $cases) {
    $layout = $case.Layout
    $actual = Get-WorktreeSlotReport @layout
    $passed = if ($null -eq $case.Expected) { $null -eq $actual } else { $actual -and $actual.Contains($case.Expected) }
    if ($passed) {
        Write-Output "PASS  $($case.Name)"
    }
    else {
        Write-Output "FAIL  $($case.Name) -> $actual"
        $failures++
    }
}
exit $failures
