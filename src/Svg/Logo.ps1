. $PSScriptRoot\Svg.ps1
. $PSScriptRoot\Logo.Radio.ps1

function New-SettingsFromGlyphSize(
    [bool] $IncludeBorder = $false,
    [bool] $IncludeBackground = $true,
    [bool] $IncludeId = $true,
    [bool] $IncludeDiagnostic = $false,
    [string] $ForegroundColor = '#fff',
    [string] $BackgroundColor = '#68217a')
{
    $fontPath = Join-Path $PSScriptRoot 'ConsolasGlyphs.svg'
    $glyphSet = Get-SvgGlyphSet -Path $fontPath

    $fi = 1.618
    $columnCount = 3
    $rowCount = 3
    $textWidth = $glyphSet.Width * $columnCount
    $textHeight = $textWidth * $fi
    $textSpace = ($textHeight - ($glyphSet.Height * $rowCount)) / ($rowCount - 1)
    $width = $textWidth + $textHeight
    $height = $width
    $firstThird =  $width / 3
    $secondThird =  $width - $firstThird
    # Origin Thick (Vertical Letter Line Width) / Origin Glyph Width
    $thickRatio = 160.0 / 1126.0
    [int] $borderThick = $glyphSet.Width * $thickRatio

    $x = 0
    $y = 0
    $docWidth = $width
    $docHeight = $height

    if ($IncludeBorder)
    {
        $x = $borderThick
        $y = $borderThick
        $docWidth = $width + $borderThick * 2
        $docHeight = $height + $borderThick * 2
    }

    $textY = $y + $height / 2 - ($textHeight  / 2)
    $slot1Width = $textWidth / $fi
    $slot1Y = $textY + $glyphSet.Height + $textSpace

    @{
        GlyphSet = $glyphSet
        Document = @{
            Width = [int] $docWidth
            Height = [int] $docHeight
        }
        Background = @{
            Id = if ($IncludeId) { 'bg' } else { $null }
            Visible = $IncludeBackground
            X = [int] $x
            Y = [int] $y
            Width = [int] $width
            Height = [int] $height
            Color = $BackgroundColor
        }
        Text = @{
            Id = if ($IncludeId) { 'tx' } else { $null }
            ColumnCount = $columnCount
            RowCount = $rowCount
            X = [int] ($x + $secondThird - $textWidth / 2)
            Y = [int] $textY
            Width = [int] $textWidth
            Height = [int] $textHeight
            VerticalSpace = [int] $textSpace
            AddGlyphId = $IncludeDiagnostic
            Color = $ForegroundColor
        }
        Border = @{
            Id = if ($IncludeId) { 'br' } else { $null }
            Visible = $IncludeBorder
            Thickness = $borderThick
            X = [int] ($borderThick / 2)
            Y = [int] ($borderThick / 2)
            Width = [int] ($docWidth) - $borderThick
            Height = [int] ($docHeight) - $borderThick
            Color = $ForegroundColor
        }
        Slot1 = @{
            X = $x + $firstThird - $slot1Width / 2
            Y = $slot1Y
            Width = [int] $slot1Width
            Height = [int] ($slot1Width * $fi)
        }
        Diagnostic = @{
            Id = 'dg'
            Visible = $IncludeDiagnostic
            Slot1Visible = $false
        }
    }
}

function New-Background([hashtable] $BackgroundSettings)
{
    if (-not $BackgroundSettings.Visible)
    {
        return
    }

    $bgAttributes = [ordered] @{
        fill = $BackgroundSettings.Color
    }

    New-SvgRect -Id $BackgroundSettings.Id -X $BackgroundSettings.X -Y $BackgroundSettings.Y -Width $BackgroundSettings.Width -Height $BackgroundSettings.Height -Attributes $bgAttributes
}

function New-TextGlyph([SvgGlyph] $Glyph, [int] $Position, [hashtable] $GlyphSet, [Hashtable] $TextSettings)
{
    $columnIndex = $Position % $TextSettings.RowCount
    $rowIndex = [Math]::Floor([Math]::Abs($Position) / $TextSettings.ColumnCount)
    [int] $x = $TextSettings.X + $GlyphSet.Width * $columnIndex
    [int] $y = $TextSettings.Y + ($GlyphSet.Height + $TextSettings.VerticalSpace) * $rowIndex

    # HACK: for DotNet.Ru logo
    if ((($Position -eq 6) -and ($Glyph.Unicode -eq '.')) -or
        (($Position -eq 7) -and ($Glyph.Unicode -eq 'R')) -or
        (($Position -eq 8) -and ($Glyph.Unicode -eq 'U')))
    {
        # BUG: It works only for glyph size 113×131
        # «-38.7» — is the third number from glyph «T»
        $factor = if ($Glyph.Unicode -eq '.') { 0.5 } else { 1.0 }
        $x -= 38.7 * $factor
    }

    $Glyph.Move($x, $y)
}

function Select-TextGlyph
{
    [CmdletBinding()]
    [OutputType([SvgGlyph])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]
        $Letter,

        [Parameter(Mandatory)]
        [hashtable]
        $GlyphSet,

        [Parameter(Mandatory)]
        [Hashtable]
        $TextSettings,

        [Parameter()]
        [int]
        $StartPosition = -1
    )

    begin
    {
        $Position = $StartPosition
    }
    process
    {
        $Position++

        $glyph = $GlyphSet.Glyphs | Where-Object { $_.Unicode -eq $Letter }
        if (-not $glyph) { throw "Can't find glyph for «$letter»" }

        New-TextGlyph -Glyph $glyph -Position $Position -GlyphSet $GlyphSet -TextSettings $TextSettings
    }
}

function New-Text([string] $Text, [hashtable] $GlyphSet, [Hashtable] $TextSettings)
{
    $maxLenth = $TextSettings.ColumnCount * $TextSettings.RowCount
    $hackMaxLength = 11
    if (($Text.Length -lt $maxLenth) -or ($Text.Length -gt $hackMaxLength))
    {
        throw "Text length must be minimum $maxLenth letters long and meximun $hackMaxLength"
    }
    $startPosition = -1
    if ($Text.Length -gt $maxLenth)
    {
        $startPosition = $maxLenth - $Text.Length - 1
    }

    $txAttributes = [ordered] @{
        fill = $TextSettings.Color
    }

    $Text |
    Select-Many |
    Select-TextGlyph -GlyphSet $GlyphSet -TextSettings $TextSettings -StartPosition $startPosition |
    ForEach-Object { $_.ToPath($TextSettings.AddGlyphId) } |
    New-SvgGroup -Id $TextSettings.Id -Attributes $txAttributes
}

function New-Border([Hashtable] $BorderSettings)
{
    if (-not $BorderSettings.Visible)
    {
        return
    }

    $brAttributes = [ordered] @{
        stroke = $BorderSettings.Color
        'stroke-width' = $BorderSettings.Thickness
        'fill-opacity' = 0
    }

    New-SvgRect -Id $BorderSettings.Id -X $BorderSettings.X -Y $BorderSettings.Y -Width $BorderSettings.Width -Height $BorderSettings.Height -Attributes $brAttributes
}

function New-Diagnostic([hashtable] $Settings)
{
    if (-not $Settings.Diagnostic.Visible)
    {
        return
    }

    # Origin Thick / Origin Glyph Width
    $thickRatio = 20.0 / 1126.0
    [int] $thick = $Settings.GlyphSet.Width * $thickRatio
    [int] $thickDash = $thick * 5
    [int] $centerRadius = $thick * 4

    &{
        New-SvgComment -Message 'Rule of thirds'
        $x = $Settings.Background.X
        $y = $Settings.Background.Y
        [int] $width = $Settings.Background.Width
        [int] $h13 =  $width / 3
        [int] $h23 =  $width - $h13
        [int] $height = $Settings.Background.Height
        [int] $v13 =  $height / 3
        [int] $v23 =  $height - $v13
        @(
            @(($x + $h13), $y, ($x + $h13), ($y + $height)),
            @(($x + $h23), $y, ($x + $h23), ($y + $height)),
            @($x, ($y + $v13), ($x + $width), ($y + $v13)),
            @($x, ($y + $v23), ($x + $width), ($y + $v23))
        ) |
        ForEach-Object {
            New-SvgLine -X1 $_[0] -Y1 $_[1] -X2 $_[2] -Y2 $_[3] -Attributes @{ stroke='lime' }
        }

        New-SvgComment -Message 'Golden rectangle'
        $rectAttributes = [Ordered] @{ stroke='#fbff00' }
        New-SvgRect -X $Settings.Text.X -Y $Settings.Text.Y -Width $Settings.Text.Width -Height $Settings.Text.Height -Attributes $rectAttributes
        if ($Settings.Diagnostic.Slot1Visible)
        {
            New-SvgRect -X $Settings.Slot1.X -Y $Settings.Slot1.Y -Width $Settings.Slot1.Width -Height $Settings.Slot1.Height -Attributes $rectAttributes
        }

        New-SvgComment -Message 'Social circle'
        [int] $centerX = $x + $width / 2
        [int] $centerY = $y + $height / 2
        [int] $radius = [Math]::Min($width, $height) / 2
        New-SvgCircle -X $centerX -Y $centerY -Radius $radius -Attributes @{ stroke = 'coral'; 'stroke-dasharray' = $thickDash }

        New-SvgComment -Message 'Centers'
        $centerAttributes = [Ordered] @{ fill = 'red'; 'fill-opacity' = 1 }
        New-SvgCircle -X $centerX -Y $centerY -Radius $centerRadius -Attributes $centerAttributes
        [int] $halfRectX = $Settings.Text.X + $Settings.Text.Width / 2
        New-SvgCircle -X $halfRectX -Y $Settings.Text.Y -Radius $centerRadius -Attributes $centerAttributes
        New-SvgCircle -X $halfRectX -Y ($Settings.Text.Y + $Settings.Text.Height) -Radius $centerRadius -Attributes $centerAttributes

        if ($Settings.Diagnostic.Slot1Visible)
        {
            [int] $halfRect1X = $Settings.Slot1.X + $Settings.Slot1.Width / 2
            New-SvgCircle -X $halfRect1X -Y $Settings.Slot1.Y -Radius $centerRadius -Attributes $centerAttributes
            New-SvgCircle -X $halfRect1X -Y ($Settings.Slot1.Y + $Settings.Slot1.Height) -Radius $centerRadius -Attributes $centerAttributes
        }
    } |
    New-SvgGroup -Id $Settings.Diagnostic.Id -Attributes @{ 'fill-opacity' = 0; 'stroke-width' = $thick }
}

function New-RadioLogo([Hashtable] $Settings)
{
    $Settings.Diagnostic.Slot1Visible = $true
    $includeId = if ($Settings.Text.Id) { $true } else { $false }
    $firstId = if ($includeId) { 'wl' } else { $null }
    $secondId = if ($includeId) { 'wr' } else { $null }

    $drawWave = {
        New-SvgWave `
            -X $Settings.Slot1.X `
            -Y $Settings.Slot1.Y `
            -Width $Settings.Slot1.Width `
            -Height $Settings.Slot1.Height `
            -FirstId $firstId `
            -SecondId $secondId
    }

    New-Logo -Text 'RadioDotNet' -Settings $settings -Enricher $drawWave
}

function New-Logo([string] $Text, [Hashtable] $Settings, [ScriptBlock] $Enricher = {})
{
    if (-not $Settings)
    {
        $Settings = New-SettingsFromGlyphSize
    }

    &{
        New-Background -BackgroundSettings $Settings.Background

        New-Border -BorderSettings $Settings.Border

        New-Text -Text $Text.ToUpperInvariant() -GlyphSet $Settings.GlyphSet -TextSettings $Settings.Text

        & $Enricher

        New-Diagnostic -Settings $Settings
    } |
    New-SvgDocument -Width $Settings.Document.Width -Height $Settings.Document.Height
}

# $settings = New-SettingsFromGlyphSize -IncludeId $true -IncludeDiagnostic $true -IncludeBorder $true
# New-Logo -Text 'SpbDotNet' -Settings $settings | Set-Content (Join-Path $PSScriptRoot 'Logo.svg')
# New-RadioLogo -Settings $settings | Set-Content (Join-Path $PSScriptRoot 'Logo.svg')
