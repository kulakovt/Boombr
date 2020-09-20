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
    $rectWidth = $glyphSet.Width * $columnCount
    $rectHeight = $rectWidth * $fi
    $squareSize = $rectWidth + $rectHeight
    $firstThird =  $squareSize / 3
    $secondThird =  $squareSize - $firstThird
    # HACK: hardcode for Glyph 113×131
    [int] $borderThick = 16

    @{
        GlyphSet = $glyphSet
        # TODO: Rename to Background
        Square = @{
            # TODO: Split to Width separate demensions
            Size = [int] $squareSize
            Center = [int] ($squareSize / 2)
        }
        # TODO: Rename to Text
        Rect = @{
            # TODO: Remove Counts (non-configurable options)
            ColumnCount = $columnCount
            RowCount = 3
            X = [int] ($secondThird - $rectWidth / 2)
            Y = [int] ($squareSize / 2 - ($rectHeight  / 2))
            # TODO: Check customization
            Width = [int] $rectWidth
            Height = [int] $rectHeight
        }
        Border = @{
            Visible = $true
            Thickness = $borderThick
            X = [int] ($borderThick / 2)
            Y = [int] ($borderThick / 2)
            Width = [int] ($squareSize) - $borderThick
            Height = [int] ($squareSize) - $borderThick
        }
        Diagnostic = @{
            Visible = $true
        }
    }
}

# TODO: Remove static dependency
$Settings = New-SettingsFromGlyphSize

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

function New-Text([string] $Text)
{
    $maxLenth = $Settings.Rect.ColumnCount * $Settings.Rect.RowCount
    if ($Text.Length -ne $maxLenth) { throw "Text length must be $maxLenth letters long" }

    $Text |
    Select-Many |
    Select-TextGlyph -GlyphSet $Settings.GlyphSet -TextSettings $Settings.Rect |
    ForEach-Object { $_.ToPath() } |
    New-SvgGroup -Attributes @{ fill = 'white' }
}

function New-Border()
{
    if (-not $Settings.Border.Visible)
    {
        return
    }

    $borderAttributes = [Ordered] @{
        stroke = 'white'
        'stroke-width' = $Settings.Border.Thickness
        'fill-opacity' = '0'
    }
    New-SvgRect -X $Settings.Border.X -Y $Settings.Border.Y -Width $Settings.Border.Width -Height $Settings.Border.Height -Attributes $borderAttributes
}

function New-Diagnostic()
{
    if (-not $Settings.Diagnostic.Visible)
    {
        return
    }

    &{
        New-SvgComment -Message 'Rule of thirds'
        [int] $firstThird =  $Settings.Square.Size / 3
        [int] $secondThird =  $Settings.Square.Size - $firstThird
        [int] $size = $Settings.Square.Size
        @(
            @(0, $firstThird, $size, $firstThird),
            @(0, $secondThird, $size, $secondThird),
            @($firstThird, 0, $firstThird, $size),
            @($secondThird, 0, $secondThird, $size)
        ) |
        ForEach-Object {
            New-SvgLine -X1 $_[0] -Y1 $_[1] -X2 $_[2] -Y2 $_[3] -Attributes @{ stroke='lime' }
        }

        New-SvgComment -Message 'Golden rectangle'
        New-SvgRect -X $Settings.Rect.X -Y $Settings.Rect.Y -Width $Settings.Rect.Width -Height $Settings.Rect.Height -Attributes @{ stroke='#fbff00' }

        New-SvgComment -Message 'Social circle'
        $center = $Settings.Square.Center
        New-SvgCircle -X $center -Y $center -Radius ($Settings.Square.Size / 2) -Attributes @{ stroke = 'coral'; 'stroke-dasharray' = 10 }

        New-SvgComment -Message 'Centers'
        $centerAttributes = [Ordered] @{ fill = 'red'; 'fill-opacity' = 1 }
        New-SvgCircle -X $center -Y $center -Radius 10 -Attributes $centerAttributes
        [int] $halfRectX = $Settings.Rect.X + $Settings.Rect.Width / 2
        New-SvgCircle -X $halfRectX -Y $Settings.Rect.Y -Radius 10 -Attributes $centerAttributes
        New-SvgCircle -X $halfRectX -Y ($Settings.Rect.Y + $Settings.Rect.Height) -Radius 10 -Attributes $centerAttributes
    } |
    New-SvgGroup -Attributes @{ id = 'diag'; 'fill-opacity' = 0; 'stroke-width' = 2 }
}

function New-Logo([string] $Text)
{
    $size = $Settings.Square.Size
    &{
        New-SvgRect -X 0 -Y 0 -Width $size -Height $size -Attributes @{ fill='#68217a' }

        New-Border

        New-Text -Text $Text.ToUpperInvariant()

        New-Diagnostic
    } |
    New-SvgDocument -Width $size -Height $size
}

New-Logo -Text 'SpbDotNet' | Set-Content (Join-Path $PSScriptRoot 'Logo.svg')
