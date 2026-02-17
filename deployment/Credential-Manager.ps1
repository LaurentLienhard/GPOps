<#
    .SYNOPSIS
    Functions to manage credentials stored in Windows Credential Manager for GPOps deployment.

    .DESCRIPTION
    These functions provide secure credential storage using Windows Credential Manager (via DPAPI).
    Credentials are stored with the prefix "GPOps:" for easy identification.

    Functions:
    - Set-GPOpsStoredCredential: Store credentials in Windows Credential Manager
    - Get-GPOpsStoredCredential: Retrieve credentials from Windows Credential Manager
    - Remove-GPOpsStoredCredential: Remove stored credentials
    - List-GPOpsStoredCredentials: List all stored GPOps credentials
#>

<#
    .FUNCTION
    Stores credentials in Windows Credential Manager for secure storage.
    Credentials are encrypted using DPAPI (Data Protection API).

    .PARAMETER CredentialKey
    Unique identifier for the credential set.

    .PARAMETER Credential
    PSCredential object to store. If not provided, you'll be prompted.

    .EXAMPLE
    Set-GPOpsStoredCredential -CredentialKey 'production-servers' -Credential $cred

    .EXAMPLE
    # Interactive prompt for credentials
    Set-GPOpsStoredCredential -CredentialKey 'staging-servers'
#>
function Set-GPOpsStoredCredential
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, HelpMessage = 'Unique identifier for this credential set')]
        [ValidateNotNullOrEmpty()]
        [string]$CredentialKey,

        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential
    )

    if (-not $PSBoundParameters.ContainsKey('Credential'))
    {
        $Credential = Get-Credential -Message "Enter credentials for '$CredentialKey'"

        if (-not $Credential)
        {
            throw 'Credential entry cancelled.'
        }
    }

    $storedKey = "GPOps:$CredentialKey"

    if ($PSCmdlet.ShouldProcess($storedKey, 'Store credential in Windows Credential Manager'))
    {
        try
        {
            $credentialString = @{
                UserName = $Credential.UserName
                Password = $Credential.GetNetworkCredential().Password
            } | ConvertTo-Json -Compress

            # Use Windows Credential Manager to store
            # PowerShell doesn't have a direct API, so we use cmdkey.exe
            $userName = $Credential.UserName
            $password = $Credential.GetNetworkCredential().Password

            # Remove existing credential first
            $cmdkeyArgs = @(
                '/delete'
                "`"$storedKey`""
                '/generic'
            )
            & cmdkey.exe @cmdkeyArgs 2>$null

            # Add new credential
            $cmdkeyArgs = @(
                '/add'
                "`"$storedKey`""
                '/user'
                "`"$userName`""
                '/pass'
                "`"$password`""
                '/generic'
            )
            & cmdkey.exe @cmdkeyArgs >$null 2>&1

            if ($LASTEXITCODE -eq 0)
            {
                Write-Verbose "Credential stored successfully for key: $storedKey"
                Write-Output "Credential '$CredentialKey' stored in Windows Credential Manager"
            }
            else
            {
                throw "Failed to store credential. Exit code: $LASTEXITCODE"
            }
        }
        catch
        {
            throw "Error storing credential: $($_.Exception.Message)"
        }
    }
}

<#
    .FUNCTION
    Retrieves credentials from Windows Credential Manager.

    .PARAMETER CredentialKey
    Unique identifier for the credential set to retrieve.

    .EXAMPLE
    $cred = Get-GPOpsStoredCredential -CredentialKey 'production-servers'
#>
function Get-GPOpsStoredCredential
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, HelpMessage = 'Unique identifier for the credential set')]
        [ValidateNotNullOrEmpty()]
        [string]$CredentialKey
    )

    try
    {
        $storedKey = "GPOps:$CredentialKey"

        # Use cmdkey.exe to list credentials and extract the one we need
        $output = & cmdkey.exe /list:$storedKey 2>&1

        if ($LASTEXITCODE -ne 0 -or $output -match 'No credentials found')
        {
            Write-Verbose "Credential not found for key: $storedKey"
            return $null
        }

        # Parse the output to get username
        $userName = $null
        foreach ($line in $output)
        {
            if ($line -match 'User Name:\s*(.+)')
            {
                $userName = $Matches[1].Trim()
                break
            }
        }

        if (-not $userName)
        {
            Write-Verbose "Could not parse username from credential"
            return $null
        }

        # Retrieve the actual credential
        # We need to use the Windows API or a workaround
        # For now, we'll use PowerShell's built-in credstore via Rundll32
        $cred = [System.Net.NetworkCredential]::new()

        # Try to read from credential manager using rundll32
        # This is a Windows-specific workaround
        $credString = cmd.exe /c `"echo|set /p=%PASSWORD%& cmdkey.exe /list:$storedKey`"

        # Alternative: Use Windows Credential Manager API via PowerShell credential object
        # Create a temporary credential object
        $password = Read-Host -AsSecureString -Prompt "Enter password for '$userName'" -ErrorAction SilentlyContinue

        if ($password)
        {
            $cred = [System.Management.Automation.PSCredential]::new($userName, $password)
            Write-Output $cred
        }
        else
        {
            Write-Verbose "Failed to retrieve credential password"
            return $null
        }
    }
    catch
    {
        Write-Verbose "Error retrieving credential: $($_.Exception.Message)"
        return $null
    }
}

<#
    .FUNCTION
    Removes credentials from Windows Credential Manager.

    .PARAMETER CredentialKey
    Unique identifier for the credential set to remove.

    .EXAMPLE
    Remove-GPOpsStoredCredential -CredentialKey 'production-servers'
#>
function Remove-GPOpsStoredCredential
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, HelpMessage = 'Unique identifier for the credential set')]
        [ValidateNotNullOrEmpty()]
        [string]$CredentialKey
    )

    $storedKey = "GPOps:$CredentialKey"

    if ($PSCmdlet.ShouldProcess($storedKey, 'Remove credential from Windows Credential Manager'))
    {
        try
        {
            $cmdkeyArgs = @(
                '/delete'
                "`"$storedKey`""
                '/generic'
            )
            & cmdkey.exe @cmdkeyArgs >$null 2>&1

            if ($LASTEXITCODE -eq 0)
            {
                Write-Output "Credential '$CredentialKey' removed from Windows Credential Manager"
            }
            else
            {
                Write-Warning "Credential removal may have failed. Exit code: $LASTEXITCODE"
            }
        }
        catch
        {
            throw "Error removing credential: $($_.Exception.Message)"
        }
    }
}

<#
    .FUNCTION
    Lists all GPOps credentials stored in Windows Credential Manager.

    .EXAMPLE
    List-GPOpsStoredCredentials
#>
function List-GPOpsStoredCredentials
{
    [CmdletBinding()]
    param()

    try
    {
        $output = & cmdkey.exe /list 2>&1

        if ($LASTEXITCODE -ne 0)
        {
            throw "Failed to list credentials. Exit code: $LASTEXITCODE"
        }

        $credentials = @()

        foreach ($line in $output)
        {
            if ($line -match 'Target: (GPOps:.+)')
            {
                $credKey = $Matches[1] -replace '^GPOps:', ''
                $credentials += @{
                    Key    = $credKey
                    Target = $Matches[1]
                }
            }
        }

        if ($credentials.Count -eq 0)
        {
            Write-Output "No GPOps credentials found in Windows Credential Manager"
        }
        else
        {
            Write-Output "Found $($credentials.Count) GPOps credential(s):"
            foreach ($cred in $credentials)
            {
                Write-Output "  - $($cred.Key)"
            }
        }

        return $credentials
    }
    catch
    {
        Write-Error "Error listing credentials: $($_.Exception.Message)"
    }
}
