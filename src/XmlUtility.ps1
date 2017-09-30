$WikiConfig = @{
    CacheDir = Resolve-FullPath $Config.ArtifactsDir 'cache'
    WikiDir = Resolve-FullPath $Config.RootDir '..\..\SpbDotNet.wiki'
}

$WikiRepository = @{
    Communities = @{}
    Meetups = @{}
    Talks = @{}
    Speakers = @{}
    Friends = @{}
    Venues = @{}
}

function Test-WikiEnvironment()
{
    if (-not (Test-Path $WikiConfig.CacheDir))
    {
        New-Item -Path $WikiConfig.CacheDir -ItemType Directory | Out-Null
        Write-Information "Create Cache directory «$($WikiConfig.CacheDir)»"
    }
    else
    {
        Write-Information "Use Cache directory «$($WikiConfig.CacheDir)»"
    }

    if (-not (Test-Path -Path $WikiConfig.WikiDir))
    {
        throw "Wiki directory is not found at «$($WikiConfig.WikiDir)»"
    }
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
    Read-NiceXml
}

function Read-Meetup()
{
    Get-ChildItem -Path (Join-Path $Config.AuditDir 'meetups') -Filter '*.xml' |
    Read-NiceXml |
    Sort-Object -Property Date
}

function Read-Talk()
{
    Get-ChildItem -Path (Join-Path $Config.AuditDir 'talks') -Filter '*.xml' |
    Read-NiceXml
}

function Read-Speaker()
{
    Get-ChildItem -Path (Join-Path $Config.AuditDir 'speakers') -Filter 'index.xml' -Recurse |
    Read-NiceXml
}

function Read-Friend()
{
    Get-ChildItem -Path (Join-Path $Config.AuditDir 'friends') -Filter 'index.xml' -Recurse |
    Read-NiceXml
}

function Read-Venue()
{
    Get-ChildItem -Path (Join-Path $Config.AuditDir 'venues') -Filter '*.xml' |
    Read-NiceXml
}

function Convert-ToXml($Entities = $(throw "Entity required"), [string] $EntitiesName = $null)
{
    $xEntities = [System.Xml.Linq.XElement]::new([System.Xml.Linq.XName]$EntitiesName)
    foreach ($entity in $Entities) {
        $xEntity = ConvertTo-NiceXml -Entity $entity
        $xEntities.Add($xEntity)
    }

    return $xEntities
}

function Export-Xml()
{
    Test-WikiEnvironment

    $timer = Start-TimeOperation -Name 'Create XML'

    # Load all
    Read-Community | ForEach-Object { $WikiRepository.Communities.Add($_.Id, $_) }
    Write-Information "Load $($WikiRepository.Communities.Count) communities"
    Read-Meetup | ForEach-Object { $WikiRepository.Meetups.Add($_.Id, $_) }
    Write-Information "Load $($WikiRepository.Meetups.Count) meetups"
    Read-Talk | ForEach-Object { $WikiRepository.Talks.Add($_.Id, $_) }
    Write-Information "Load $($WikiRepository.Talks.Count) talks"
    Read-Speaker | ForEach-Object { $WikiRepository.Speakers.Add($_.Id, $_) }
    Write-Information "Load $($WikiRepository.Speakers.Count) speakers"
    Read-Friend | ForEach-Object { $WikiRepository.Friends.Add($_.Id, $_) }
    Write-Information "Load $($WikiRepository.Friends.Count) friends"
    Read-Venue | ForEach-Object { $WikiRepository.Venues.Add($_.Id, $_) }
    Write-Information "Load $($WikiRepository.Venues.Count) venues"

    # Export all

    $xRoot = [System.Xml.Linq.XElement]::new([System.Xml.Linq.XName]"xml")

    $xRoot.Add((Convert-ToXml -Entities $WikiRepository.Communities.Values -EntitiesName "Communities"))
    $xRoot.Add((Convert-ToXml -Entities $WikiRepository.Meetups.Values -EntitiesName "Meetups"))
    $xRoot.Add((Convert-ToXml -Entities $WikiRepository.Talks.Values -EntitiesName "Talks"))
    $xRoot.Add((Convert-ToXml -Entities $WikiRepository.Speakers.Values -EntitiesName "Speakers"))
    $xRoot.Add((Convert-ToXml -Entities $WikiRepository.Friends.Values -EntitiesName "Friends"))
    $xRoot.Add((Convert-ToXml -Entities $WikiRepository.Venues.Values -EntitiesName "Venues"))

    $xdoc = [System.Xml.Linq.XDocument]::new()
    $xDoc.Add($xRoot)

    $xDoc.Save($Config.RootDir + "/common.xml")

    $timer | Stop-TimeOperation
}
