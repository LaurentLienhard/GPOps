# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

GPOps is a PowerShell module for full Group Policy Object (GPO) lifecycle management. It uses the **Sampler/ModuleBuilder** build system, which is the modern standard for building, testing, and publishing PowerShell modules.

## Common Commands

### Build and Test
- **Full build with tests (default)**: `./build.ps1`
- **Build only**: `./build.ps1 -Tasks build`
- **Run all tests**: `./build.ps1 -Tasks test`
- **Run specific test file**: `./build.ps1 -Tasks test -PesterScript tests/Unit/Public/Get-Something.tests.ps1`
- **Code coverage check**: Automatically enforced during tests (threshold: 85% in build.yaml)

### Linting and Analysis
- **PSScriptAnalyzer** runs automatically during the build process as part of the ModuleBuilder workflow. It checks for code quality issues and PowerShell best practices.

### Publishing
- **Publish to GitHub and PowerShell Gallery**: `./build.ps1 -Tasks publish`

## Architecture and Structure

### Build System: Sampler/ModuleBuilder
The project uses Invoke-Build tasks defined in `build.yaml`:
- **`.` (default task)**: Runs `build` and `test` sequentially
- **`build` task**: Cleans output, compiles module, generates changelog
- **`test` task**: Runs Pester tests with code coverage validation
- **`pack` task**: Packages the module as a NuGet package
- **`publish` task**: Publishes to GitHub and PowerShell Gallery

### Module Structure
```
source/
  ├── Public/           # Exported functions (Get-Something.ps1, etc.)
  ├── Private/          # Internal helper functions (Get-PrivateFunction.ps1, etc.)
  └── en-US/            # Localization/help files

output/                 # Build artifacts (generated, contains compiled .psm1)
  └── module/
    └── GPOps/
      └── [version]/    # Versioned module directory

tests/
  ├── Unit/             # Unit tests for individual functions
  │   ├── Public/       # Tests for public functions
  │   └── Private/      # Tests for private functions
  └── QA/               # Quality assurance tests (module-level validation)
```

### Build Process
1. **ModuleBuilder** compiles `source/Public/*.ps1` and `source/Private/*.ps1` into a single `.psm1` file in `output/`
2. **Semantic versioning** via GitVersion: Tags and commits define version numbers based on commit messages (see GitVersion.yml for patterns)
3. **Code coverage**: Pester tests measure coverage; build fails if coverage drops below 85% threshold
4. **Changelog**: Automatically generated from commit history

### Key Files
- **build.yaml**: Defines ModuleBuilder configuration and Invoke-Build workflows
- **build.ps1**: Entry point that bootstraps dependencies and runs build tasks
- **GitVersion.yml**: Semantic versioning rules (e.g., "breaking change" = major bump, "adds feature" = minor bump)
- **RequiredModules.psd1**: Lists build-time dependencies (Sampler, Pester, ModuleBuilder, etc.)
- **Resolve-Dependency.ps1**: Bootstraps required modules for the build environment

### Function Patterns
Public functions follow the PowerShell advanced function pattern:
- Parameter validation with `[Parameter()]` attributes
- Comment-based help (`.SYNOPSIS`, `.DESCRIPTION`, `.EXAMPLE`, `.PARAMETER`)
- `SupportsShouldProcess = $true` and `-Confirm` support where appropriate
- Verbose and Debug output support
- Error handling with proper exit codes

### Naming Conventions

#### Function Naming - REQUIRED MODULE PREFIX

**All public functions MUST be prefixed with `GPOps` to avoid naming conflicts.**

**Format**: `<Verb>-GPOps<Noun>`

**Examples:**
- ✅ `Get-GPOpsInfo` - Get GPO information
- ✅ `Link-GPOpsToOU` - Link a GPO to an organizational unit
- ✅ `Unlink-GPOpsFromOU` - Unlink a GPO from an organizational unit
- ✅ `New-GPOpsPolicy` - Create a new GPO policy
- ✅ `Remove-GPOpsPolicy` - Remove a GPO policy
- ✅ `Backup-GPOpsSettings` - Backup GPO settings
- ✅ `Restore-GPOpsSettings` - Restore GPO settings
- ✅ `Test-GPOpsHealth` - Test GPO health status
- ✅ `Get-GPOpsReport` - Generate a GPO report
- ✅ `Set-GPOpsPermission` - Set GPO permissions

**❌ Avoid (incorrect naming):**
- ❌ `Get-GPOInfo` - Missing module prefix
- ❌ `GetGPOInfo` - Not Verb-Noun format
- ❌ `Get-Info` - No context about GPO module

#### Why This Matters

1. **Namespace Safety**: Prevents conflicts with native `Get-GPO`, `Set-GPO`, etc. from GroupPolicy module
2. **Clear Module Origin**: Users immediately know the function comes from GPOps
3. **Discoverability**: `Get-Command *GPOps*` easily finds all module functions
4. **Professional Standard**: Industry best practice for module naming
5. **Export Control**: Makes it obvious which functions should be exported in module manifest

#### Verb Selection

Use standard PowerShell verbs:
- **Query**: `Get-`, `Search-`, `Find-`
- **Modify**: `Set-`, `New-`, `Add-`, `Remove-`, `Update-`
- **Actions**: `Invoke-`, `Start-`, `Stop-`, `Test-`
- **Data**: `Import-`, `Export-`, `Backup-`, `Restore-`

All verbs must be from `Get-Verb` approved list.

#### Private Functions

Private functions (in `source/Private/`) may use simpler names without the full prefix:
- `Resolve-GpoPath` - OK for internal use
- `Test-AdConnection` - OK for internal use

But can also use full prefix for consistency:
- `Resolve-GPOpsPath` - Consistent with public functions
- `Test-GPOpsAdConnection` - Consistent with public functions

**Recommendation**: Use full `GPOps` prefix even for private functions for consistency.

### Code Style

#### General Rules
- **All code, functions, and documentation must be written in English**
- Comment-based help must be placed **immediately after the function name** (inside the function, before `[CmdletBinding()]`)
- **Every function (Public and Private) and every class must have a corresponding Pester test file**
- Tests must use mocks for external dependencies (no real API/AD/network calls)
- Each function/class must achieve **minimum 85% code coverage**
- **Prefer `Write-Verbose` over `Write-Host` or `Write-Output`** for informational messages

#### Function Structure
- Use **uppercase** for `BEGIN`, `PROCESS`, `END` blocks
- Use `[CmdletBinding()]` for all functions
- Use `[OutputType()]` attribute when returning specific types
- Support pipeline input with `ValueFromPipeline` and `ValueFromPipelineByPropertyName`
- Use `[Parameter()]` attribute with `Mandatory`, `HelpMessage`, `Position` as needed
- Use validation attributes: `[ValidateSet()]`, `[ValidateNotNullOrEmpty()]`, `[ValidateRange()]`

#### Parameter Patterns
- Credential parameter pattern (optional credentials):
  ```powershell
  [Parameter()]
  [System.Management.Automation.PSCredential]$Credential
  ```
- Check for credential with `$PSBoundParameters.ContainsKey('Credential')`

#### Coding Conventions
- Use **splatting** for commands with multiple parameters:
  ```powershell
  $params = @{
      ComputerName = $Computer
      ErrorAction  = 'Stop'
  }
  Invoke-Command @params
  ```
- Use `[PSCustomObject]@{}` for structured output objects
- Use `[System.Collections.Generic.List[T]]::new()` instead of `ArrayList` for collections
- Use `try/catch` blocks with specific exception types when possible
- Use `[SuppressMessageAttribute()]` to bypass PSScriptAnalyzer rules only when justified

#### Code Formatting (VSCode PowerShell Extension)
**Brace Placement:**
- Opening braces on new line: `OpenBraceOnSameLine = false`
- New line after opening brace: `true`
- New line after closing brace: `true`
- Whitespace before opening brace: `true`

**Spacing & Operators:**
- Whitespace before opening parenthesis: `true`
- Whitespace around operators: `true`
- Whitespace after separator: `true`
- Align property value pairs: `true`

**Pipeline Formatting:**
- Pipeline indentation style: `IncreaseIndentationAfterEveryPipeline`
- Single-line blocks ignored: `false`

**File Formatting:**
- Trim trailing whitespace: `true`
- Trim final newlines: `true`
- Insert final newline: `true`
- PSScriptAnalyzer enabled: `true`

**Example formatted code:**
```powershell
function Get-Example
{
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $result = Get-Content -Path $Name |
        Where-Object { $_ -match 'pattern' } |
        Select-Object -Property Property1, Property2

    return $result
}
```

#### Class Structure
- Use `#region` comments to organize sections: `#region <Properties>`, `#region <Constructor>`, `#region <Methods>`
- Prefix class files with numbers for load order (e.g., `01_GPO.ps1`, `02_LinkedGPO.ps1`)
- Use `HIDDEN` keyword for internal properties (e.g., credentials)

#### Object-Oriented Design Philosophy
**Prefer classes over functions whenever possible.** Classes provide:
- **Encapsulation**: Properties and methods bundled together with state
- **Reusability**: Create instances with specific state rather than passing parameters everywhere
- **Testability**: Easier to mock and test isolated objects
- **Maintainability**: Self-documenting code with clear object relationships
- **Type Safety**: Static typing prevents common errors

**When to use classes:**
- ✅ Any entity with multiple related properties (GPO, LinkedGPO, Group, etc.)
- ✅ Objects that need to maintain state across method calls
- ✅ When you have a collection of related functions working on the same data
- ✅ Infrastructure objects with behavior (e.g., AD Query wrapper, Policy Filter)

**When functions are acceptable:**
- ✅ Simple utilities that transform input to output with no state
- ✅ Formatters or validators
- ✅ Wrapper functions for a single external command
- ✅ Functions that orchestrate multiple classes

**Example: Refactor from functions to classes**
```powershell
# ❌ AVOID: Multiple functions with scattered logic
function Get-GpoTarget {
    param([string]$GpoName)
    # ...
}

function Add-GpoLink {
    param([string]$GpoName, [string]$OuPath)
    # ...
}

function Remove-GpoLink {
    param([string]$GpoName, [string]$OuPath)
    # ...
}

# ✅ PREFER: Class with encapsulated state and behavior
class GPO
{
    [System.String]$DisplayName
    [System.Guid]$Id
    [System.Collections.Generic.List[string]]$LinkedOUs

    GPO([string]$Name)
    {
        if (-not [string]::IsNullOrEmpty($Name)) {
            $this.DisplayName = $Name
        }
        else {
            $this.DisplayName = ''
        }
        $this.Id = [guid]::NewGuid()
        $this.LinkedOUs = [System.Collections.Generic.List[string]]::new()
    }

    [void] LinkToOu([string]$OuPath)
    {
        $this.LinkedOUs.Add($OuPath)
    }

    [void] UnlinkFromOu([string]$OuPath)
    {
        $this.LinkedOUs.Remove($OuPath)
    }

    [object] GetTargets()
    {
        return $this.LinkedOUs
    }
}
```

**Benefits of this approach:**
- State is managed within the object (no scattered parameters)
- Methods naturally operate on the object's data
- Easier to extend with new methods (e.g., `Backup()`, `Restore()`, `Report()`)
- Testable: Create test instances without mocking external dependencies
- Discoverable: IDE autocomplete shows all available methods on an object

### PowerShell Compatibility and Standards

This project follows standard PowerShell practices compatible with PowerShell 5.1 and higher. All code should prioritize:
- **Explicit over implicit**: Use clear null checks and conditional statements
- **Compatibility**: Avoid PowerShell 7+ specific syntax features
- **Readability**: Favor clarity over brevity
- **Performance**: Use efficient data structures (`List[T]`, generic collections) and pipeline operations

### Performance and Best Practices

**Use Generic Lists Instead of ArrayList**
```powershell
# ✅ PREFERRED: 100x faster than +=
$results = [System.Collections.Generic.List[PSCustomObject]]::new()

$items | ForEach-Object {
    $results.Add([PSCustomObject]@{
        Name  = $_
        Value = Get-Value $_
    })
}

return $results
```

**Pipeline Optimization**
```powershell
# ✅ Use pipeline for filtering/transformation
$filtered = $gpos |
    Where-Object { $_.Name -like "PROD-*" } |
    Select-Object DisplayName, Id, Owner |
    Sort-Object DisplayName

# ✅ Use early LDAP filtering instead of post-processing
$results = Get-ADObject -LDAPFilter "(|(cn=GPO-*)(cn=PROD-*))" |
    Where-Object { $_.ObjectClass -eq "groupPolicyContainer" }
```

**Avoid Sequential Loops**
```powershell
# ❌ AVOID: Sequential loop for multiple items
foreach ($computer in $computers) {
    Get-GPOStatus -Computer $computer
}

# ✅ PREFER: Parallel processing
$computers | ForEach-Object -ThrottleLimit 32 -Parallel {
    Get-GPOStatus -Computer $_
}
```

#### Language Features to Leverage

**Strongly Typed Collections**
```powershell
# ✅ Use typed collections for better performance
class GPOBatch
{
    [System.Collections.Generic.List[GPO]]$Items
    [System.Collections.Generic.Dictionary[string, GPO]]$Index

    GPOBatch()
    {
        $this.Items = [System.Collections.Generic.List[GPO]]::new()
        $this.Index = [System.Collections.Generic.Dictionary[string, GPO]]::new()
    }
}
```

**Splatting with Modern Syntax**
```powershell
# ✅ Use splatting for clean, maintainable code
$params = @{
    Filter      = "Name -like 'PROD-*'"
    Properties  = 'DisplayName', 'Owner', 'Created'
    ErrorAction = 'Stop'
}

$gpos = Get-ADObject @params
```

**Switch Statement (Modern Pattern Matching)**
```powershell
# ✅ Modern switch with conditions
$action = switch ($gpo.Status) {
    'Active'   { 'monitor' }
    'Disabled' { 'audit' }
    'Draft'    { 'review' }
    default    { 'unknown' }
}
```

#### Cross-Platform Considerations

**Path Handling**
```powershell
# ✅ Use Path module for cross-platform compatibility
$configPath = Join-Path $PSScriptRoot "configs" "policy.json"
$logPath = Join-Path $env:TEMP "gpo.log"
```

**Environment Variables**
```powershell
# ✅ Use standard cross-platform variables
$tmpDir = $env:TEMP      # Works on Windows, macOS, Linux
$homeDir = $env:HOME     # Cross-platform
$pathSep = [IO.Path]::PathSeparator
```

#### PowerShell Compatibility

- **Minimum**: PowerShell 5.1 (Windows PowerShell) or PowerShell 7.0 (Core)
- **Recommended**: PowerShell 7.2+ for best compatibility and performance
- **Focus**: Write code compatible with PowerShell 5.1+ to maximize compatibility

**Compatibility Rules:**
- Use explicit null checks (`-eq $null`, `-ne $null`) instead of operators like `??` or `?.`
- Use `if/else` statements for conditional assignment instead of ternary operators
- Avoid `ForEach-Object -Parallel` (PowerShell 7+ only) for core functionality
- Use `[System.Collections.Generic.List[T]]` for better performance than array concatenation
- Use splatting and explicit parameters over modern operator shortcuts

## Development Workflow

1. **Add new functions**: Create `.ps1` files in `source/Public/` or `source/Private/`
2. **Add help content**: Include comment-based help in the function definition
3. **Write tests**: Create corresponding `.tests.ps1` files in `tests/Unit/{Public|Private}/`
4. **Run tests**: `./build.ps1 -Tasks test` validates tests pass and code coverage threshold is met
5. **Full build**: `./build.ps1` performs build and test validation
6. **Commit messages** control versioning via GitVersion regex patterns in GitVersion.yml

## Testing Guidelines

### Test Requirements
- **Every function (Public and Private) and every class must have a corresponding Pester test file**
- Tests must use **mocks for external dependencies** (no real API/AD/network/file system calls)
- Test files use Pester v5 syntax (`BeforeAll`, `AfterAll`, `Describe`, `Context`, `It`)
- Maintain **85% code coverage threshold** - all code paths must be tested
- Mock external dependencies with `Mock -CommandName ... -ModuleName GPOps`
- Test both named parameters and pipeline input
- Test `ShouldProcess` (`-WhatIf`) support where applicable

### Functional Mocking Patterns

#### Mocking External Commands
```powershell
BeforeAll {
    Import-Module GPOps -Force
    Mock -CommandName Get-GPO -ModuleName GPOps -MockWith {
        return @{
            DisplayName = 'Test GPO'
            Id          = [guid]::NewGuid()
        }
    }
}

It "retrieves GPO data without actual AD calls" {
    $result = Get-GpoInfo -Name 'Test GPO'
    Assert-MockCalled -CommandName Get-GPO -Times 1 -Scope It
}
```

#### Mocking with Different Return Values per Call
```powershell
Mock -CommandName Test-ComputerConnectivity -ModuleName GPOps -MockWith {
    param($ComputerName)
    if ($ComputerName -eq 'OnlineServer') {
        return $true
    }
    return $false
}
```

#### Mocking Failures and Error Handling
```powershell
Mock -CommandName Get-ADObject -ModuleName GPOps -MockWith {
    throw [System.UnauthorizedAccessException]"Access Denied"
}

It "handles access denied errors gracefully" {
    { Get-GpoDetails -Name 'SecureGPO' } | Should -Throw -ExceptionType ([System.UnauthorizedAccessException])
}
```

#### Verifying Mock Calls
```powershell
It "processes all items in parallel" {
    $items = @('Item1', 'Item2', 'Item3')
    Invoke-BatchOperation -Items $items

    # Verify the command was called for each item
    Assert-MockCalled -CommandName Process-Item -Times 3 -Scope It
    Assert-MockCalled -CommandName Process-Item -ParameterFilter { $Name -eq 'Item1' } -Times 1
}
```

### Test File Organization

Test files mirror the source structure:
- `tests/Unit/Public/` - Tests for public functions
- `tests/Unit/Private/` - Tests for private functions
- `tests/Unit/Classes/` - Tests for classes
- `tests/QA/` - Quality assurance tests (module-level validation)

Example test structure:
```powershell
BeforeAll {
    Import-Module $PSScriptRoot/../../output/module/GPOps -Force -ErrorAction Stop
}

AfterAll {
    Remove-Module GPOps -Force -ErrorAction SilentlyContinue
}

Describe 'Get-GpoInfo' {
    Context 'When GPO exists' {
        BeforeEach {
            Mock -CommandName Get-GPO -ModuleName GPOps -MockWith {
                return [PSCustomObject]@{
                    DisplayName = 'Test GPO'
                    Id          = '12345678-1234-1234-1234-123456789012'
                }
            }
        }

        It 'returns GPO information' {
            $result = Get-GpoInfo -Name 'Test GPO'
            $result.DisplayName | Should -Be 'Test GPO'
        }

        It 'calls Get-GPO once' {
            Get-GpoInfo -Name 'Test GPO'
            Assert-MockCalled -CommandName Get-GPO -Times 1 -Scope It
        }
    }

    Context 'When GPO does not exist' {
        BeforeEach {
            Mock -CommandName Get-GPO -ModuleName GPOps -MockWith { return $null }
        }

        It 'returns null' {
            $result = Get-GpoInfo -Name 'NonExistent'
            $result | Should -BeNullOrEmpty
        }
    }
}
```

## Dependencies

Build dependencies (auto-resolved by build.ps1):
- **Sampler**: Framework for the build pipeline
- **ModuleBuilder**: Compiles module source into output
- **Pester**: Testing framework (v5+)
- **PSScriptAnalyzer**: Code analysis and linting
- **InvokeBuild**: Task execution engine
- **ChangelogManagement**: Changelog generation

These are installed from PowerShell Gallery during the first build run.
