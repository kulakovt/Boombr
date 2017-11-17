$Audit = @{
    Communities = New-Object System.Collections.Generic.List[System.Object]
    Meetups = New-Object System.Collections.Generic.List[System.Object]
    Talks = New-Object System.Collections.Generic.List[System.Object]
    Speakers = New-Object System.Collections.Generic.List[System.Object]
    Friends = New-Object System.Collections.Generic.List[System.Object]
    Venues = New-Object System.Collections.Generic.List[System.Object]
}

function Read-NiceXml()
{
    process
    {
        $content = $_ | Get-Content -Encoding UTF8 -Raw
        $doc = [System.Xml.Linq.XDocument]::Parse($content)
        ConvertFrom-NiceXml ($doc.Root)
    }
}

function Read-Community()
{
    Get-ChildItem -Path (Join-Path $Config.AuditDir 'communities') -Filter '*.xml' |
    Read-NiceXml |
    ForEach-Object { $Audit.Communities.Add($_) }
}

function Read-Meetup()
{
    Get-ChildItem -Path (Join-Path $Config.AuditDir 'meetups') -Filter '*.xml' |
    Read-NiceXml |
    ForEach-Object { $Audit.Meetups.Add($_) }
}

function Read-Talk()
{
    Get-ChildItem -Path (Join-Path $Config.AuditDir 'talks') -Filter '*.xml' |
    Read-NiceXml |
    ForEach-Object { $Audit.Talks.Add($_) }
}

function Read-Speaker()
{
    Get-ChildItem -Path (Join-Path $Config.AuditDir 'speakers') -Filter 'index.xml' -Recurse |
    Read-NiceXml |
    ForEach-Object { $Audit.Speakers.Add($_) }
}

function Read-Friend()
{
    Get-ChildItem -Path (Join-Path $Config.AuditDir 'friends') -Filter 'index.xml' -Recurse |
    Read-NiceXml |
    ForEach-Object { $Audit.Friends.Add($_) }
}

function Read-Venue()
{
    Get-ChildItem -Path (Join-Path $Config.AuditDir 'venues') -Filter '*.xml' |
    Read-NiceXml |
    ForEach-Object { $Audit.Venues.Add($_) }
}

function Write-Entity($Entities = $(throw "Entities required"), [string] $EntitiesName = $null)
{
    $xRoot = [System.Xml.Linq.XElement]::new([System.Xml.Linq.XName]$EntitiesName)

    foreach ($entity in $Entities) {
        $xEntity = ConvertTo-NiceXml -Entity $entity
        $xRoot.Add($xEntity)
    }

    $xdoc = [System.Xml.Linq.XDocument]::new()
    $xDoc.Add($xRoot)

    $xDoc.Save((Join-Path -Path $Config.ArtifactsDir -ChildPath ($EntitiesName + ".xml")))
}

function Export-Xml()
{
    $timer = Start-TimeOperation -Name 'Create XMLs'

    # Load all

    Read-Community
    Write-Information "Load $($Audit.Communities.Count) communities"
    Read-Meetup
    Write-Information "Load $($Audit.Meetups.Count) meetups"
    Read-Talk
    Write-Information "Load $($Audit.Talks.Count) talks"
    Read-Speaker
    Write-Information "Load $($Audit.Speakers.Count) speakers"
    Read-Friend
    Write-Information "Load $($Audit.Friends.Count) friends"
    Read-Venue
    Write-Information "Load $($Audit.Venues.Count) venues"

    # Export all

    Write-Entity $Audit.Communities -EntitiesName "Communities"
    Write-Entity $Audit.Meetups -EntitiesName "Meetups"
    Write-Entity $Audit.Talks -EntitiesName "Talks"
    Write-Entity $Audit.Speakers -EntitiesName "Speakers"
    Write-Entity $Audit.Friends -EntitiesName "Friends"
    Write-Entity $Audit.Venues -EntitiesName "Venues"

    $timer | Stop-TimeOperation
}
