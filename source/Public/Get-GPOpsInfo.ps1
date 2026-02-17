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
            If not specified, retrieves all GPOs in the domain.

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

        .EXAMPLE
            Get-GPOpsInfo

            Retrieves all GPOs in the current domain.

        .EXAMPLE
            Get-GPOpsInfo -Domain "contoso.com"

            Retrieves all GPOs from contoso.com domain.

        .OUTPUTS
            GPO
            Instances of the GPO class with properties and linked OUs.

        .NOTES
            This function requires the Active Directory PowerShell module to be available on the execution machine.
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
        [string]$Domain
    )

    PROCESS
    {
        try
        {
            Write-Verbose "Starting Get-GPOpsInfo"

            # Determine which GPOs to process
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
                Write-Verbose "No GPO names specified - retrieving all GPOs from domain: $(if ($Domain) { $Domain } else { 'current' })"
                return [GPO]::GetAll($Domain)
            }

            # Check if any name contains wildcards
            $hasWildcards = $gposToProcess | Where-Object { $_ -match '[\*\?]' }

            if ($hasWildcards)
            {
                # Wildcard patterns detected - retrieve by pattern
                Write-Verbose "Wildcard pattern detected. Processing: $($gposToProcess -join ', ')"
                return [GPO]::GetByPattern($gposToProcess, $Domain)
            }
            else
            {
                # All exact names
                Write-Verbose "Exact names specified. Processing: $($gposToProcess -join ', ')"
                return [GPO]::GetByName($gposToProcess, $Domain)
            }
        }
        catch [System.Exception]
        {
            $errorMsg = "Error retrieving GPO information: $($_.Exception.Message)"
            Write-Error -Message $errorMsg -ErrorAction Stop
        }
    }
}
