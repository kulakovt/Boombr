function Resolve-FullPath()
{
    if (-not $args)
    {
        throw 'Provide a paths to be joined'
    }

    if (-not [IO.Path]::IsPathRooted($args[0]))
    {
        throw "First part shoul be absolute path, but not: $($args[0])"
    }

    $path = [IO.Path]::Combine([string[]]$args)
    [IO.Path]::GetFullPath($path)
}

function Start-TimeOperation([string] $Name = $(throw 'Name required'))
{
    Write-Information "$Name..."
    @{
        Name = $Name
        Timer = [System.Diagnostics.Stopwatch]::StartNew()
    }
}

function Stop-TimeOperation()
{
    process
    {
        $operation = $_
        $operation.Timer.Stop()
        Write-Information "$($operation.Name) completed in $($operation.Timer.Elapsed)"
    }
}

filter Select-NotNull([switch] $AndNotWhiteSpace)
{
    if ($AndNotWhiteSpace)
    {
        if (-not [String]::IsNullOrWhiteSpace($_))
        {
            $_
        }
    }
    else
    {
        if ($_)
        {
            $_
        }
    }
}

function Select-Single($ElementNames = 'elements')
{
    begin
    {
        $count = 0
    }
    process
    {
        if ($_)
        {
            $count++
            $_
        }
    }
    end
    {
        if ($count -ne 1)
        {
            throw "Found $count $ElementNames in collection"
        }
    }
}

function Select-Many
{
    [CmdletBinding()]
    [OutputType([object[]])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        $Collection
    )

    process
    {
        if ($Collection -is [System.Collections.IEnumerable])
        {
            $Collection.GetEnumerator()
        }
        else
        {
            $Collection
        }
    }
}

filter Out-Tee()
{
    $_ | Out-Host
    $_
}

function Join-ToString
{
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        $Item,

        [string]
        $Delimeter = ', '
    )

    begin
    {
        $items = @()
    }
    process
    {
        $items += $Item
    }
    end
    {
        $items -join $Delimeter
    }
}

function ConvertTo-Hashtable
{
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        $Item,

        [Parameter(Mandatory, Position=0)]
        [ScriptBlock]
        $KeySelector,

        [ScriptBlock]
        [Parameter(Position=1)]
        $ElementSelector = { $_ }
    )

    begin
    {
        $items = @{}
    }
    process
    {
        $key = & $KeySelector $Item
        if ($key)
        {
            $element = & $ElementSelector $Item
            $items[$key] = $element
        }
    }
    end
    {
        $items
    }
}

function Format-UriQuery
{
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [Hashtable]
        $Parts
    )

    process
    {
        $Parts |
        Select-Many |
        ForEach-Object {
            "{0}={1}" -f $_.Key,[Uri]::EscapeDataString($_.Value)
        } |
        Join-ToString -Delimeter '&'
    }
}

function Join-Uri
{
    [CmdletBinding()]
    [OutputType([Uri])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [Uri]
        $BaseUri,

        [Parameter(Mandatory)]
        [string]
        $RelativeUri
    )

    $left = $BaseUri.ToString().TrimEnd('/')
    $right = $RelativeUri.TrimStart('/')
    $separator = '/'

    if ($left.Contains('?') -or $right.StartsWith('?'))
    {
        $separator = ''
    }

    [Uri] "${left}${separator}${right}"
}

function Get-Secret
{
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Key
    )

    begin
    {
        $profileDir = Split-Path $profile
        $secretFile = Join-Path $profileDir 'Secret.xml'

        [xml] $storage = $null
        if (Test-Path -Path $secretFile)
        {
            $storage = Get-Content -Path $secretFile
        }
        else
        {
            throw "Can't find file with secrets at: $secretFile"
        }
    }
    process
    {
        Select-Xml -Xml $storage -XPath "//$Key" |
        ForEach-Object { $_.node.InnerXML } |
        Select-Single -ElementNames $Key
    }
}

function Format-Declension
{
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [int]
        $Number,
        [string]
        $Nominativ = 'штука',
        [string]
        $Genetiv = 'штуки',
        [string]
        $Plural = 'штук'
    )

    process
    {
        $text = $Plural
        if ($Number % 10 -eq 1) { $text = $Nominativ }
        if (($Number % 10 -ge 2) -and ($Number % 10 -le 4)) { $text = $Genetiv }
        '{0:N0} {1}' -f $Number,$text
    }
}

function ConvertTo-LocalTime
{
    [CmdletBinding()]
    [OutputType([DateTime])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [DateTime]
        $Date
    )

    process
    {
        $utcTime = $Date.ToUniversalTime()
        $mskTimeZone = [TimeZoneInfo]::FindSystemTimeZoneById("Russian Standard Time")
        [TimeZoneInfo]::ConvertTimeFromUtc($utcTime, $mskTimeZone)
    }
}
