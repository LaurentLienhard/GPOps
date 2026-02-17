# Build task for deploying GPOps module to local and remote locations
# This task is part of the ModuleBuilder Sampler build system
# Usage: ./build.ps1 -Tasks Deploy_GPOpsModule

task Deploy_GPOpsModule {
    <#
        .SYNOPSIS
        Deploys the compiled GPOps module to configured destinations.

        .DESCRIPTION
        This build task copies the compiled GPOps module to:
        - Local module paths on Windows machine
        - Remote servers via PowerShell Remoting with credentials from Windows Credential Manager

        Configuration is read from deployment/config.json
        Credentials are stored in Windows Credential Manager for secure access.
    #>

    Write-Build Magenta "Deploying GPOps module to configured destinations..."

    $deploymentConfigPath = Join-Path $PSScriptRoot '../deployment/config.json'
    $credentialHelperPath = Join-Path $PSScriptRoot '../deployment/Credential-Manager.ps1'

    if (-not (Test-Path -Path $deploymentConfigPath))
    {
        Write-Build Yellow "Deployment configuration not found at $deploymentConfigPath"
        Write-Build Yellow "Create configuration file to enable deployment. See deployment/config.example.json for template."
        return
    }

    try
    {
        # Load deployment configuration
        $config = Get-Content -Path $deploymentConfigPath -Raw | ConvertFrom-Json

        # Determine the built module path
        if ($BuiltModuleSubdirectory)
        {
            $builtModulePath = Join-Path $OutputDirectory $BuiltModuleSubdirectory 'GPOps'
        }
        else
        {
            $builtModulePath = Join-Path $OutputDirectory 'GPOps'
        }

        # Get the latest version subdirectory
        $moduleVersionDir = Get-ChildItem -Path $builtModulePath -Directory |
            Sort-Object Name -Descending |
            Select-Object -First 1

        if (-not $moduleVersionDir)
        {
            throw "No module version directory found in $builtModulePath"
        }

        $sourceModulePath = $moduleVersionDir.FullName
        Write-Build Green "Source module path: $sourceModulePath"

        # Deploy to local destinations
        if ($config.LocalDestinations -and $config.LocalDestinations.Count -gt 0)
        {
            Write-Build Cyan "`nDeploying to local destinations..."

            foreach ($destination in $config.LocalDestinations)
            {
                if ([string]::IsNullOrWhiteSpace($destination))
                {
                    continue
                }

                $destPath = [System.Environment]::ExpandEnvironmentVariables($destination)

                try
                {
                    Write-Build DarkGray "  Copying to: $destPath"

                    $moduleDir = Split-Path -Path $destPath -Parent
                    if (-not (Test-Path -Path $moduleDir))
                    {
                        $null = New-Item -ItemType Directory -Path $moduleDir -Force
                        Write-Build DarkGray "    Created directory: $moduleDir"
                    }

                    Copy-Item -Path $sourceModulePath -Destination $destPath -Recurse -Force
                    Write-Build Green "    ✓ Successfully deployed to $destPath"
                }
                catch
                {
                    Write-Build Red "    ✗ Failed to deploy to $destPath`: $($_.Exception.Message)"
                }
            }
        }

        # Deploy to remote servers
        if ($config.RemoteServers -and $config.RemoteServers.Count -gt 0)
        {
            Write-Build Cyan "`nDeploying to remote servers..."

            # Source the credential helper if available
            if (Test-Path -Path $credentialHelperPath)
            {
                . $credentialHelperPath
            }

            foreach ($server in $config.RemoteServers)
            {
                if (-not $server.ComputerName)
                {
                    Write-Build Yellow "  Skipping server without ComputerName"
                    continue
                }

                $computerName = $server.ComputerName
                $destinationPath = $server.DestinationPath
                $credentialKey = $server.CredentialKey

                try
                {
                    Write-Build DarkGray "  Connecting to: $computerName"

                    # Retrieve credentials from Windows Credential Manager
                    $credential = $null
                    if ($credentialKey -and (Get-Command Get-GPOpsStoredCredential -ErrorAction SilentlyContinue))
                    {
                        $credential = Get-GPOpsStoredCredential -CredentialKey $credentialKey
                        if (-not $credential)
                        {
                            throw "Credential key '$credentialKey' not found in Windows Credential Manager"
                        }
                    }

                    # Prepare remoting parameters
                    $sessionParams = @{
                        ComputerName = $computerName
                        ErrorAction  = 'Stop'
                    }

                    if ($credential)
                    {
                        $sessionParams['Credential'] = $credential
                    }

                    # Create PSSession and copy module
                    $session = New-PSSession @sessionParams
                    Write-Build DarkGray "    PSSession created successfully"

                    # Copy module via PSSession
                    Copy-Item -Path $sourceModulePath `
                              -Destination $destinationPath `
                              -ToSession $session `
                              -Recurse `
                              -Force

                    Write-Build Green "    ✓ Successfully deployed to $computerName`:$destinationPath"

                    $session | Remove-PSSession
                }
                catch
                {
                    Write-Build Red "    ✗ Failed to deploy to $computerName`: $($_.Exception.Message)"
                }
            }
        }

        Write-Build Green "`n✓ Deployment task completed"
    }
    catch
    {
        Write-Build Red "Deployment task failed: $($_.Exception.Message)"
        throw
    }
}
