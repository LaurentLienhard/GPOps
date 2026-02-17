# GPOps Module Deployment

This directory contains configuration and utilities for deploying the GPOps module to local and remote servers.

## Setup

### 1. Create Deployment Configuration

Copy `config.example.json` to `config.json` and customize with your deployment targets:

```bash
cp config.example.json config.json
```

Edit `config.json` to specify:
- **LocalDestinations**: Paths where the module should be copied locally
- **RemoteServers**: Remote servers where the module should be deployed via PowerShell Remoting

Example:
```json
{
  "LocalDestinations": [
    "$env:ProgramFiles\\PowerShell\\Modules\\GPOps"
  ],
  "RemoteServers": [
    {
      "ComputerName": "prod-server-01",
      "DestinationPath": "C:\\Program Files\\PowerShell\\Modules\\GPOps",
      "CredentialKey": "prod-servers"
    }
  ]
}
```

### 2. Store Remote Credentials

Use the credential management functions to securely store credentials in Windows Credential Manager:

```powershell
# Import the credential helper functions
. .\deployment\Credential-Manager.ps1

# Store credentials for a set of servers
Set-GPOpsStoredCredential -CredentialKey 'prod-servers'
```

This will prompt you for credentials and store them using Windows Credential Manager (DPAPI encryption).

### 3. Deploy the Module

After building the module, deploy it to configured destinations:

```powershell
# Deploy as part of the build process
./build.ps1 -Tasks build, Deploy_GPOpsModule

# Or deploy separately (module must already be built)
./build.ps1 -Tasks Deploy_GPOpsModule
```

## Credential Management

### Store Credentials
```powershell
. .\deployment\Credential-Manager.ps1
Set-GPOpsStoredCredential -CredentialKey 'prod-servers'
```

### Retrieve Credentials (for testing)
```powershell
. .\deployment\Credential-Manager.ps1
$cred = Get-GPOpsStoredCredential -CredentialKey 'prod-servers'
```

### List Stored Credentials
```powershell
. .\deployment\Credential-Manager.ps1
List-GPOpsStoredCredentials
```

### Remove Credentials
```powershell
. .\deployment\Credential-Manager.ps1
Remove-GPOpsStoredCredential -CredentialKey 'prod-servers'
```

## Configuration File

### LocalDestinations

Array of local paths where the compiled module should be copied. Environment variables are supported:

```json
"LocalDestinations": [
  "$env:ProgramFiles\\PowerShell\\Modules\\GPOps",
  "C:\\MyModules\\GPOps"
]
```

### RemoteServers

Array of remote servers to deploy to. Each entry must have:

| Property | Description |
|----------|-------------|
| `ComputerName` | FQDN or hostname of the target server |
| `DestinationPath` | Path where the module should be copied on remote server |
| `CredentialKey` | Identifier for credentials stored in Windows Credential Manager (e.g., 'prod-servers') |

Example:
```json
"RemoteServers": [
  {
    "ComputerName": "prod-server-01.example.com",
    "DestinationPath": "C:\\Program Files\\PowerShell\\Modules\\GPOps",
    "CredentialKey": "prod-servers"
  }
]
```

## Build Workflow Integration

The deployment task is optional. You can add it to your build workflow in `build.yaml`:

```yaml
BuildWorkflow:
  deploy:
    - build
    - Deploy_GPOpsModule
```

Then run: `./build.ps1 -Tasks deploy`

## Security Notes

- **Credentials**: Stored in Windows Credential Manager using DPAPI encryption
- **Configuration**: `config.json` should not be committed (it's in `.gitignore`)
- **Access**: Credentials are only accessible to the user who stored them on that machine
- **Remote Access**: Requires PowerShell Remoting to be enabled on target servers

## Troubleshooting

### "PSSession connection failed"
- Verify the remote server has PowerShell Remoting enabled: `Enable-PSRemoting`
- Check network connectivity to the remote server
- Verify credentials are correct and the user has permission to log in

### "Credential key not found"
- Ensure you've stored the credential with matching key: `Set-GPOpsStoredCredential -CredentialKey 'prod-servers'`
- Use `List-GPOpsStoredCredentials` to see all stored keys

### "Access Denied" on local deployment
- Verify you have write permissions to the destination path
- Ensure the destination directory exists or the parent directory exists
