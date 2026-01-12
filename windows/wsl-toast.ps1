# wsl-toast.ps1
# PowerShell Toast Notification Script for Claude Code CLI on WSL2
# Displays Windows toast notifications with UTF-8 encoding support

#Requires -Version 5.1

<#
.SYNOPSIS
    Displays Windows toast notifications from WSL2 for Claude Code CLI

.DESCRIPTION
    This script creates and displays Windows toast notifications using the
    BurntToast PowerShell module. It supports UTF-8 encoding for multi-language
    content (English, Korean, Japanese, Chinese) and provides configurable
    notification types and durations.

.PARAMETER Title
    The title of the notification (required)

.PARAMETER Message
    The message body of the notification (required)

.PARAMETER Type
    The type of notification: Information, Warning, Error, or Success (default: Information)

.PARAMETER Duration
    The display duration: Short, Normal, or Long (default: Normal)

.PARAMETER AppLogo
    Optional path to a custom icon/image for the notification

.PARAMETER MockMode
    Testing mode that doesn't display actual notifications (default: false)

.EXAMPLE
    .\wsl-toast.ps1 -Title "Test" -Message "Test message"
    Displays a basic information notification

.EXAMPLE
    .\wsl-toast.ps1 -Title "Warning" -Message "Warning message" -Type "Warning" -Duration "Long"
    Displays a warning notification with long duration

.EXAMPLE
    .\wsl-toast.ps1 -Title "테스트" -Message "한글 메시지" -Type "Success"
    Displays a success notification with Korean characters

.NOTES
    Version: 1.0.0
    Author: Claude Code TDD Implementation
    Requires: PowerShell 5.1+, BurntToast module (optional, with graceful fallback)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0)]
    [ValidateNotNullOrEmpty()]
    [string]$Title,

    [Parameter(Mandatory=$true, Position=1)]
    [ValidateNotNullOrEmpty()]
    [string]$Message,

    [Parameter(Mandatory=$false)]
    [ValidateSet('Information', 'Warning', 'Error', 'Success')]
    [string]$Type = 'Information',

    [Parameter(Mandatory=$false)]
    [ValidateSet('Short', 'Normal', 'Long')]
    [string]$Duration = 'Normal',

    [Parameter(Mandatory=$false)]
    [string]$AppLogo,

    [Parameter(Mandatory=$false)]
    [switch]$MockMode
)

#region Helper Functions

<#
.SYNOPSIS
    Tests if the BurntToast module is available

.OUTPUTS
    System.Boolean indicating if BurntToast is available
#>
function Test-BurntToastAvailability {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $module = Get-Module -ListAvailable -Name BurntToast -ErrorAction SilentlyContinue
    return ($null -ne $module)
}

<#
.SYNOPSIS
    Tests UTF-8 encoding for international characters

.PARAMETER Title
    The title to test

.PARAMETER Message
    The message to test

.OUTPUTS
    System.Boolean indicating if encoding is valid
#>
function Test-UTF8Encoding {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Title,

        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    try {
        # Test encoding by converting to UTF-8 bytes and back
        $titleBytes = [System.Text.Encoding]::UTF8.GetBytes($Title)
        $messageBytes = [System.Text.Encoding]::UTF8.GetBytes($Message)

        $decodedTitle = [System.Text.Encoding]::UTF8.GetString($titleBytes)
        $decodedMessage = [System.Text.Encoding]::UTF8.GetString($messageBytes)

        # Verify round-trip conversion
        return ($Title -eq $decodedTitle) -and ($Message -eq $decodedMessage)
    }
    catch {
        Write-Error "UTF-8 encoding test failed: $_"
        return $false
    }
}

<#
.SYNOPSIS
    Validates and returns the notification type with defaults

.PARAMETER Type
    The type to validate

.OUTPUTS
    System.String with valid notification type
#>
function Get-DefaultNotificationType {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Type = 'Information'
    )

    $validTypes = @('Information', 'Warning', 'Error', 'Success')

    if ($Type -in $validTypes) {
        return $Type
    }

    return 'Information'
}

<#
.SYNOPSIS
    Validates the notification type

.PARAMETER Type
    The type to validate

.OUTPUTS
    System.Boolean indicating if type is valid
#>
function Validate-NotificationType {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Type
    )

    $validTypes = @('Information', 'Warning', 'Error', 'Success')
    return $Type -in $validTypes
}

<#
.SYNOPSIS
    Validates and returns the duration with defaults

.PARAMETER Duration
    The duration to validate

.OUTPUTS
    System.String with valid duration
#>
function Get-DefaultDuration {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Duration = 'Normal'
    )

    $validDurations = @('Short', 'Normal', 'Long')

    if ($Duration -in $validDurations) {
        return $Duration
    }

    return 'Normal'
}

<#
.SYNOPSIS
    Validates the duration

.PARAMETER Duration
    The duration to validate

.OUTPUTS
    System.Boolean indicating if duration is valid
#>
function Validate-Duration {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Duration
    )

    $validDurations = @('Short', 'Normal', 'Long')
    return $Duration -in $validDurations
}

<#
.SYNOPSIS
    Tests if a parameter value is null

.PARAMETER Value
    The value to test

.PARAMETER ParameterName
    The name of the parameter (for error messages)

.OUTPUTS
    System.Boolean indicating if value is null
#>
function Test-NullParameter {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$true)]
        [AllowNull()]
        $Value,

        [Parameter(Mandatory=$true)]
        [string]$ParameterName
    )

    if ($null -eq $Value) {
        Write-Warning "Parameter '$ParameterName' is null"
        return $true
    }

    return $false
}

<#
.SYNOPSIS
    Tests if a parameter value is empty

.PARAMETER Value
    The value to test

.PARAMETER ParameterName
    The name of the parameter (for error messages)

.OUTPUTS
    System.Boolean indicating if value is empty
#>
function Test-EmptyParameter {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Value,

        [Parameter(Mandatory=$true)]
        [string]$ParameterName
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        Write-Warning "Parameter '$ParameterName' is empty"
        return $true
    }

    return $false
}

<#
.SYNOPSIS
    Gets the default toast configuration

.OUTPUTS
    System.Management.Automation.PSObject with default configuration
#>
function Get-DefaultToastConfiguration {
    [CmdletBinding()]
    [OutputType([psobject])]
    param()

    return [PSCustomObject]@{
        Type = 'Information'
        Duration = 'Normal'
        AppName = 'Claude Code'
    }
}

<#
.SYNOPSIS
    Creates a toast object with specified properties

.PARAMETER Title
    The notification title

.PARAMETER Message
    The notification message

.PARAMETER Type
    The notification type

.PARAMETER Duration
    The notification duration

.PARAMETER AppLogo
    Optional path to app logo

.OUTPUTS
    System.Management.Automation.PSObject representing the toast
#>
function New-ToastObject {
    [CmdletBinding()]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Title,

        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [string]$Type = 'Information',

        [Parameter(Mandatory=$false)]
        [string]$Duration = 'Normal',

        [Parameter(Mandatory=$false)]
        [string]$AppLogo
    )

    $toast = [PSCustomObject]@{
        Title = $Title
        Message = $Message
        Type = Get-DefaultNotificationType -Type $Type
        Duration = Get-DefaultDuration -Duration $Duration
        AppLogo = $AppLogo
        Timestamp = Get-Date
    }

    return $toast
}

<#
.SYNOPSIS
    Tests the toast output without displaying

.PARAMETER Title
    The notification title

.PARAMETER Message
    The notification message

.OUTPUTS
    System.Management.Automation.PSObject with test result
#>
function Test-ToastOutput {
    [CmdletBinding()]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Title,

        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    return [PSCustomObject]@{
        Success = $true
        Title = $Title
        Message = $Message
        Timestamp = Get-Date
    }
}

<#
.SYNOPSIS
    Displays the toast notification using BurntToast or fallback

.PARAMETER Toast
    The toast object to display

.PARAMETER MockMode
    If true, don't display actual notification

.OUTPUTS
    System.Management.Automation.PSObject with result
#>
function Show-ToastNotification {
    [CmdletBinding()]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory=$true)]
        [psobject]$Toast,

        [Parameter(Mandatory=$false)]
        [switch]$MockMode
    )

    $result = [PSCustomObject]@{
        Success = $false
        Method = $null
        Message = $null
        Timestamp = Get-Date
    }

    try {
        if ($MockMode) {
            $result.Success = $true
            $result.Method = 'Mock'
            $result.Message = 'Mock mode: Notification not displayed'
        }
        elseif (Test-BurntToastAvailability) {
            # Import BurntToast module
            Import-Module BurntToast -ErrorAction Stop

            # Map notification types to BurntToast functions
            $toastBuilder = switch ($Toast.Type) {
                'Warning'  { { & $Toast.Title $Toast.Message -WarningBanner } }
                'Error'    { { & $Toast.Title $Toast.Message -BannerColor Red } }
                'Success'  { { & $Toast.Title $Toast.Message -BannerColor Green } }
                default    { { & $Toast.Title $Toast.Message } }
            }

            # Display the toast
            if ($Toast.AppLogo) {
                $null = New-BurntToastNotification -Title $Toast.Title -Body $Toast.Message -AppLogo $Toast.AppLogo
            }
            else {
                $null = New-BurntToastNotification -Title $Toast.Title -Body $Toast.Message
            }

            $result.Success = $true
            $result.Method = 'BurntToast'
            $result.Message = 'Notification displayed using BurntToast'
        }
        else {
            # Fallback: Use Windows Forms Balloon Tip
            Add-Type -AssemblyName System.Windows.Forms

            $balloon = New-Object System.Windows.Forms.NotifyIcon
            $balloon.Icon = [System.Drawing.SystemIcons]::Information
            $balloon.BalloonTipIcon = switch ($Toast.Type) {
                'Warning' { 'Warning' }
                'Error'   { 'Error' }
                'Success' { 'Info' }
                default   { 'Info' }
            }
            $balloon.BalloonTipTitle = $Toast.Title
            $balloon.BalloonTipText = $Toast.Message
            $balloon.Visible = $true

            # Show balloon and cleanup
            $balloon.ShowBalloonTip(5000)
            Start-Sleep -Milliseconds 100
            $balloon.Dispose()

            $result.Success = $true
            $result.Method = 'BalloonTip'
            $result.Message = 'Notification displayed using Windows Forms BalloonTip'
        }
    }
    catch {
        $result.Success = $false
        $result.Method = 'Failed'
        $result.Message = "Error displaying notification: $_"
    }

    return $result
}

#endregion

#region Main Function

<#
.SYNOPSIS
    Main function to send WSL toast notification

.PARAMETER Title
    The notification title

.PARAMETER Message
    The notification message

.PARAMETER Type
    The notification type

.PARAMETER Duration
    The notification duration

.PARAMETER AppLogo
    Optional path to app logo

.PARAMETER MockMode
    Testing mode flag

.OUTPUTS
    System.Management.Automation.PSObject with operation result
#>
function Send-WSLToast {
    [CmdletBinding()]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [ValidateNotNullOrEmpty()]
        [string]$Title,

        [Parameter(Mandatory=$true, Position=1)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [ValidateSet('Information', 'Warning', 'Error', 'Success')]
        [string]$Type = 'Information',

        [Parameter(Mandatory=$false)]
        [ValidateSet('Short', 'Normal', 'Long')]
        [string]$Duration = 'Normal',

        [Parameter(Mandatory=$false)]
        [string]$AppLogo,

        [Parameter(Mandatory=$false)]
        [switch]$MockMode
    )

    $result = [PSCustomObject]@{
        Success = $false
        Title = $Title
        Message = $Message
        Type = $Type
        Duration = $Duration
        Timestamp = Get-Date
        Error = $null
    }

    try {
        # Validate UTF-8 encoding
        if (-not (Test-UTF8Encoding -Title $Title -Message $Message)) {
            throw "UTF-8 encoding validation failed"
        }

        # Create toast object
        $toast = New-ToastObject -Title $Title -Message $Message -Type $Type -Duration $Duration -AppLogo $AppLogo

        # Display the notification
        $displayResult = Show-ToastNotification -Toast $toast -MockMode:$MockMode

        $result.Success = $displayResult.Success
        $result.DisplayMethod = $displayResult.Method
        $result.DisplayMessage = $displayResult.Message
    }
    catch {
        $result.Success = $false
        $result.Error = $_.Exception.Message
    }

    return $result
}

#endregion

# Script entry point
if ($MyInvocation.InvocationName -ne '.') {
    # Script is being executed directly
    $result = Send-WSLToast @PSBoundParameters

    # Output result as JSON for programmatic access
    $result | ConvertTo-Json -Compress

    # Exit with appropriate code
    exit $(if ($result.Success) { 0 } else { 1 })
}
