# GPOps

A comprehensive PowerShell module for full Group Policy Object (GPO) lifecycle management.

## Overview

GPOps provides powerful cmdlets for managing Group Policy Objects in Active Directory environments. It handles creation, configuration, linking, and maintenance of GPOs with a modern, efficient approach built on PowerShell 7+ capabilities.

## Features

- 🎯 **Complete GPO Lifecycle Management** - Create, read, update, and delete GPOs
- 🔗 **GPO Linking** - Link and unlink GPOs from organizational units
- 📊 **Policy Analysis** - Analyze and report on GPO configurations
- ⚡ **High Performance** - Optimized for PowerShell 7+ with parallel processing support
- 🛡️ **Secure** - Built-in credential handling and error management
- 📝 **Well Documented** - Complete comment-based help for all functions

## Installation

### From PowerShell Gallery

```powershell
Install-Module -Name GPOps -Repository PSGallery
```

### From Source

```powershell
# Clone the repository
git clone https://github.com/yourusername/GPOps.git
cd GPOps

# Build the module
./build.ps1

# Import the module
Import-Module ./output/module/GPOps/<version>/GPOps.psd1
```

## Quick Start

```powershell
# Import the module
Import-Module GPOps

# Get help on available commands
Get-Command -Module GPOps

# Get detailed help for a specific function
Get-Help Get-GpoInfo -Full

# Example: Retrieve GPO information
Get-GpoInfo -Name "MyGPO"
```

## Requirements

- **PowerShell 5.1+** (optimized for PowerShell 7+)
- **Active Directory Module** for PowerShell
- **.NET Framework 4.5+** or **.NET Core 3.1+**
- **Windows Server 2016+** or **Windows 10+** (for GPO management features)

## Module Structure

```
GPOps/
├── source/
│   ├── Public/              # Exported cmdlets (user-facing)
│   ├── Private/             # Internal helper functions
│   ├── Classes/             # PowerShell classes
│   └── en-US/               # Help documentation
├── tests/
│   ├── Unit/                # Unit tests
│   │   ├── Public/
│   │   ├── Private/
│   │   └── Classes/
│   └── QA/                  # Quality assurance tests
├── build.ps1                # Build automation script
└── build.yaml               # Build configuration
```

## Build & Development

### Build Commands

```powershell
# Full build with tests
./build.ps1

# Build only
./build.ps1 -Tasks build

# Run tests
./build.ps1 -Tasks test

# Build and package
./build.ps1 -Tasks pack

# Publish to PowerShell Gallery
./build.ps1 -Tasks publish
```

### Development Workflow

1. Create new functions in `source/Public/` or `source/Private/`
2. Add comment-based help (SYNOPSIS, DESCRIPTION, PARAMETERS, EXAMPLES)
3. Create corresponding Pester tests in `tests/Unit/`
4. Run `./build.ps1 -Tasks test` to validate
5. Ensure code coverage meets 85% threshold
6. Commit with semantic versioning-compliant message

### Code Style

The project follows strict PowerShell best practices:
- Advanced function syntax with `[CmdletBinding()]`
- Comment-based help immediately after function name
- Pester tests with functional mocking for all functions
- 85% minimum code coverage
- VSCode PowerShell extension formatting rules

For detailed guidelines, see [CLAUDE.md](./CLAUDE.md)

## Testing

All functions and classes require corresponding Pester tests with functional mocks:

```powershell
# Run all tests
./build.ps1 -Tasks test

# Run specific test file
./build.ps1 -Tasks test -PesterScript tests/Unit/Public/Get-GpoInfo.tests.ps1

# View test results
# (Results are in output/testResults/)
```

Tests use Pester v5 with mocks for external dependencies (no real AD calls during testing).

## Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Make your changes following the code style in CLAUDE.md
4. Add/update tests to maintain 85% coverage
5. Run `./build.ps1` to ensure everything passes
6. Commit with a clear, semantic message
7. Push and create a Pull Request

### Commit Message Format

Use semantic commit messages for automatic versioning:

```
fix: resolve GPO deletion issue
feature: add GPO backup functionality
breaking change: update parameter names for consistency
```

## Troubleshooting

### "Access Denied" Errors

Ensure you have appropriate Active Directory permissions:
- Read permissions for domain
- Write permissions for OUs (if creating/linking GPOs)
- Domain Admin or equivalent privileges for system policies

### Module Import Issues

```powershell
# Clear cached modules
Remove-Module GPOps -Force -ErrorAction SilentlyContinue

# Reimport with verbose output
Import-Module GPOps -Verbose

# Check for conflicts
Get-Command -Name Get-GpoInfo -All
```

## Documentation

- **CLAUDE.md** - Developer guidelines and architecture
- **Function Help** - Use `Get-Help <CmdletName> -Full` for specific cmdlet documentation
- **Examples** - Check `source/Examples/` for usage examples

## License

This project is licensed under the MIT License. See LICENSE file for details.

## Support

For issues, questions, or feature requests:
- Open an issue on GitHub
- Check existing issues and discussions
- Review the troubleshooting section above

## Changelog

All changes are documented in [CHANGELOG.md](./CHANGELOG.md), automatically generated from commit history using semantic versioning.

---

**Current Version**: Check `Get-Module GPOps | Select-Object Version`

**Last Updated**: 2026-02-13
