<#
    .SYNOPSIS
        EXPERIMENTAL: Clone a git repository

    .DESCRIPTION
        EXPERIMENTAL: Clone a git repository

        Note: We require git.exe in your path

        Relevant Dependency metadata:
            DependencyName (Key): Git URL
                You can override this with the 'Name'.
                If you specify only an Account/Repository, we assume GitHub is the source
            Name: Optional override for the Git URL, same rules as DependencyName (key)
            Version: Used with git checkout.  Specify a branch name, commit hash, or tags/<tag name>, for example.  Defaults to master
            Target: Path to clone this repository.  Defaults to nothing (current path/repo name)
            AddToPath: Prepend the Target to ENV:PATH and ENV:PSModulePath

    .PARAMETER Force
        If specified and target does not exist, create directory tree up to the target folder

    .PARAMETER PSDependAction
        Test, Install, or Import the module.  Defaults to Install

        Test: Return true or false on whether the dependency is in place (Note: Currently only checks if path exists)
        Install: Install the dependency

    .EXAMPLE
        @{
            'buildhelpers' = @{
                Name = 'https://github.com/RamblingCookieMonster/BuildHelpers.git'
                Version = 'd32a9495c39046c851ceccfb7b1a85b17d5be051'
                Target = 'C:\git'
            }
        }

        # Full syntax
          # DependencyName (key) uses (unique) name 'buildhelpers'
          # Override DependencyName as URL the name https://github.com/RamblingCookieMonster/BuildHelpers.git
          # Specify a commit to checkout (version)
          # Clone in C:\git

    .EXAMPLE

        @{
            'ramblingcookiemonster/PSDeploy' = 'master'
            'ramblingcookiemonster/BuildHelpers' = 'd32a9495c39046c851ceccfb7b1a85b17d5be051'
        }

        # Simple syntax
          # First example shows cloning PSDeploy from ramblingcookiemonster's GitHub account
          # Second example shows clonging PSDeploy from ramblingcookiemonster's GitHub account and checking out a specific commit
          # Both are cloned to the current path (e.g. .\<repo name>)
          # This syntax assumes GitHub as a source. The right hand side is the version (branch, commit, tags/<tag name>, etc.
#>
[cmdletbinding()]
param(
    [PSTypeName('PSDepend.Dependency')]
    [psobject[]]$Dependency,

    [switch]$Force,

    [ValidateSet('Test', 'Install')]
    [string[]]$PSDependAction = @('Install')
)

# Extract data from Dependency
$DependencyName = $Dependency.DependencyName
$Name = $Dependency.Name
if(-not $Name)
{
    $Name = $DependencyName
}

#Name is in account/repo format, default to GitHub as source
#This likely needs work, and will need to change if GitHub changes valid characters for usernames
if($Name -match "[a-zA-Z0-9]+/[a-zA-Z0-9_-]+")
{
    $Name = "https://github.com/$Name.git"
}
$GitName = $Name.split('/')[-1] -replace "\.git[/]?$", ''

#TODO: PSDependAction Test should test that it exists, is a git repo, and if specified, the version...
$Target = $Dependency.Target
if($Target)
{
    $RepoPath = $Target
    if(-not (Test-Path $Target))
    {
        # Nothing found, return test output
        if( $PSDependAction -contains 'Test' -and $PSDependAction.count -eq 1)
        {
            return $False
        }
        if( $PSDependAction -contains 'Install')
        {
            mkdir $Target -Force
        }
    }
}
else
{
    $RepoPath = Join-Path $PWD.Path $GitName
    if($PSDependAction -contains 'Test' -and $PSDependAction.count -eq 1)
    {
        if(Test-Path $RepoPath)
        {
            return $true
        }
        else
        {
            return $false
        }
    }
}

if($PSDependAction -notcontains 'Install')
{
    return
}

$Version = $Dependency.Version
if(-not $Version)
{
    $Version = 'master'
}

if(-not (Get-Command git.exe -ErrorAction SilentlyContinue))
{
    Write-Error "Git dependency type requires git.exe.  Ensure this is in your path, or explicitly specified in $ModuleRoot\PSDepend.Config's GitPath.  Skipping [$DependencyName]"
}

Write-Verbose -Message "Cloning dependency [$Name] with git"
$CloneParams = @('clone', $Name)
if($Target)
{
    $CloneParams += $Target
}

#TODO: Add logic to test for existing repo
Invoke-ExternalCommand git $CloneParams
Push-Location
Set-Location $RepoPath

#TODO: Should we do a fetch, once existing repo is found?
Write-Verbose -Message "Checking out [$Version] of [$Name]"
$CheckoutParams = @('checkout', $Version)
Invoke-ExternalCommand git $CheckoutParams
Pop-Location

if($Dependency.AddToPath)
{
    Write-Verbose "Setting PSModulePath to`n$($RepoPath, $env:PSModulePath -join ';' | Out-String)"
    $env:PSModulePath = $RepoPath, $env:PSModulePath -join ';'
    
    Write-Verbose "Setting PATH to`n$($RepoPath, $env:PATH -join ';' | Out-String)"
    $env:PATH = $RepoPath, $env:PATH -join ';'
}
