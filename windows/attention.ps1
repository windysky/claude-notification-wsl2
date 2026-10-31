# attention.ps1 - Flash the Windows Terminal window that owns a given session.
#
# Called from WSL by hooks/_attention.sh:
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File attention.ps1 `
#       -Needle "claude notification wsl2" [-Mode until_focus|fixed] [-Count 5]
#
# How it finds the window: every Windows Terminal top-level window has class
# CASCADIA_HOSTING_WINDOW_CLASS. The WSL side passes space-joined tokens from
# the session's working-directory basename; a window matches when its title,
# normalized (lowercase, non-alphanumerics stripped), contains EVERY token.
# This works in both title regimes:
#   - launcher-fixed titles like "HG_ClaudeWSL2Notification" (title-suppressed
#     profiles, e.g. windows managed by TerminalOrganizer) - the launcher name
#     embeds the project name in any word order;
#   - ordinary titles like "user@host: ~/PROJECTS/claude-notification-wsl2",
#     where the path itself carries the tokens.
# Known limitation: a session hidden in an inactive tab of a window with
# suppressed titles is not discoverable this way; that case exits with code 2
# and the caller logs it.
#
# Exit codes: 0 = flashed at least one window
#             2 = no matching window found
#             3 = unexpected error

param(
    [Parameter(Mandatory = $true)]
    [string]$Needle,

    [ValidateSet("until_focus", "fixed")]
    [string]$Mode = "until_focus",

    [int]$Count = 5
)

$ErrorActionPreference = "Stop"

$source = @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

namespace WslToast
{
    public static class Attention
    {
        private const string TerminalClass = "CASCADIA_HOSTING_WINDOW_CLASS";

        public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

        [DllImport("user32.dll")]
        private static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lParam);

        [DllImport("user32.dll")]
        private static extern int GetClassName(IntPtr hWnd, StringBuilder text, int count);

        [DllImport("user32.dll")]
        private static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);

        [DllImport("user32.dll")]
        private static extern bool IsWindowVisible(IntPtr hWnd);

        [StructLayout(LayoutKind.Sequential)]
        public struct FLASHWINFO
        {
            public uint cbSize;
            public IntPtr hwnd;
            public uint dwFlags;
            public uint uCount;
            public IntPtr dwTimeout;
        }

        [DllImport("user32.dll")]
        private static extern bool FlashWindowEx(ref FLASHWINFO pwfi);

        private const uint FLASHW_ALL = 3;         // flash caption + taskbar
        private const uint FLASHW_TIMERNOFG = 12;  // keep flashing until window is foreground

        // Normalize: lowercase, strip everything that is not a letter or digit.
        private static string Normalize(string s)
        {
            var sb = new StringBuilder(s.Length);
            foreach (char c in s.ToLowerInvariant())
            {
                if (char.IsLetterOrDigit(c)) sb.Append(c);
            }
            return sb.ToString();
        }

        // True when every token of needle (split on whitespace) appears in the
        // normalized window title. Token order does not matter.
        public static bool TitleMatches(string windowTitle, string[] tokens)
        {
            if (tokens.Length == 0) return false;
            string norm = Normalize(windowTitle);
            if (norm.Length == 0) return false;
            foreach (string token in tokens)
            {
                string t = Normalize(token);
                if (t.Length == 0) continue;
                if (norm.IndexOf(t, StringComparison.Ordinal) < 0) return false;
            }
            return true;
        }

        public static List<IntPtr> FindTerminalWindows(string[] tokens)
        {
            var result = new List<IntPtr>();
            EnumWindows((hWnd, lParam) =>
            {
                var cls = new StringBuilder(256);
                GetClassName(hWnd, cls, 256);
                if (cls.ToString() == TerminalClass && IsWindowVisible(hWnd))
                {
                    var txt = new StringBuilder(512);
                    GetWindowText(hWnd, txt, 512);
                    if (TitleMatches(txt.ToString(), tokens))
                    {
                        result.Add(hWnd);
                    }
                }
                return true;
            }, IntPtr.Zero);
            return result;
        }

        public static void Flash(IntPtr hwnd, bool untilForeground, uint count)
        {
            var info = new FLASHWINFO();
            info.cbSize = (uint)Marshal.SizeOf(typeof(FLASHWINFO));
            info.hwnd = hwnd;
            if (untilForeground)
            {
                info.dwFlags = FLASHW_ALL | FLASHW_TIMERNOFG;
                info.uCount = 0;
            }
            else
            {
                info.dwFlags = FLASHW_ALL;
                info.uCount = count;
            }
            info.dwTimeout = IntPtr.Zero;
            FlashWindowEx(ref info);
        }
    }
}
'@

try
{
    Add-Type -TypeDefinition $source -Language CSharp
}
catch [System.Management.RuntimeException]
{
    # Already loaded in this PowerShell session (e.g. repeated calls) - safe to continue.
}

try
{
    $tokens = @($Needle -split '\s+' | Where-Object { $_ -match '\S' })
    if ($tokens.Count -eq 0)
    {
        Write-Output "attention: no needle tokens given"
        exit 2
    }

    $windows = [WslToast.Attention]::FindTerminalWindows($tokens)
    if ($windows.Count -eq 0)
    {
        Write-Output "attention: no window matched '$($tokens -join ' ')'"
        exit 2
    }

    $untilFocus = ($Mode -ne "fixed")
    foreach ($hwnd in $windows)
    {
        [WslToast.Attention]::Flash($hwnd, $untilFocus, [uint32]$Count)
    }

    Write-Output "attention: flashed $($windows.Count) window(s), mode=$Mode"
    exit 0
}
catch
{
    Write-Output "attention: error: $($_.Exception.Message)"
    exit 3
}
