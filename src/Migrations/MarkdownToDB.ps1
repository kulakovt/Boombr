﻿Clear-Host

Set-StrictMode -version Latest
$ErrorActionPreference = 'Stop'

. $PSScriptRoot\..\Model.ps1
. $PSScriptRoot\..\Serialization.ps1

$srcHome = "$PSScriptRoot\..\..\..\SpbDotNet.wiki"
$outHome = "$PSScriptRoot\..\..\artifacts\db"

$community = [Community]::new()
$community.Id = 'SpbDotNet'
$community.Name = 'SpbDotNet'

if (-not (Test-Path $srcHome))
{
    throw 'Markdown wiki source not found'
}

function ReCreateDirectory()
{
    process
    {
        if (Test-Path $_ -PathType Container)
        {
            Remove-Item $_ -Recurse -Force | Out-Null
        }

        New-Item $_ -ItemType Directory | Out-Null
    }
}

function TrimArray($content)
{
    function GetSpaceCount([array] $lines)
    {
        $count = 0
        foreach ($line in $lines)
        {
            if ($line -eq '')
            { $count++ }
            else
            { return $count }
        }
    }

    $result = $content.Trim()
    if (-not ($result -is [array]))
    {
        return $result
    }
    $start = GetSpaceCount $result
    $end = GetSpaceCount ($result[($result.Length - 1)..0])
    $end = $result.Length - $end - 1
    $result = $result[$start..$end]

    if ($result.Length -eq 1)
    {
        return $result[0]
    }
    else
    {
        return $result
    }
}

function MarkdownToDict()
{
    begin
    {
        $dict = @{}
        $key = $null
        $content = @()
    }
    process
    {
        if ($_.StartsWith("#"))
        {
            if ($key)
            {
                $c = TrimArray $content
                $dict.Add($key, $c)
            }

            $key = $_.Trim('#',' ')
            $content = @()
        }
        else
        {
            $content += $_
        }
    }
    end
    {
        if ($key)
        {
            $c = TrimArray $content
            $dict.Add($key, $c)
        }

        return $dict
    }
}

function ReplaceHead($lines, [string] $firstHead, [string] $secondHead)
{
    [System.Collections.ArrayList]$list = $lines
    $firstLine = $list[0].Trim('#', ' ')
    $list.RemoveAt(0)
    $list.InsertRange(0, @(('#'+$firstHead), $firstLine, ('#'+$secondHead)))
    return $list
}

function Assert($condition)
{
    process
    {
        if (-not (& $condition $_))
        {
            throw ('Assert mismatch: ' + $condition.ToString())
        }
    }
}

filter ConvertTo-Link()
{
    switch -wildcard ($_)
    {
        "- Twitter: *"
        {
            $rel = [LinkRelation]::Twitter
        }
        "- Блог: *"
        {
            $rel = [LinkRelation]::Blog
        }
        "- LinkedIn: *"
        {
            $rel = [LinkRelation]::Contact
        }
        "- Хабрахабр: *"
        {
            $rel = [LinkRelation]::Habr
        }

        "*://github.com/*"
        {
            $rel = [LinkRelation]::Code
        }
        "*://www.slideshare.net/*"
        {
            $rel = [LinkRelation]::Slide
        }
        "*://www.youtube.com/*"
        {
            $rel = [LinkRelation]::Video
        }
        "- StackOverflow: *"
        {
            return
        }
        default
        {
            throw "Link relation not found for: $_"
        }
    }

    $_ -match '(?<Url>https?://[^\s]+)' | Assert { $_ -eq $true }

    $link = [Link]::new()
    $link.Relation = $rel
    $link.Url = $Matches.Url.Trim(')')
    $link.Url.IsAbsoluteUri | Assert { $_ -eq $true }
    return $link
}

function ReadSpeaker($Path)
{
    $content = Get-Content -Path $Path -Encoding UTF8
    $dict = ReplaceHead $content 'Имя' 'Описание' | MarkDownToDict
    #$dict | Out-Host

    $s = [Speaker]::new()
    $s.Id = [IO.Path]::GetFileNameWithoutExtension($Path)
    $s.Name = $dict['Имя']

    # Company
    $companyLine = $dict['Описание'] | Where-Object { $_ -like 'Работает*' }
    $companyLine | Assert { $_ -ne $null }
    $companyLine -match '.*\[(?<Name>.+)\]\((?<Url>.+?)\)' | Assert { $_ -eq $true }
    $s.CompanyName = $Matches.Name
    $s.CompanyUrl = $Matches.Url

    $s.Description = $dict['Описание'] | Where-Object { ($_ -notlike '`[!`[Photo`]*') -and ($_ -notlike 'Работает*') } | Out-String
    $s.Description = $s.Description.Trim()
    $s.Links = $dict['Контакты'] | Select-NotNull | ConvertTo-Link

    return $s
}

filter Select-NotNull()
{
    if (($_) -and ($_ -ne ''))
    {
        return $_
    }
}

filter Select-MeetupFile()
{
    if ($_.Name -like 'Meetup-*')
    {
        return $_
    }
}

filter Select-SpeakerFile()
{
    $notSpeakers = @(
        'Brave-CoreCLR.md'
        'Data-grid.md'
        'DSL-unexpurgated.md'
        'Dynamic-Prototyping.md'
        'GC-Tips.md'
        'Machine-learning.md'
        'Practice-WCF.md'
        'Project-Rider.md'
        'Structured-logging.md'
        'F-Battle.md'
        'Functional-NET.md'
        'Rider-Internals.md'
        'Windows-Containers.md'
        'Memory-Model.md'
        'Web-security.md')

    if (
       (($_.Name -split '-').Length -eq 2) -and
       (-not ($_ | Select-MeetupFile)) -and
       (-not $notSpeakers.Contains($_.Name))
       )
    {
        return $_
    }
}

filter Select-VenueFile()
{
    $venues = @(
        'DotNext.md'
        'JetBrains.md'
        'ITGM.md'
        'Luxoft.md'
        'DataArt.md'
        'EMC.md'
        'SEMrush.md',
        'EPAM.md')

    if ($venues.Contains($_.Name))
    {
        return $_
    }
}

filter Select-TalkFile()
{
    if (
        ($_.Name -ne 'Home.md') -and
        ($_.Name -ne 'SpbDotNet.md') -and
        (-not ($_ | Select-MeetupFile)) -and
        (-not ($_ | Select-VenueFile)) -and
        (-not ($_ | Select-SpeakerFile)))
    {
        return $_
    }
}

function ReadTalk($Path)
{
    $content = Get-Content -Path $Path -Encoding UTF8
    $dict = ReplaceHead $content 'Название' 'Описание' | MarkDownToDict
    #$dict | Out-Host

    $talk = [Talk]::new()
    $talk.Id = [IO.Path]::GetFileNameWithoutExtension($Path)

    $dict['Название'] -match '(?<Speakers>.+)\s+«(?<Title>.+)»' | Assert { $_ -eq $true }
    $talk.Title = $Matches.Title
    $talk.SpeakerIds = $Matches.Speakers.Trim() -split ',\s*' | ForEach-Object { Find-SpeakerIdByName $_ }

    $talk.Description = $dict['Описание'] |
        Where-Object { ($_ -ne '---') -and ($_ -notlike 'Доклад был представлен*')  -and ($_ -notlike 'Круглый стол был представлен*') } |
        Out-String
    $talk.Description = $talk.Description.Trim()
    $dict['Описание'] | Where-Object { ($_ -like 'Доклад был представлен*') -or ($_ -like 'Круглый стол был представлен*') } |
                        ForEach-Object { $_ -match 'Meetup (?<Meetup>\d+)' } | Assert { $_ -eq $true }
    #$talk.MeetupId = "SpbDotNet-$($Matches.Meetup)"

    $talk.Links = @(
        $dict['Демо'] | Select-NotNull | ConvertTo-Link
        $dict['Слайды'] -replace 'https?://cdn.slidesharecdn.com/','' `
                        -replace 'Ждём :hourglass:','' `
                        -replace '.*http://dmitriyvlasov.github.io/Presentations/review-fsharp-4.html\)','' `
                        | Select-NotNull | ConvertTo-Link
        $dict['Видео'] -replace 'http://i.ytimg.com/','' `
                       -replace 'Ждём :hourglass:','' `
                       -replace ':movie_camera: Видео нет','' `
                       | Select-NotNull | ConvertTo-Link
    )

    $knownRefs = @('Lack-of-CPlusPlus-in-CSharp-1','Lack-of-CPlusPlus-in-CSharp-2','Lack-of-CPlusPlus-in-CSharp-3')
    if ($knownRefs -contains $talk.Id)
    {
        $talk.SeeAlsoTalkIds = $knownRefs -ne $talk.Id
    }

    return $talk
}

function Find-SpeakerIdByName([string] $SpeakerName)
{
    $id = Get-ChildItem (Join-Path $outHome 'speakers') -File 'index.xml' -Recurse | ForEach-Object {
        [xml]$content = Get-Content -Path $_.FullName -Encoding UTF8
        if ($content.Speaker.Name -eq $SpeakerName)
        {
            return $content.Speaker.Id
        }
    }

    if (-not $id)
    {
        throw "Speaker not found: $SpeakerName"
    }

    return $id
}

function ReadFriend($Path)
{
    $content = Get-Content -Path $Path -Encoding UTF8
    $dict = ReplaceHead $content 'Имя' 'Описание' | MarkDownToDict
    #$dict | Out-Host

    $f = [Friend]::new()
    $f.Id = [IO.Path]::GetFileNameWithoutExtension($Path)
    $f.Name = $dict['Имя']

    # Company
    $descLine = $dict['Описание'] | Where-Object { $_ -notlike '`[!`[Logo`]*' } | Out-String
    $descLine | Assert { $_ -ne $null }
    $descLine = $descLine.Trim()
    $descLine -match '^\[(?<Name>.+)\]\((?<Url>.+?)\)(?<Desc>.*)' | Assert { $_ -eq $true }

    $f.Url = $Matches.Url
    $f.Description = "$($Matches.Name)$($Matches.Desc)".Trim()

    return $f
}

function GetVenueByFriendId([string] $FriendId)
{
    $v = @{}
    switch ($FriendId)
    {
        'DotNext'
        {
            $v.Id = 'Spb-Radison'
            $v.Name = 'Гостиница «Park Inn by Radisson Пулковская»'
        }
        'JetBrains'
        {
            $v.Id = 'Spb-Universe'
            $v.Name = 'БЦ «Universe»'
        }
        'ITGM'
        {
            $v.Id = 'Spb-House'
            $v.Name = 'КДЦ «Club House»'
        }
        'Luxoft'
        {
            $v.Id = 'Spb-Osen'
            $v.Name = 'БЦ «Осень»'
        }
        'DataArt'
        {
            $v.Id = 'Spb-Telekom'
            $v.Name = 'БЦ «Телеком СПб»'
        }
        'EMC'
        {
            $v.Id = 'Spb-Ostrov'
            $v.Name = 'БЦ «Остров»'
        }
        'SEMrush'
        {
            $v.Id = 'Spb-Ankor'
            $v.Name = 'БЦ «Анкор»'
        }
        'EPAM'
        {
            $v.Id = 'Spb-Welcome'
            $v.Name = 'Пространство «Welcome»'
        }

        default
        {
            throw "Venue $FriendId not found"
        }
    }

    return $v
}

function ReadVenue($Path)
{
    $content = Get-Content -Path $Path -Encoding UTF8
    $dict = ReplaceHead $content 'Имя' 'Описание' | MarkDownToDict
    #$dict | Out-Host

    $v = [Venue]::new()
    $v.Id = [IO.Path]::GetFileNameWithoutExtension($Path)
    $v.Name = $dict['Имя']

    $dict['Адрес'] -match '^\[(?<Address>.+)\]\((?<Url>.+)\)$' | Assert { $_ -eq $true }

    $v.Address = $Matches.Address
    $v.MapUrl = $Matches.Url

    $f = GetVenueByFriendId -FriendId $v.Id
    $v.Id = $f.Id
    $v.Name = $f.Name

    return $v
}

function ReadMeetup($Path)
{
    $content = Get-Content -Path $Path -Encoding UTF8
    $dict = ReplaceHead $content 'Имя' 'Описание' | MarkDownToDict
    #$dict | Out-Host

    $m = [Meetup]::new()
    $m.CommunityId = $community.Id

    $dict['Имя'] -match '^Встреча №(?<Num>\d+)$' | Assert { $_ -eq $true }
    $m.Number = $Matches.Num

    $m.Id = "SpbDotNet-$($m.Number)"

    $dict['Описание'] -match '^Встреча №\d+ состоялась (?<Date>.+)$' | Assert { $_ -eq $true }
    $d = [DateTime]::ParseExact($Matches.Date, 'D', [Globalization.CultureInfo]::GetCultureInfo("ru"))
    $m.Date = [DateTime]::SpecifyKind($d, 'Utc')


    $dict['Место'] -match '^Встреча прошла в гостях у( компании| конференции)? \[\[(?<Comp>.+)\]\].*$' | Assert { $_ -eq $true }
    $m.FriendIds = @($Matches.Comp)

    $m.VenueId = (GetVenueByFriendId -FriendId ($m.FriendIds[0])).Id

    $m.TalkIds = $dict['Доклады'] | ForEach-Object {
        $_ -split '\|' | Select-Object -Last 1 | ForEach-Object { $_.TrimEnd(']') -replace ' ','-' }
    }

    return $m
}


######## Main #########

"$outHome\speakers" | ReCreateDirectory
Get-ChildItem $srcHome -File '*.md' | Select-SpeakerFile | ForEach-Object {

    Write-Host $_.Name
    $speaker = ReadSpeaker -Path $_.FullName
    $bucket = Join-Path "$outHome\speakers" ($speaker.Id)
    $bucket | ReCreateDirectory

    $index = Join-Path $bucket 'index.xml'
    (ConvertTo-NiceXml $speaker 'Speaker').ToString() | Out-File -FilePath $index -Encoding UTF8

    $avaOrigin = Join-Path $srcHome ($speaker.Id) | Join-Path -ChildPath ($speaker.Id + '.jpg')
    $avaSmall = Join-Path $srcHome ($speaker.Id) | Join-Path -ChildPath ($speaker.Id + '-small.jpg')
    Copy-Item $avaOrigin (Join-Path $bucket 'avatar.jpg')
    Copy-Item $avaSmall (Join-Path $bucket 'avatar.small.jpg')
}

"$outHome\talks" | ReCreateDirectory
Get-ChildItem $srcHome -File '*.md' | Select-TalkFile | ForEach-Object {

    Write-Host $_.Name
    $talk = ReadTalk -Path $_.FullName
    $file = Join-Path "$outHome\talks" ($talk.Id + '.xml')
    (ConvertTo-NiceXml $talk 'Talk').ToString() | Out-File -FilePath $file -Encoding UTF8
}

"$outHome\friends" | ReCreateDirectory
Get-ChildItem $srcHome -File '*.md' | Select-VenueFile | ForEach-Object {

    Write-Host $_.Name
    $friend = ReadFriend -Path $_.FullName
    $bucket = Join-Path "$outHome\friends" ($friend.Id)
    $bucket | ReCreateDirectory

    $index = Join-Path $bucket 'index.xml'
    (ConvertTo-NiceXml $friend 'Friend').ToString() | Out-File -FilePath $index -Encoding UTF8

    $avaOrigin = Join-Path $srcHome 'Friends' | Join-Path -ChildPath ($friend.Id + '.png')
    $avaSmall = Join-Path $srcHome 'Friends' | Join-Path -ChildPath ($friend.Id + '-small.png')
    Copy-Item $avaOrigin (Join-Path $bucket 'logo.png')
    Copy-Item $avaSmall (Join-Path $bucket 'logo.small.png')
}

"$outHome\venues" | ReCreateDirectory
Get-ChildItem $srcHome -File '*.md' | Select-VenueFile | ForEach-Object {

    Write-Host $_.Name
    $venue = ReadVenue -Path $_.FullName
    $file = Join-Path "$outHome\venues" ($venue.Id + '.xml')
    (ConvertTo-NiceXml $venue 'Venue').ToString() | Out-File -FilePath $file -Encoding UTF8
}

"$outHome\meetups" | ReCreateDirectory
Get-ChildItem $srcHome -File '*.md' | Select-MeetupFile | ForEach-Object {

    Write-Host $_.Name
    $meetup = ReadMeetup -Path $_.FullName
    $file = Join-Path "$outHome\meetups" ($meetup.Id + '.xml')
    (ConvertTo-NiceXml $meetup 'Meetup').ToString() | Out-File -FilePath $file -Encoding UTF8
}

"$outHome\communities" | ReCreateDirectory
$community | ForEach-Object {

    Write-Host $_.Name
    $file = Join-Path "$outHome\communities" ($_.Id + '.xml')
    (ConvertTo-NiceXml $_ 'Community').ToString() | Out-File -FilePath $file -Encoding UTF8
}
