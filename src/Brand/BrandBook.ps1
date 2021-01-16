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

    Write-Information "Generate $fileName"
    $settings = New-SettingsFromGlyphSize @Type

    $logoText = $CommunityName
    # HACK: for DotNet.Ru logo
    if ($CommunityName -ieq 'DotNetRu')
    {
        $logoText = 'DotNet.Ru'
    }

    if ($CommunityName -ieq 'RadioDotNet')
    {
        $logoContent = New-RadioLogo -Settings $settings
    }
    else
    {
        $logoContent = New-Logo -Text $logoText -Settings $settings
    }

    $logoContent | Set-Content $outPath
    $outPath | Format-BrandLogo
}

function Update-BrandCommunity
{
    [CmdletBinding()]
    [OutputType([Hashtable])]
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
            @{ NameTemplate = '{CommunityName}-logo-squared-white-bordered'; IncludeBorder = $true; IncludeBackground = $false },
            @{ NameTemplate = '{CommunityName}-logo-squared-black'; IncludeBorder = $false; IncludeBackground = $true; BackgroundColor = '#1e1e1e' },
            @{ NameTemplate = '{CommunityName}-logo-squared-green'; IncludeBorder = $false; IncludeBackground = $true; BackgroundColor = '#329932' }
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

    $radio = @{
        Name = 'RadioDotNet'
        Title = 'Подкаст RadioDotNet'
        City = $null
        ShortName = 'Radio'
        Site = [Uri] 'https://radio.dotnet.ru/'
        Description = 'Разговоры на тему .NET во всех его проявлениях, новости, статьи, библиотеки, конференции, личности и прочее интересное из мира IT'
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
    Join-ToPipe -After $radio |
    Update-BrandCommunity -Path $logoPath

    $arts = Get-ChildItem $artPath -Directory |
    ForEach-Object {
        Update-ArtReadMe -Path $_.FullName
    } |
    Sort-Object -Property { $_.'Title' }

    $podcasts = Update-PodcastsCommunity -Path $logoPath

    $all = @{
        Communities = $communities | Where-Object { $_.Title -notlike 'Подкаст *'}
        Arts = $arts
        Podcasts = $podcasts | Join-ToPipe -Before ($communities | Where-Object { $_.Title -like 'Подкаст *'})
    }

    Update-MainReadMe -Path $Config.BrandBookDir -LogoPath $logoPath -Data $all
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

            if ($svg)
            {
                if ($svg.Node.HasAttribute('width'))
                {
                    $width = $svg.Node.width -replace 'px',''
                    $image.Width = [int] $width
                }
                elseif ($svg.Node.HasAttribute('viewBox') -and ($svg.Node.viewBox -match '\d+ \d+ (?<Width>\d+) \d+'))
                {
                    $image.Width = [int] $Matches.Width
                }
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
    @('white', 'bordered', 'black', 'green') |
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
            $tags = $Family.Tags
            $types = @('white', 'black', 'green')

            $rank = $tags | ForEach-Object { $types.IndexOf($_) + 1 } | Measure-Object -Sum | Select-Object -ExpandProperty Sum
            $rank *= 10
            $rank += $tags | Where-Object { $_ -eq 'bordered' } | Measure-Object | Select-Object -ExpandProperty Count

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
            '*-logo-squared-black' { @('Чёрный квадрат', 'Используйте для организационного направления.') }
            '*-logo-squared-green' { @('Зелёный квадрат', 'Используйте для образовательного направления.') }
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
        $Community.Path = $Path
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
        $art.Path = $Path
        $art
    }
}

function Expand-MainComponent
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
        $Data
    )

    begin
    {
        Push-Location
    }
    process
    {
        Set-Location -Path $Path

        $components = $Data.Communities |
        Join-ToPipe -After $Data.Arts |
        Join-ToPipe -After $Data.Podcasts

        foreach ($component in $components)
        {
            $relativePath = Resolve-Path -Path $component.Path -Relative
            $component.Link = $relativePath.TrimStart('.').TrimStart('\').Replace('\', '/')
        }

        $Data
    }
    end
    {
        Pop-Location
    }
}

function Update-BrandReadMe([string] $Path, [Hashtable] $Community)
{
    $readMePath = Join-Path $Path 'README.md'
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUserDeclaredVarsMoreThanAssignments', '', Scope='Function', Target='Model')]
    $Model = Expand-CommunityComponent -Path $Path -Community $Community
    . $PSScriptRoot\BrandBook.Logo.ps1 |
    Out-File -FilePath $readMePath -Encoding UTF8

    $Model
}

function Update-ArtReadMe([string] $Path)
{
    $readMePath = Join-Path $Path 'README.md'
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUserDeclaredVarsMoreThanAssignments', '', Scope='Function', Target='Model')]
    $Model = Expand-ArtComponent -Path $Path
    . $PSScriptRoot\BrandBook.Art.ps1 |
    Out-File -FilePath $readMePath -Encoding UTF8

    $Model
}

function Update-PodcastsCommunity([string] $Path)
{
    $more = @{
        Name = 'DotNetMore'
        Title = 'Подкаст DotNet & More'
        City = $null
        ShortName = 'More'
        Site = [Uri] 'https://more.dotnet.ru/'
        Description = 'Подкаст о DotNet разработке и не только'
    }

    @($more) |
    ForEach-Object {

        $community = $_
        $shortName = $community.ShortName
        $communityPath = Join-Path $Path $shortName
        Confirm-DirectoryExist -Path $communityPath

        Update-BrandReadMe -Path $communityPath -Community $community
    }
}

function Update-MainReadMe([string] $Path, [string] $LogoPath, [Hashtable] $Data)
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUserDeclaredVarsMoreThanAssignments', '', Scope='Function', Target='Model')]
    $Model = $Path | Expand-MainComponent -Data $Data

    # $readMePath = Join-Path $LogoPath 'README.md'
    # . $PSScriptRoot\BrandBook.LogoMain.ps1 |
    # Out-File -FilePath $readMePath -Encoding UTF8

    $readMePath = Join-Path $Path 'README.md'
    . $PSScriptRoot\BrandBook.Main.ps1 |
    Out-File -FilePath $readMePath -Encoding UTF8
}
