. $PSScriptRoot\..\Utility.ps1

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

function New-SvgGroup([Hashtable] $Attributes = @{})
{
    begin
    {
        '<g{0}>' -f ($Attributes | Format-XmlAttributeLine)
    }
    process
    {
        $_ | Format-Indent -IndentSize 1
    }
    end
    {
        '</g>'
    }
}

function New-SvgRect([double] $X, [double] $Y, [double] $Width, [double] $Height, [Hashtable] $Attributes = @{})
{
    $idPart = ''
    if ($Attributes.ContainsKey('id'))
    {
        $idPart = ' id="{0}"' -f $Attributes['id']
        $Attributes.Remove('id')
    }

    '<rect{0} x="{1}" y="{2}" width="{3}" height="{4}"{5} />' -f $idPart,"$X","$Y","$Width","$Height",($Attributes | Format-XmlAttributeLine)
}

function New-SvgLine([double] $X1, [double] $Y1, [double] $X2, [double] $Y2, [Hashtable] $Attributes = @{})
{
    '<line x1="{0}" y1="{1}" x2="{2}" y2="{3}"{4} />' -f "$X1","$Y1","$X2","$Y2",($Attributes | Format-XmlAttributeLine)
}

function New-SvgCircle([double] $X, [double] $Y, [double] $Radius, [Hashtable] $Attributes = @{})
{
    '<circle cx="{0}" cy="{1}" r="{2}"{3} />' -f "$X","$Y","$Radius",($Attributes | Format-XmlAttributeLine)
}

function New-SvgComment($Message)
{
    '<!-- {0} -->' -f $Message
}

function New-SvgDocument([double] $Width, [double] $Height)
{
    begin
    {
'<svg width="{0}" height="{1}" version="1.1" xmlns="http://www.w3.org/2000/svg">' -f "$Width","$Height"
    }
    process
    {
        $_ | Format-Indent -IndentSize 1
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

    [string] ToPath([bool] $AddIdentity)
    {
        # TODO: Skip «id» attribute
        $id = [SvgGlyph]::UnicodeToId($this.Unicode)
        if ($AddIdentity)
        {
            return '<path id="{0}" d="{1}" />' -f $id,$this.Path
        }
        else
        {
            return '<path d="{0}" />' -f $this.Path
        }
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

    [int] $newWidth = $width * $scaleFactor
    [int] $newHeight = $height * $scaleFactor
    [int] $halfWidth = $width / 2
    [int] $halfHeight = $height / 2

    $transform = 'scale({0}, {0}) rotate(180 {1} {2}) scale(-1, 1) translate(-{3}, 0)' -f "$scaleFactor",$halfWidth,$halfHeight,$width

    $f.svg.defs.font.glyph |
    Select-SvgUsefulGlyph |
    ForEach-Object { $_.ToPath() } |
    New-SvgGroup -Attributes @{ transform = $transform } |
    New-SvgDocument -Width $newWidth -Height $newHeight
}

# Convert-SvgFontToTransformGlyph 'C:\Users\akulakov\Desktop\RadioDotNet\Font\consola.svg' > ./src/Svg/ConsolasRaw.svg
