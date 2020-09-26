Set-StrictMode -version Latest
$ErrorActionPreference = 'Stop'

$InformationPreference = 'Continue'
$VerbosePreference = 'SilentlyContinue'

. $PSScriptRoot\Utility.ps1
. $PSScriptRoot\Model.ps1
. $PSScriptRoot\Serialization.ps1
. $PSScriptRoot\Svg\Logo.ps1

function Update-BrandLogo([string] $Path, [Community] $Community)
{
    New-Logo -Text $Community.Name |
    Set-Content (Join-Path $Path 'Logo.svg')
}

function Update-BrandCommunity
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [Community]
        $Community
    )

    process
    {
        $shortName = $Community.Name -replace 'DotNet$',''
        $communityPath = Join-Path $logoPath $shortName
        Confirm-DirectoryExist -Path $communityPath

        Update-BrandLogo -Path $communityPath -Community $Community
    }
}

function Update-BrandBook([string] $Path, [Hashtable] $Config)
{
    $logopath = Join-Path $Path 'Logo'
    Confirm-DirectoryExist -Path $logoPath

    Read-Community -AuditDir $Config.AuditDir |
    Update-BrandCommunity
}


$Config = @{
    RootDir = $PSScriptRoot
    ArtifactsDir = Resolve-FullPath $PSScriptRoot '..\artifacts'
    AuditDir = Resolve-FullPath $PSScriptRoot '..\..\Audit\db'
    IsOffline = $false
}
Update-BrandBook -Path 'C:\Users\akulakov\Desktop\GitHub\BrandBook' -Config $Config
