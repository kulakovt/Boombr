#Requires -Version 5

Set-StrictMode -version Latest
$ErrorActionPreference = 'Stop'

. $PSScriptRoot\Svg.ps1

function Format-Glyph([SvgGlyph] $Glyph, [int] $TranslateX, [int] $TranslateY)
{
    $newGlyph = $Glyph.Move($TranslateX, $TranslateY)
    '    ' + $newGlyph.ToString()
    $basePoint = $newGlyph.GetBasePoint()
    '    <circle cx="{0}" cy="{1}" r="50" fill="red"/>' -f $basePoint.X,$basePoint.Y
}

function Show-SvgGrid()
{
    $cw = [SvgGlyph]::Width
    $ch = [SvgGlyph]::Height
    $s = 100
    $gc = 6
    $gr = 5
    $gw = $s + ($gc * ($s + $cw + $s)) + $s
    $gh = $s + ($gr * ($s + $ch + $s)) + $s

@'
<svg width="{0}" height="{1}" xmlns="http://www.w3.org/2000/svg">
  <rect x="0" y="0" width="{0}" height="{1}" fill="#68217a"/>
  <g stroke="#fbff00">

'@ -f $gw,$gh

    for ($x = 0; $x -le $gc; $x++)
    {
        $xw = $s + ($x * ($s + $cw + $s))
'    <line x1="{0}" y1="{1}" x2="{2}" y2="{3}" />' -f $xw,$s,$xw,($gh - $s)
    }

    for ($y = 0; $y -le $gr; $y++)
    {
        $yh = $s + ($y * ($s + $ch + $s))
'    <line x1="{0}" y1="{1}" x2="{2}" y2="{3}" />' -f $s,$yh,($gw - $s),$yh
    }

    ''
    $i = 0
    $path = Join-Path $PSScriptRoot 'ConsolasGlyphs.svg'
    $glyphs = Get-SvgGlyph -Path $path | Sort-Object { Get-Random }

    for ($y = 0; $y -lt $gr; $y++)
    {
        $yh = $s + ($y * ($s + $ch + $s)) +$s
        for ($x = 0; $x -lt $gc; $x++)
        {
            if ($i -lt $glyphs.Length)
            {
                $xw = $s + ($x * ($s + $cw + $s)) + $s
                $glyph = $glyphs[$i++]
                Format-Glyph -Glyph $glyph -TranslateX $xw -TranslateY $yh
            }
        }
    }

@'

  </g>
</svg>
'@
}

Show-SvgGrid | Set-Content (Join-Path $PSScriptRoot 'font-grid.svg')
