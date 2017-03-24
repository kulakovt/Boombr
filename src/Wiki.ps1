clear

#Requires -Version 5.0

Set-StrictMode -version Latest
$ErrorActionPreference = 'Stop'

$InformationPreference = "Continue"
$DebugPreference = "Continue"
$VerbosePreference = "Continue"

. $PSScriptRoot\Model.ps1
. $PSScriptRoot\Serialization.ps1 

$artifactsDir = "$PSScriptRoot\..\artifacts"
$dbDir = Join-Path $artifactsDir 'db'
$wikiDir = Join-Path $artifactsDir 'wiki'
$offline = $true


if (Test-Path $wikiDir -PathType Container)
{
    Remove-Item $wikiDir -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
}
New-Item $wikiDir -ItemType Directory -ErrorAction SilentlyContinue | Out-Null


$allMeetups = @{}
$allTalks = @{}
$allSpeakers = @{}
$allFriends = @{}
$allVenues = @{}


function Read-NiceXml()
{
    process
    {
        $content = $_ | Get-Content -Encoding UTF8 -Raw
        $doc = [System.Xml.Linq.XDocument]::Parse($content)
        ConvertFrom-NiceXml ($doc.Root)
    }
}

function Read-Meetups()
{
    Get-ChildItem -Path (Join-Path $dbDir 'meetups') -Filter '*.xml' |
    Read-NiceXml |
    Sort-Object -Property Number
}

function Read-Talks()
{
    Get-ChildItem -Path (Join-Path $dbDir 'talks') -Filter '*.xml' |
    Read-NiceXml
}

function Read-Speakers()
{
    Get-ChildItem -Path (Join-Path $dbDir 'speakers') -Filter 'index.xml' -Recurse |
    Read-NiceXml
}

function Read-Friends()
{
    Get-ChildItem -Path (Join-Path $dbDir 'friends') -Filter 'index.xml' -Recurse |
    Read-NiceXml
}

function Read-Venues()
{
    Get-ChildItem -Path (Join-Path $dbDir 'venues') -Filter '*.xml' |
    Read-NiceXml
}

function Export-Meetup()
{
    # [Meetup]
    process
    {
        Write-Information $_.Id
        $path = Join-Path $wikiDir "Meetup-$($_.Number).md"
        $content = $_ | Format-MeetupPage
        $content | Set-Content -Path $path -Encoding UTF8
    }
}

function Export-Friend([string] $FriendDir = $(throw "Friend dir required"))
{
    begin
    {
        $wikiImageDir = Join-Path $wikiDir "Friends"
        if (-not (Test-Path $wikiImageDir -PathType Container))
        {
            New-Item $wikiImageDir -ItemType Directory | Out-Null
        }
    }
    # [Friend]
    process
    {
        Write-Information $_.Id

        $dbImagemageDir = Join-Path $FriendDir $_.Id
        Copy-Item -Path (Join-Path $dbImagemageDir 'logo.png') -Destination (Join-Path $wikiImageDir "$($_.Id).png")
        Copy-Item -Path (Join-Path $dbImagemageDir 'logo.small.png') -Destination (Join-Path $wikiImageDir "$($_.Id)-small.png")

        $path = Join-Path $wikiDir "$($_.Id).md"
        $content = $_ | Format-FriendPage
        $content | Set-Content -Path $path -Encoding UTF8
    }
}

function Export-Talk()
{
    # [Talk]
    process
    {
        Write-Information $_.Id
        $path = Join-Path $wikiDir "$($_.Id).md"
        $content = $_ | Format-TalkPage
        $content | Set-Content -Path $path -Encoding UTF8
    }
}

function Get-OpenGraph()
{
    process
    {
        $url = [Uri]$_
        $content = Invoke-WebRequest -Uri $url
        $meta = $content.ParsedHtml.getElementsByTagName('meta') | ? { ($_.outerHTML -ne $null) -and ($_.outerHTML.Contains("property=`"og:")) }

        function Get-PropertyContent([string] $propertyValue)
        {
            $meta |
            # This is not the correct search, but the fastest
            ? { $_.outerHTML.Contains("property=`"og:$propertyValue`"") } |
            % { $_.content } |
            Select-Object -First 1
        }

        @{
            SiteName = Get-PropertyContent 'site_name'
            Type = Get-PropertyContent 'type'
            #Url = Get-PropertyContent 'url'
            Title = Get-PropertyContent 'title'
            Description = Get-PropertyContent 'description'
            Image = Get-PropertyContent 'image'
        }
    }
}

function Format-RuDate([DateTime] $Date = $(throw "Date required"))
{
    Get-Date -Date $Date -Format ([Globalization.CultureInfo]::GetCultureInfo("ru").DateTimeFormat.LongDatePattern)
}

function Format-TalkLine()
{
    # [Talk].Id
    process
    {
        $talk = $allTalks[$_]
        $speaker = $talk.SpeakerIds |
        % { $allSpeakers[$_] } |
        % { "[[$($_.Name)|$($_.Id)]]" }

        "$($speaker -join ', ') [[«$($talk.Title)»|$($talk.Id)]]"
    }
}

function Format-MeetupLine()
{
    # [Meetup]
    process
    {
        "[[Встреча №$($_.Number) ($(Format-RuDate -Date $_.Date))|Meetup-$($_.Number)]]"
    }
}

function Format-SpeakerLine()
{
    # [Speaker]
    process
    {
        "[[$($_.Name)|$($_.Id)]]"
    }
}

function Format-ImageLinkLine()
{
    process
    {
        $url = [Uri]$_
        if ($offline)
        {
            return $url
        }

        $og = $link.Url | Get-OpenGraph
        if (($og.Title -eq $null) -or ($og.Image -eq $null))
        {
            return $url
        }

        "[![$($og.Title)]($($og.Image))]($url)"
    }
}

function Format-LinkLine()
{
    process
    {
        $link = [Link]$_
        switch ($link.Relation)
        {
            Code
            {
                '## Демо'
            }
            Slide
            {
                '## Слайды'
            }

            Video
            {
                '## Видео'
            }

            default
            {
                throw "Format not found link relation: $_"
            }
        }

        $link.Url | Format-ImageLinkLine
        ''
    }
}

function Format-ChainLine()
{
    begin
    {
        $all = @()
    }
    process
    {
        $all += $_
    }
    end
    {
        if ($all.Length -eq 0) { return }
        if ($all.Length -eq 1) { return $all[0] }

        $head = $all | Select-Object -First ($all.Length - 1)
        $last = $all | Select-Object -Last 1

        "$($head -join ', ') и $last"
    }
}

filter Only-NotNull()
{
    if (($_ -ne $null) -and ($_ -ne ''))
    {
        $_
    }
}

function Format-MeetupPage()
{
    # [Meetup]
    process
    {
@"
# Встреча №$($_.Number)

Встреча №$($_.Number) состоялась $(Format-RuDate -Date $_.Date)

## Доклады

"@
        $_.TalkIds | Format-TalkLine | % { "- $_" }
        $rank = if ($_.FriendIds -contains 'ITGM') { '' } elseif ($_.FriendIds -contains 'DotNext') { 'конференции ' } else { 'компании ' }
        # TODO: refer to Friend Name
        $friends = $_.FriendIds | % { "[[$_]]" }
        $venue = $allVenues[$_.VenueId]
        # TODO: remove venue Name from Address part
@"

## Место

Встреча прошла в гостях у $rank$($friends -join ', ') по адресу: [$($venue.Address)]($($venue.MapUrl)).
"@
    }
}

function Format-FriendPage()
{
    # [Friend]
    process
    {
        # TODO: Remove friend Name from Description
        $id = $_.Id
@"
# $($_.Name)

[![Logo](./Friends/$id-small.png)](./Friends/$id.png)

$($_.Url)

$($_.Description)

## Встречи

"@

        $allMeetups.Values |
        Sort-Object -Property 'Number' |
        ? { $_.FriendIds -contains $id } |
        Format-MeetupLine |
        % { "- $_" }
    }
}

function Format-TalkPage()
{
    # [Talk]
    process
    {
        [array]$speakers = $_.SpeakerIds | % { $allSpeakers[$_] }
        $speakersVerb = if ($speakers.Length -eq 1) { 'представил' } else { 'представили' }

        $id = $_.Id
        $meetup = $allMeetups.Values |
        ? { $_.TalkIds -contains $id } |
        % { "[[Встречи №$($_.Number)|Meetup-$($_.Number)]]" }

@"
# $($speakers | % { $_.Name } | Format-ChainLine) «$($_.Title)»

$($_.Description)

---

Доклад $speakersVerb $($speakers | Format-SpeakerLine | Format-ChainLine) в рамках $meetup.

"@
        $_.Links | Only-NotNull | Format-LinkLine
    }
}

### Load all
Read-Meetups | % { $allMeetups.Add($_.Id, $_) }
Write-Debug "Load $($allMeetups.Count) meetups"
Read-Talks | % { $allTalks.Add($_.Id, $_) }
Write-Debug "Load $($allTalks.Count) talks"
Read-Speakers | % { $allSpeakers.Add($_.Id, $_) }
Write-Debug "Load $($allSpeakers.Count) speakers"
Read-Friends | % { $allFriends.Add($_.Id, $_) }
Write-Debug "Load $($allFriends.Count) friends"
Read-Venues | % { $allVenues.Add($_.Id, $_) }
Write-Debug "Load $($allVenues.Count) venues"

### Export all
#$allMeetups.Values | Export-Meetup
#$allFriends.Values | Export-Friend -FriendDir (Join-Path $dbDir 'friends')
$allTalks.Values | Export-Talk
