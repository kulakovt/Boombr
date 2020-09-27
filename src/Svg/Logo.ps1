. $PSScriptRoot\Svg.ps1

function New-SettingsFromGlyphSize(
    [bool] $IncludeBorder = $false,
    [bool] $IncludeBackground = $true,
    [bool] $IncludeId = $true,
    [bool] $IncludeDiagnostic = $false,
    [string] $ForegroundColor = 'white',
    [string] $BackgroundColor = '#68217a')
{
    $fontPath = Join-Path $PSScriptRoot 'ConsolasGlyphs.svg'
    $glyphSet = Get-SvgGlyphSet -Path $fontPath

    $fi = 1.618
    $columnCount = 3
    $textWidth = $glyphSet.Width * $columnCount
    $textHeight = $textWidth * $fi
    $width = $textWidth + $textHeight
    $height = $width
    $firstThird =  $width / 3
    $secondThird =  $width - $firstThird
    # Origin Thick (Vertical Letter Line Width) / Origin Glyph Width
    $thickRatio = 160.0 / 1126.0
    [int] $borderThick = $glyphSet.Width * $thickRatio
    $x = if ($IncludeBorder) { $borderThick } else { 0 }
    $y = if ($IncludeBorder) { $borderThick } else { 0 }

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
            RowCount = 3
            X = [int] ($x + $secondThird - $textWidth / 2)
            Y = [int] ($y + $height / 2 - ($textHeight  / 2))
            Width = [int] $textWidth
            Height = [int] $textHeight
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
        Diagnostic = @{
            Id = 'dg'
            Visible = $IncludeDiagnostic
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
    $rowIndex = [Math]::Floor($Position / $TextSettings.ColumnCount)
    [int] $x = $TextSettings.X + $GlyphSet.Width * $columnIndex
    $verticalSpace = ($TextSettings.Height - ($GlyphSet.Height * $TextSettings.RowCount)) / ($TextSettings.RowCount - 1)
    [int] $y = $TextSettings.Y + ($GlyphSet.Height + $verticalSpace) * $rowIndex

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
        $TextSettings
    )

    begin
    {
        $Position = -1
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
    if ($Text.Length -ne $maxLenth) { throw "Text length must be $maxLenth letters long" }

    $txAttributes = [ordered] @{
        fill = $TextSettings.Color
    }

    $Text |
    Select-Many |
    Select-TextGlyph -GlyphSet $GlyphSet -TextSettings $TextSettings |
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
    [int] $centerRadius = $thick * 5

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
        New-SvgRect -X $Settings.Text.X -Y $Settings.Text.Y -Width $Settings.Text.Width -Height $Settings.Text.Height -Attributes @{ stroke='#fbff00' }

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
    } |
    New-SvgGroup -Id $Settings.Diagnostic.Id -Attributes @{ 'fill-opacity' = 0; 'stroke-width' = $thick }
}

function New-Logo([string] $Text, [Hashtable] $Settings)
{
    if (-not $Settings)
    {
        $Settings = New-SettingsFromGlyphSize
    }

    &{
        New-Background -BackgroundSettings $Settings.Background

        New-Border -BorderSettings $Settings.Border

        New-Text -Text $Text.ToUpperInvariant() -GlyphSet $Settings.GlyphSet -TextSettings $Settings.Text

        New-Diagnostic -Settings $Settings
    } |
    New-SvgDocument -Width $Settings.Document.Width -Height $Settings.Document.Height
}

# $settings = New-SettingsFromGlyphSize -IncludeId $true -IncludeDiagnostic $true -IncludeBorder $true
# New-Logo -Text 'SpbDotNet' -Settings $settings | Set-Content (Join-Path $PSScriptRoot 'Logo.svg')
