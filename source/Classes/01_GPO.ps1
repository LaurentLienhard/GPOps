class GPO
{
    <#
    .DESCRIPTION
        Represents a Group Policy Object with encapsulated state and behavior.
        This class manages GPO properties and linked organizational units.
    #>

    #region <Properties>

    [System.String]$DisplayName
    [System.Guid]$Id
    [System.String]$Domain
    [System.DateTime]$Created
    [System.DateTime]$Modified
    [System.Boolean]$IsEnabled
    [System.String]$Owner
    [System.Collections.Generic.List[string]]$LinkedOUs
    [System.String]$Description

    #endregion <Properties>

    #region <Constructor>

    GPO()
    {
        $this.LinkedOUs = [System.Collections.Generic.List[string]]::new()
    }

    GPO([object]$ADObject)
    {
        $this.DisplayName = if ($null -ne $ADObject.DisplayName) { $ADObject.DisplayName } else { '' }
        $this.Id = if ($null -ne $ADObject.Id) { $ADObject.Id } else { [guid]::Empty }
        $this.Domain = if ($null -ne $ADObject.Domain) { $ADObject.Domain } else { '' }
        $this.Created = if ($null -ne $ADObject.Created) { $ADObject.Created } else { [System.DateTime]::MinValue }
        $this.Modified = if ($null -ne $ADObject.Modified) { $ADObject.Modified } else { [System.DateTime]::MinValue }
        $this.Owner = if ($null -ne $ADObject.Owner) { $ADObject.Owner } else { 'Unknown' }
        $this.Description = if ($null -ne $ADObject.Description) { $ADObject.Description } else { '' }
        $this.IsEnabled = -not ($ADObject.GpoStatus -eq 'AllSettingsDisabled')
        $this.LinkedOUs = [System.Collections.Generic.List[string]]::new()
    }

    GPO([string]$Name, [System.Guid]$Id)
    {
        $this.DisplayName = $Name
        $this.Id = $Id
        $this.LinkedOUs = [System.Collections.Generic.List[string]]::new()
    }

    #endregion <Constructor>

    #region <Methods>

    [void] LinkToOu([string]$OuPath)
    {
        if ([string]::IsNullOrWhiteSpace($OuPath))
        {
            throw [System.ArgumentException]"OU path cannot be null or empty"
        }

        if ($this.LinkedOUs.Contains($OuPath))
        {
            return
        }

        $this.LinkedOUs.Add($OuPath)
    }

    [void] UnlinkFromOu([string]$OuPath)
    {
        if ([string]::IsNullOrWhiteSpace($OuPath))
        {
            throw [System.ArgumentException]"OU path cannot be null or empty"
        }

        $this.LinkedOUs.Remove($OuPath)
    }

    [void] UnlinkAll()
    {
        $this.LinkedOUs.Clear()
    }

    [string[]] GetLinkedOUs()
    {
        return $this.LinkedOUs.ToArray()
    }

    [int] GetLinkCount()
    {
        return $this.LinkedOUs.Count
    }

    [hashtable] ToHashtable()
    {
        return @{
            DisplayName = $this.DisplayName
            Id          = $this.Id
            Domain      = $this.Domain
            Created     = $this.Created
            Modified    = $this.Modified
            IsEnabled   = $this.IsEnabled
            Owner       = $this.Owner
            Description = $this.Description
            LinkedOUs   = $this.LinkedOUs.ToArray()
            LinkCount   = $this.GetLinkCount()
        }
    }

    [PSCustomObject] ToObject()
    {
        return [PSCustomObject]$this.ToHashtable()
    }

    [string] ToString()
    {
        return "$($this.DisplayName) [$($this.Id)]"
    }

    #endregion <Methods>

    #region <Static Methods>

    <#
    .SYNOPSIS
        Retrieves all GPOs from the specified domain.

    .PARAMETER Domain
        The domain to query. If not specified, uses the current domain.

    .OUTPUTS
        [GPO[]]
    #>
    static [GPO[]] GetAll([string]$Domain)
    {
        Write-Verbose "Retrieving all GPOs"

        $results = [System.Collections.Generic.List[GPO]]::new()

        try
        {
            $params = @{
                All         = $true
                ErrorAction = 'Stop'
            }

            if (-not [string]::IsNullOrEmpty($Domain))
            {
                $params['Domain'] = $Domain
                Write-Verbose "Querying domain: $Domain"
            }

            $adGpos = Get-GPO @params

            if ($null -ne $adGpos)
            {
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
        }
        catch
        {
            Write-Error "Failed to retrieve all GPOs: $_"
        }

        return $results.ToArray()
    }

    <#
    .SYNOPSIS
        Retrieves GPOs by exact name from the specified domain.

    .PARAMETER Names
        Array of exact GPO names to retrieve.

    .PARAMETER Domain
        The domain to query. If not specified, uses the current domain.

    .OUTPUTS
        [GPO[]]
    #>
    static [GPO[]] GetByName([string[]]$Names, [string]$Domain)
    {
        Write-Verbose "Retrieving GPOs by exact name"

        $results = [System.Collections.Generic.List[GPO]]::new()

        if ($null -eq $Names -or $Names.Count -eq 0)
        {
            return $results.ToArray()
        }

        foreach ($gpoName in $Names)
        {
            Write-Verbose "Processing GPO: $gpoName"

            try
            {
                $params = @{
                    Name        = $gpoName
                    ErrorAction = 'Stop'
                }

                if (-not [string]::IsNullOrEmpty($Domain))
                {
                    $params['Domain'] = $Domain
                    Write-Verbose "Querying domain: $Domain"
                }

                $adGpos = Get-GPO @params

                if ($null -ne $adGpos)
                {
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
            }
            catch
            {
                # Check exception type by name since type may not be available in all contexts
                if ($_.Exception.GetType().Name -like '*ADIdentityNotFoundException')
                {
                    Write-Error "GPO not found: $gpoName"
                }
                else
                {
                    Write-Error "Failed to retrieve GPO '$gpoName': $_"
                }
            }
        }

        return $results.ToArray()
    }

    <#
    .SYNOPSIS
        Retrieves GPOs by wildcard patterns from the specified domain.

    .PARAMETER Patterns
        Array of wildcard patterns to match against GPO names.

    .PARAMETER Domain
        The domain to query. If not specified, uses the current domain.

    .OUTPUTS
        [GPO[]]
    #>
    static [GPO[]] GetByPattern([string[]]$Patterns, [string]$Domain)
    {
        Write-Verbose "Retrieving GPOs by wildcard pattern"

        $results = [System.Collections.Generic.List[GPO]]::new()

        if ($null -eq $Patterns -or $Patterns.Count -eq 0)
        {
            return $results.ToArray()
        }

        try
        {
            $params = @{
                All         = $true
                ErrorAction = 'Stop'
            }

            if (-not [string]::IsNullOrEmpty($Domain))
            {
                $params['Domain'] = $Domain
                Write-Verbose "Querying domain: $Domain"
            }

            $allGpos = Get-GPO @params

            if ($null -ne $allGpos)
            {
                $gpoCollection = @($allGpos)

                foreach ($pattern in $Patterns)
                {
                    Write-Verbose "Filtering GPOs for pattern: $pattern"

                    foreach ($adGpo in $gpoCollection)
                    {
                        if ($adGpo.DisplayName -like $pattern)
                        {
                            # Check if already added (avoid duplicates)
                            if (-not ($results | Where-Object { $_.Id -eq $adGpo.Id }))
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
                    }
                }
            }
        }
        catch
        {
            Write-Error "Failed to retrieve GPOs with wildcard filter: $_"
        }

        return $results.ToArray()
    }

    <#
    .SYNOPSIS
        Retrieves GPOs from a remote computer via PowerShell Remoting.

    .PARAMETER Names
        Array of GPO names (exact or wildcard patterns).

    .PARAMETER Domain
        The domain to query. If not specified, uses the current domain.

    .PARAMETER ComputerName
        Remote computer to execute the query on.

    .PARAMETER Credential
        Credentials for remote authentication.

    .OUTPUTS
        [GPO[]]
    #>
    static [GPO[]] GetFromRemote([string[]]$Names, [string]$Domain, [string]$ComputerName, [PSCredential]$Credential)
    {
        Write-Verbose "Remote execution mode: $ComputerName"

        $results = [System.Collections.Generic.List[GPO]]::new()

        # Define script block for remote execution
        $scriptBlock = {
            param($Names, $Domain)

            $remoteResults = [System.Collections.Generic.List[hashtable]]::new()

            # If Names is empty or null, use -All to get all GPOs
            if ($null -eq $Names -or $Names.Count -eq 0)
            {
                Write-Verbose "Remote: No names specified - retrieving all GPOs"

                try
                {
                    $params = @{
                        All         = $true
                        ErrorAction = 'Stop'
                    }

                    if ($Domain)
                    {
                        $params['Domain'] = $Domain
                        Write-Verbose "Remote: Querying domain: $Domain"
                    }

                    $adGpos = Get-GPO @params
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
                catch
                {
                    Write-Error "Remote: Failed to retrieve all GPOs: $_"
                }
            }
            else
            {
                # Check if any name contains wildcards
                $hasWildcards = $Names | Where-Object { $_ -match '[\*\?]' }

                if ($hasWildcards)
                {
                    # If wildcards are present, retrieve all GPOs and filter
                    Write-Verbose "Remote: Wildcard pattern detected - retrieving all GPOs and filtering"

                    try
                    {
                        $params = @{
                            All         = $true
                            ErrorAction = 'Stop'
                        }

                        if ($Domain)
                        {
                            $params['Domain'] = $Domain
                            Write-Verbose "Remote: Querying domain: $Domain"
                        }

                        $allGpos = Get-GPO @params

                        if ($null -ne $allGpos)
                        {
                            $gpoCollection = @($allGpos)

                            foreach ($gpoName in $Names)
                            {
                                Write-Verbose "Remote: Filtering GPOs for pattern: $gpoName"

                                foreach ($adGpo in $gpoCollection)
                                {
                                    if ($adGpo.DisplayName -like $gpoName)
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
                        }
                    }
                    catch
                    {
                        Write-Error "Remote: Failed to retrieve GPOs with wildcard filter: $_"
                    }
                }
                else
                {
                    # No wildcards - use exact name matching
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
                }
            }

            return $remoteResults
        }

        # Prepare parameters
        $namesToPass = if ($null -ne $Names -and $Names.Count -gt 0) { @(,$Names) } else { $null }

        $invokeParams = @{
            ComputerName = $ComputerName
            ScriptBlock  = $scriptBlock
            ArgumentList = @($namesToPass, $Domain)
            ErrorAction  = 'Stop'
        }

        if ($null -ne $Credential)
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

        return $results.ToArray()
    }

    #endregion <Static Methods>
}
