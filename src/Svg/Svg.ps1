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
'<svg width="{0}" height="{1}" xmlns="http://www.w3.org/2000/svg">' -f $Width,$Height
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
    static [int] $Width = 1126
    static [int] $Height = 1307

    [string] $Unicode
    [string] $Path

    hidden [string] $BasePattern = '^m(?<X>\-?\d+)\s?(?<Y>\-?\d+)'

    SvgGlyph([string] $Unicode, [string] $Path)
    {
        $this.Unicode = $Unicode
        $this.Path = $Path
    }

    static [SvgGlyph] FromXml([xml] $PathElement)
    {
        return [SvgGlyph]::new($PathElement.path.id, $PathElement.path.d)
    }

    [string] ToString()
    {
        return '<path id="{0}" d="{1}" />' -f $this.Unicode,$this.Path
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

    [SvgGlyph] Move([int] $TranslateX, [int] $TranslateY)
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

function Get-SvgGlyph($Path)
{
    Get-Content -Path $Path |
    Where-Object { $_.Contains('<path id="') } |
    ForEach-Object { [SvgGlyph]::FromXml($_) }
}
