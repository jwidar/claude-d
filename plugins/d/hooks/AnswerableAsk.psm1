$AgentIdKeyPattern = '(?<!\\)"agent_id"\s*:\s*"[^"]'
$HandBackReason = 'You run as a subagent, where nobody can answer a permission prompt. ' +
    'Do not run this step, and do not run it in another way. ' +
    'Stop, and give the step back to the main agent with the exact command or call and why it is needed. The main agent asks the user.'

function Resolve-AnswerableDecision {
    param(
        [hashtable] $Decision
        , [string] $RawInput
    )

    if ($Decision.Decision -ne 'ask' -or -not (Test-SubagentCall -RawInput $RawInput)) {
        return $Decision
    }
    return @{
        Decision = 'deny'
        Reason = "$($Decision.Reason)`n`n$HandBackReason"
    }
}

function Test-SubagentCall {
    param([string] $RawInput)

    try {
        return [bool] ($RawInput | ConvertFrom-Json -ErrorAction Stop).agent_id
    }
    catch {
        return $RawInput -match $AgentIdKeyPattern
    }
}

Export-ModuleMember -Function Resolve-AnswerableDecision
