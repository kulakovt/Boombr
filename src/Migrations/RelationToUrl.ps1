clear

Set-StrictMode -version Latest
$ErrorActionPreference = 'Stop'

$InformationPreference = "Continue"
$DebugPreference = "Continue"
$VerbosePreference = "Continue"

. $PSScriptRoot\..\Model.ps1
. $PSScriptRoot\..\Serialization.ps1 

$auditDir = Join-Path $PSScriptRoot '..\..\..\Audit\db' -Resolve

function Read-NiceXml()
{
    process
    {
        $content = $_ | Get-Content -Encoding UTF8 -Raw
        $doc = [System.Xml.Linq.XDocument]::Parse($content)
        ConvertFrom-NiceXml ($doc.Root)
    }
}

function Read-Talks()
{
    Get-ChildItem -Path (Join-Path $auditDir 'talks') -Filter '*.xml' |
    Read-NiceXml
}

function Read-Speakers()
{
    Get-ChildItem -Path (Join-Path $auditDir 'speakers') -Filter 'index.xml' -Recurse |
    Read-NiceXml
}

function Save-Entity()
{
    process
    {
        $entity = $_
        $id = $entity.Id
        $fileName = $null

        switch ($entity.GetType())
        {
            ([Talk])      { $fileName = "talks/$id.xml" }
            ([Speaker])   { $fileName = "speakers/$id/index.xml" }
            default       { throw "Entity not detected: $($_.FullName)" }
        }

        $file = Join-Path $auditDir $fileName
        if (-not (Test-Path $file -PathType Leaf))
        {
            throw "Can't find existing file: $file"
        }

        Write-Information "Save $($entity.Id)"

        (ConvertTo-NiceXml -Entity $entity).ToString() | Out-File -FilePath $file -Encoding UTF8
    }
}

function Unlink-Speaker()
{
    process
    {
        $speaker = [Speaker]$_

        $speaker.Links | ? { $_ } |
        % {
            $link = [Link]$_

            switch ($link.Relation)
            {
                Twitter { $speaker.TwitterUrl = $link.Url }
                Blog    { $speaker.BlogUrl = $link.Url }
                Contact { $speaker.ContactsUrl = $link.Url }
                Habr    { $speaker.HabrUrl = $link.Url }

                default { throw "Speaker link relation not found: $_" }
            }
        }

        $speaker.Links = $null
        $speaker
    }
}


function Unlink-Talk()
{
    process
    {
        $talk = [Talk]$_

        $talk.Links | ? { $_ } |
        % {
            $link = [Link]$_

            switch ($link.Relation)
            {
                Code  { $talk.CodeUrl = $link.Url }
                Slide { $talk.SlidesUrl = $link.Url }
                Video { $talk.VideoUrl = $link.Url }

                default { throw "Talk link relation not found: $_" }
            }
        }

        $talk.Links = $null
        $talk
    }
}


### Convert

Read-Speakers | Unlink-Speaker | Save-Entity
Read-Talks | Unlink-Talk | Save-Entity

