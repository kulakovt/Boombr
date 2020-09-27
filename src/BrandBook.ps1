Set-StrictMode -version Latest
$ErrorActionPreference = 'Stop'

$InformationPreference = 'Continue'
$VerbosePreference = 'SilentlyContinue'

. $PSScriptRoot\Utility.ps1
. $PSScriptRoot\Model.ps1
. $PSScriptRoot\Serialization.ps1
. $PSScriptRoot\Svg\Logo.ps1

function Update-BrandLogo([string] $Path, [Community] $Community, [Hashtable] $Type)
{
    $fileName = $Type.NameTemplate -replace '{CommunityName}',$Community.Name.ToLowerInvariant()
    $fileName += '.svg'
    $settings = New-SettingsFromGlyphSize -IncludeBorder $Type.IncludeBorder -IncludeBackground $Type.IncludeBackground

    New-Logo -Text $Community.Name -Settings $settings |
    Set-Content (Join-Path $Path $fileName)
}

function Update-BrandCommunity
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [Community]
        $Community,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [array]
        $Types
    )

    process
    {
        $shortName = $Community.Name -replace 'DotNet$',''
        $communityPath = Join-Path $logoPath $shortName
        Confirm-DirectoryExist -Path $communityPath

        foreach ($type in $Types)
        {
            Update-BrandLogo -Path $communityPath -Community $Community -Type $type
        }
    }
}

function Update-BrandBook([string] $Path, [Hashtable] $Config)
{
    $logopath = Join-Path $Path 'Logo'
    Confirm-DirectoryExist -Path $logoPath

    $logoTypes = @(
        @{ NameTemplate = '{CommunityName}-logo-squared'; IncludeBorder = $false; IncludeBackground = $true },
        @{ NameTemplate = '{CommunityName}-logo-squared-bordered'; IncludeBorder = $true; IncludeBackground = $true; },
        @{ NameTemplate = '{CommunityName}-logo-squared-white'; IncludeBorder = $false; IncludeBackground = $false; },
        @{ NameTemplate = '{CommunityName}-logo-squared-white-bordered'; IncludeBorder = $true; IncludeBackground = $false }
    )

    # - SVG
    # - PNG-200
    # - PNG-800
    # - PNG-5000
    # - EPS
    $logoFormats = @(
        @{ Type = 'eps' },
        @{ Type = 'png'; Width = 200; Height = 200; },
        @{ Type = 'png'; Width = 800; Height = 800; },
        @{ Type = 'png'; Width = 5000; Height = 5000; }
    )

    Read-Community -AuditDir $Config.AuditDir |
    Update-BrandCommunity -Types $logoTypes
}


$Config = @{
    RootDir = $PSScriptRoot
    ArtifactsDir = Resolve-FullPath $PSScriptRoot '..\artifacts'
    AuditDir = Resolve-FullPath $PSScriptRoot '..\..\Audit\db'
    IsOffline = $false
}
Update-BrandBook -Path 'C:\Users\akulakov\Desktop\GitHub\BrandBook' -Config $Config
