#Requires -Modules powershell-yaml

. $PSScriptRoot\Utility.ps1

function ConvertTo-NiceYaml()
{
    process
    {
        $_ | ConvertTo-NiceYamlArray | Join-ToString -Delimeter "`n"
    }
}

function ConvertFrom-NiceYaml()
{
    process
    {
        $yaml = $_

        $typeLine = $yaml -split "`n" | Select-Object -First 1 | Where-Object { $_ -like '###*' }
        if (-not $typeLine)
        {
            throw 'Can not find type line'
        }

        $entityType = $typeLine -replace '[#\s]'
        $properties = ConvertFrom-Yaml -Yaml $yaml

        # Fix time kind
        foreach ($key in $($properties.Keys))
        {
            $value = $properties[$key]
            if ($value -is [datetime])
            {
                $properties[$key] = $value.ToUniversalTime()
            }
        }

        New-Object -TypeName $entityType -Property $properties
    }
}


function Write-NiceYaml([string] $FilePath = $(throw "File path required"))
{
    $input |
    ConvertTo-NiceYaml |
    Out-File -FilePath $FilePath -Encoding UTF8
}

function Read-NiceYaml()
{
    process
    {
        $_ |
        Get-ChildItem |
        Get-Content -Encoding UTF8 -Raw |
        Split-MultiYaml |
        ConvertFrom-NiceYaml
    }
}

function ConvertTo-NiceYamlArray()
{
    process
    {
        $entity = $_
        if (-not $entity) { throw "Entity required1" }

        $entityType = $entity.GetType()
        "$('#' * 16) $($entityType.Name) $('#' * 16)"
        ''
        ConvertTo-Yaml -Data $entity
        ''
        ''
    }
}

function Split-MultiYaml()
{
    process
    {
        function PopDocument()
        {
            $document | Join-ToString -Delimeter "`n" | Select-NotNull -AndNotWhiteSpace
        }

        $document = @()
        $text = $_
        $lines = $text -split "`n"

        for ($i = 0; $i -lt $lines.Length; $i++)
        {
            $line = $lines[$i]
            if ($line -like '###*')
            {
                PopDocument
                $document = @()
            }

            $document += $line
        }

        PopDocument
    }
}
