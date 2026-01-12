# Pester tests for wsl-toast.ps1
# These tests verify the PowerShell toast notification functionality

BeforeDiscovery {
    # Test module requirements
    $pesterVersion = $null
    if (Get-Module -ListAvailable -Name Pester) {
        $pesterVersion = (Get-Module -ListAvailable -Name Pester | Sort-Object Version -Descending | Select-Object -First 1).Version
    }

    # Check if BurntToast module is available
    $burntToastAvailable = Get-Module -ListAvailable -Name BurntToast

    # Mock flag for testing without actual toast notifications
    $script:MockMode = $true
}

BeforeAll {
    # Import the script under test
    $scriptPath = $PSScriptRoot + '/../windows/wsl-toast.ps1'

    # Create mock Windows directory structure for testing
    $windowsDir = $PSScriptRoot + '/../windows'
    if (-not (Test-Path $windowsDir)) {
        New-Item -ItemType Directory -Path $windowsDir -Force | Out-Null
    }

    # Source the script (we'll create functions that can be tested)
    . $scriptPath
}

Describe 'wsl-toast.ps1 - Module Requirements' {
    It 'Should have PowerShell version 5.1 or higher' {
        $PSVersionTable.PSVersion.Major | Should -BeGreaterOrEqual 5
    }

    It 'Should have BurntToast module available or gracefully handle missing module' {
        $burntToast = Get-Module -ListAvailable -Name BurntToast
        if ($null -eq $burntToast) {
            # Script should handle missing module gracefully
            { Test-BurntToastAvailability } | Should -Not -Throw
        } else {
            $burntToast.Name | Should -Be 'BurntToast'
        }
    }
}

Describe 'wsl-toast.ps1 - Parameter Validation' {
    It 'Should accept title parameter' {
        $params = (Get-Command Send-WSLToast).Parameters
        $params.ContainsKey('Title') | Should -Be $true
    }

    It 'Should accept message parameter' {
        $params = (Get-Command Send-WSLToast).Parameters
        $params.ContainsKey('Message') | Should -Be $true
    }

    It 'Should accept optional type parameter' {
        $params = (Get-Command Send-WSLToast).Parameters
        $params.ContainsKey('Type') | Should -Be $true
    }

    It 'Should accept optional duration parameter' {
        $params = (Get-Command Send-WSLToast).Parameters
        $params.ContainsKey('Duration') | Should -Be $true
    }

    It 'Should accept optional appLogo parameter' {
        $params = (Get-Command Send-WSLToast).Parameters
        $params.ContainsKey('AppLogo') | Should -Be $true
    }
}

Describe 'wsl-toast.ps1 - UTF-8 Encoding Support' {
    It 'Should handle English characters' {
        $title = 'Test Notification'
        $message = 'This is a test message'

        { Test-UTF8Encoding -Title $title -Message $message } | Should -Not -Throw
    }

    It 'Should handle Korean characters' {
        $title = '테스트 알림'
        $message = '이것은 테스트 메시지입니다'

        { Test-UTF8Encoding -Title $title -Message $message } | Should -Not -Throw
    }

    It 'Should handle Japanese characters' {
        $title = 'テスト通知'
        $message = 'これはテストメッセージです'

        { Test-UTF8Encoding -Title $title -Message $message } | Should -Not -Throw
    }

    It 'Should handle Chinese characters' {
        $title = '测试通知'
        $message = '这是一条测试消息'

        { Test-UTF8Encoding -Title $title -Message $message } | Should -Not -Throw
    }
}

Describe 'wsl-toast.ps1 - Notification Type Validation' {
    It 'Should accept valid notification type: Information' {
        { Validate-NotificationType -Type 'Information' } | Should -Not -Throw
    }

    It 'Should accept valid notification type: Warning' {
        { Validate-NotificationType -Type 'Warning' } | Should -Not -Throw
    }

    It 'Should accept valid notification type: Error' {
        { Validate-NotificationType -Type 'Error' } | Should -Not -Throw
    }

    It 'Should accept valid notification type: Success' {
        { Validate-NotificationType -Type 'Success' } | Should -Not -Throw
    }

    It 'Should default to Information type for invalid type' {
        $result = Get-DefaultNotificationType -Type 'InvalidType'
        $result | Should -Be 'Information'
    }
}

Describe 'wsl-toast.ps1 - Duration Validation' {
    It 'Should accept duration: Short' {
        { Validate-Duration -Duration 'Short' } | Should -Not -Throw
    }

    It 'Should accept duration: Normal' {
        { Validate-Duration -Duration 'Normal' } | Should -Not -Throw
    }

    It 'Should accept duration: Long' {
        { Validate-Duration -Duration 'Long' } | Should -Not -Throw
    }

    It 'Should default to Normal duration for invalid duration' {
        $result = Get-DefaultDuration -Duration 'InvalidDuration'
        $result | Should -Be 'Normal'
    }
}

Describe 'wsl-toast.ps1 - Toast Construction' {
    BeforeEach {
        $script:TestToastCreated = $false
        $script:LastToastTitle = $null
        $script:LastToastMessage = $null
    }

    It 'Should create toast with title and message' {
        $title = 'Test Title'
        $message = 'Test Message'

        $result = New-ToastObject -Title $title -Message $message

        $result.Title | Should -Be $title
        $result.Message | Should -Be $message
    }

    It 'Should create toast with Information type by default' {
        $result = New-ToastObject -Title 'Test' -Message 'Message'

        $result.Type | Should -Be 'Information'
    }

    It 'Should create toast with custom type' {
        $result = New-ToastObject -Title 'Test' -Message 'Message' -Type 'Warning'

        $result.Type | Should -Be 'Warning'
    }
}

Describe 'wsl-toast.ps1 - Error Handling' {
    It 'Should gracefully handle null title' {
        $result = Test-NullParameter -Value $null -ParameterName 'Title'
        $result | Should -Be $true
    }

    It 'Should gracefully handle empty message' {
        $result = Test-EmptyParameter -Value '' -ParameterName 'Message'
        $result | Should -Be $true
    }

    It 'Should provide default values for missing optional parameters' {
        $toast = Get-DefaultToastConfiguration

        $toast.Type | Should -Not -BeNullOrEmpty
        $toast.Duration | Should -Not -BeNullOrEmpty
    }
}

Describe 'wsl-toast.ps1 - Script Entry Point' {
    It 'Should have Send-WSLToast function' {
        { Get-Command Send-WSLToast -ErrorAction Stop } | Should -Not -Throw
    }

    It 'Should accept parameters from command line' {
        # Test that the script can be called with parameters
        $paramBlock = (Get-Command Send-WSLToast).Parameters
        $paramBlock.Count | Should -BeGreaterOrEqual 2
    }

    It 'Should output result object' {
        # Mock the toast creation and verify output
        $result = Test-ToastOutput -Title 'Test' -Message 'Message'

        $result.Success | Should -BeOfType [bool]
        $result.Message | Should -Not -BeNullOrEmpty
    }
}

Describe 'wsl-toast.ps1 - Help Documentation' {
    It 'Should have synopsis documentation' {
        $help = Get-Help Send-WSLToast
        $help.Synopsis | Should -Not -BeNullOrEmpty
    }

    It 'Should have description documentation' {
        $help = Get-Help Send-WSLToast
        $help.Description | Should -Not -BeNullOrEmpty
    }

    It 'Should document all parameters' {
        $help = Get-Help Send-WSLToast -Parameter *
        $help | Should -Not -BeNullOrEmpty
    }
}

Describe 'wsl-toast.ps1 - Integration Tests' {
    BeforeEach {
        $script:MockMode = $true
    }

    It 'Should complete notification flow without errors' {
        $title = 'Integration Test'
        $message = 'Testing complete flow'

        { Send-WSLToast -Title $title -Message $message -MockMode $true } | Should -Not -Throw
    }

    It 'Should handle Unicode content correctly' {
        $title = '테スト'
        $message = '日本語 中文 한국어'

        { Send-WSLToast -Title $title -Message $message -MockMode $true } | Should -Not -Throw
    }

    It 'Should return success result object' {
        $result = Send-WSLToast -Title 'Test' -Message 'Message' -MockMode $true

        $result.Success | Should -Be $true
        $result.Timestamp | Should -BeOfType [datetime]
    }
}
