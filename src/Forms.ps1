function Read-NiceXml()
{
    process
    {
        $content = Get-Content -Path $_ -Encoding UTF8 -Raw
        $doc = [System.Xml.Linq.XDocument]::Parse($content)
        ConvertFrom-NiceXml ($doc.Root)
    }
}

function Format-PretyName()
{
    process
    {
        $name = $_
        $name -replace '(.+)Id$','$1' -replace '(.+)Ids$','$1s'
    }
}

function Format-UnPretyName($Vocabulary)
{
    process
    {
        $name = $_
        @("$name", "$($name.TrimEnd('s'))Ids", "${name}Id") |
        ? { $Vocabulary -contains $_ } |
        Select-Single -ElementNames 'unprety property names'
    }
}

function Render-Property($Property, $Value)
{
    $nameView = $Property.Name | Format-PretyName

    $valueView = $Value
    switch ($Property.PropertyType)
    {
        ([DateTime]) { $valueView = '{0:yyyy.MM.dd}' -f $Value }
        ([string[]]) { $valueView = $Value -join ', ' }
    }

    "${nameView}: $valueView"
}

function Render-Entity()
{
    process
    {
        $entity = $_
        $entityType = $entity.GetType()
        ''
        "############ $($entityType.Name) ############"
        ''

        Get-EntityProperties -EntityType $entityType |
        % {
            $property = $_
            $value = $entity."$($property.Name)"
            Render-Property -Property $property -Value $value
        }
        ''
    }
}

function Parse-InputFormLines()
{
    begin
    {
        $entity = $null
        $props = @{}
    }
    process
    {
        $line = $_
        if ([String]::IsNullOrWhiteSpace($line))
        {
            return
        }

        if ($line -like '#*')
        {
            # New Entity
            if ($entity)
            {
                $entity
            }
            $entityType = $line -replace '[#\s]'
            $entity = New-Object -TypeName $entityType
            $props = Get-EntityProperties -EntityType $entityType |
                ConvertTo-Hashtable -KeySelector { $_.Name } -ElementSelector { $_.PropertyType }
        }
        elseif ($line -like '*:*')
        {
            # New Property value
            $propertyName, $propertyValue = $line -split ':',2 | % { $_.Trim() }

            if (-not $propertyValue)
            {
                # Skip empty values
                return
            }

            $propertyName = $propertyName | Format-UnPretyName -Vocabulary $props.Keys
            $propertyType = $props[$propertyName]

            switch ($propertyType)
            {
                ([DateTime])   { $propertyValue = [DateTime]::ParseExact($propertyValue, 'yyyy.MM.dd', [System.Globalization.CultureInfo]::InvariantCulture) }
                ([string[]]) { $propertyValue = $propertyValue -split ', ' | % { $_.Trim() } }
            }
            $entity."$propertyName" = $propertyValue
        }
        else
        {
            throw "Invalid input form line: $_"
        }
    }
    end
    {
        if ($entity)
        {
            $entity
        }
    }
}

function Save-Entity([switch] $CreateOnly)
{
    process
    {
        $entity = $_
        $id = $entity.Id
        $fileName = $null

        switch ($entity.GetType())
        {
            ([Community]) { $fileName = "communities/$id.xml" }
            ([Meetup])    { $fileName = "meetups/$id.xml" }
            ([Venue])     { $fileName = "venues/$id.xml" }
            ([Friend])    { $fileName = "friends/$id/index.xml" }
            ([Talk])      { $fileName = "talks/$id.xml" }
            ([Speaker])   { $fileName = "speakers/$id/index.xml" }
            default       { throw "Entity not detected: $($_.FullName)" }
        }

        $file = Join-Path $Config.AuditDir $fileName
        if ((Test-Path $file -PathType Leaf) -and ($CreateOnly))
        {
            throw "Can't override existed file: $file"
        }

        $dir = Split-Path $file -Parent
        if (-not (Test-Path $dir -PathType Container))
        {
            New-Item -Path $dir -ItemType Directory | Out-Null
        }

        Write-Information "Save $($entity.Id)"

        (ConvertTo-NiceXml -Entity $entity).ToString() | Out-File -FilePath $file -Encoding UTF8
    }
}

function New-Meetup()
{
    $file = Join-Path $Config.ArtifactsDir 'New Meetup.txt'
    if (-not (Test-Path $file))
    {
        @(
            'meetups/SpbDotNet-8.xml' 
            'friends/DataArt/index.xml'
            'venues/Spb-Telekom.xml'
            'talks/Structured-logging.xml'
            'talks/Design-of-RESTFul-API.xml'
            'speakers/Anatoly-Kulakov/index.xml'
        ) |
        % { Join-Path $Config.AuditDir $_ } |
        Read-NiceXml |
        Render-Entity |
        Set-Content -Path $file -Encoding UTF8
    }

    Start-Process -FilePath 'notepad.exe' -ArgumentList $file -Wait

    $timer = Start-TimeOperation -Name 'New Meetup'

    Get-Content -Path $file -Encoding UTF8 |
    Parse-InputFormLines |
    # TODO: Add content validation
    Save-Entity -CreateOnly

    $timer | Stop-TimeOperation
}
