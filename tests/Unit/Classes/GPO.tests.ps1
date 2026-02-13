BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../../../source/Classes/01_GPO.ps1'
    . $modulePath
}

AfterAll {
    Remove-Variable -Name GPO -Force -ErrorAction SilentlyContinue
}

Describe 'GPO Class' {
    Context 'Constructor - Default' {
        It 'creates an empty GPO instance' {
            $gpo = [GPO]::new()
            $gpo | Should -Not -BeNullOrEmpty
            $gpo.LinkedOUs.Count | Should -Be 0
        }

        It 'initializes LinkedOUs as a list' {
            $gpo = [GPO]::new()
            $gpo.LinkedOUs | Should -BeOfType System.Collections.Generic.List[string]
        }
    }

    Context 'Constructor - From AD Object' {
        It 'creates GPO from AD object with all properties' {
            $adObject = @{
                DisplayName = 'Test GPO'
                Id          = [guid]'12345678-1234-1234-1234-123456789012'
                Domain      = 'contoso.com'
                Created     = [System.DateTime]::Now.AddDays(-30)
                Modified    = [System.DateTime]::Now
                Owner       = 'CONTOSO\Admins'
                Description = 'Test Description'
                GpoStatus   = 'AllSettingsEnabled'
            }

            $gpo = [GPO]::new($adObject)

            $gpo.DisplayName | Should -Be 'Test GPO'
            $gpo.Id | Should -Be '12345678-1234-1234-1234-123456789012'
            $gpo.Domain | Should -Be 'contoso.com'
            $gpo.Owner | Should -Be 'CONTOSO\Admins'
            $gpo.Description | Should -Be 'Test Description'
            $gpo.IsEnabled | Should -Be $true
        }

        It 'handles null properties with null-coalescing' {
            $adObject = @{
                DisplayName = 'Partial GPO'
                Id          = [guid]'87654321-4321-4321-4321-210987654321'
                Domain      = $null
                Created     = $null
                Owner       = $null
            }

            $gpo = [GPO]::new($adObject)

            $gpo.DisplayName | Should -Be 'Partial GPO'
            $gpo.Domain | Should -Be ''
            $gpo.Owner | Should -Be 'Unknown'
        }

        It 'correctly identifies disabled GPO' {
            $adObject = @{
                DisplayName = 'Disabled GPO'
                Id          = [guid]::NewGuid()
                GpoStatus   = 'AllSettingsDisabled'
            }

            $gpo = [GPO]::new($adObject)

            $gpo.IsEnabled | Should -Be $false
        }
    }

    Context 'Constructor - With Name and ID' {
        It 'creates GPO with name and ID' {
            $id = [guid]'11111111-1111-1111-1111-111111111111'
            $gpo = [GPO]::new('My GPO', $id)

            $gpo.DisplayName | Should -Be 'My GPO'
            $gpo.Id | Should -Be $id
            $gpo.LinkedOUs.Count | Should -Be 0
        }
    }

    Context 'LinkToOu Method' {
        It 'adds OU to LinkedOUs list' {
            $gpo = [GPO]::new('Test GPO', [guid]::NewGuid())
            $ouPath = 'OU=Test,DC=contoso,DC=com'

            $gpo.LinkToOu($ouPath)

            $gpo.LinkedOUs.Count | Should -Be 1
            $gpo.LinkedOUs[0] | Should -Be $ouPath
        }

        It 'does not add duplicate OUs' {
            $gpo = [GPO]::new('Test GPO', [guid]::NewGuid())
            $ouPath = 'OU=Test,DC=contoso,DC=com'

            $gpo.LinkToOu($ouPath)
            $gpo.LinkToOu($ouPath)

            $gpo.LinkedOUs.Count | Should -Be 1
        }

        It 'throws on null OU path' {
            $gpo = [GPO]::new('Test GPO', [guid]::NewGuid())

            { $gpo.LinkToOu($null) } | Should -Throw -ExceptionType System.ArgumentException
        }

        It 'throws on empty OU path' {
            $gpo = [GPO]::new('Test GPO', [guid]::NewGuid())

            { $gpo.LinkToOu('') } | Should -Throw -ExceptionType System.ArgumentException
        }

        It 'adds multiple different OUs' {
            $gpo = [GPO]::new('Test GPO', [guid]::NewGuid())
            $ou1 = 'OU=Test1,DC=contoso,DC=com'
            $ou2 = 'OU=Test2,DC=contoso,DC=com'

            $gpo.LinkToOu($ou1)
            $gpo.LinkToOu($ou2)

            $gpo.LinkedOUs.Count | Should -Be 2
            $gpo.LinkedOUs | Should -Contain $ou1
            $gpo.LinkedOUs | Should -Contain $ou2
        }
    }

    Context 'UnlinkFromOu Method' {
        It 'removes OU from LinkedOUs list' {
            $gpo = [GPO]::new('Test GPO', [guid]::NewGuid())
            $ouPath = 'OU=Test,DC=contoso,DC=com'

            $gpo.LinkToOu($ouPath)
            $gpo.UnlinkFromOu($ouPath)

            $gpo.LinkedOUs.Count | Should -Be 0
        }

        It 'does not error when unlinking non-existent OU' {
            $gpo = [GPO]::new('Test GPO', [guid]::NewGuid())

            { $gpo.UnlinkFromOu('OU=Fake,DC=contoso,DC=com') } | Should -Not -Throw
        }

        It 'throws on null OU path' {
            $gpo = [GPO]::new('Test GPO', [guid]::NewGuid())

            { $gpo.UnlinkFromOu($null) } | Should -Throw -ExceptionType System.ArgumentException
        }
    }

    Context 'UnlinkAll Method' {
        It 'removes all OUs from LinkedOUs' {
            $gpo = [GPO]::new('Test GPO', [guid]::NewGuid())

            $gpo.LinkToOu('OU=Test1,DC=contoso,DC=com')
            $gpo.LinkToOu('OU=Test2,DC=contoso,DC=com')
            $gpo.LinkToOu('OU=Test3,DC=contoso,DC=com')

            $gpo.UnlinkAll()

            $gpo.LinkedOUs.Count | Should -Be 0
        }
    }

    Context 'GetLinkedOUs Method' {
        It 'returns array of linked OUs' {
            $gpo = [GPO]::new('Test GPO', [guid]::NewGuid())
            $ou1 = 'OU=Test1,DC=contoso,DC=com'
            $ou2 = 'OU=Test2,DC=contoso,DC=com'

            $gpo.LinkToOu($ou1)
            $gpo.LinkToOu($ou2)

            $result = $gpo.GetLinkedOUs()

            $result | Should -BeOfType System.String[]
            $result.Count | Should -Be 2
            $result | Should -Contain $ou1
            $result | Should -Contain $ou2
        }

        It 'returns empty array when no OUs are linked' {
            $gpo = [GPO]::new('Test GPO', [guid]::NewGuid())

            $result = $gpo.GetLinkedOUs()

            $result | Should -BeOfType System.String[]
            $result.Count | Should -Be 0
        }
    }

    Context 'GetLinkCount Method' {
        It 'returns correct count of linked OUs' {
            $gpo = [GPO]::new('Test GPO', [guid]::NewGuid())

            $gpo.GetLinkCount() | Should -Be 0

            $gpo.LinkToOu('OU=Test1,DC=contoso,DC=com')
            $gpo.GetLinkCount() | Should -Be 1

            $gpo.LinkToOu('OU=Test2,DC=contoso,DC=com')
            $gpo.GetLinkCount() | Should -Be 2
        }
    }

    Context 'ToHashtable Method' {
        It 'returns all properties as hashtable' {
            $id = [guid]'11111111-1111-1111-1111-111111111111'
            $gpo = [GPO]::new('Test GPO', $id)
            $gpo.Domain = 'contoso.com'
            $gpo.Owner = 'CONTOSO\Admins'
            $gpo.IsEnabled = $true

            $result = $gpo.ToHashtable()

            $result | Should -BeOfType System.Collections.Hashtable
            $result['DisplayName'] | Should -Be 'Test GPO'
            $result['Id'] | Should -Be $id
            $result['Domain'] | Should -Be 'contoso.com'
            $result['Owner'] | Should -Be 'CONTOSO\Admins'
            $result['LinkCount'] | Should -Be 0
        }

        It 'includes linked OUs in hashtable' {
            $gpo = [GPO]::new('Test GPO', [guid]::NewGuid())
            $gpo.LinkToOu('OU=Test1,DC=contoso,DC=com')
            $gpo.LinkToOu('OU=Test2,DC=contoso,DC=com')

            $result = $gpo.ToHashtable()

            $result['LinkedOUs'] | Should -HaveCount 2
            $result['LinkCount'] | Should -Be 2
        }
    }

    Context 'ToObject Method' {
        It 'returns PSCustomObject with all properties' {
            $gpo = [GPO]::new('Test GPO', [guid]::NewGuid())
            $gpo.Domain = 'contoso.com'

            $result = $gpo.ToObject()

            $result | Should -BeOfType PSCustomObject
            $result.DisplayName | Should -Be 'Test GPO'
            $result.Domain | Should -Be 'contoso.com'
        }
    }

    Context 'ToString Method' {
        It 'returns formatted string representation' {
            $id = [guid]'11111111-1111-1111-1111-111111111111'
            $gpo = [GPO]::new('Test GPO', $id)

            $result = $gpo.ToString()

            $result | Should -Be "Test GPO [$id]"
        }
    }
}
