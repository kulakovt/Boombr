﻿function Resolve-FullPath()
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
        [Parameter(ValueFromPipeline)]
        $Collection
    )

    process
    {
        if ($Collection -is [System.Collections.IEnumerable])
        {
            $Collection.GetEnumerator()
        }
        elseif ($Collection)
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

function Join-ToPipe
{
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        $Item,

        [Parameter()]
        $Before = $null,

        [Parameter()]
        $BeforeMany = @(),

        [Parameter()]
        $After = $null,

        [Parameter()]
        $AfterMany = @()
    )

    begin
    {
        if ($Before)
        {
            $Before
        }

        $BeforeMany | Select-Many
    }
    process
    {
        $Item
    }
    end
    {
        if ($After)
        {
            $After
        }

        $AfterMany | Select-Many
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

function Format-XmlAttributeLine
{
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [Hashtable]
        $Pairs,

        [Parameter()]
        [string]
        $Prefix = ' '
    )

    process
    {
        $Prefix = $Prefix # HACK: Avoid Analizer BUG

        $Pairs |
        Select-Many |
        ForEach-Object {
            '{0}="{1}"' -f $_.Key,$_.Value
        } |
        Join-ToString -Delimeter ' ' |
        ForEach-Object {

            if ($_)
            {
                $Prefix + $_
            }
            else
            {
                ''
            }
        }
    }
}

function Format-HtmlEncode()
{
    process
    {
        [System.Net.WebUtility]::HtmlEncode($_)
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

    process
    {
        $left = $BaseUri.ToString().TrimEnd('/')
        $right = $RelativeUri.TrimStart('/')
        $separator = '/'

        if ($left.Contains('?') -or $right.StartsWith('?'))
        {
            $separator = ''
        }

        [Uri] "${left}${separator}${right}"
    }
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

function Confirm-DirectoryExist
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path
    )

    process
    {
        if (-not (Test-Path -Path $Path -PathType 'Container'))
        {
            New-Item -Path $Path -ItemType 'Directory' | Out-Null
        }
    }
}

function Get-GitRemotePath
{
    [CmdletBinding()]
    [OutputType([Uri])]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('FullName')]
        [string]
        $Path,

        [Parameter()]
        [switch]
        $UserContent
    )

    begin
    {
        Push-Location
    }
    process
    {
        $startDirectory = if (Test-Path -Path $Path -PathType Leaf) { Split-Path $Path } else { $Path }
        Set-Location -Path $startDirectory
        $status = Get-GitStatus
        if (-not $status)
        {
            throw "Git repository not found in $startDirectory"
        }

        $localRoot = Split-Path $status.GitDir
        Set-Location $localRoot
        $relativeLocal = Resolve-Path -Path $Path -Relative

        $remoteRoot = (git config --get remote.origin.url) -replace '\.git$',''
        if (Test-Path -Path $Path -PathType Leaf)
        {
            if ($UserContent)
            {
                $remoteRoot = $remoteRoot.Replace('https://github.com/', 'https://raw.githubusercontent.com/')
            }
            else
            {
                $remoteRoot = Join-Uri $remoteRoot 'blob'
            }
        }
        else
        {
            $remoteRoot = Join-Uri $remoteRoot 'tree'
        }

        $remoteRoot = Join-Uri $remoteRoot ($status.Branch + '/')
        [Uri]::new($remoteRoot, $relativeLocal)
    }
    end
    {
        Pop-Location
    }
}


function Add-NumberToCustomObject
{
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject]
        $Object,

        [Parameter()]
        [string]
        $NumberPropertyName = 'Number'
    )

    begin
    {
        $number = 0
    }
    process
    {
        $hashtable = [ordered]@{}
        $hashtable[$NumberPropertyName] = ++$number
        foreach ($property in $Object.PSObject.Properties.Name)
        {
            $hashtable[$property] = $Object.$property
        }

        [PSCustomObject]$hashtable
    }
}
