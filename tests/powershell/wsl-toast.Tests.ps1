# wsl-toast.ps1 Tests
# Pester test suite for PowerShell toast notification script
#
# Author: Claude Code TDD Implementation
# Version: 1.0.0

BeforeAll {
    # Import the script to test
    $ScriptPath = $PSScriptRoot + "\..\..\windows\wsl-toast.ps1"
    . $ScriptPath

    # Mock environment for testing
    $TestResults = @()
}

AfterAll {
    # Cleanup
}

Describe 'wsl-toast.ps1 Unit Tests' {
    Context 'Helper Functions' {
        It 'Test-BurntToastAvailability returns boolean' {
            $result = Test-BurntToastAvailability
            $result | Should -BeOfType [bool]
        }

        It 'Test-UTF8Encoding validates UTF-8 strings correctly' {
            $result = Test-UTF8Encoding -Title "Test" -Message "Test Message"
            $result | Should -BeOfType [bool]
            $result | Should -Be $true
        }

        It 'Test-UTF8Encoding handles Korean characters' {
            $result = Test-UTF8Encoding -Title "테스트" -Message "한글 메시지"
            $result | Should -Be $true
        }

        It 'Test-UTF8Encoding handles Japanese characters' {
            $result = Test-UTF8Encoding -Title "テスト" -Message "日本語メッセージ"
            $result | Should -Be $true
        }

        It 'Test-UTF8Encoding handles Chinese characters' {
            $result = Test-UTF8Encoding -Title "测试" -Message "中文消息"
            $result | Should -Be $true
        }

        It 'Get-DefaultNotificationType returns valid type' {
            $result = Get-DefaultNotificationType -Type 'Information'
            $result | Should -Be 'Information'
        }

        It 'Get-DefaultNotificationType defaults to Information for invalid type' {
            $result = Get-DefaultNotificationType -Type 'InvalidType'
            $result | Should -Be 'Information'
        }

        It 'Validate-NotificationType validates correct types' {
            $validTypes = @('Information', 'Warning', 'Error', 'Success')
            foreach ($type in $validTypes) {
                $result = Validate-NotificationType -Type $type
                $result | Should -Be $true
            }
        }

        It 'Validate-NotificationType rejects invalid types' {
            $result = Validate-NotificationType -Type 'InvalidType'
            $result | Should -Be $false
        }

        It 'Get-DefaultDuration returns valid duration' {
            $result = Get-DefaultDuration -Duration 'Normal'
            $result | Should -Be 'Normal'
        }

        It 'Get-DefaultDuration defaults to Normal for invalid duration' {
            $result = Get-DefaultDuration -Duration 'InvalidDuration'
            $result | Should -Be 'Normal'
        }

        It 'Validate-Duration validates correct durations' {
            $validDurations = @('Short', 'Normal', 'Long')
            foreach ($duration in $validDurations) {
                $result = Validate-Duration -Duration $duration
                $result | Should -Be $true
            }
        }

        It 'Test-NullParameter detects null values' {
            $result = Test-NullParameter -Value $null -ParameterName 'TestParam'
            $result | Should -Be $true
        }

        It 'Test-NullParameter returns false for non-null values' {
            $result = Test-NullParameter -Value 'Test' -ParameterName 'TestParam'
            $result | Should -Be $false
        }

        It 'Test-EmptyParameter detects empty strings' {
            $result = Test-EmptyParameter -Value '' -ParameterName 'TestParam'
            $result | Should -Be $true
        }

        It 'Test-EmptyParameter detects whitespace strings' {
            $result = Test-EmptyParameter -Value '   ' -ParameterName 'TestParam'
            $result | Should -Be $true
        }

        It 'Get-DefaultToastConfiguration returns default config object' {
            $result = Get-DefaultToastConfiguration
            $result | Should -Not -BeNullOrEmpty
            $result.Type | Should -Be 'Information'
            $result.Duration | Should -Be 'Normal'
            $result.AppName | Should -Be 'Claude Code'
        }

        It 'New-ToastObject creates toast with correct properties' {
            $result = New-ToastObject -Title 'Test' -Message 'Test Message' -Type 'Success' -Duration 'Long'
            $result.Title | Should -Be 'Test'
            $result.Message | Should -Be 'Test Message'
            $result.Type | Should -Be 'Success'
            $result.Duration | Should -Be 'Long'
            $result.Timestamp | Should -Not -BeNullOrEmpty
        }

        It 'New-ToastObject applies default values for optional parameters' {
            $result = New-ToastObject -Title 'Test' -Message 'Test Message'
            $result.Type | Should -Be 'Information'
            $result.Duration | Should -Be 'Normal'
        }

        It 'Test-ToastOutput returns success result' {
            $result = Test-ToastOutput -Title 'Test' -Message 'Test Message'
            $result.Success | Should -Be $true
            $result.Title | Should -Be 'Test'
            $result.Message | Should -Be 'Test Message'
            $result.Timestamp | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Show-ToastNotification' {
        It 'Show-ToastNotification returns result object' {
            $toast = New-ToastObject -Title 'Test' -Message 'Test Message'
            $result = Show-ToastNotification -Toast $toast -MockMode
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
            $result.Method | Should -Be 'Mock'
        }

        It 'Show-ToastNotification in MockMode does not display notification' {
            $toast = New-ToastObject -Title 'Test' -Message 'Test Message'
            $result = Show-ToastNotification -Toast $toast -MockMode
            $result.Success | Should -Be $true
            $result.Method | Should -Be 'Mock'
            $result.Message | Should -BeLike '*Mock*'
        }
    }

    Context 'Send-WSLToast Main Function' {
        It 'Send-WSLToast returns success for valid parameters' {
            $result = Send-WSLToast -Title 'Test' -Message 'Test Message' -MockMode
            $result.Success | Should -Be $true
            $result.Title | Should -Be 'Test'
            $result.Message | Should -Be 'Test Message'
            $result.Error | Should -BeNullOrEmpty
        }

        It 'Send-WSLToast handles multi-language content' {
            $testCases = @(
                @{ Title = '테스트'; Message = '한글 메시지' },
                @{ Title = 'テスト'; Message = '日本語メッセージ' },
                @{ Title = '测试'; Message = '中文消息' }
            )

            foreach ($testCase in $testCases) {
                $result = Send-WSLToast -Title $testCase.Title -Message $testCase.Message -MockMode
                $result.Success | Should -Be $true
            }
        }

        It 'Send-WSLToast validates notification types' {
            $validTypes = @('Information', 'Warning', 'Error', 'Success')
            foreach ($type in $validTypes) {
                $result = Send-WSLToast -Title 'Test' -Message 'Test Message' -Type $type -MockMode
                $result.Success | Should -Be $true
                $result.Type | Should -Be $type
            }
        }

        It 'Send-WSLToast validates durations' {
            $validDurations = @('Short', 'Normal', 'Long')
            foreach ($duration in $validDurations) {
                $result = Send-WSLToast -Title 'Test' -Message 'Test Message' -Duration $duration -MockMode
                $result.Success | Should -Be $true
                $result.Duration | Should -Be $duration
            }
        }

        It 'Send-WSLToast includes timestamp in result' {
            $result = Send-WSLToast -Title 'Test' -Message 'Test Message' -MockMode
            $result.Timestamp | Should -Not -BeNullOrEmpty
            $result.Timestamp | Should -BeOfType [datetime]
        }

        It 'Send-WSLToast includes display method in result' {
            $result = Send-WSLToast -Title 'Test' -Message 'Test Message' -MockMode
            $result.DisplayMethod | Should -Not -BeNullOrEmpty
            $result.DisplayMessage | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Error Handling' {
        It 'Send-WSLToast handles null title gracefully' {
            # The parameter validation should catch this before execution
            { Send-WSLToast -Title $null -Message 'Test' -MockMode } | Should -Throw
        }

        It 'Send-WSLToast handles empty message gracefully' {
            # The parameter validation should catch this before execution
            { Send-WSLToast -Title 'Test' -Message '' -MockMode } | Should -Throw
        }
    }

    Context 'Edge Cases' {
        It 'Send-WSLToast handles very long titles' {
            $longTitle = 'A' * 200
            $result = Send-WSLToast -Title $longTitle -Message 'Test Message' -MockMode
            $result.Success | Should -Be $true
        }

        It 'Send-WSLToast handles very long messages' {
            $longMessage = 'B' * 1000
            $result = Send-WSLToast -Title 'Test' -Message $longMessage -MockMode
            $result.Success | Should -Be $true
        }

        It 'Send-WSLToast handles special characters' {
            $specialChars = 'Test with <special> & "characters" and `quotes`'
            $result = Send-WSLToast -Title $specialChars -Message $specialChars -MockMode
            $result.Success | Should -Be $true
        }

        It 'Send-WSLToast handles emojis' {
            $emojiTitle = 'Test 🎉 🚀 ✅'
            $emojiMessage = 'Notification with emojis: 😀 🎊 🌟'
            $result = Send-WSLToast -Title $emojiTitle -Message $emojiMessage -MockMode
            $result.Success | Should -Be $true
        }
    }
}

Describe 'wsl-toast.ps1 Integration Tests' {
    Context 'End-to-End Scenarios' {
        It 'Complete notification flow works correctly' {
            $result = Send-WSLToast -Title 'Build Complete' -Message 'Your project built successfully' -Type 'Success' -Duration 'Normal' -MockMode
            $result.Success | Should -Be $true
            $result.DisplayMethod | Should -Be 'Mock'
        }

        It 'Notification with custom logo works' {
            $logoPath = 'C:\temp\logo.png'
            $result = Send-WSLToast -Title 'Test' -Message 'Test with logo' -AppLogo $logoPath -MockMode
            $result.Success | Should -Be $true
        }
    }
}
