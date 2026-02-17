BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../../../output/module/GPOps' -Resolve -ErrorAction SilentlyContinue
    if (-not $modulePath -or -not (Test-Path $modulePath)) {
        # If module not built yet, load from source
        $classPath = Join-Path $PSScriptRoot '../../../source/Classes/01_GPO.ps1' | Resolve-Path
        & $classPath

        $functionPath = Join-Path $PSScriptRoot '../../../source/Public/Get-GPOpsInfo.ps1' | Resolve-Path
        & $functionPath
    }
    else {
        Import-Module $modulePath -Force -ErrorAction Stop
    }
}

AfterAll {
    Remove-Module GPOps -Force -ErrorAction SilentlyContinue
}

Describe 'Get-GPOpsInfo' {
    Context 'When GPO exists' {
            BeforeEach {
                Mock -CommandName Get-GPO -MockWith {
                    param([string]$Name)

                return [PSCustomObject]@{
                    DisplayName = 'Test GPO'
                    Id          = [guid]'12345678-1234-1234-1234-123456789012'
                    Domain      = 'contoso.com'
                    Created     = [System.DateTime]::Now.AddDays(-30)
                    Modified    = [System.DateTime]::Now
                    Owner       = 'CONTOSO\Admins'
                    Description = 'Test Description'
                    GpoStatus   = 'AllSettingsEnabled'
                }
            }
        }

        It 'retrieves GPO by name' {
            $result = Get-GPOpsInfo -Name 'Test GPO'

            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 1
        }

        It 'returns GPO instances' {
            $result = Get-GPOpsInfo -Name 'Test GPO'

            $result[0] | Should -BeOfType GPO
        }

        It 'populates GPO properties' {
            $result = Get-GPOpsInfo -Name 'Test GPO'

            $result[0].DisplayName | Should -Be 'Test GPO'
            $result[0].Id | Should -Be '12345678-1234-1234-1234-123456789012'
            $result[0].Domain | Should -Be 'contoso.com'
            $result[0].Owner | Should -Be 'CONTOSO\Admins'
        }

        It 'sets IsEnabled correctly' {
            $result = Get-GPOpsInfo -Name 'Test GPO'

            $result[0].IsEnabled | Should -Be $true
        }

        It 'calls Get-GPO once' {
            Get-GPOpsInfo -Name 'Test GPO'

            Assert-MockCalled -CommandName Get-GPO -Times 1 -Scope It
        }

        It 'passes Name parameter to Get-GPO' {
            Get-GPOpsInfo -Name 'Test GPO'

            Assert-MockCalled -CommandName Get-GPO -ParameterFilter {
                $Name -eq 'Test GPO'
            } -Times 1 -Scope It
        }

        It 'supports wildcard patterns' {
            Get-GPOpsInfo -Name 'Test*'

            Assert-MockCalled -CommandName Get-GPO -ParameterFilter {
                $Name -eq 'Test*'
            } -Times 1 -Scope It
        }

        It 'accepts Domain parameter' {
            Get-GPOpsInfo -Name 'Test GPO' -Domain 'contoso.com'

            Assert-MockCalled -CommandName Get-GPO -ParameterFilter {
                $Domain -eq 'contoso.com'
            } -Times 1 -Scope It
        }
    }

    Context 'When multiple GPOs exist' {
        BeforeEach {
            Mock -CommandName Get-GPO -MockWith {
                @(
                    [PSCustomObject]@{
                        DisplayName = 'GPO-1'
                        Id          = [guid]'11111111-1111-1111-1111-111111111111'
                        Domain      = 'contoso.com'
                        GpoStatus   = 'AllSettingsEnabled'
                    },
                    [PSCustomObject]@{
                        DisplayName = 'GPO-2'
                        Id          = [guid]'22222222-2222-2222-2222-222222222222'
                        Domain      = 'contoso.com'
                        GpoStatus   = 'AllSettingsEnabled'
                    }
                )
            }
        }

        It 'returns all matching GPOs' {
            $result = Get-GPOpsInfo -Name 'GPO-*'

            $result.Count | Should -Be 2
        }

        It 'returns all as GPO instances' {
            $result = Get-GPOpsInfo -Name 'GPO-*'

            $result[0] | Should -BeOfType GPO
            $result[1] | Should -BeOfType GPO
        }

        It 'preserves individual GPO properties' {
            $result = Get-GPOpsInfo -Name 'GPO-*'

            $result[0].DisplayName | Should -Be 'GPO-1'
            $result[1].DisplayName | Should -Be 'GPO-2'
        }
    }

    Context 'When GPO does not exist' {
        BeforeEach {
            Mock -CommandName Get-GPO -MockWith {
                return $null
            }
        }

        It 'returns empty result' {
            $result = Get-GPOpsInfo -Name 'NonExistent'

            $result | Should -BeNullOrEmpty
        }

        It 'does not throw error' {
            { Get-GPOpsInfo -Name 'NonExistent' } | Should -Not -Throw
        }
    }

    Context 'When Get-GPO throws ADIdentityNotFoundException' {
        BeforeEach {
            Mock -CommandName Get-GPO -MockWith {
                throw [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]"GPO not found"
            }
        }

        It 'writes error message' {
            $result = Get-GPOpsInfo -Name 'NonExistent' -ErrorVariable err -ErrorAction SilentlyContinue

            $err | Should -HaveCount 1
            $err[0].Exception.Message | Should -Match "GPO not found"
        }

        It 'does not throw' {
            { Get-GPOpsInfo -Name 'NonExistent' -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }

    Context 'When Get-GPO throws generic exception' {
        BeforeEach {
            Mock -CommandName Get-GPO -MockWith {
                throw [System.Exception]"Generic error"
            }
        }

        It 'writes error message' {
            $result = Get-GPOpsInfo -Name 'Test' -ErrorVariable err -ErrorAction SilentlyContinue

            $err | Should -HaveCount 1
        }
    }

    Context 'Pipeline input' {
        BeforeEach {
            Mock -CommandName Get-GPO -MockWith {
                param([string]$Name)

                return [PSCustomObject]@{
                    DisplayName = $Name
                    Id          = [guid]::NewGuid()
                    Domain      = 'contoso.com'
                    GpoStatus   = 'AllSettingsEnabled'
                }
            }
        }

        It 'accepts names from pipeline' {
            $result = @('GPO1', 'GPO2') | Get-GPOpsInfo

            $result.Count | Should -Be 2
        }

        It 'processes each name from pipeline' {
            $result = @('GPO1', 'GPO2', 'GPO3') | Get-GPOpsInfo

            Assert-MockCalled -CommandName Get-GPO -Times 3 -Scope It
        }

        It 'returns results in correct order' {
            $result = @('GPO1', 'GPO2') | Get-GPOpsInfo

            $result[0].DisplayName | Should -Be 'GPO1'
            $result[1].DisplayName | Should -Be 'GPO2'
        }
    }

    Context 'Disabled GPO' {
        BeforeEach {
            Mock -CommandName Get-GPO -MockWith {
                return [PSCustomObject]@{
                    DisplayName = 'Disabled GPO'
                    Id          = [guid]::NewGuid()
                    Domain      = 'contoso.com'
                    GpoStatus   = 'AllSettingsDisabled'
                }
            }
        }

        It 'marks disabled GPO correctly' {
            $result = Get-GPOpsInfo -Name 'Disabled GPO'

            $result[0].IsEnabled | Should -Be $false
        }
    }

    Context 'Verbose output' {
        BeforeEach {
            Mock -CommandName Get-GPO -MockWith {
                return [PSCustomObject]@{
                    DisplayName = 'Test GPO'
                    Id          = [guid]::NewGuid()
                    GpoStatus   = 'AllSettingsEnabled'
                }
            }
        }

        It 'supports verbose output' {
            $result = Get-GPOpsInfo -Name 'Test GPO' -Verbose 4>&1

            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Error handling for GPO object creation' {
        BeforeEach {
            Mock -CommandName Get-GPO -MockWith {
                return @(
                    [PSCustomObject]@{
                        DisplayName = 'Valid GPO'
                        Id          = [guid]::NewGuid()
                        GpoStatus   = 'AllSettingsEnabled'
                    },
                    @{
                        # Intentionally malformed object
                        DisplayName = 'Invalid GPO'
                    }
                )
            }
        }

        It 'handles mixed valid and invalid GPO objects' {
            $result = Get-GPOpsInfo -Name '*' -ErrorVariable err -ErrorAction SilentlyContinue

            $result.Count | Should -BeGreaterThan 0
            $err.Count | Should -BeGreaterThan 0
        }
    }

    Context 'Parameter validation' {
        It 'requires Name parameter' {
            { Get-GPOpsInfo } | Should -Throw
        }

        It 'rejects null Name' {
            { Get-GPOpsInfo -Name $null } | Should -Throw
        }

        It 'rejects empty Name' {
            { Get-GPOpsInfo -Name '' } | Should -Throw
        }
    }

    Context 'Execution behavior' {
        BeforeEach {
            Mock -CommandName Get-GPO -MockWith {
                return @{
                    DisplayName = 'Local GPO'
                    Id          = [guid]::NewGuid()
                    Domain      = 'contoso.com'
                    GpoStatus   = 'AllSettingsEnabled'
                }
            }
        }

        It 'executes and retrieves GPOs' {
            $result = Get-GPOpsInfo -Name 'Test'

            $result | Should -Not -BeNullOrEmpty
            Assert-MockCalled -CommandName Get-GPO -Times 1 -Scope It
        }

        It 'returns GPO objects' {
            $result = Get-GPOpsInfo -Name 'Test'

            $result | Should -BeOfType GPO
            $result.DisplayName | Should -Be 'Local GPO'
        }
    }
}
