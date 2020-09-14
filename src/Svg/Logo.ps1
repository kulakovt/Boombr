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
            Size = $squareSize
            Center = $squareSize / 2
        }
        Rect = @{
            ColumnCount = $columnCount
            RowCount = 3
            X = $secondThird - $rectWidth / 2
            Y = $squareSize / 2 - ($rectHeight  / 2)
            Width = $rectWidth
            Height = $rectHeight
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
    '<g id="diag" fill-opacity="0" stroke-width="2">'
    $firstThird =  $Settings.Square.Size / 3
    $secondThird =  $Settings.Square.Size - $firstThird
    @(
        '   <!-- Rule of thirds -->'
        '  <line x1="0" y1="{1}" x2="{0}" y2="{1}" stroke="lime" />'
        '  <line x1="0" y1="{2}" x2="{0}" y2="{2}" stroke="lime" />'
        '  <line x1="{1}" y1="0" x2="{1}" y2="{0}" stroke="lime" />'
        '  <line x1="{2}" y1="0" x2="{2}" y2="{0}" stroke="lime" />'
    ) |
    ForEach-Object {
        $_ -f "$($Settings.Square.Size)","$firstThird","$secondThird"
    }
    '  <!-- Golden rectangle -->'
    '  <rect x="{0}" y="{1}" width="{2}" height="{3}" stroke="#fbff00"/>' -f "$($Settings.Rect.X)","$($Settings.Rect.Y)","$($Settings.Rect.Width)","$($Settings.Rect.Height)"
    '  <!-- Social circle -->'
    '  <circle cx="{0}" cy="{0}" r="{1}" stroke="coral" stroke-dasharray="10" />' -f "$($Settings.Square.Center)","$($Settings.Square.Size / 2)"
    '  <!-- Centers -->'
    '  <circle cx="{0}" cy="{0}" r="10" fill="red" fill-opacity="1"/>' -f "$($Settings.Square.Center)"
    '  <circle cx="{0}" cy="{1}" r="10" fill="red" fill-opacity="1"/>' -f "$($Settings.Rect.X + $Settings.Rect.Width / 2)","$($Settings.Rect.Y)"
    '  <circle cx="{0}" cy="{1}" r="10" fill="red" fill-opacity="1"/>' -f "$($Settings.Rect.X + $Settings.Rect.Width / 2)","$($Settings.Rect.Y + $Settings.Rect.Height)"
    '</g>'
}

function New-Logo([string] $Text)
{
    $size = $Settings.Square.Size
    &{
        New-SvgRect -X 0 -Y 0 -Width $size -Height $size -FillColor '#68217a' | Format-Indent -IndentSize 1
        New-GlyphRect -Text $Text.ToUpperInvariant() | Format-Indent -IndentSize 1 |
        New-SvgGroup -FillColor 'white' | Format-Indent -IndentSize 1
        New-Diagnostic | Format-Indent -IndentSize 1
    } |
    New-SvgDocument -Width $size -Height $size
}

New-Logo -Text 'SpbDotNet' | Set-Content (Join-Path $PSScriptRoot 'Logo.svg')
