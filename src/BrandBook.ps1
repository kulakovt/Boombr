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

function Update-BrandLogo([string] $Path, [string] $CommunityName, [Hashtable] $Type)
{
    $fileName = $Type.NameTemplate -replace '{CommunityName}',$CommunityName.ToLowerInvariant()
    $fileName += '.svg'
    $outPath = (Join-Path $Path $fileName)

    if (Test-Path -PathType Leaf $outPath)
    {
        Write-Information "Skip existed $fileName file"
        return
    }

    Write-Information "Generate $fileName file"
    $settings = New-SettingsFromGlyphSize -IncludeBorder $Type.IncludeBorder -IncludeBackground $Type.IncludeBackground

    $logoText = $CommunityName
    # HACK: for DotNet.Ru logo
    if ($CommunityName -ieq 'DotNetRu')
    {
        $logoText = 'DotNet.Ru'
    }

    New-Logo -Text $logoText -Settings $settings |
    Set-Content $outPath

    $outPath | Format-BrandLogo
}

function Update-BrandCommunity
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]
        $CommunityName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path
    )

    process
    {
        $shortName = $CommunityName -replace 'DotNet',''
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
            Update-BrandLogo -Path $communityPath -CommunityName $CommunityName -Type $type
        }
    }
}

function Update-BrandBook()
{
    $logoPath = Join-Path $Config.BrandBookDir 'Logo'
    Confirm-DirectoryExist -Path $logoPath

    Read-Community -AuditDir $Config.AuditDir |
    Select-Object -ExpandProperty 'Name' |
    Join-ToPipe -After 'DotNetRu' |
    Update-BrandCommunity -Path $logoPath
}

class Image
{
    [string] $Path
    [string] $Name
    [string] $Format
    [int] $Width
}

class ImageFamily
{
    [string] $Name
    [Image[]] $Images
    [Image] $Preview
}

class Component
{
    [string] $Name
    [string] $RootPath
    [string] $ReadMePath
    [ImageFamily[]] $Families
}

function Get-Image
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [IO.FileInfo]
        $File
    )

    process
    {
        $image = [Image]::new()
        $image.Path = $File.FullName
        $image.Name = $File.Name
        $image.Format = $File.Extension.Trim('.').ToLowerInvariant()
        $image.Width = -1
        if ($File.Name -match '.*-(?<Width>\d+)\.\w+$')
        {
            $image.Width = [int] $Matches.Width
        }
        if ($image.Format -eq 'svg')
        {
            $svg = Select-Xml -Path $image.Path -XPath '/ns:svg' -Namespace @{ ns = 'http://www.w3.org/2000/svg' }
            if ($svg -and $svg.Node.width)
            {
                $width = $svg.Node.width -replace 'px',''
                $image.Width = [int] $width
            }
        }

        $image
    }
}

function Get-FamilyName([string] $ImageName)
{
    $familyName = [IO.Path]::GetFileNameWithoutExtension($ImageName)
    if ($familyName -match '(?<BaseName>.*)-\d+$')
    {
        $familyName = $Matches.BaseName
    }

    $familyName
}

function Get-Family([string] $Path)
{
    $imageFormats = @('*.svg', '*.ai', '*.eps', '*.png')
    Get-ChildItem -Path $Path -Include $imageFormats -Recurse -File |
    Get-Image |
    Group-Object -Property { Get-FamilyName -ImageName $_.Name } |
    ForEach-Object {
        $group = $_

        $family = [ImageFamily]::new()
        $family.Name = $group.Name
        $family.Images = $group.Group
        $family.Preview = $family.Images | Where-Object { $_.Format -eq 'png' -and $_.Width -eq 200 } | Select-Object -First 1
        $family
    }
}

function Get-Component
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
        $component = [Component]::new()
        $component.Name = Split-Path -Leaf $Path
        $component.RootPath = Resolve-Path $Path
        $component.ReadMePath = Join-Path $component.RootPath 'README.md'
        $component.Families = Get-Family -Path $component.RootPath

        $component
    }
}

function Find-AllComponent([string] $Path)
{
    Get-ChildItem $Path -Directory |
    Select-Object -ExpandProperty 'FullName' |
    Get-Component
}
