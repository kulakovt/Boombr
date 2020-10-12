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

    Write-Information "Generate $fileName"
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
        [Hashtable]
        $Community,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path
    )

    process
    {
        $communityName = $Community.Name
        $shortName = $Community.ShortName
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
            Update-BrandLogo -Path $communityPath -CommunityName $communityName -Type $type
        }

        Update-BrandReeadMe -Path $communityPath -Community $Community
    }
}

function Update-BrandBook()
{
    $logoPath = Join-Path $Config.BrandBookDir 'Logo'
    Confirm-DirectoryExist -Path $logoPath

    $dotNetRu = @{
        Name = 'DotNetRu'
        City = $null
        ShortName = 'Ru'
        Site = [Uri] 'https://dotnet.ru/'
    }

    Read-Community -AuditDir $Config.AuditDir |
    ForEach-Object {

        $shortName = $_.Name -replace 'DotNet',''
        @{
            Name = $_.Name
            City = $_.City
            ShortName = $shortName
            # TODO: Add Site to Audit (DotNetRu/Audit#199)
            Site = [Uri] ('https://{0}.dotnet.ru/' -f $shortName.ToLowerInvariant())
        }
    } |
    Join-ToPipe -After $dotNetRu |
    Update-BrandCommunity -Path $logoPath
}

class Image
{
    static [array] $Orderer = @(
        @{ Expression = { @('png', 'svg').IndexOf($_.Format) }; Descending = $true }
        @{ Expression = 'Format'; Ascending = $true }
        @{ Expression = 'Width'; Ascending = $true }
    )

    static $IsPreview = { $_.Format -eq 'png' -and $_.Width -eq 200 }

    [string] $LocalPath
    [string] $RemotePath
    [string] $DownloadPath
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

class CommunityComponent
{
    [string] $Name
    [string] $City
    [Uri] $Site
    [string] $HashTag
    [ImageFamily[]] $Logos
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
        $image.LocalPath = $File.FullName
        $image.RemotePath = $File | Get-GitRemotePath
        $image.DownloadPath = $File | Get-GitRemotePath -UserContent

        $image.Format = $File.Extension.Trim('.').ToLowerInvariant()
        $image.Width = -1
        if ($File.Name -match '.*-(?<Width>\d+)\.\w+$')
        {
            $image.Width = [int] $Matches.Width
        }
        if ($image.Format -eq 'svg')
        {
            $svg = Select-Xml -Path $image.LocalPath -XPath '/ns:svg' -Namespace @{ ns = 'http://www.w3.org/2000/svg' }
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
        $family.Images = $group.Group | Sort-Object ([Image]::Orderer)
        $family.Preview = $family.Images | Where-Object ([Image]::IsPreview) | Select-Single -ElementNames 'image preview'
        $family
    }
}

function Get-CommunityComponent
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Hashtable]
        $Community
    )

    process
    {
        $component = [CommunityComponent]::new()
        $component.Name = $Community.Name
        $component.City = $Community.City
        $component.Site = $Community.Site
        $component.HashTag = '#{0}' -f $Community.Name.ToLowerInvariant()
        $component.Logos = Get-Family -Path $Path
        $component
    }
}

function Update-BrandReeadMe([string] $Path, [Hashtable] $Community)
{
    $readMePath = Join-Path $Path 'README.md'
    $Model = Get-CommunityComponent -Path $Path -Community $Community
    . $PSScriptRoot\BrandBook.Logo.ps1 |
    Out-File -FilePath $readMePath -Encoding UTF8
}
