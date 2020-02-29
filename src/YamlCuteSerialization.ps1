function Select-CuteYamlIndent
{
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(ValueFromPipeline)]
        [string]
        $Line,
        [Parameter()]
        [int]
        $Size = 1,
        [Parameter()]
        [string]
        $Fill = '  '
    )
    begin
    {
        $prefix = $Fill * $Size
    }
    process
    {
        if ($Line)
        {
            "${prefix}${Line}"
        }
        else
        {
            ''
        }
    }
}

function ConvertTo-CuteYamlDictionary
{
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        $Data
    )

    foreach ($key in $Data.Keys)
    {
        $value = $Data[$key]
        if (-not $value)
        {
            continue
        }

        $valueType = $value.GetType()
        $isSimpleType = $valueType.IsValueType -or ($valueType -eq [string])
        $lines = ConvertTo-CuteYaml -Data $value

        if ($isSimpleType)
        {
            "${key}: $lines"
        }
        else
        {
            "${key}:"
            $lines | Select-CuteYamlIndent
        }
    }
}

function ConvertTo-CuteYamlList
{
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        $Data
    )

    $hasPrevComplex = $false
    foreach ($item in $Data)
    {
        [array] $lines = ConvertTo-CuteYaml -Data $item
        $isComplex = $lines.Length -gt 1

        if (-not $hasPrevComplex -and $isComplex)
        {
            ''
            $hasPrevComplex = $true
        }

        $lines |
        Select-Object -First 1 |
        ForEach-Object { "- $_" }

        $lines |
        Select-Object -Skip 1 |
        Select-CuteYamlIndent

        if ($isComplex)
        {
            ''
        }
        else
        {
            $hasPrevComplex = $false
        }
    }
}

function ConvertTo-CuteYaml
{
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        $Data
    )

    if (-not $Data)
    {
        return
    }

    $dataType = $Data.GetType()

    if ($dataType.IsValueType -or ($dataType -eq [string]))
    {
        "$Data"
    }
    elseif ($dataType.IsArray)
    {
        ConvertTo-CuteYamlList -Data $Data
    }
    elseif ([System.Collections.IDictionary].IsAssignableFrom($dataType))
    {
        ConvertTo-CuteYamlDictionary -Data $Data
    }
    else
    {
        throw "Unknown type $($dataType.FullName): $Data"
    }
}
