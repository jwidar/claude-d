. "$PSScriptRoot/../../gate-service-start.ps1"

$cases = @(
    @{ Name = 'build'; Command = 'dotnet build App.sln'; Expected = $null }
    @{ Name = 'test'; Command = 'dotnet test'; Expected = $null }
    @{ Name = 'package install'; Command = 'npm install'; Expected = $null }
    @{ Name = 'script that is not a server'; Command = 'npm run lint'; Expected = $null }
    @{ Name = 'text that mentions a start'; Command = 'git log --grep="dotnet run"'; Expected = $null }
    @{ Name = 'dotnet run'; Command = 'dotnet run --project src/Api'; Expected = 'Start a program: dotnet run --project src/Api.' }
    @{ Name = 'dotnet watch'; Command = 'dotnet watch'; Expected = 'Start a program: dotnet watch.' }
    @{ Name = 'npm start'; Command = 'npm start'; Expected = 'Start a program: npm start.' }
    @{ Name = 'npm run dev'; Command = 'npm run dev'; Expected = 'Start a program: npm run dev.' }
    @{ Name = 'pnpm dev'; Command = 'pnpm dev'; Expected = 'Start a program: pnpm dev.' }
    @{ Name = 'start after another command'; Command = 'dotnet build; dotnet run'; Expected = 'Start a program: dotnet build; dotnet run.' }
    @{ Name = 'Start-Process'; Command = 'Start-Process .\bin\App.exe'; Expected = 'Start a program: Start-Process .\bin\App.exe.' }
    @{ Name = 'opt-out'; Command = 'dotnet run'; StartWithoutAsking = '1'; Expected = $null }
)

$failures = 0
foreach ($case in $cases) {
    $actual = Get-GateDecision -Command $case.Command -StartWithoutAsking $case.StartWithoutAsking
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
