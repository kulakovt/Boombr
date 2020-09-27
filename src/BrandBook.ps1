. $PSScriptRoot\Utility.ps1
. $PSScriptRoot\Model.ps1
. $PSScriptRoot\Serialization.ps1
. $PSScriptRoot\Svg\Logo.ps1

function Format-BrandLogo
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path
    )

    process
    {
        $Inkscape = $Config.Inkscape

        $sourceFile = Get-ChildItem -Path $Path
        $directory = $sourceFile.DirectoryName
        $baseName =  $sourceFile.BaseName

        $outPath = Join-Path $directory "${baseName}-200.png"
        &$Inkscape --export-type=png --export-width=200 --export-height=200 --export-filename=$outPath $Path

        $outPath = Join-Path $directory "${baseName}-800.png"
        &$Inkscape --export-type=png --export-width=800 --export-height=800 --export-filename=$outPath $Path

        $outPath = Join-Path $directory "${baseName}.eps"
        &$Inkscape --export-type=eps --export-filename=$outPath $Path
    }
}

function Update-BrandLogo([string] $Path, [Community] $Community, [Hashtable] $Type)
{
    $fileName = $Type.NameTemplate -replace '{CommunityName}',$Community.Name.ToLowerInvariant()
    $fileName += '.svg'
    $outPath = (Join-Path $Path $fileName)

    if (Test-Path -PathType Leaf $outPath)
    {
        Write-Information "Skip existed $fileName file"
        return
    }

    Write-Information "Generate $fileName file"
    $settings = New-SettingsFromGlyphSize -IncludeBorder $Type.IncludeBorder -IncludeBackground $Type.IncludeBackground

    New-Logo -Text $Community.Name -Settings $settings |
    Set-Content $outPath

    $outPath | Format-BrandLogo
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
        [string]
        $Path
    )

    process
    {
        $shortName = $Community.Name -replace 'DotNet$',''
        $communityPath = Join-Path $Path $shortName
        Confirm-DirectoryExist -Path $communityPath

        $logoTypes = @(
            @{ NameTemplate = '{CommunityName}-logo-squared'; IncludeBorder = $false; IncludeBackground = $true },
            @{ NameTemplate = '{CommunityName}-logo-squared-bordered'; IncludeBorder = $true; IncludeBackground = $true; },
            @{ NameTemplate = '{CommunityName}-logo-squared-white'; IncludeBorder = $false; IncludeBackground = $false; },
            @{ NameTemplate = '{CommunityName}-logo-squared-white-bordered'; IncludeBorder = $true; IncludeBackground = $false }
        )

        foreach ($type in $logoTypes)
        {
            Update-BrandLogo -Path $communityPath -Community $Community -Type $type
        }
    }
}

function Update-BrandBook()
{
    $logoPath = Join-Path $Config.BrandBookDir 'Logo'
    Confirm-DirectoryExist -Path $logoPath

    Read-Community -AuditDir $Config.AuditDir |
    Update-BrandCommunity -Path $logoPath
}

