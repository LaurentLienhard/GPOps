function Get-GPOpsInfo
{
    <#
        .SYNOPSIS
            Retrieves detailed information about Group Policy Objects from Active Directory.

        .DESCRIPTION
            Gets one or more Group Policy Objects by name or pattern from Active Directory
            and returns them as GPO class instances with full properties and linked OUs.
            Supports wildcard patterns and returns results as a list for easy pipeline usage.

        .PARAMETER Name
            The name or wildcard pattern of the GPO to retrieve.
            Supports PowerShell wildcards (e.g., "PROD-*", "*-Security").

        .PARAMETER Domain
            The Active Directory domain to query.
            If not specified, uses the current domain.

        .EXAMPLE
            Get-GPOpsInfo -Name "PROD-*"

            Retrieves all production GPOs with names starting with "PROD-".

        .EXAMPLE
            Get-GPOpsInfo -Name "*Security*" -Domain "contoso.com"

            Retrieves all GPOs containing "Security" in the name from contoso.com domain.

        .EXAMPLE
            "PROD-Firewall", "PROD-Updates" | Get-GPOpsInfo

            Retrieves multiple specific GPOs from the pipeline.

        .OUTPUTS
            GPO
            Instances of the GPO class with properties and linked OUs.

        .NOTES
            This function requires the Active Directory PowerShell module.
            Does not make actual AD calls - uses mocked Get-GPO for testing.
    #>
    [CmdletBinding()]
    [OutputType([GPO])]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'Name or wildcard pattern of the GPO to retrieve'
        )]
        [ValidateNotNullOrEmpty()]
        [string[]]$Name,

        [Parameter(
            HelpMessage = 'Active Directory domain to query'
        )]
        [string]$Domain
    )

    BEGIN
    {
        Write-Verbose "Starting Get-GPOpsInfo"
        $results = [System.Collections.Generic.List[GPO]]::new()
    }

    PROCESS
    {
        foreach ($gpoName in $Name)
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

    END
    {
        Write-Verbose "Completed Get-GPOpsInfo - Found $($results.Count) GPO(s)"
        return $results
    }
}
