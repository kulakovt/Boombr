Set-StrictMode -version Latest
$ErrorActionPreference = 'Stop'

$InformationPreference = 'Continue'
$VerbosePreference = 'SilentlyContinue'

. $PSScriptRoot\Svg.ps1

function New-SettingsFromGlyphSize()
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
    # HACK: hardcode for Glyph 113×131
    [int] $borderThick = 16
    $includeId = $true
    $includeDiagnostic = $true
    # TODO: Add border, text, and bg colors

    @{
        GlyphSet = $glyphSet
        Background = @{
            Width = [int] $width
            Height = [int] $height
            AddId = $includeId
        }
        Text = @{
            ColumnCount = $columnCount
            RowCount = 3
            X = [int] ($secondThird - $textWidth / 2)
            Y = [int] ($height / 2 - ($textHeight  / 2))
            Width = [int] $textWidth
            Height = [int] $textHeight
            AddId = $includeId
            AddGlyphId = $includeDiagnostic
        }
        Border = @{
            Visible = $true
            Thickness = $borderThick
            X = [int] ($borderThick / 2)
            Y = [int] ($borderThick / 2)
            Width = [int] ($width) - $borderThick
            Height = [int] ($height) - $borderThick
            AddId = $includeId
        }
        Diagnostic = @{
            Visible = $includeDiagnostic
        }
    }
}

function New-Background([hashtable] $BackgroundSettings)
{
    $bgAttributes = [ordered] @{
        fill = '#68217a'
    }

    if ($BackgroundSettings.AddId)
    {
        $bgAttributes.id = 'bg'
    }

    New-SvgRect -X 0 -Y 0 -Width $BackgroundSettings.Width -Height $BackgroundSettings.Height -Attributes $bgAttributes
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
        fill = 'white'
    }

    if ($TextSettings.AddId)
    {
        $txAttributes.id = 'tx'
    }

    $Text |
    Select-Many |
    Select-TextGlyph -GlyphSet $GlyphSet -TextSettings $TextSettings |
    ForEach-Object { $_.ToPath($TextSettings.AddGlyphId) } |
    New-SvgGroup -Attributes $txAttributes
}

function New-Border([Hashtable] $BorderSettings)
{
    if (-not $BorderSettings.Visible)
    {
        return
    }

    $brAttributes = [ordered] @{
        stroke = 'white'
        'stroke-width' = $BorderSettings.Thickness
        'fill-opacity' = '0'
    }

    if ($BorderSettings.AddId)
    {
        $brAttributes.id = 'br'
    }

    New-SvgRect -X $BorderSettings.X -Y $BorderSettings.Y -Width $BorderSettings.Width -Height $BorderSettings.Height -Attributes $brAttributes
}

function New-Diagnostic([hashtable] $Settings)
{
    if (-not $Settings.Diagnostic.Visible)
    {
        return
    }

    &{
        New-SvgComment -Message 'Rule of thirds'
        [int] $width = $Settings.Background.Width
        [int] $h13 =  $width / 3
        [int] $h23 =  $width - $h13
        [int] $height = $Settings.Background.Height
        [int] $v13 =  $height / 3
        [int] $v23 =  $height - $v13
        @(
            @($h13, 0, $h13, $height),
            @($h23, 0, $h23, $height),
            @(0, $v13, $width, $v13),
            @(0, $v23, $width, $v23)
        ) |
        ForEach-Object {
            New-SvgLine -X1 $_[0] -Y1 $_[1] -X2 $_[2] -Y2 $_[3] -Attributes @{ stroke='lime' }
        }

        New-SvgComment -Message 'Golden rectangle'
        New-SvgRect -X $Settings.Text.X -Y $Settings.Text.Y -Width $Settings.Text.Width -Height $Settings.Text.Height -Attributes @{ stroke='#fbff00' }

        New-SvgComment -Message 'Social circle'
        [int] $centerX = $width / 2
        [int] $centerY = $height / 2
        [int] $radius = [Math]::Min($width, $height) / 2
        New-SvgCircle -X $centerX -Y $centerY -Radius $radius -Attributes @{ stroke = 'coral'; 'stroke-dasharray' = 10 }

        New-SvgComment -Message 'Centers'
        $centerAttributes = [Ordered] @{ fill = 'red'; 'fill-opacity' = 1 }
        New-SvgCircle -X $centerX -Y $centerY -Radius 10 -Attributes $centerAttributes
        [int] $halfRectX = $Settings.Text.X + $Settings.Text.Width / 2
        New-SvgCircle -X $halfRectX -Y $Settings.Text.Y -Radius 10 -Attributes $centerAttributes
        New-SvgCircle -X $halfRectX -Y ($Settings.Text.Y + $Settings.Text.Height) -Radius 10 -Attributes $centerAttributes
    } |
    New-SvgGroup -Attributes @{ id = 'diag'; 'fill-opacity' = 0; 'stroke-width' = 2 }
}

function New-Logo([string] $Text)
{
    $settings = New-SettingsFromGlyphSize
    &{
        New-Background -BackgroundSettings $settings.Background

        New-Border -BorderSettings $settings.Border

        New-Text -Text $Text.ToUpperInvariant() -GlyphSet $settings.GlyphSet -TextSettings $settings.Text

        New-Diagnostic -Settings $settings
    } |
    New-SvgDocument -Width $settings.Background.Width -Height $settings.Background.Height
}

New-Logo -Text 'SpbDotNet' | Set-Content (Join-Path $PSScriptRoot 'Logo.svg')
