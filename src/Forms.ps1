. $PSScriptRoot\TextSerialization.ps1

function Read-NiceXml()
{
    process
    {
        $content = Get-Content -Path $_ -Encoding UTF8 -Raw
        $doc = [System.Xml.Linq.XDocument]::Parse($content)
        ConvertFrom-NiceXml ($doc.Root)
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
        ForEach-Object { Join-Path $Config.AuditDir $_ } |
        Read-NiceXml |
        Write-NiceText -FilePath $file
    }

    Start-Process -FilePath 'notepad.exe' -ArgumentList $file -Wait

    $timer = Start-TimeOperation -Name 'New Meetup'

    $file |
        Read-NiceText |
        # TODO: Add content validation
        Save-Entity -CreateOnly

    $timer | Stop-TimeOperation
}
