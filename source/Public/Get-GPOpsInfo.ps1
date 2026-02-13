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
        $results = [System.Collections.Generic.List[GPO]]::new()

        # Detect execution mode: remote or local
        $isRemote = $PSBoundParameters.ContainsKey('ComputerName')

        if ($isRemote)
        {
            Write-Verbose "Remote execution mode: $ComputerName"

            # Initialize collection for names to process
            $allNames = [System.Collections.Generic.List[string]]::new()

            # If Name was provided directly (not from pipeline), add them now
            if ($PSBoundParameters.ContainsKey('Name') -and $Name.Count -gt 0)
            {
                foreach ($gpoName in $Name)
                {
                    $allNames.Add($gpoName)
                }
            }

            # Define script block for remote execution
            $scriptBlock = {
                param($Names, $Domain)

                $remoteResults = [System.Collections.Generic.List[hashtable]]::new()

                # If Names is empty or null, use wildcard to get all
                if ($null -eq $Names -or $Names.Count -eq 0)
                {
                    Write-Verbose "Remote: No names specified - retrieving all GPOs"
                    $Names = @('*')
                }

                foreach ($gpoName in $Names)
                {
                    Write-Verbose "Remote: Processing GPO: $gpoName"

                    try
                    {
                        $params = @{
                            Name        = $gpoName
                            ErrorAction = 'Stop'
                        }

                        if ($Domain)
                        {
                            $params['Domain'] = $Domain
                            Write-Verbose "Remote: Querying domain: $Domain"
                        }

                        $adGpos = Get-GPO @params

                        if ($null -ne $adGpos)
                        {
                            $gpoCollection = @($adGpos)

                            foreach ($adGpo in $gpoCollection)
                            {
                                # Serialize to hashtable for remote transport
                                $remoteResults.Add(@{
                                    DisplayName = $adGpo.DisplayName
                                    Id          = $adGpo.Id
                                    Domain      = $adGpo.Domain
                                    Created     = $adGpo.Created
                                    Modified    = $adGpo.Modified
                                    Owner       = $adGpo.Owner
                                    Description = $adGpo.Description
                                    GpoStatus   = $adGpo.GpoStatus
                                })
                            }
                        }
                    }
                    catch
                    {
                        # Check exception type by name since type may not be available in remote session
                        if ($_.Exception.GetType().Name -like '*ADIdentityNotFoundException')
                        {
                            Write-Error "Remote: GPO not found: $gpoName"
                        }
                        else
                        {
                            Write-Error "Remote: Failed to retrieve GPO '$gpoName': $_"
                        }
                    }
                }

                return $remoteResults
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
            # Local execution path (existing logic)
            # If Name is empty, use wildcard to get all
            $gposToProcess = if ($PSBoundParameters.ContainsKey('Name') -and $Name.Count -gt 0)
            {
                $Name
            }
            else
            {
                Write-Verbose "No GPO names specified - will retrieve all GPOs"
                @('*')
            }

            foreach ($gpoName in $gposToProcess)
            {
                Write-Verbose "Processing GPO: $gpoName"

                try
                {
                    $params = @{
                        Name        = $gpoName
                        ErrorAction = 'Stop'
                    }

                    if ($PSBoundParameters.ContainsKey('Domain'))
                    {
                        $params['Domain'] = $Domain
                        Write-Verbose "Querying domain: $Domain"
                    }

                    $adGpos = Get-GPO @params

                    if ($null -eq $adGpos)
                    {
                        Write-Verbose "No GPO found matching: $gpoName"
                        continue
                    }

                    # Handle both single object and array results
                    $gpoCollection = @($adGpos)

                    foreach ($adGpo in $gpoCollection)
                    {
                        try
                        {
                            $gpo = [GPO]::new($adGpo)
                            $results.Add($gpo)
                            Write-Verbose "Added GPO: $($gpo.DisplayName) [$($gpo.Id)]"
                        }
                        catch
                        {
                            Write-Error "Failed to create GPO object for '$($adGpo.DisplayName)': $_"
                        }
                    }
                }
                catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
                {
                    Write-Error "GPO not found: $gpoName"
                }
                catch
                {
                    Write-Error "Failed to retrieve GPO '$gpoName': $_"
                }
            }
        }
    }

    END
    {
        if ($isRemote)
        {
            Write-Verbose "Executing remote command on $ComputerName"

            # If no names were specified, use wildcard to get all GPOs
            if ($allNames.Count -eq 0)
            {
                Write-Verbose "No GPO names specified - will retrieve all GPOs"
                $allNames.Add('*')
            }

            # Build Invoke-Command parameters
            $invokeParams = @{
                ComputerName = $ComputerName
                ScriptBlock  = $scriptBlock
                ArgumentList = @(,$allNames.ToArray()), $Domain
                ErrorAction  = 'Stop'
            }

            if ($PSBoundParameters.ContainsKey('Credential'))
            {
                $invokeParams['Credential'] = $Credential
                Write-Verbose "Using explicit credentials for remote execution"
            }

            try
            {
                $remoteResults = Invoke-Command @invokeParams

                # Reconstruct GPO objects from hashtable results
                foreach ($hashResult in $remoteResults)
                {
                    try
                    {
                        $gpo = [GPO]::new($hashResult)
                        $results.Add($gpo)
                        Write-Verbose "Added remote GPO: $($gpo.DisplayName) [$($gpo.Id)]"
                    }
                    catch
                    {
                        Write-Error "Failed to reconstruct GPO from remote result: $_"
                    }
                }
            }
            catch [System.Management.Automation.Remoting.PSRemotingTransportException]
            {
                Write-Error "Cannot connect to '$ComputerName'. Verify WinRM is enabled and accessible: $_"
                throw
            }
            catch [System.UnauthorizedAccessException]
            {
                Write-Error "Access denied to '$ComputerName'. Check credentials and remote permissions: $_"
                throw
            }
            catch
            {
                Write-Error "Remote execution failed: $_"
                throw
            }
        }

        Write-Verbose "Completed Get-GPOpsInfo - Found $($results.Count) GPO(s)"
        return $results
    }
}
