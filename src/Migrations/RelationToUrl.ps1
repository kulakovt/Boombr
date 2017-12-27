Clear-Host

Set-StrictMode -version Latest
$ErrorActionPreference = 'Stop'

$InformationPreference = "Continue"
$DebugPreference = "Continue"
$VerbosePreference = "Continue"

. $PSScriptRoot\..\Model.ps1
. $PSScriptRoot\..\Serialization.ps1

$auditDir = Join-Path $PSScriptRoot '..\..\..\Audit\db' -Resolve

function Read-Talk()
{
    Get-ChildItem -Path (Join-Path $auditDir 'talks') -Filter '*.xml' |
    Read-NiceXml
}

function Read-Speaker()
{
    Get-ChildItem -Path (Join-Path $auditDir 'speakers') -Filter 'index.xml' -Recurse |
    Read-NiceXml
}

function Invoke-SpeakerUnlink()
{
    process
    {
        $speaker = [Speaker]$_

        $speaker.Links | Where-Object { $_ } |
        ForEach-Object {
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


function Invoke-TalkUnlink()
{
    process
    {
        $talk = [Talk]$_

        $talk.Links | Where-Object { $_ } |
        ForEach-Object {
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

Read-Speaker | Invoke-SpeakerUnlink | Save-Entity $auditDir -CreateOnly
Read-Talk | Invoke-TalkUnlink | Save-Entity $auditDir -CreateOnly

