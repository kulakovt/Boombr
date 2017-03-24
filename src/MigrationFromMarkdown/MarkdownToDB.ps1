clear

Set-StrictMode -version Latest
$ErrorActionPreference = 'Stop'

. $PSScriptRoot\..\Model.ps1
. $PSScriptRoot\..\Serialization.ps1 

$srcHome = "$PSScriptRoot\..\..\..\SpbDotNet.wiki"
$outHome = "$PSScriptRoot\..\..\artifacts\db"

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
            if ($key -ne $null)
            {
                $c = if ($content.Count -eq 1) { $content[0] } else { $content }
                $dict.Add($key, $c)
            }
 
            $key = $_.Trim('#',' ')
            $content = @()
        }
        elseif ($_.Trim() -ne '')
        {
            $content += $_
        }
    }
    end
    {
        if ($key -ne $null)
        {
            $c = if ($content.Count -eq 1) { $content[0] } else { $content }
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

filter Parse-Link()
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
    $companyLine = $dict['Описание'] | ? { $_ -like 'Работает*' }
    $companyLine | Assert { $_ -ne $null }
    $companyLine -match '.*\[(?<Name>.+)\]\((?<Url>.+?)\)' | Assert { $_ -eq $true }
    $s.CompanyName = $Matches.Name
    $s.CompanyUrl = $Matches.Url

    $s.Description = $dict['Описание'] | ? { ($_ -notlike '`[!`[Photo`]*') -and ($_ -notlike 'Работает*') } | Out-String
    $s.Description = $s.Description.Trim()
    $s.Links = $dict['Контакты'] | Only-NotNull | Parse-Link

    return $s
}

filter Only-NotNull()
{
    if (($_ -ne $null) -and ($_ -ne ''))
    {
        return $_
    }
}

filter Only-Meetups()
{
    if ($_.Name -like 'Meetup-*')
    {
        return $_
    }
}

filter Only-Speakers()
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
       (($_ | Only-Meetups) -eq $null) -and
       (-not $notSpeakers.Contains($_.Name))
       )
    {
        return $_
    }
}

filter Only-Venue()
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

filter Only-Talks()
{
    if (
        ($_.Name -ne 'Home.md') -and
        (($_ | Only-Meetups) -eq $null) -and
        (($_ | Only-Venue) -eq $null) -and
        (($_ | Only-Speakers) -eq $null))
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
    $talk.SpeakerIds = $Matches.Speakers.Trim() -split ',\s*' | % { Lookup-SpeakerIdByName $_ }
    
    $talk.Description = $dict['Описание'] | ? { ($_ -ne '---') -and ($_ -notlike 'Доклад был представлен*') } | Out-String
    $talk.Description = $talk.Description.Trim()
    $dict['Описание'] | ? { ($_ -like 'Доклад был представлен*') -or ($_ -like 'Круглый стол был представлен*') } |
                        % { $_ -match 'Meetup (?<Meetup>\d+)' } | Assert { $_ -eq $true }
    #$talk.MeetupId = "SpbDotNet-$($Matches.Meetup)"

    $talk.Links = @(
        $dict['Демо'] | Only-NotNull | Parse-Link
        $dict['Слайды'] -replace 'https?://cdn.slidesharecdn.com/','' `
                        -replace 'Ждём :hourglass:','http://www.slideshare.net/waiting' `
                        -replace '.*http://dmitriyvlasov.github.io/Presentations/review-fsharp-4.html\)','' `
                        | Only-NotNull | Parse-Link
        $dict['Видео'] -replace 'http://i.ytimg.com/','' `
                       -replace 'Ждём :hourglass:','http://www.youtube.com/waiting' `
                       -replace ':movie_camera: Видео нет','' `
                       | Only-NotNull | Parse-Link
    )

    return $talk
}

function Lookup-SpeakerIdByName([string] $SpeakerName)
{
    $id = ls (Join-Path $outHome 'speakers') -File 'index.xml' -Recurse | % {
        [xml]$content = Get-Content -Path $_.FullName -Encoding UTF8
        if ($content.Speaker.Name -eq $SpeakerName)
        {
            return $content.Speaker.Id
        }
    }

    if ($id -eq $null)
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
    $descLine = $dict['Описание'] | ? { $_ -notlike '`[!`[Logo`]*' } | Out-String
    $descLine | Assert { $_ -ne $null }
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

    $dict['Имя'] -match '^Встреча №(?<Num>\d+)$' | Assert { $_ -eq $true }
    $m.Number = $Matches.Num

    $m.Id = "SpbDotNet-$($m.Number)"

    $dict['Описание'] -match '^Встреча №\d+ состоялась (?<Date>.+)$' | Assert { $_ -eq $true }
    $d = [DateTime]::ParseExact($Matches.Date, 'D', [Globalization.CultureInfo]::GetCultureInfo("ru"))
    $m.Date = [DateTime]::SpecifyKind($d, 'Utc')
    

    $dict['Место'] -match '^Встреча прошла в гостях у( компании| конференции)? \[\[(?<Comp>.+)\]\].*$' | Assert { $_ -eq $true }
    $m.FriendIds = @($Matches.Comp)

    $m.VenueId = (GetVenueByFriendId -FriendId ($m.FriendIds[0])).Id

    $m.TalkIds = $dict['Доклады'] | % {
        $_ -split '\|' | Select-Object -Last 1 | % { $_.TrimEnd(']') -replace ' ','-' }
    }

    return $m
}


######## Main #########


"$outHome\speakers" | ReCreateDirectory
ls $srcHome -File '*.md' | Only-Speakers | % {

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
ls $srcHome -File '*.md' | Only-Talks | % {

    Write-Host $_.Name
    $talk = ReadTalk -Path $_.FullName
    $file = Join-Path "$outHome\talks" ($talk.Id + '.xml')
    (ConvertTo-NiceXml $talk 'Talk').ToString() | Out-File -FilePath $file -Encoding UTF8
}

"$outHome\friends" | ReCreateDirectory
ls $srcHome -File '*.md' | Only-Venue | % {

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
ls $srcHome -File '*.md' | Only-Venue | % {

    Write-Host $_.Name
    $venue = ReadVenue -Path $_.FullName
    $file = Join-Path "$outHome\venues" ($venue.Id + '.xml')
    (ConvertTo-NiceXml $venue 'Venue').ToString() | Out-File -FilePath $file -Encoding UTF8
}

"$outHome\meetups" | ReCreateDirectory
ls $srcHome -File '*.md' | Only-Meetups | % {

    Write-Host $_.Name
    $meetup = ReadMeetup -Path $_.FullName
    $file = Join-Path "$outHome\meetups" ($meetup.Id + '.xml')
    (ConvertTo-NiceXml $meetup 'Meetup').ToString() | Out-File -FilePath $file -Encoding UTF8
}
