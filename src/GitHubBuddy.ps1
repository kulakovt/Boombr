#Requires -Version 5
#Requires -Modules PowerShellForGitHub

Set-StrictMode -version Latest
$ErrorActionPreference = 'Stop'

. $PSScriptRoot\Utility.ps1

# Register GitHub API Token before work (https://github.com/microsoft/PowerShellForGitHub#configuration)

$LocalRootPath = Join-Path $PSScriptRoot '..\..\Seeds' -Resolve
$AuditCommunityPath = Join-Path $PSScriptRoot '..\..\Audit\db\communities' -Resolve
$OrganizationName = 'DotNetRu-Seeds'

class CommunitySite
{
    [string] $Name
    [string] $Description
    [string] $HomePage
    [string] $CommunityName
    [Uri] $Url
}

function Convert-GitHubRepositoryToSite
{
    [CmdletBinding()]
    [OutputType([CommunitySite])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        $Repository
    )

    process
    {
        if ($Repository.description -match '(?<Community>\w+) Community')
        {
            $communityName = $Matches['Community']
        }
        else
        {
            Write-Warning "Can't parese Community name for $($Repository.name): $($Repository.description). Skip."
            return
        }

        $site = [CommunitySite]::New()
        $site.Name = $Repository.name
        $site.Description = $Repository.description
        $site.HomePage = $Repository.homepage
        $site.CommunityName = $communityName
        $site.Url = $Repository.html_url

        $site
    }
}

function Get-CommunitySite
{
    [CmdletBinding()]
    [OutputType([CommunitySite[]])]
    param (
        [ValidateNotNullOrEmpty()]
        [string]
        $Name
    )

    $params = @{
        OrganizationName = $OrganizationName
        Type = 'Public'
        NoStatus = $true
    }

    $repos = Get-GitHubRepository @params
    if ($Name)
    {
        $repos = $repos | Where-Object {  $_.name -eq $Name }
    }

    $repos |
    Convert-GitHubRepositoryToSite
}

function New-CommunitySite
{
    [CmdletBinding()]
    [OutputType([CommunitySite])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $CommunityName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name
    )

    $params = @{
        OrganizationName = $OrganizationName
        RepositoryName = $Name
        Description = "$CommunityName Community"
        Homepage = "https://$Name.DotNet.Ru"
        NoIssues = $true
        NoProjects = $true
        NoWiki = $true
        NoStatus = $true
    }

    New-GitHubRepository @params |
    Convert-GitHubRepositoryToSite
}

function Initialize-CommunitySite
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        $CommunityName
    )

    process
    {
        $name = $null
        if ($CommunityName -match '(?<Prefix>\w{3})DotNet')
        {
            $name = $Matches['Prefix']
            Write-Information "Initialize $name site"
        }
        else
        {
            throw "Can't resolve site name for $CommunityName"
        }

        ### GitHub ##################################################################
        $site = Get-CommunitySite -Name $name
        if ($site)
        {
            Write-Information "  - GitHub repository already exists"
        }
        else
        {
            Write-Information "  + Create GitHub repository"
            $site = New-CommunitySite -CommunityName $CommunityName -Name $Name
        }

        ### Local Repo ##################################################################
        if (-not (Test-Path $LocalRootPath -PathType Container))
        {
            throw "Local repository root not found at $LocalRootPath"
        }

        $localPath = Join-Path $LocalRootPath $site.Name
        if (Test-Path $localPath -PathType Container)
        {
            Write-Information "  - Local repository already exists"
        }
        else
        {
            Write-Information "  + Clone to local repository"
            Push-Location
            Set-Location $LocalRootPath
            git clone "https://github.com/${OrganizationName}/$($site.Name).git"
            Pop-Location
        }

        ### CNAME ##################################################################
        $cnamePath = Join-Path $localPath 'CNAME'
        if (Test-Path $cnamePath -PathType Leaf)
        {
            Write-Information "  - CNAME file already exists"
        }
        else
        {
            Write-Information "  + Create CNAME file"
            "$($site.Name.ToLower()).dotnet.ru" | Set-Content -Path $cnamePath -Encoding UTF8 -NoNewline
        }

        ### TODO ##################################################################
        # - [GitHub Pages] Enable GitHub Pages at master branch
        # - [GitHub Pages] Enable Enforce HTTPS
    }
}

function Initialize-CommunityEnv
{
    Get-ChildItem -Path $AuditCommunityPath -Filter '*.xml' |
    ForEach-Object {
        [xml] $community = $_ | Get-Content -Raw -Encoding UTF8
        $community.Community.Name
    } |
    Initialize-CommunitySite -InformationAction Continue
}

