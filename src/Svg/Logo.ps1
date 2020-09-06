Set-StrictMode -version Latest
$ErrorActionPreference = 'Stop'

$InformationPreference = 'Continue'
$VerbosePreference = 'SilentlyContinue'

. $PSScriptRoot\Svg.ps1

function New-SettingsFromGlyphSize()
{
    $fi = 1.618
    $columnCount = 3
    $rectWidth = [SvgGlyph]::Width * $columnCount
    $rectHeight = $rectWidth * $fi
    $squareSize = $rectWidth + $rectHeight

    @{
        Square = @{
            Size = $squareSize
            Center = $squareSize / 2
        }
        Rect = @{
            ColumnCount = $columnCount
            RowCount = 3
            X = $squareSize / 2
            Y = $squareSize / 2 - ($rectHeight  / 2)
            Width = $rectWidth
            Height = $rectHeight
        }
    }
}

$Settings = New-SettingsFromGlyphSize

function New-GlyphRect([string] $Text)
{
    if ($Text.Length -ne 9) { throw 'Text must be 9 letters long' }

    $fontPath = Join-Path $PSScriptRoot 'ConsolasGlyphs.svg'
    $glyphs = Get-SvgGlyph -Path $fontPath

    for ($i = 0; $i -lt $Text.Length; $i++)
    {
        $columnIndex =  [Math]::Floor($i / $rectColumns)
        $rowIndex = $i % $rectRows
        $x = $rectX + [SvgGlyph]::Width * $columnIndex
        # TDO: Resolve from $rectHeight
        $y = $rectY + [SvgGlyph]::Height * $rowIndex

        $letter = $Text[$i]
        $glyph = $glyphs | Where-Object { $_.Unicode -eq $letter }
        if (-not $glyph) { throw "Can't find glyph for «$letter»" }

        Write-Host "$letter = ($x, $y)"
        $glyph.Move($x, $y).ToString()
    }
}

function New-Diagnostic()
{
    '<g fill-opacity="0" stroke-width="20">'
    '  <!-- Center -->'
    '  <circle cx="{0}" cy="{0}" r="100" fill="red" fill-opacity="1"/>' -f "$($Settings.Square.Center)"
    '  <!-- Social circle -->'
    '  <circle cx="{0}" cy="{0}" r="{1}" stroke="coral" stroke-dasharray="100" />' -f "$($Settings.Square.Center)","$($Settings.Square.Size / 2)"
    '  <!-- Golden rectangle -->'
    '  <rect x="{0}" y="{1}" width="{2}" height="{3}" stroke="#fbff00"/>' -f "$($Settings.Rect.X)","$($Settings.Rect.Y)","$($Settings.Rect.Width)","$($Settings.Rect.Height)"
    '  <!-- Rule of thirds -->'
    $firstThird =  $Settings.Square.Size / 3
    $secondThird =  $Settings.Square.Size - $firstThird
    '  <line x1="0" y1="{0}" x2="{1}" y2="{0}" stroke="lime" />' -f "$firstThird","$($Settings.Square.Size)"
    '  <line x1="0" y1="{0}" x2="{1}" y2="{0}" stroke="lime" />' -f "$secondThird","$($Settings.Square.Size)"
    '  <line x1="{0}" y1="0" x2="{0}" y2="{1}" stroke="lime" />' -f "$firstThird","$($Settings.Square.Size)"
    '  <line x1="{0}" y1="0" x2="{0}" y2="{1}" stroke="lime" />' -f "$secondThird","$($Settings.Square.Size)"
    '</g>'
}

function New-Logo([string] $Text)
{
    $size = $Settings.Square.Size
    &{
        New-SvgRect -X 0 -Y 0 -Width $size -Height $size -FillColor '#68217a' | Format-Indent -IndentSize 1
        # New-GlyphRect -Text $Text | Format-Indent -IndentSize 2 |
        # New-SvgGroup  | Format-Indent -IndentSize 1
        New-Diagnostic | Format-Indent -IndentSize 1
    } |
    New-SvgDocument -Width $size -Height $size
}

New-Logo -Text 'SPBDOTNET' | Set-Content (Join-Path $PSScriptRoot 'Logo.svg')
