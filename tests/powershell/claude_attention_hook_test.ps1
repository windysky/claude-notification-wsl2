# claude_attention_hook_test.ps1 - plain-PowerShell tests for
# windows/claude-attention-hook.ps1 (Windows-native Claude Code attention hook).
#
# Run: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\powershell\claude_attention_hook_test.ps1
# Exit code = number of failures (like tests/bash/*_test.sh).
#
# Deliberately NOT named *.Tests.ps1 and not Pester syntax: this machine only has
# Pester 3.4, and a whole-folder Invoke-Pester would run this file and its final
# `exit` would end the Pester host. Source stays ASCII (Windows PowerShell 5.1
# reads BOM-less files as ANSI); non-ASCII test text is built from char codes.

$ErrorActionPreference = 'Stop'
$Hook = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\windows\claude-attention-hook.ps1'))
$Utf8 = New-Object Text.UTF8Encoding($false)
$script:Fails = 0
$script:Passes = 0
$Root = Join-Path ([IO.Path]::GetTempPath()) ('cah-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Root | Out-Null

function Check([string]$Label, [bool]$Ok, [string]$Detail = '') {
    if ($Ok) { Write-Host "ok   - $Label"; $script:Passes++ }
    else { Write-Host "FAIL - ${Label}: $Detail"; $script:Fails++ }
}

function New-SigDir {
    $d = Join-Path $Root ([guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $d | Out-Null
    $d
}

# Run the hook as a real child process: payload on stdin (UTF-8), env seam for the
# signal directory, LAUNCHER_SESSION controlled per call.
function Invoke-Hook {
    param([string]$Payload, [string]$Dir, [string]$Launcher = $null)
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = Join-Path $PSHOME 'powershell.exe'
    $psi.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $Hook + '"'
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $psi.EnvironmentVariables['WSL_TOAST_ATTENTION_DIR'] = $Dir
    if ($Launcher -ne $null) { $psi.EnvironmentVariables['LAUNCHER_SESSION'] = $Launcher }
    else { $psi.EnvironmentVariables.Remove('LAUNCHER_SESSION') }
    $p = [Diagnostics.Process]::Start($psi)
    $bytes = $Utf8.GetBytes($Payload)
    $p.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length)
    $p.StandardInput.Close()
    $so = $p.StandardOutput.ReadToEndAsync()
    $se = $p.StandardError.ReadToEndAsync()
    if (-not $p.WaitForExit(60000)) { $p.Kill(); throw 'hook timed out' }
    [pscustomobject]@{ Exit = $p.ExitCode; Out = $so.Result; Err = $se.Result }
}

function Get-Signals([string]$Dir) {
    @(Get-ChildItem -LiteralPath $Dir -Filter 'att-*.json' -ErrorAction SilentlyContinue)
}
function Read-Signal($File) {
    [IO.File]::ReadAllText($File.FullName, $Utf8) | ConvertFrom-Json
}
function J($h) { $h | ConvertTo-Json -Compress -Depth 5 }

# Run a hook call and return the single resulting signal object (or $null).
function Get-One([string]$Payload, [string]$Launcher = $null) {
    $d = New-SigDir
    $null = Invoke-Hook -Payload $Payload -Dir $d -Launcher $Launcher
    $f = Get-Signals $d
    if ($f.Count -eq 1) { Read-Signal $f[0] } else { $null }
}

$Cwd = 'C:\Users\someone\HLab-richR_v2.0 app'

# ---- needle -------------------------------------------------------------
$s = Get-One (J @{ hook_event_name = 'Stop'; session_id = 's1'; cwd = $Cwd }) 'HLab_richR'
Check 'needle comes from LAUNCHER_SESSION when set' ($s -and $s.needle -ceq 'HLab_richR') "got [$($s.needle)]"

$s = Get-One (J @{ hook_event_name = 'Stop'; session_id = 's1'; cwd = $Cwd })
Check 'needle falls back to cwd basename tokens (split on - _ . whitespace, lowercased)' `
    ($s -and $s.needle -ceq 'hlab richr v2 0 app') "got [$($s.needle)]"

$s = Get-One (J @{ hook_event_name = 'Stop'; session_id = 's1'; cwd = $Cwd }) '   '
Check 'blank LAUNCHER_SESSION counts as unset (basename fallback)' `
    ($s -and $s.needle -ceq 'hlab richr v2 0 app') "got [$($s.needle)]"

$s = Get-One (J @{ hook_event_name = 'Stop'; session_id = 's1'; cwd = 'C:\work\proj-x\' })
Check 'basename fallback tolerates a trailing separator' ($s -and $s.needle -ceq 'proj x') "got [$($s.needle)]"

# ---- kind mapping (mirror of _attention_kind) ---------------------------
foreach ($t in 'permission_prompt', 'elicitation_dialog', 'worker_permission_prompt', 'agent_needs_input') {
    $s = Get-One (J @{ hook_event_name = 'Notification'; notification_type = $t; message = 'm'; cwd = $Cwd })
    Check "notification_type $t -> kind ask" ($s -and $s.kind -ceq 'ask' -and $s.notification_type -ceq $t) "got [$($s.kind)]"
}
foreach ($t in 'idle_prompt', 'auth_success') {
    $s = Get-One (J @{ hook_event_name = 'Notification'; notification_type = $t; message = 'm'; cwd = $Cwd })
    Check "notification_type $t -> kind info" ($s -and $s.kind -ceq 'info') "got [$($s.kind)]"
}
$s = Get-One (J @{ hook_event_name = 'Notification'; notification_type = 'something_new'; message = 'm'; cwd = $Cwd })
Check 'unknown notification_type -> kind null' ($s -and $null -eq $s.kind) "got [$($s.kind)]"
$s = Get-One (J @{ hook_event_name = 'Notification'; message = 'm'; cwd = $Cwd })
Check 'missing notification_type -> kind null, notification_type null' `
    ($s -and $null -eq $s.kind -and $null -eq $s.notification_type)
$s = Get-One (J @{ hook_event_name = 'Stop'; last_assistant_message = 'Done.'; cwd = $Cwd })
Check 'Stop event -> kind null' ($s -and $null -eq $s.kind)

# ---- events -------------------------------------------------------------
$s = Get-One (J @{ hook_event_name = 'Notification'; message = 'n'; cwd = $Cwd })
Check 'Notification maps to event "notification"' ($s -and $s.event -ceq 'notification')
$s = Get-One (J @{ hook_event_name = 'Stop'; last_assistant_message = 's'; cwd = $Cwd })
Check 'Stop maps to event "stop"' ($s -and $s.event -ceq 'stop')

foreach ($ev in 'PreToolUse', 'UserPromptSubmit', 'SubagentStop', 'stop', '') {
    $d = New-SigDir
    $r = Invoke-Hook -Payload (J @{ hook_event_name = $ev; cwd = $Cwd }) -Dir $d
    Check "event [$ev] writes nothing, exits 0, no stdout" `
        ((Get-Signals $d).Count -eq 0 -and $r.Exit -eq 0 -and $r.Out -eq '') "files=$((Get-Signals $d).Count) exit=$($r.Exit)"
}
$d = New-SigDir
$r = Invoke-Hook -Payload (J @{ cwd = $Cwd }) -Dir $d
Check 'payload without hook_event_name writes nothing' ((Get-Signals $d).Count -eq 0 -and $r.Exit -eq 0)

# ---- messages -----------------------------------------------------------
$s = Get-One (J @{ hook_event_name = 'Stop'; cwd = $Cwd; last_assistant_message = "First paragraph here.`n`nSecond paragraph must not appear." })
Check 'Stop message is the first paragraph only' ($s -and $s.message -ceq 'First paragraph here.') "got [$($s.message)]"

$long = ('This is a reasonably long sentence number one. ' * 30)
$s = Get-One (J @{ hook_event_name = 'Stop'; cwd = $Cwd; last_assistant_message = $long })
Check 'Stop message capped at 600 and cut on a sentence boundary' `
    ($s -and $s.message.Length -le 600 -and $s.message.Length -gt 400 -and $s.message.EndsWith('.')) "len=$($s.message.Length)"

$s = Get-One (J @{ hook_event_name = 'Stop'; cwd = $Cwd; last_assistant_message = ('x' * 900) })
Check 'Stop message with no sentence boundary is cut and ends with "..."' `
    ($s -and $s.message.Length -eq 602 -and $s.message.EndsWith('...')) "len=$($s.message.Length)"

$s = Get-One (J @{ hook_event_name = 'Stop'; cwd = $Cwd; last_assistant_message = '## Title' + "`n" + 'All **bold** and [a link](http://x.y) with `code`.' })
Check 'Stop message strips markdown like first_paragraph' ($s -and $s.message -ceq 'Title All bold and a link with code.') "got [$($s.message)]"

$ko = -join ([char]0xD55C, [char]0xAE00, [char]0xC644, [char]0xB8CC)   # Korean text built from code points
$s = Get-One (J @{ hook_event_name = 'Stop'; cwd = $Cwd; last_assistant_message = $ko })
Check 'non-ASCII message round-trips as UTF-8' ($s -and $s.message -ceq $ko) "got [$($s.message)]"

# Stop text from the transcript (what Stop.sh does) when the payload has no last_assistant_message
$tp = Join-Path $Root 'transcript.jsonl'
$lines = @(
    (J @{ type = 'user'; message = @{ role = 'user'; content = 'hi' } }),
    (J @{ type = 'assistant'; message = @{ role = 'assistant'; content = @(@{ type = 'text'; text = 'Older answer.' }) } }),
    (J @{ type = 'assistant'; message = @{ role = 'assistant'; content = @(@{ type = 'thinking'; thinking = 'hmm' }, @{ type = 'text'; text = "Newest answer.`n`nSecond para." }) } }),
    (J @{ type = 'assistant'; message = @{ role = 'assistant'; content = @(@{ type = 'tool_use'; name = 'Bash' }) } }),
    'not json at all'
)
[IO.File]::WriteAllText($tp, ($lines -join "`n") + "`n", $Utf8)
$s = Get-One (J @{ hook_event_name = 'Stop'; cwd = $Cwd; transcript_path = $tp })
Check 'Stop falls back to the last assistant TEXT in the transcript' ($s -and $s.message -ceq 'Newest answer.') "got [$($s.message)]"
$s = Get-One (J @{ hook_event_name = 'Stop'; cwd = $Cwd; transcript_path = $tp; last_assistant_message = 'From payload.' })
Check 'payload last_assistant_message wins over the transcript' ($s -and $s.message -ceq 'From payload.') "got [$($s.message)]"
$s = Get-One (J @{ hook_event_name = 'Stop'; cwd = $Cwd; transcript_path = (Join-Path $Root 'missing.jsonl') })
Check 'missing transcript -> signal still written, message null' ($s -and $null -eq $s.message)

# Notification message: payload message, newlines flattened, capped at 600
$s = Get-One (J @{ hook_event_name = 'Notification'; notification_type = 'permission_prompt'; cwd = $Cwd; message = "Claude needs`nyour permission" })
Check 'Notification message = payload message with newlines flattened' ($s -and $s.message -ceq 'Claude needs your permission') "got [$($s.message)]"
$s = Get-One (J @{ hook_event_name = 'Notification'; cwd = $Cwd; message = ('y' * 900) })
Check 'Notification message capped at 600 chars' ($s -and $s.message.Length -eq 600) "len=$($s.message.Length)"

# ---- file naming, JSON shape, encoding ----------------------------------
$d = New-SigDir
$before = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
$r = Invoke-Hook -Payload (J @{ hook_event_name = 'Notification'; notification_type = 'permission_prompt'; session_id = 'sess-42'; cwd = $Cwd; message = $ko }) -Dir $d -Launcher 'WG_x'
$after = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
$all = @(Get-ChildItem -LiteralPath $d)
Check 'exactly one file left behind (no temp leftovers)' ($all.Count -eq 1) "files=$($all.Name -join ',')"
$f = Get-Signals $d
if ($f.Count -ne 1) {
    Check 'one signal file was written' $false "files=$($f.Count) stderr=[$($r.Err)]"
} else {
    $m = [regex]::Match($f[0].Name, '^att-([0-9]+)-(.*)\.json$')
    Check 'filename matches the consumer regex ^att-([0-9]+)-(.*)\.json$' $m.Success "name=$($f[0].Name)"
    $ms = if ($m.Success) { [int64]$m.Groups[1].Value } else { 0 }
    Check 'filename epoch is current milliseconds' ($ms -ge ($before - 2000) -and $ms -le ($after + 2000)) "ms=$ms window=$before..$after"
    $raw = [IO.File]::ReadAllBytes($f[0].FullName)
    Check 'file is UTF-8 without BOM' (-not ($raw.Length -ge 3 -and $raw[0] -eq 0xEF -and $raw[1] -eq 0xBB -and $raw[2] -eq 0xBF))
    $obj = $Utf8.GetString($raw) | ConvertFrom-Json
    Check 'JSON has version 1, event, non-empty needle' ($obj.version -eq 1 -and $obj.event -ceq 'notification' -and $obj.needle -ceq 'WG_x')
    Check 'JSON carries session_id, cwd, notification_type, message' `
        ($obj.session_id -ceq 'sess-42' -and $obj.cwd -ceq $Cwd -and $obj.notification_type -ceq 'permission_prompt' -and $obj.message -ceq $ko)
    Check 'timestamp is ISO-8601 with offset and parses' `
        ($obj.timestamp -match '^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d[+-]\d\d:\d\d$' -and [bool][DateTimeOffset]::Parse($obj.timestamp)) "ts=$($obj.timestamp)"
}
Check 'success writes nothing to stdout and exits 0' ($r.Exit -eq 0 -and $r.Out -eq '') "exit=$($r.Exit) out=[$($r.Out)]"

# ---- robustness ---------------------------------------------------------
foreach ($bad in @('{ this is not json', '', '   ', '[1,2,3]', 'null')) {
    $d = New-SigDir
    $r = Invoke-Hook -Payload $bad -Dir $d
    Check "stdin [$bad] -> exit 0, nothing written, no stdout" `
        ($r.Exit -eq 0 -and (Get-Signals $d).Count -eq 0 -and $r.Out -eq '') "exit=$($r.Exit) out=[$($r.Out)]"
}

# signal dir that cannot be created (a regular file stands in its place)
$blocked = Join-Path $Root 'blocked'
[IO.File]::WriteAllText($blocked, 'x')
$r = Invoke-Hook -Payload (J @{ hook_event_name = 'Stop'; cwd = $Cwd }) -Dir $blocked
Check 'unusable signal dir -> exit 0, no stdout' ($r.Exit -eq 0 -and $r.Out -eq '') "exit=$($r.Exit) out=[$($r.Out)]"

# missing signal dir is created
$fresh = Join-Path $Root 'fresh\nested'
$r = Invoke-Hook -Payload (J @{ hook_event_name = 'Stop'; cwd = $Cwd }) -Dir $fresh
Check 'missing signal dir is created' ((Get-Signals $fresh).Count -eq 1)

# ---- self-prune ---------------------------------------------------------
$d = New-SigDir
$old = Join-Path $d 'att-1-old.json'
$oldTmp = Join-Path $d 'tmp-leftover.tmp'
$keep = Join-Path $d 'att-2-recent.json'
$hb = Join-Path $d 'organizer.json'
foreach ($p in $old, $oldTmp, $keep, $hb) { [IO.File]::WriteAllText($p, '{}') }
(Get-Item $old).LastWriteTime = (Get-Date).AddMinutes(-10)
(Get-Item $oldTmp).LastWriteTime = (Get-Date).AddMinutes(-10)
(Get-Item $hb).LastWriteTime = (Get-Date).AddMinutes(-10)
(Get-Item $keep).LastWriteTime = (Get-Date).AddMinutes(-1)
$null = Invoke-Hook -Payload (J @{ hook_event_name = 'Stop'; cwd = $Cwd }) -Dir $d
Check 'att-*.json older than 5 minutes is pruned' (-not (Test-Path $old))
Check 'stale temp leftovers are pruned' (-not (Test-Path $oldTmp))
Check 'recent att-*.json is kept' (Test-Path $keep)
Check 'organizer.json heartbeat is never touched' (Test-Path $hb)

# ---- done ---------------------------------------------------------------
Remove-Item -LiteralPath $Root -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ''
Write-Host "claude_attention_hook_test: $script:Passes passed, $script:Fails failed"
exit $script:Fails
