. $PSScriptRoot\Model.ps1

[Reflection.Assembly]::LoadWithPartialName("System.Xml.Linq") | Out-Null

function Get-EntityProperties([Type] $EntityType)
{
    $props = $EntityType.GetProperties()
    if ([Entity].IsAssignableFrom($EntityType))
    {
        $props = $props[-1..($props.Length - 2)]
    }

    $props
}

function New-XElement([string] $Name = $(throw "Name required"), $Value = $null)
{
    $xName = [System.Xml.Linq.XName]::Get($Name)
    return New-Object -TypeName System.Xml.Linq.XElement -ArgumentList $xName,$Value
}

function ConvertTo-NiceXml($Entity = $(throw "Entity required"), [string] $EntityName = $null)
{
    if (!$EntityName)
    {
        $EntityName = $Entity.GetType().Name
    }

    $xEntity = New-XElement $EntityName
    $props = Get-EntityProperties -EntityType ($Entity.GetType())

    foreach ($property in $props)
    {
        $value = $Entity."$($property.Name)"
        if ($value -eq $null)
        {
            continue
        }

        if ([Entity].IsAssignableFrom($property.PropertyType))
        {
            $xProperty = ConvertTo-NiceXml -Entity $value -EntityName $property.Name
            $xEntity.Add($xProperty)
        }
        elseif ($property.PropertyType.IsArray)
        {
            if ($value.Count -eq 0)
            {
                continue
            }

            $itemType = $property.PropertyType.GetElementType()
            $xList = New-XElement $property.Name

            if ($itemType.IsValueType -or ($itemType -eq [string]))
            {
                $elementName = $itemType.Name
                if ($property.Name -like '*Ids')
                {
                    if ($property.Name -eq 'SeeAlsoTalkIds')
                    {
                        $elementName = 'TalkId'
                    }
                    else
                    {
                        $elementName = $property.Name -replace 'Ids$','Id'
                    }
                }

                $value | % { New-XElement $elementName $_ } | % { $xList.Add($_) }
            }
            else
            {
                $value | % { ConvertTo-NiceXml -Entity $_ -EntityName $itemType.Name } | % { $xList.Add($_) }
            }

            $xEntity.Add($xList)
        }
        else
        {
            if ($property.PropertyType -eq [DateTime])
            {
                $value = $value.ToUniversalTime().ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
            }

            if ($value)
            {
                $xProperty = New-XElement $property.Name $value
                $xEntity.Add($xProperty)
            }
        }
    }

    # TODO: return string?
    return $xEntity
}

function ConvertFrom-NiceXml([System.Xml.Linq.XElement] $XEntity = $(throw "XEntity required"))
{
    $entity = New-Object -TypeName ($XEntity.Name.LocalName)

    foreach ($property in $entity.GetType().GetProperties())
    {
        $propertyName = $property.Name
        $xProperty = $XEntity.Element($propertyName)
        if ($xProperty -eq $null)
        {
            continue
        }

        if ([Entity].IsAssignableFrom($property.PropertyType))
        {
            $entityValue = ConvertFrom-NiceXml $xProperty
            $entity."$propertyName" = $entityValue
        }
        elseif ($property.PropertyType.IsArray)
        {
            $itemType = $property.PropertyType.GetElementType()
            $listValue = $null

            if ($itemType.IsValueType -or ($itemType -eq [string]))
            {
                $listValue = $xProperty.Elements() | % { $_.Value }
            }
            else
            {
                $listValue = $xProperty.Elements() | % { ConvertFrom-NiceXml $_ }
            }

            $entity."$propertyName" = $listValue
        }
        else
        {
            $value = $xProperty.Value
            if ($property.PropertyType -eq [DateTime])
            {
                $value = [DateTime]::ParseExact($value, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
                $value = [DateTime]::SpecifyKind($value, 'Utc')
            }

            $entity."$propertyName" = $value
        }
    }

    return $entity
}
