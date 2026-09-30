# A resumed session keeps the line from its first start, even in another terminal.

$VsCodeLinkForm = 'Local file links: use vscode://file/<absolute path>[:line] (VS Code integrated terminal).'
$FileLinkForm = 'Local file links: use file:///<absolute path> (not a VS Code terminal).'

function Main {
    [Console]::OutputEncoding = New-Object Text.UTF8Encoding $false
    [Console]::Out.WriteLine((Get-LocalLinkForm -TermProgram $env:TERM_PROGRAM))
}

function Get-LocalLinkForm {
    param([string] $TermProgram)

    if ($TermProgram -eq 'vscode') {
        return $VsCodeLinkForm
    }
    return $FileLinkForm
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $ErrorActionPreference = 'Stop'
        Main
    }
    catch {
        # A failure here must never block the session start.
    }
    exit 0
}
