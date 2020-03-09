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
        $Data,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [scriptblock]
        $KeyOrderer
    )

    foreach ($key in $Data.Keys | Sort-Object -Property @{ Expression = $KeyOrderer; Descending = $false })
    {
        $value = $Data[$key]
        if (-not $value)
        {
            continue
        }

        $valueType = $value.GetType()
        $isSimpleType = $valueType.IsValueType -or ($valueType -eq [string])
        $lines = ConvertTo-CuteYaml -Data $value -KeyOrderer $KeyOrderer

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
        $Data,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [scriptblock]
        $KeyOrderer
    )

    $hasPrevComplex = $false
    foreach ($item in $Data)
    {
        [array] $lines = ConvertTo-CuteYaml -Data $item -KeyOrderer $KeyOrderer
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
        $Data,

        [Parameter()]
        [scriptblock]
        $KeyOrderer = { $_ }
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
        ConvertTo-CuteYamlList -Data $Data -KeyOrderer $KeyOrderer
    }
    elseif ([System.Collections.IDictionary].IsAssignableFrom($dataType))
    {
        ConvertTo-CuteYamlDictionary -Data $Data -KeyOrderer $KeyOrderer
    }
    else
    {
        throw "Unknown type $($dataType.FullName): $Data"
    }
}
