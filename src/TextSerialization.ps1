. $PSScriptRoot\Serialization.ps1
. $PSScriptRoot\Utility.ps1

function ConvertTo-NiceText()
{
    process
    {
        $entity = $_
        if (-not $entity) { throw "Entity required" }

        $entityType = $entity.GetType()
        "$('#' * 16) $($entityType.Name) $('#' * 16)"
        ''

        Get-EntityProperty -EntityType $entityType |
        ForEach-Object {
            $property = $_
            $value = $entity."$($property.Name)"
            Format-NiceTextProperty -Property $property -Value $value
        }
        ''
        ''
    }
}

function ConvertFrom-NiceText()
{
    begin
    {
        $head = $null
        $body = @()

        function Pop-Entity()
        {
            if ($head)
            {
                # New Entity
                $body |
                    ConvertFrom-NiceTextEntity -TypeText $head
            }
        }
    }
    process
    {
        $line = $_
        if ($line -and $line -like '#*')
        {
            Pop-Entity

            $head = $line
            $body = @()
        }
        else
        {
            $body += $line
        }
    }
    end
    {
        Pop-Entity
    }
}

function Write-NiceText([string] $FilePath = $(throw "File path required"))
{
    $text = $input | ConvertTo-NiceText
    $text -join [Environment]::NewLine |
        Out-File -FilePath $FilePath -Encoding UTF8
}

function Read-NiceText()
{
    process
    {
        $filePath = $_
        if (-not $filePath) { throw "File path required" }

        Get-Content -Path $filePath -Encoding UTF8 |
        ConvertFrom-NiceText
    }
}

function ConvertFrom-NiceTextEntity([string] $TypeText = $(throw "Type text required"))
{
    $entityType = $TypeText -replace '[#\s]'
    $entity = New-Object -TypeName $entityType

    $textValues =  $input | ConvertFrom-NiceTextToDict

    $properties = Get-EntityProperty -EntityType $entityType |
        ConvertTo-Hashtable -KeySelector { $_.Name } -ElementSelector { $_.PropertyType }

    foreach ($propertyName in $textValues.Keys)
    {
        $propertyType = $properties[$propertyName]
        $propertyValue = $textValues[$propertyName]

        $property = Format-UnNiceTextProperty `
            -NameCandidate $propertyName `
            -ValueCandidate $propertyValue `
            -PropertyType $propertyType `
            -Vocabulary $properties.Keys

        $entity."$($property.Name)" = $property.Value
    }

    $entity
}

function Format-NiceTextProperty($Property = $(throw "Property required"), $Value = $(throw "Value required"))
{
    # Remove ID suffix
    $nameView = $Property.Name -replace '(.+)Id$','$1' -replace '(.+)Ids$','$1s'

    # Custom format for special types
    $valueView = $Value
    switch ($Property.PropertyType)
    {
        ([DateTime]) { $valueView = '{0:yyyy.MM.dd}' -f $Value }
        ([string[]]) { $valueView = $Value -join ', ' }
        ([string])
        {
            if ($Value -and $Value.Contains("`n"))
            {
                $nl = [Environment]::NewLine
                $nameView = $nl + $nameView
                $valueView = $nl + $Value + $nl
            }
        }
    }

    "${nameView}: $valueView"
}

function Format-UnNiceTextProperty(
    $NameCandidate = $(throw "Name candidate required"),
    $ValueCandidate = $(throw "Value candidate required"),
    $PropertyType = $(throw "Property type required"),
    $Vocabulary = $(throw "Vocabulary required"))
{
    # Restore ID suffix
    $name = @("$NameCandidate", "${NameCandidate}Id", "$($NameCandidate.TrimEnd('s'))Ids") |
        Where-Object { $Vocabulary -contains $_ } |
        Select-Single -ElementNames "unnice property names"

    # Custom unformat for special types
    $value = $ValueCandidate
    switch ($PropertyType)
    {
        ([DateTime])
        {
            $value = [DateTime]::ParseExact($value, 'yyyy.MM.dd', [Globalization.CultureInfo]::InvariantCulture)
            $value = [DateTime]::SpecifyKind($value, 'Utc')
        }
        ([string[]]) { $value = ($value -split ',').Trim() }
    }

    @{
        Name = $name
        Value = $value
    }
}

function ConvertFrom-NiceTextToDict()
{
    begin
    {
        $nl = [System.Environment]::NewLine
        $onelinePattern = '^(?<Key>\w+)\s*\:\s*(?<Value>.*?)\s*$'
        $dict = @{}
        $lastKey = $null
    }
    process
    {
        $line = $_
        if ($line -match $onelinePattern)
        {
            $lastKey = $Matches['Key']
            $dict[$lastKey] = $Matches['Value']
        }
        else
        {
            if (-not $lastKey)
            {
                if ($line) { throw "Found unassigned line: $line" }
                return
            }

            $dict[$lastKey] = $dict[$lastKey] + $nl + $line
        }
    }
    end
    {
        foreach ($key in @($dict.Keys))
        {
            $dict[$key] = $dict[$key].Trim()
        }

        $dict
    }
}
