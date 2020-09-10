function Format-Indent([int] $IndentSize)
{
    begin
    {
        $indentString = '  ' * $IndentSize
    }
    process
    {
        if ($_)
        {
            $indentString + $_
        }
        else
        {
            ''
        }
    }
}

function New-SvgGroup([string] $FillColor)
{
    begin
    {
        '<g fill="{0}">' -f $FillColor
    }
    process
    {
        $_
    }
    end
    {
        '</g>'
    }
}

function New-SvgRect([int] $X, [int] $Y, [int] $Width, [int] $Height, [string] $FillColor)
{
    '<rect x="{0}" y="{1}" width="{2}" height="{3}" fill="{4}" />' -f $X,$Y,$Width,$Height,$FillColor
}

function New-SvgDocument([int] $Width, [int] $Height)
{
    begin
    {
'<svg width="{0}" height="{1}" version="1.1" xmlns="http://www.w3.org/2000/svg">' -f $Width,$Height
    }
    process
    {
        $_
    }
    end
    {
'</svg>'
    }
}


class SvgGlyph
{
    [string] $Unicode
    [string] $Path

    hidden [string] $BasePattern = '^m(?<X>[\d\.]+)\s?(?<Y>[\d\.]+)'

    SvgGlyph([string] $Unicode, [string] $Path)
    {
        $this.Unicode = $Unicode
        $this.Path = $Path
    }

    static [string] UnicodeToId([string] $unicode)
    {
        if ($unicode -eq '.')
        {
            return 'dot'
        }
        return $unicode
    }

    static [string] IdToUnicode([string] $id)
    {
        if ($id -eq 'dot')
        {
             return '.'
        }
        return $id
    }

    [string] ToPath()
    {
        $id = [SvgGlyph]::UnicodeToId($this.Unicode)
        return '<path id="{0}" d="{1}" />' -f $id,$this.Path
    }

    [Hashtable] GetBasePoint()
    {
        if ($this.Path -match $this.BasePattern)
        {
            return @{
                X = [int]$Matches.X
                Y = [int]$Matches.Y
            }
        }

        throw "Can't parse Path from $($this.Unicode): $($this.Path)"
    }

    [SvgGlyph] Move($TranslateX, $TranslateY)
    {
        $basePoint = $this.GetBasePoint()
        $newX = $basePoint.X + $TranslateX
        $newY = $basePoint.Y + $TranslateY
        $separator = if ($newY -ge 0) { ' ' } else { '' }
        $newBase = "m${newX}${separator}${newY}"

        $newPath = $this.Path -replace $this.BasePattern,$newBase

        return [SvgGlyph]::new($this.Unicode, $newPath)
    }
}

<#

### How to make Glyphs.svg file

1. Conver TTF font file to SVG
2. Send [1] file to `Convert-SvgFontToTransformGlyph` function
3. Open [2] file in Inkscape
4. Select group with letters
5. Call «Object → Ungroup»
6. Call «File → Save As...» (change type to «Optimized SVG»)
7. Make sure file [4] doesn't contains any `g` elements

- File [7] is a file with Glyphs. You can use it with `Get-SvgGlyphSet` function.
- You can run GlyphGrid.ps1 to make sure that all glyphs are displayed correctly
- You can run Logo.svg to create a new square logo

#>
function Get-SvgGlyphSet($Path)
{
    [xml] $f = Get-Content -Path $Path
    @{
        Width = [int] $f.svg.width
        Height = [int] $f.svg.height
        Glyphs = $f.svg.path | ForEach-Object {
            $unicode = [SvgGlyph]::IdToUnicode($_.id)
            [SvgGlyph]::new($unicode, $_.d)
        }
    }
}

function Convert-SvgFontToTransformGlyph($Path)
{
    [xml] $f = Get-Content -Path $Path
    [int] $width = $f.svg.defs.font.'horiz-adv-x'
    [int] $height = $f.svg.defs.font.'font-face'.'cap-height'
    $scaleFactor = 0.1

    filter Select-SvgUsefulGlyph
    {
        if (($_.unicode.Length -eq 1))
        {
            $char = $_.unicode[0]
            if (($char -ge 'A') -and ($char -le 'Z'))
            {
                [SvgGlyph]::new($_.unicode, $_.d)
            }
            if ($char -eq '.')
            {
                [SvgGlyph]::new('dot', $_.d)
            }
        }
    }

@'
<svg width="{1}" height="{2}" version="1.1" xmlns="http://www.w3.org/2000/svg">
  <g transform="scale(0.1, 0.1) rotate(180 {3} {4}) scale(-1, 1) translate(-{0}, 0)">
'@ -f $width,[int]($width * $scaleFactor),[int]($height * $scaleFactor),[int]($width / 2),[int]($height / 2)

    $f.svg.defs.font.glyph |
    Select-SvgUsefulGlyph |
    ForEach-Object { '    ' + $_.ToPath() }
'  </g>'
'</svg>'
}

# Convert-SvgFontToTransformGlyph 'C:\Users\akulakov\Desktop\RadioDotNet\Font\consola.svg' > ./src/Svg/ConsolasRaw.svg
