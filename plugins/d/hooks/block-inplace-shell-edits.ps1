$InPlaceEditPatterns = @(
    '(^|[\s;&|(])sed\b[^;&|]*\s(-[a-zA-Z]*i|--in-place)'
    '(^|[\s;&|(])perl\b[^;&|]*\s-[a-zA-Z]*i'
)

$DenyReason = 'An in-place shell edit (sed -i, perl -i) writes LF line endings and converts a whole CRLF file. Change an existing file with the Edit tool.'

function Main {
    $hookInput = Read-HookInput
    $command = $hookInput.tool_input.command
    if (Test-InPlaceEdit -Command $command) {
        Write-Denial -Reason $DenyReason
    }
}

function Read-HookInput {
    [Console]::InputEncoding = New-Object Text.UTF8Encoding $false
    return [Console]::In.ReadToEnd() | ConvertFrom-Json
}

function Test-InPlaceEdit {
    param([string] $Command)

    foreach ($pattern in $InPlaceEditPatterns) {
        if ($Command -cmatch $pattern) {
            return $true
        }
    }
    return $false
}

function Write-Denial {
    param([string] $Reason)

    $output = @{
        hookSpecificOutput = @{
            hookEventName = 'PreToolUse'
            permissionDecision = 'deny'
            permissionDecisionReason = $Reason
        }
    }
    [Console]::OutputEncoding = New-Object Text.UTF8Encoding $false
    [Console]::Out.Write(($output | ConvertTo-Json -Compress -Depth 3))
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $ErrorActionPreference = 'Stop'
        Main
    }
    catch {
        # A failure here must never block the command.
    }
    exit 0
}
