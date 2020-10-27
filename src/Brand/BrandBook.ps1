. $PSScriptRoot\..\Utility.ps1
. $PSScriptRoot\..\Model.ps1
. $PSScriptRoot\..\Serialization.ps1
. $PSScriptRoot\..\Svg\Logo.ps1

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

        Update-BrandReadMe -Path $communityPath -Community $Community
    }
}

function Update-BrandBook()
{
    $logoPath = Join-Path $Config.BrandBookDir 'Logo'
    $artPath = Join-Path $Config.BrandBookDir 'Art'
    Confirm-DirectoryExist -Path $logoPath

    $dotNetRu = @{
        Name = 'DotNetRu'
        Title = 'DotNetRu'
        City = $null
        ShortName = 'Ru'
        Site = [Uri] 'https://dotnet.ru/'
        Description = 'Объединение независимых русскоязычных .NET сообществ'
    }

    $communities = Read-Community -AuditDir $Config.AuditDir -Sorted |
    ForEach-Object {

        $shortName = $_.Name -replace 'DotNet',''
        @{
            Name = $_.Name
            Title = "Сообщество $($_.Name)"
            City = $_.City
            ShortName = $shortName
            # TODO: Add Site to Audit (DotNetRu/Audit#199)
            Site = [Uri] ('https://{0}.dotnet.ru/' -f $shortName.ToLowerInvariant())
            Description = "Независимое сообщество .NET разработчиков из города $($_.City)"
        }
    } |
    Join-ToPipe -Before $dotNetRu |
    Update-BrandCommunity -Path $logoPath

    Get-ChildItem $artPath -Directory |
    ForEach-Object {
        Update-ArtReadMe -Path $_.FullName
    }

    Update-PodcastsReadMe -Path $logoPath
}

class Image
{
    static [array] $Orderer = @(
        @{ Expression = { @('png', 'svg').IndexOf($_.Format) }; Descending = $true }
        @{ Expression = 'Format'; Ascending = $true }
        @{ Expression = 'Width'; Ascending = $true }
    )

    static $IsPreview = { $_.Format -eq 'png' -and $_.Width -eq 200 }

    [string] $Name
    [string] $LocalPath
    [string] $RemotePath
    [string] $DownloadPath
    [string] $Format
    [int] $Width
}

class ImageFamily
{
    [string] $Name
    [string] $Title
    [Image[]] $Images
    [Image] $Preview
    [string[]] $Tags
    [string] $Description
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

        $image.Name = $image.Format.ToUpperInvariant()
        if (($image.Format -eq 'png') -and ($image.Width -ge 0))
        {
            $image.Name += '×' + $image.Width
        }

        $image
    }
}

function Get-FamilyName([string] $ImagePath)
{
    $familyName = [IO.Path]::GetFileNameWithoutExtension($ImagePath)
    if ($familyName -match '(?<BaseName>.*)-\d+$')
    {
        $familyName = $Matches.BaseName
    }

    $familyName
}

function Get-FamilyTag([string] $Name)
{
    @('white', 'bordered') |
    ForEach-Object {
        $tag = $_
        if ($Name -match "\b$tag\b")
        {
            $tag
        }
    }
}

function Get-FamilyOrderer()
{
    @(
        @{ Expression = {
            $Family = [ImageFamily] $_
            $rank = 0
            $rank += ($Family.Tags | Where-Object { $_ -ne 'bordered' } | Measure-Object | Select-Object -ExpandProperty Count) * 10
            $rank += ($Family.Tags | Where-Object { $_ -eq 'bordered' } | Measure-Object | Select-Object -ExpandProperty Count) * 05
            $rank
        }; Ascending = $true }
        @{ Expression = 'Name'; Ascending = $true }
    )
}

function Expand-LogoFamilyDisplayInfo()
{
    process
    {
        $family = [ImageFamily] $_
        $display = switch -Wildcard ($family.Name)
        {
            '*-logo-squared' { @('Квадрат', 'На светлом фоне используйте логотип без рамки. Подходит для создания круглых миниатюр в соц. сетях.') }
            '*-logo-squared-bordered' { @('Квадрат с рамкой', 'На тёмном фоне используйте логотип с рамкой.') }
            '*-logo-squared-white' { @('Квадрат на прозрачном фоне', 'На тёмном цветном фоне используйте прозрачный логотип.') }
            '*-logo-squared-white-bordered' { @('Квадрат на прозрачном фоне с рамкой', 'На тёмном цветном фоне используйте прозрачный логотип с рамкой.') }
            default { @('', '') }
        }

        $family.Title = $display[0]
        $family.Description = $display[1]
        $family
    }
}

function Get-Family([string] $Path)
{
    $imageFormats = @('*.svg', '*.ai', '*.eps', '*.png')

    Get-ChildItem -Path $Path -Include $imageFormats -Recurse -File |
    Get-Image |
    Group-Object -Property { Get-FamilyName -ImagePath $_.LocalPath } |
    ForEach-Object {
        $group = $_

        $family = [ImageFamily]::new()
        $family.Name = $group.Name
        $family.Title = $group.Name
        $family.Images = $group.Group | Sort-Object ([Image]::Orderer)
        $family.Preview = $family.Images | Where-Object ([Image]::IsPreview) | Select-Single -ElementNames 'image preview'
        $family.Tags = Get-FamilyTag -Name $group.Name
        $family
    } |
    Sort-Object (Get-FamilyOrderer)
}

function Format-DownloadSection([Image[]] $Images)
{
    $Images |
    ForEach-Object {
        "[$($_.Name)]($($_.DownloadPath))"
    } |
    Join-ToString -Delimeter ', '
}

function Format-Family
{
    process
    {
        $family = [ImageFamily] $_
        $previewLink = Split-Path -Leaf $family.Preview.RemotePath

"#### $($family.Title)"
''
        if ($family.Description)
        {
            $($family.Description)
            ''
        }
'|       |'
'| :---: |'
'|       |'
"| ![$($family.Title)]($previewLink) |"
"| Скачать: $(Format-DownloadSection($family.Images)) |"
''
    }
}

function Expand-CommunityComponent
{
    [CmdletBinding()]
    [OutputType([Hashtable])]
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
        @('Name', 'Title', 'City', 'Site', 'Description') |
        ForEach-Object {
            $key = $_
            if (-not $Community.ContainsKey($key))
            {
                throw "Property $key not found in Community object"
            }
        }

        $Community.HashTag = '#{0}' -f $Community.Name.ToLowerInvariant()
        $Community.Logos = Get-Family -Path $Path | Expand-LogoFamilyDisplayInfo
        $Community
    }
}

function Expand-ArtComponent
{
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path
    )

    process
    {
        $art = @{}
        $art.Title = Split-Path -Leaf $Path
        $art.Pictures = Get-Family -Path $Path
        $art
    }
}

function Update-BrandReadMe([string] $Path, [Hashtable] $Community)
{
    $readMePath = Join-Path $Path 'README.md'
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUserDeclaredVarsMoreThanAssignments', '', Scope='Function', Target='Model')]
    $Model = Expand-CommunityComponent -Path $Path -Community $Community
    . $PSScriptRoot\BrandBook.Logo.ps1 |
    Out-File -FilePath $readMePath -Encoding UTF8
}

function Update-ArtReadMe([string] $Path)
{
    $readMePath = Join-Path $Path 'README.md'
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUserDeclaredVarsMoreThanAssignments', '', Scope='Function', Target='Model')]
    $Model = Expand-ArtComponent -Path $Path
    . $PSScriptRoot\BrandBook.Art.ps1 |
    Out-File -FilePath $readMePath -Encoding UTF8
}

function Update-PodcastsReadMe([string] $Path)
{
    $radioPath = Join-Path $Path 'Radio'
    $radio = @{
        Title = 'RadioDotNet'
        Description = 'Разговоры на тему .NET во всех его проявлениях, новости, статьи, библиотеки, конференции, личности и прочее интересное из мира IT'
        Site = [Uri] 'https://radio.dotnet.ru/'
        HashTag = '#radiodotnet'
        RootPath = $radioPath
    }

    $morePath = Join-Path $Path 'More'
    $more = @{
        Title = 'DotNet & More'
        Description = 'Подкаст о DotNet разработке и не только'
        Site = [Uri] 'https://dotnetmore.ru/'
        HashTag = '#dotnetmore'
        RootPath = $morePath
    }

    @($radio, $more) |
    ForEach-Object {

        $Model = $_
        $Model.Logos = Get-Family -Path $Model.RootPath | Expand-LogoFamilyDisplayInfo
        $readMePath = Join-Path $Model.RootPath 'README.md'
        . $PSScriptRoot\BrandBook.Podcast.ps1 |
        Out-File -FilePath $readMePath -Encoding UTF8
    }
}

    # TODO:
    # - More README:
    #   /Logo
    #   /Art
    #   /README.md
