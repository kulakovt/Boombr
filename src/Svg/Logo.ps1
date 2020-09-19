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

    @{
        GlyphSet = $glyphSet
        Square = @{
            Size = [int] $squareSize
            Center = [int] ($squareSize / 2)
        }
        Rect = @{
            ColumnCount = $columnCount
            RowCount = 3
            X = [int] ($secondThird - $rectWidth / 2)
            Y = [int] ($squareSize / 2 - ($rectHeight  / 2))
            Width = [int] $rectWidth
            Height = [int] $rectHeight
        }
        Border = @{
            # 0,0, +8, -16
            Width = 16
        }
    }
}

$Settings = New-SettingsFromGlyphSize

function New-GlyphRect([string] $Text)
{
    $maxLenth = $Settings.Rect.ColumnCount * $Settings.Rect.RowCount
    if ($Text.Length -ne $maxLenth) { throw "Text length must be $maxLenth letters long" }

    for ($i = 0; $i -lt $Text.Length; $i++)
    {
        $columnIndex = $i % $Settings.Rect.RowCount
        $rowIndex = [Math]::Floor($i / $Settings.Rect.ColumnCount)
        [int] $x = $Settings.Rect.X + $Settings.GlyphSet.Width * $columnIndex
        $ys = ($Settings.Rect.Height - ($Settings.GlyphSet.Height * $Settings.Rect.RowCount)) / ($Settings.Rect.RowCount - 1)
        [int] $y = $Settings.Rect.Y + ($Settings.GlyphSet.Height + $ys) * $rowIndex

        $letter = $Text[$i]
        $glyph = $Settings.GlyphSet.Glyphs | Where-Object { $_.Unicode -eq $letter }
        if (-not $glyph) { throw "Can't find glyph for «$letter»" }

        $glyph.Move($x, $y).ToPath()
    }
}

function New-Diagnostic()
{
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
        $centerAttributes = @{ fill = 'red'; 'fill-opacity' = 1 }
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

        New-GlyphRect -Text $Text.ToUpperInvariant() |
        New-SvgGroup -Attributes @{ fill = 'white' }

        New-Diagnostic
    } |
    New-SvgDocument -Width $size -Height $size
}

New-Logo -Text 'SpbDotNet' | Set-Content (Join-Path $PSScriptRoot 'Logo.svg')
