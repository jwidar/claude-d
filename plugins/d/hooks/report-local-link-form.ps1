# A resumed session keeps the line from its first start, even in another terminal.

$SharedRule = 'The label is the file name. The target holds the full absolute path from the drive letter, with / for every \. ' +
    'Never a relative path, a placeholder, or ~. Link every mention of a local file, also a later mention of a scratchpad file.'

$VsCodeLinkForm = 'Local file links (VS Code terminal): write a markdown link to vscode://file/<absolute path>. ' +
    'For a line, add :<line> to the URL and to the label, for example ' +
    '[notes.md:12](vscode://file/C:/Users/ALEX~1.DOE/AppData/Local/Temp/notes.md:12). ' + $SharedRule
$FileLinkForm = 'Local file links (not a VS Code terminal): write a markdown link to file:///<absolute path>, for example ' +
    '[notes.md](file:///C:/Users/ALEX~1.DOE/AppData/Local/Temp/notes.md). A file:/// URL cannot point at a line; put the line in the text. ' + $SharedRule

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
