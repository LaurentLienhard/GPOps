function Get-GPOpsInfo
{
    <#
        .SYNOPSIS
            Retrieves detailed information about Group Policy Objects from Active Directory.

        .DESCRIPTION
            Gets one or more Group Policy Objects by name or pattern from Active Directory
            and returns them as GPO class instances with full properties and linked OUs.
            Supports wildcard patterns and returns results as a list for easy pipeline usage.
            Can execute locally or on remote computers via PowerShell Remoting.

        .PARAMETER Name
            The name or wildcard pattern of the GPO to retrieve.
            Supports PowerShell wildcards (e.g., "PROD-*", "*-Security").
            If not specified, retrieves all GPOs in the domain.

        .PARAMETER Domain
            The Active Directory domain to query.
            If not specified, uses the current domain.

        .PARAMETER ComputerName
            Remote computer to execute the GPO query on.
            If not specified, executes locally on the current computer.
            Requires PowerShell Remoting to be enabled on the remote computer.

        .PARAMETER Credential
            PSCredential object for remote authentication.
            Only used when ComputerName is specified.
            If not specified, uses the current user's credentials.

        .EXAMPLE
            Get-GPOpsInfo -Name "PROD-*"

            Retrieves all production GPOs with names starting with "PROD-" locally.

        .EXAMPLE
            Get-GPOpsInfo -Name "*Security*" -Domain "contoso.com"

            Retrieves all GPOs containing "Security" in the name from contoso.com domain locally.

        .EXAMPLE
            "PROD-Firewall", "PROD-Updates" | Get-GPOpsInfo

            Retrieves multiple specific GPOs from the pipeline locally.

        .EXAMPLE
            Get-GPOpsInfo -Name "PROD-*" -ComputerName "DC01.contoso.com"

            Retrieves all production GPOs from remote domain controller DC01.

        .EXAMPLE
            $cred = Get-Credential "CONTOSO\Administrator"
            Get-GPOpsInfo -Name "*Security*" -ComputerName "DC01" -Credential $cred

            Retrieves GPOs from remote computer using explicit credentials.

        .EXAMPLE
            Get-GPOpsInfo

            Retrieves all GPOs in the current domain locally.

        .EXAMPLE
            Get-GPOpsInfo -Domain "contoso.com"

            Retrieves all GPOs from contoso.com domain.

        .OUTPUTS
            GPO
            Instances of the GPO class with properties and linked OUs.

        .NOTES
            This function requires the Active Directory PowerShell module on the execution target.
            When using remote execution, the GroupPolicy module must be available on the remote computer.
            Remote execution requires PowerShell Remoting to be enabled (WinRM).
    #>
    [CmdletBinding()]
    [OutputType([GPO])]
    param(
        [Parameter(
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'Name or wildcard pattern of the GPO to retrieve. If not specified, retrieves all GPOs'
        )]
        [string[]]$Name,

        [Parameter(
            HelpMessage = 'Active Directory domain to query'
        )]
        [string]$Domain,

        [Parameter(
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'Remote computer to query GPOs from'
        )]
        [ValidateNotNullOrEmpty()]
        [string]$ComputerName,

        [Parameter(
            HelpMessage = 'Credentials for remote execution'
        )]
        [System.Management.Automation.PSCredential]$Credential
    )

    BEGIN
    {
        Write-Verbose "Starting Get-GPOpsInfo"

        # Detect execution mode: remote or local
        $isRemote = $PSBoundParameters.ContainsKey('ComputerName')

        if ($isRemote)
        {
            # Initialize collection for names to process (pipeline accumulation)
            $allNames = [System.Collections.Generic.List[string]]::new()

            # If Name was provided directly (not from pipeline), add them now
            if ($PSBoundParameters.ContainsKey('Name') -and $Name.Count -gt 0)
            {
                foreach ($gpoName in $Name)
                {
                    $allNames.Add($gpoName)
                }
            }
        }
    }

    PROCESS
    {
        if ($isRemote)
        {
            Write-Verbose "Accumulating GPO names for remote batch execution"

            # Add names from pipeline (if any)
            if ($PSBoundParameters.ContainsKey('Name') -and $Name.Count -gt 0)
            {
                foreach ($gpoName in $Name)
                {
                    if (-not $allNames.Contains($gpoName))
                    {
                        $allNames.Add($gpoName)
                    }
                }
            }
        }
        else
        {
            # Local execution: process immediately using class methods
            $gposToProcess = if ($PSBoundParameters.ContainsKey('Name') -and $Name.Count -gt 0)
            {
                $Name
            }
            else
            {
                @()
            }

            if ($gposToProcess.Count -eq 0)
            {
                # No names provided - retrieve all GPOs
                Write-Verbose "No GPO names specified - will retrieve all GPOs"
                return [GPO]::GetAll($Domain)
            }

            # Check if any name contains wildcards
            $hasWildcards = $gposToProcess | Where-Object { $_ -match '[\*\?]' }

            if ($hasWildcards)
            {
                # Mixed: some exact names, some wildcards
                # Retrieve by pattern (which handles both)
                return [GPO]::GetByPattern($gposToProcess, $Domain)
            }
            else
            {
                # All exact names
                return [GPO]::GetByName($gposToProcess, $Domain)
            }
        }
    }

    END
    {
        if ($isRemote)
        {
            Write-Verbose "Executing remote command on $ComputerName"

            # Use the static method for remote execution
            $remoteParams = @{
                Names       = if ($allNames.Count -gt 0) { $allNames.ToArray() } else { $null }
                Domain      = $Domain
                ComputerName = $ComputerName
                Credential  = if ($PSBoundParameters.ContainsKey('Credential')) { $Credential } else { $null }
            }

            $results = [GPO]::GetFromRemote(
                $remoteParams.Names,
                $remoteParams.Domain,
                $remoteParams.ComputerName,
                $remoteParams.Credential
            )

            Write-Verbose "Completed Get-GPOpsInfo - Found $($results.Count) GPO(s)"
            return $results
        }
    }
}
