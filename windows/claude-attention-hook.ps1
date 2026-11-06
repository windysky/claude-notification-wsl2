# claude-attention-hook.ps1 - attention signal for Windows-native Claude Code sessions.
#
# Windows PowerShell 5.1 port of the signal half of hooks/_attention.sh
# (_attention_write_signal / _attention_kind / _attention_needle) plus the message
# extracts of hooks/Stop.sh and hooks/Notification.sh. Registered as a Claude Code
# "Notification" and "Stop" hook, it drops one JSON file into the signal directory
# that TerminalOrganizer polls, so the tray app rings the Windows Terminal tab of
# the session that needs the user. Signal only: no toast, no taskbar flash.
#
# Contract: reads the hook JSON on stdin; never throws; prints NOTHING to stdout
# (a Stop hook's stdout can be read as a decision); always exits 0; best effort.
#
# Needle: $env:LAUNCHER_SESSION (set by terminal-auto-launcher in every tab) when
# non-empty, else the cwd basename split on - _ . and whitespace, lowercased.
# Signal dir: $env:WSL_TOAST_ATTENTION_DIR (test seam) or %LOCALAPPDATA%\wsl-toast\attention.
# Source is kept ASCII on purpose (5.1 reads BOM-less files as ANSI).

$ErrorActionPreference = 'SilentlyContinue'

$SignalMaxMessage = 600            # first_paragraph / Notification.sh cap
$TranscriptTailBytes = 2MB         # Stop.sh scans the whole file; the last text is near the end
$PruneMinutes = 5                  # same self-prune window as _attention_write_signal

function Read-StdinText {
    $ms = New-Object IO.MemoryStream
    [Console]::OpenStandardInput().CopyTo($ms)
    (New-Object Text.UTF8Encoding($false)).GetString($ms.ToArray()).TrimStart([char]0xFEFF)
}

# _attention_kind: asks block until focus, infos blink briefly, anything else is unset.
function Get-Kind([string]$Evt, [string]$Ntype) {
    if ($Evt -ne 'notification') { return $null }
    switch ($Ntype) {
        { $_ -in 'permission_prompt', 'elicitation_dialog', 'worker_permission_prompt', 'agent_needs_input' } { return 'ask' }
        { $_ -in 'idle_prompt', 'auth_success' } { return 'info' }
        default { return $null }
    }
}

function Get-Needle([string]$Cwd) {
    $s = $env:LAUNCHER_SESSION
    if (-not [string]::IsNullOrWhiteSpace($s)) { return $s.Trim() }
    $base = [IO.Path]::GetFileName($Cwd.TrimEnd('\', '/'))
    if ([string]::IsNullOrEmpty($base)) { $base = $Cwd }
    $tokens = [regex]::Split($base.ToLowerInvariant(), '[-_.\s]+') | Where-Object { $_ }
    $tokens -join ' '
}

# Stop.sh _clean(): markdown / dash-rule stripping shared by the extracts.
function Get-CleanText([string]$Text) {
    $Text = [regex]::Replace($Text, '[─━═\-–—~=]{3,}', ' ')
    $Text = [regex]::Replace($Text, '\[([^\]]+)\]\(([^)]+)\)', '$1')
    $Text = [regex]::Replace($Text, '(\*\*|__)(?=\S)(.+?)(?<=\S)\1', '$2')
    $Text = [regex]::Replace($Text, '(?<!\w)(\*|_)(?=\S)(.+?)(?<=\S)\1(?!\w)', '$2')
    $Text = [regex]::Replace($Text, '`{1,3}([^`]*)`{1,3}', '$1')
    [regex]::Replace($Text, '^\s{0,3}#{1,6}\s+', '', 'Multiline')
}

# Stop.sh first_paragraph(): first paragraph, whitespace collapsed, capped with a
# sentence-boundary cut (or "..." when no boundary past char 40).
function Get-FirstParagraph([string]$Text, [int]$Max) {
    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    $Text = Get-CleanText $Text
    $paras = @([regex]::Split($Text, '\n\s*\n') | Where-Object { $_.Trim() })
    $first = if ($paras.Count) { $paras[0] } else { $Text }
    $r = ([regex]::Replace($first, '\s+', ' ')).Trim()
    if ($r.Length -le $Max) { return $r }
    $r = $r.Substring(0, $Max - 1).TrimEnd()
    $cut = [Math]::Max($r.LastIndexOf('.'), [Math]::Max($r.LastIndexOf('!'), $r.LastIndexOf('?')))
    if ($cut -gt 40) { return $r.Substring(0, $cut + 1) }
    if ($r.Length -and [char]::IsHighSurrogate($r[$r.Length - 1])) { $r = $r.Substring(0, $r.Length - 1) }
    $r + '...'
}

# Stop.sh extract_text_from_content(): last text block, else any text/thinking.
function Get-ContentText($Content) {
    if ($null -eq $Content -or $Content -is [string]) { return '' }
    $blocks = @($Content)
    for ($i = $blocks.Count - 1; $i -ge 0; $i--) {
        if ($blocks[$i].type -eq 'text' -and $blocks[$i].text) { return ([string]$blocks[$i].text).Trim() }
    }
    for ($i = $blocks.Count - 1; $i -ge 0; $i--) {
        if ($blocks[$i].text) { return ([string]$blocks[$i].text).Trim() }
        if ($blocks[$i].thinking) { return ([string]$blocks[$i].thinking).Trim() }
    }
    ''
}

# Stop.sh get_last_assistant_message(), scanning backwards over the file tail.
function Get-TranscriptText([string]$Path) {
    if ([string]::IsNullOrEmpty($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { return '' }
    $fs = [IO.File]::Open($Path, 'Open', 'Read', 'ReadWrite')
    try {
        $start = [Math]::Max(0, $fs.Length - $TranscriptTailBytes)
        $null = $fs.Seek($start, 'Begin')
        $bytes = (New-Object IO.BinaryReader($fs)).ReadBytes([int]($fs.Length - $start))
    } finally { $fs.Dispose() }
    $lines = (New-Object Text.UTF8Encoding($false)).GetString($bytes) -split "`n"
    $stop = if ($start -gt 0) { 1 } else { 0 }       # first line of a tail slice is partial
    for ($i = $lines.Count - 1; $i -ge $stop; $i--) {
        if ($lines[$i] -notmatch '"assistant"') { continue }
        try { $entry = $lines[$i] | ConvertFrom-Json } catch { continue }
        if ($entry.message.role -ne 'assistant') { continue }
        $t = Get-ContentText $entry.message.content
        if ($t) { return $t }
    }
    ''
}

function Write-Signal($Dir, $Obj) {
    $null = [IO.Directory]::CreateDirectory($Dir)
    $ms = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    $final = Join-Path $Dir ('att-{0}-{1}.json' -f $ms, (Get-Random -Maximum 32768))
    $tmp = Join-Path $Dir ('tmp-{0}.tmp' -f [guid]::NewGuid().ToString('N'))   # never matches att-*.json
    try {
        [IO.File]::WriteAllText($tmp, ($Obj | ConvertTo-Json -Compress), (New-Object Text.UTF8Encoding($false)))
        [IO.File]::Move($tmp, $final)
    } finally {
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force }
    }
}

function Remove-StaleFiles($Dir) {
    $limit = (Get-Date).AddMinutes(-$PruneMinutes)
    Get-ChildItem -LiteralPath $Dir -File | Where-Object {
        ($_.Name -like 'att-*.json' -or $_.Name -like 'tmp-*.tmp') -and $_.LastWriteTime -lt $limit
    } | Remove-Item -Force
}

function Invoke-Main {
    $payload = (Read-StdinText) | ConvertFrom-Json
    if ($null -eq $payload -or $payload -is [array]) { return }
    $evt = switch -CaseSensitive ($payload.hook_event_name) { 'Notification' { 'notification' } 'Stop' { 'stop' } default { $null } }
    if (-not $evt) { return }

    $cwd = [string]$payload.cwd
    if ([string]::IsNullOrEmpty($cwd)) { $cwd = (Get-Location).Path }
    $ntype = [string]$payload.notification_type

    if ($evt -eq 'notification') {
        $message = ([regex]::Replace([string]$payload.message, '\r?\n', ' '))
        if ($message.Length -gt $SignalMaxMessage) { $message = $message.Substring(0, $SignalMaxMessage) }
    } else {
        $text = [string]$payload.last_assistant_message
        if ([string]::IsNullOrWhiteSpace($text)) { $text = Get-TranscriptText ([string]$payload.transcript_path) }
        $message = Get-FirstParagraph $text $SignalMaxMessage
    }

    $dir = $env:WSL_TOAST_ATTENTION_DIR
    if ([string]::IsNullOrWhiteSpace($dir)) { $dir = Join-Path $env:LOCALAPPDATA 'wsl-toast\attention' }

    Write-Signal $dir ([ordered]@{
        version           = 1
        event             = $evt
        kind              = Get-Kind $evt $ntype
        notification_type = if ($ntype) { $ntype } else { $null }
        session_id        = [string]$payload.session_id
        cwd               = $cwd
        needle            = Get-Needle $cwd
        message           = if ($message) { $message } else { $null }
        timestamp         = [DateTimeOffset]::Now.ToString("yyyy-MM-dd'T'HH:mm:sszzz", [Globalization.CultureInfo]::InvariantCulture)
    })
    Remove-StaleFiles $dir
}

try { $null = Invoke-Main } catch { }
exit 0
