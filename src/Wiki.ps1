﻿. $PSScriptRoot\Wiki.YouTube.ps1

$WikiConfig = @{
    CacheDir = Resolve-FullPath $Config.ArtifactsDir 'cache'
    WikiDir = Resolve-FullPath $Config.RootDir '..\..\BrandBook.wiki'
    DotNetRuChannelId = 'UCHFl23Ah_l4gEUTXYUStQdQ'
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

function Export-Home([Community[]] $Communities)
{
    Write-Verbose "Export Home ($($Communities.Count))"

    $path = Join-Path $WikiConfig.WikiDir "Home.md"
    $content = Format-HomePage -Communities $Communities
    $content | Set-Content -Path $path -Encoding UTF8
}

function Export-VideoRatingPage()
{
    Write-Verbose "Export Rating"

    $path = Join-Path $WikiConfig.WikiDir "LikedVideos.md"
    $content = Format-VideoRatingPage
    $content | Set-Content -Path $path -Encoding UTF8
}

function Export-Community()
{
    process
    {
        $community = [Community]$_
        Write-Verbose "Export community $($community.Id)"

        $path = Join-Path $WikiConfig.WikiDir "$($community.Id).md"
        $content = $community | Format-CommunityPage
        $content | Set-Content -Path $path -Encoding UTF8
    }
}

function Export-Meetup()
{
    process
    {
        $meetup = [Meetup]$_
        Write-Verbose "Export meetup $($meetup.Id)"

        $path = Join-Path $WikiConfig.WikiDir "$($meetup.Id).md"
        $content = $meetup | Format-MeetupPage
        $content | Set-Content -Path $path -Encoding UTF8
    }
}

function Export-Friend([string] $FriendDir = $(throw "Friend dir required"))
{
    begin
    {
        $wikiImageDir = Join-Path $WikiConfig.WikiDir "Friends"
        if (-not (Test-Path $wikiImageDir -PathType Container))
        {
            New-Item $wikiImageDir -ItemType Directory | Out-Null
        }
    }
    process
    {
        $friend = [Friend]$_
        Write-Verbose "Export friend $($friend.Id)"

        $dbImageDir = Join-Path $FriendDir $friend.Id
        Copy-Item -Path (Join-Path $dbImageDir 'logo.png') -Destination (Join-Path $wikiImageDir "$($friend.Id).png")
        Copy-Item -Path (Join-Path $dbImageDir 'logo.small.png') -Destination (Join-Path $wikiImageDir "$($friend.Id)-small.png")

        $path = Join-Path $WikiConfig.WikiDir "$($friend.Id).md"
        $content = $friend | Format-FriendPage
        $content | Set-Content -Path $path -Encoding UTF8
    }
}

function Export-Talk()
{
    process
    {
        $talk = [Talk]$_
        Write-Verbose "Export talk $($talk.Id)"

        $path = Join-Path $WikiConfig.WikiDir "$($talk.Id).md"
        $content = $talk | Format-TalkPage
        $content | Set-Content -Path $path -Encoding UTF8
    }
}

function Export-DetailedTalkList($Talks)
{
    Write-Verbose "Export talk list"

    $Talks |
    ForEach-Object {
        $meetup = Get-MeetupByTalk -TalkId $_.Id
        [PSCustomObject]@{
            Talk = $_
            Date = $meetup.Sessions[0].StartTime
        }
    } |
    Group-Object -Property { $_.Date.Year } |
    ForEach-Object {

        $page = $_
        $path = Join-Path $WikiConfig.WikiDir "DetailedTalks-$($page.Name).md"

        $page.Group |
        Sort-Object -Property Date -Descending |
        Select-Object -ExpandProperty Talk -First 80 | # BUG: Wiki size limit
        Format-DetailedTalkList |
        Set-Content -Path $path -Encoding UTF8
    }
}

function Export-Speaker([string] $SpeakerDir = $(throw "Speaker dir required"))
{
    process
    {
        $speaker = [Speaker]$_
        $id = $speaker.Id
        Write-Verbose "Export speaker $id"

        $wikiImageDir = Join-Path $WikiConfig.WikiDir $id
        if (-not (Test-Path $wikiImageDir -PathType Container))
        {
            New-Item $wikiImageDir -ItemType Directory | Out-Null
        }
        $dbImageDir = Join-Path $SpeakerDir $id
        Copy-Item -Path (Join-Path $dbImageDir 'avatar.jpg') -Destination (Join-Path $wikiImageDir "$id.jpg")
        Copy-Item -Path (Join-Path $dbImageDir 'avatar.small.jpg') -Destination (Join-Path $wikiImageDir "$id-small.jpg")

        $path = Join-Path $WikiConfig.WikiDir "$id.md"
        $content = $speaker | Format-SpeakerPage
        $content | Set-Content -Path $path -Encoding UTF8
    }
}

function Get-UrlHash()
{
    begin
    {
        $hasher = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
    }
    process
    {
        $url = [Uri]$_

        $site = $url.Host -replace '^www\.|\.com$|\.net$',''

        $buff = [System.Text.Encoding]::UTF8.GetBytes($url.PathAndQuery)
        $hash = $hasher.ComputeHash($buff) | ForEach-Object { '{0:x2}' -f $_ }

        "$site-$($hash -join '')"
    }
    end
    {
        $hasher.Dispose()
    }
}

function Get-YouTubeOEmbed()
{
    process
    {
        $url = [Uri]$_
        $oEmbedUrl = [Uri]"http://www.youtube.com/oembed?url=${url}&format=json"

        try
        {
            $response = Invoke-WebRequest -Uri $oEmbedUrl -UseBasicParsing
        }
        catch
        {
            return
        }

        $meta = $response.Content | ConvertFrom-Json

        @{
            SiteName = $meta.provider_name
            Type = $meta.type
            Url = [string]$url
            Title = $meta.title
            Description = $null
            Image = $meta.thumbnail_url
        }
    }
}

function Get-OpenGraph()
{
    process
    {
        $url = [Uri]$_

        try
        {
            # BUG: hangs in some cases, unless -UseBasicParsing is used
            # https://github.com/PowerShell/PowerShell/issues/2812
            $response = Invoke-WebRequest -Uri $url -UseBasicParsing
        }
        catch
        {
            return
        }

        $html = New-Object -ComObject 'HTMLFile'
        $html.IHTMLDocument2_write($response.Content)
        $meta = $html.getElementsByTagName('meta') | Where-Object { ($_.outerHTML) -and ($_.outerHTML.Contains("property=`"og:")) }
        if (-not $meta)
        {
            return
        }

        function Get-PropertyContent([string] $propertyValue)
        {
            $value = $meta |
                # This is not the correct search, but the fastest
                Where-Object { $_.outerHTML.Contains("property=`"og:$propertyValue`"") } |
                ForEach-Object { $_.content } |
                Select-Object -First 1

            # Remove empty set
            if ($value) { $value } else { $null }
        }

        @{
            SiteName = Get-PropertyContent 'site_name'
            Type = Get-PropertyContent 'type'
            #Url = Get-PropertyContent 'url'
            Url = [string]$url
            Title = Get-PropertyContent 'title'
            Description = Get-PropertyContent 'description'
            Image = Get-PropertyContent 'image'
        }
    }
}

function Resolve-OpenGraph()
{
    process
    {
        $url = [Uri]$_
        $hash = $url | Get-UrlHash
        $cachePath = Join-Path $WikiConfig.CacheDir "$hash.json"

        $og = @{}
        if (Test-Path -Path $cachePath -PathType Leaf)
        {
            $json = Get-Content -Path $cachePath -Encoding UTF8 -Raw | ConvertFrom-Json
            # Convert from PSObject to Dict
            $json | Get-Member -MemberType NoteProperty | ForEach-Object { $og.Add($_.Name, [string]$json."$($_.Name)") }
        }
        elseif ($Config.IsOffline)
        {
            # Keep $og empty
        }
        else
        {
            if ($url.Host -eq 'www.youtube.com')
            {
                $latestOG = $url | Get-YouTubeOEmbed
            }
            else
            {
                $latestOG = $url | Get-OpenGraph
            }

            if ($latestOG)
            {
                $og = $latestOG
                # Save cache
                $og | ConvertTo-Json | Set-Content -Path $cachePath -Encoding UTF8 -Force
            }
            # else Keep $og empty
        }

        # HACK: Choose small image for YouTube
        if ($og['SiteName'] -eq 'YouTube')
        {
            $og.Image = $og.Image -replace '/maxresdefault\.jpg','/sddefault.jpg' -replace '/hqdefault\.jpg','/sddefault.jpg'
        }

        if ($og -and ($og.Count -gt 0))
        {
            $og
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
        $talk = $WikiRepository.Talks[$_]
        $speaker = $talk.SpeakerIds |
        ForEach-Object { $WikiRepository.Speakers[$_] } |
        ForEach-Object { "[[$($_.Name)|$($_.Id)]]" }

        "$($speaker -join ', ') [[«$($talk.Title)»|$($talk.Id)]]"
    }
}

function Format-MeetupLine()
{
    process
    {
        $meetup = [Meetup]$_
        "[[$($meetup.Name) ($(Format-RuDate -Date $meetup.Sessions[0].StartTime))|$($meetup.Id)]]"
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

function Format-ImageLink([Uri] $Url = $(throw "Url required"), [string] $Hint = $(throw "Hint required"))
{
    $og = $url | Resolve-OpenGraph
    if ((-not $og) -or (-not $og.Title) -or (-not $og.Image))
    {
        "$url"
    }
    else
    {
        "[![$Hint]($($og.Image))]($url)"
    }
}

function Format-FriendImage()
{
    process
    {
        $friend = [Friend]$_
        "[![$($friend.Name)](./Friends/$($friend.Id)-small.png)](./$($friend.Id))"
    }
}

function Get-FriendRank($CommunityId = $(throw "CommunityId required"))
{
    process
    {
        $friendId = [string]$_

        if ($friendId -eq 'DotNext')
        {
            # yep, we like DotNext
            return 10000
        }

        if ($friendId -eq 'JetBrains')
        {
            # yep, and JetBrains too
            return 1000
        }

        $WikiRepository.Meetups.Values |
        Where-Object { $_.CommunityId -eq $CommunityId } |
        ForEach-Object {
            if ($_.FriendIds -contains $friendId)
            {
                1
            }
            else
            {
                0
            }
        } |
        Measure-Object -Sum |
        Select-Object -ExpandProperty Sum
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

function Format-CommunityPage()
{
    process
    {
        $community = [Community]$_
        [array] $meetups = $WikiRepository.Meetups.Values |
            Where-Object { $_.CommunityId -eq $community.Id } |
            Sort-Object -Property @{ Expression = { $_.Sessions[0].StartTime } } -Descending

        [array] $allSpeakers = $meetups.Sessions.TalkId |
            ForEach-Object { $WikiRepository.Talks[$_].SpeakerIds } |
            Select-Object -Unique
        [array] $allFriends = $meetups.FriendIds | Select-Object -Unique
        [array] $allVenues = $meetups.VenueId | Select-Object -Unique
        if (-not $allFriends)
        {
            $allFriends = @()
        }

        "Встреч: $($meetups.Count), Докладчиков: $($allSpeakers.Count), Докладов: $($meetups.Sessions.TalkId.Count), Друзей: $($allFriends.Count), Мест: $($allVenues.Count)"
        ''
        '## Встречи'
        ''
        $meetups |
        ForEach-Object {
            $meetup = [Meetup]$_
            $speakers = $meetup.Sessions.TalkId |
                ForEach-Object { $WikiRepository.Talks[$_].SpeakerIds } |
                ForEach-Object { $WikiRepository.Speakers[$_] } |
                Format-SpeakerLine |
                Select-Object -Unique |
                ForEach-Object { "_$($_)_" }

            "- $($meetup | Format-MeetupLine): $($speakers -join ', ')"
        }

        ''
        '## Друзья'
        ''
        $fiends = $meetups |
            ForEach-Object { $_.FriendIds } |
            Select-Object -Unique |
            Sort-Object -Property @{ Expression = { $_ | Get-FriendRank -CommunityId $community.Id } } -Descending |
            ForEach-Object { $WikiRepository.Friends[$_] } |
            Format-FriendImage

        $fiends -join ' '
    }
}

function Format-HomePage([Community[]] $Communities)
{
    $sorted = $Communities | Select-SortedCommunity

    '## Всероссийское .NET сообщество'
    ''
    'Все сведения о сообществах постепенно мигрируют на сайт [DotNet.Ru](http://DotNet.Ru/). Поэтому самую полную и актуальную информацию ищите там.'
    'Здесь пока остались только энциклопедии.'

    if ($sorted)
    {
        ''
        '## Полные энциклопедии сообществ'
        ''
        $sorted |
        ForEach-Object {
            "- [[$($_.City)|$($_.Id)]]"
        }
    }

    ''
    '## Детализированные списки докладов'
    ''
    $WikiRepository.Meetups.Values.Sessions.StartTime.Year |
    Select-Object -Unique |
    Sort-Object -Descending |
    ForEach-Object {
        "- [[За $_ год|DetailedTalks-$_]]"
    }


    ''
    '## Рейтинги докладов'
    ''
    ' - [[Рейтинг любимых докладов по версии YouTube зрителей|LikedVideos]]'
}

function Format-MeetupPage()
{
    process
    {
        $meetup = [Meetup]$_
        $meetupDate = $meetup.Sessions[0].StartTime
@"
# $($meetup.Name)

$($meetup.Name) состоялась $(Format-RuDate -Date $meetupDate)

## Доклады

"@
        $meetup.Sessions.TalkId | Format-TalkLine | ForEach-Object { "- $_" }
        # TODO: refer to Friend Name
        $friends = $meetup.FriendIds
        $friendPart = ''
        if ($friends)
        {
            $rank = if ($friends -contains 'ITGM') { '' } elseif ($friends -contains 'DotNext') { 'конференции ' } else { 'компании ' }
            $friendNames = $friends | ForEach-Object { "[[$_]]" }
            $friendPart = " в гостях у $rank$($friendNames -join ', ')"
        }

        $venuePart = 'во всемирной сети «Интернет»'
        if ($meetup.VenueId)
        {
            $venue = $WikiRepository.Venues[$meetup.VenueId]
            # TODO: remove venue Name from Address part
            $venuePart = "по адресу: [$($venue.Address)]($($venue.MapUrl))"
        }
@"

## Место

Встреча прошла$friendPart $venuePart.
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

        $WikiRepository.Meetups.Values |
        Sort-Object -Property @{ Expression = { $_.Sessions[0].StartTime }} |
        Where-Object { $_.FriendIds -contains $id } |
        Format-MeetupLine |
        ForEach-Object { "- $_" }
    }
}

function Format-TalkPage()
{
    process
    {
        $talk = [Talk]$_

        [array]$speakers = $talk.SpeakerIds | ForEach-Object { $WikiRepository.Speakers[$_] }
        $speakersVerb = if ($speakers.Length -eq 1) { 'представил' } else { 'представили' }

        $id = $talk.Id
        $meetup = $WikiRepository.Meetups.Values |
        Where-Object { $_.Sessions.TalkId -contains $id } |
        ForEach-Object { "[[$($_.Name -replace 'Встреча','Встречи')|$($_.Id)]]" }

@"
# $($speakers | ForEach-Object { $_.Name } | Format-ChainLine) «$($_.Title)»

$($talk.Description)

---

Доклад $speakersVerb $($speakers | Format-SpeakerLine | Format-ChainLine) в рамках $meetup.

"@
        if ($talk.SeeAlsoTalkIds)
        {
            '## См. также'
            ''
            $talk.SeeAlsoTalkIds |
                ForEach-Object { $WikiRepository.Talks[$_] } |
                ForEach-Object { "- [[$($_.Title)|$($_.Id)]]" }
            ''
        }

        $links = @()
        if ($talk.CodeUrl)
        {
            $links += @{ 'Демо' = $talk.CodeUrl }
        }
        if ($talk.SlidesUrl)
        {
            $links += @{ 'Слайды' = $talk.SlidesUrl }
        }
        if ($talk.VideoUrl)
        {
            $links += @{ 'Видео' = $talk.VideoUrl }
        }

        $links | ForEach-Object {
            $title = $_.Keys | Select-Single
            $url = $_.Values | Select-Single
            "## $title"
            ''
            Format-ImageLink -Url $url -Hint $title
            ''
        }
    }
}

function Format-DetailedTalkList()
{
    begin
    {
        function Format-EscapeCell()
        {
            process
            {
                $_.Replace('|', '\|').Replace("`r", ' ').Replace("`n", ' ').Replace('  ', ' ')
            }
        }

        '| Когда и где | Докладчик | Доклад | Ссылки |'
        '| --- | --- | --- | --- |'
    }
    process
    {
        $talk = [Talk]$_

        $meetup = Get-MeetupByTalk -TalkId $talk.Id
        $meetupSection = "$(Format-RuDate -Date $meetup.Sessions[0].StartTime)<br/>[[$($meetup.Name)|$($meetup.Id)]]" | Format-EscapeCell

        $speakersSection = $talk.SpeakerIds |
        ForEach-Object { $WikiRepository.Speakers[$_] } |
        ForEach-Object {
            $speaker = $_
            $id = $speaker.Id
            "[![Photo](./$id/$id-small.jpg)](./$id/$id.jpg)<br/>$($speaker | Format-SpeakerLine)"
        } |
        Format-EscapeCell |
        Join-ToString -Delimeter '<br/>'

        $talkSection = "**[[$($talk.Title)|$($talk.Id)]]**<br/>$($talk.Description)" | Format-EscapeCell

        $linkSection = ''
        if ($talk.VideoUrl) { $linkSection += "[Видео]($($talk.VideoUrl))<br>" }
        if ($talk.SlidesUrl) { $linkSection += "[Слайды]($($talk.SlidesUrl))<br>" }
        if ($talk.CodeUrl) { $linkSection += "[Демо]($($talk.CodeUrl))<br>" }

        "| $meetupSection | $speakersSection | $talkSection | $linkSection |"
    }
}

function Get-MeetupByTalk([string] $TalkId)
{
    $WikiRepository.Meetups.Values |
    Where-Object { $_.Sessions.TalkId -contains $TalkId } |
    Select-Single
}

function Format-TalkTitle()
{
    process
    {
        $talk = [Talk]$_
        $meetup = Get-MeetupByTalk -TalkId $talk.Id
        $session = $meetup.Sessions | Where-Object { $_.TalkId -eq $talk.Id } | Select-Single
        $date = Format-RuDate -Date $session.StartTime

        "[[$($talk.Title)|$($talk.Id)]] ($date)"
    }
}

function Format-SpeakerPage()
{
    process
    {
        $speaker = [Speaker]$_
        $id = $speaker.Id

@"
# $($speaker.Name)

[![Photo](./$id/$id-small.jpg)](./$id/$id.jpg)

Работает в компании [$($speaker.CompanyName)]($($speaker.CompanyUrl))

$($speaker.Description)

"@

        $links = @()
        if ($speaker.BlogUrl)
        {
            $links += @{ 'Блог' = $speaker.BlogUrl }
        }
        if ($speaker.ContactsUrl)
        {
            $links += @{ 'Контакты' = $speaker.ContactsUrl }
        }
        if ($speaker.TwitterUrl)
        {
            $links += @{ 'Twitter' = $speaker.TwitterUrl }
        }
        if ($speaker.HabrUrl)
        {
            $links += @{ 'Хабрахабр' = $speaker.HabrUrl }
        }
        if ($speaker.GitHubUrl)
        {
            $links += @{ 'GitHub' = $speaker.GitHubUrl }
        }

        if ($links)
        {
            '## Контакты'
            ''
            $links | ForEach-Object {
                $title = $_.Keys | Select-Single
                $url = $_.Values | Select-Single
                "- $($title): $url"
            }
            ''
        }

        '## Доклады'
        ''
        $WikiRepository.Talks.Values |
        Where-Object { $_.SpeakerIds -contains $id } |
        Sort-Object -Property @{ Expression = {
            $talkId = $_.Id
            $meetup = Get-MeetupByTalk -TalkId $talkId

            $session = $meetup.Sessions | Where-Object { $_.TalkId -eq $talkId } | Select-Single
            # $epoch = (Get-Date -Date '2015-01-01T00:00:00Z').Ticks
            # ($meetup.Date.Ticks - $epoch) * 100 + $meetup.TalkIds.IndexOf($talkId)
            $session.StartTime
        } } |
        Format-TalkTitle |
        ForEach-Object { "- $_" }
    }
}

function Format-VideoRatingPage()
{
    '# Рейтинг любимых докладов по версии YouTube зрителей'
    ''
    "_Рейтинг актуален на $(Format-RuDate -Date (Get-Date))_"
    ''
    $orderPlaylist = @{ Expression = {

        if ($_.Name -match '(?<Year>\d{4})') { [int]$Matches['Year'] } else { 255 }

    }; Descending = $true }

    function Format-VideoLine()
    {
        process
        {
            $video = $_
            # TODO: Resolve TalkId, format nice title, make link to wiki talk page
            "1. [$($video.Title)](https://www.youtube.com/watch?v=$($video.Id)) (:+1: $($video.LikeCount)  :tv: $($video.ViewCount)  :pager: $($video.CommentCount))"
        }
    }

    function Format-VideoSummary($Videos)
    {
        $duration = [TimeSpan]::Zero
        $viewCount = 0
        $likeCount = 0
        $Videos |
        ForEach-Object {
            $video = $_
            $duration += $video.Duration
            $viewCount += $video.ViewCount
            $LikeCount += $video.LikeCount
        }

        $countText = $Videos.Length | Format-Declension -Nominativ 'запись' -Genetiv 'записи' -Plural 'записей'
        $durationText = [int]$duration.TotalHours | Format-Declension -Nominativ 'час' -Genetiv 'часа' -Plural 'часов'
        $viewText = $viewCount | Format-Declension -Nominativ 'просмотр' -Genetiv 'просмотра' -Plural 'просмотров'
        $likeText = $likeCount | Format-Declension -Nominativ 'лайк' -Genetiv 'лайка' -Plural 'лайков'

        "_Всего ${countText}, общая продолжительность ${durationText}_, $viewText, $likeText"
    }

    $videos = @{}
    $WikiConfig.DotNetRuChannelId |
    Get-YouTubePlaylist |
    Where-Object { $_.Title -match '^DotNetRu \d{4}$' } |
    ForEach-Object {
        $playlist = $_

        $playlistVideos =
            $playlist |
            Get-YouTubePlaylistItem |
            Group-ToStringBatch |
            Get-YouTubeVideo

        $videos[$playlist.Title] = $playlistVideos
    }

    '## За всё время'
    ''
    Format-VideoSummary -Videos ($videos.Values | Select-Many)
    ''
    $videos.Values |
    Select-Many |
    Sort-Object -Property LikeCount -Descending |
    Select-Object -First 10 |
    Format-VideoLine
    ''

    $videos |
    Select-Many |
    Sort-Object -Property $orderPlaylist |
    ForEach-Object {
        $playlistTitle = $_.Name
        $playlistVideos = $_.Value

        "## $($playlistTitle)"
        ''
        Format-VideoSummary -Videos $playlistVideos
        ''
        $playlistVideos |
        Sort-Object -Property LikeCount -Descending |
        Format-VideoLine
        ''
    }
}

function Invoke-ReCache()
{
    Test-WikiEnvironment

    $timer = Start-TimeOperation -Name 'Build cache'

    Read-All -AuditDir $Config.AuditDir |
    Where-Object { $_ -is [Talk] } |
    ForEach-Object {

        $talk = $_

        @($talk.CodeUrl, $talk.SlidesUrl, $talk.VideoUrl) |
        Where-Object { $_ } |
        ForEach-Object {

            $link = [Uri]$_

            if ($link | Resolve-OpenGraph)
            {
                $status = 'OK'
            }
            else
            {
                $status = 'Fail'
            }

            Write-Information "$($talk.Title): $($link.Host)    [ $status ]"
        }
    }

    $timer | Stop-TimeOperation

}

function Select-SortedCommunity
{
    [CmdletBinding()]
    [OutputType([Community])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [Community]
        $Community
    )

    begin
    {
        $order = @{
            Expression = { $_.Group.Sessions.StartTime | Sort-Object | Select-Object -First 1 }
            Descending = $false
        }
        [array] $communityOrder = $WikiRepository.Meetups.Values |
            Group-Object -Property CommunityId |
            Sort-Object -Property $order |
            Select-Object -ExpandProperty Name

        $communities = @()
    }
    process
    {
        $communities += $Community
    }
    end
    {
        $communities | Sort-Object -Property { $communityOrder.IndexOf($_.Name) }
    }
}

function Invoke-BuildWiki()
{
    Test-WikiEnvironment

    $timer = Start-TimeOperation -Name 'Build wiki'

    # Load all
    $entities = Read-All -AuditDir $Config.AuditDir

    $WikiRepository.Communities = $entities | Where-Object { $_ -is [Community] } | ConvertTo-Hashtable { $_.Id }
    Write-Information "Load $($WikiRepository.Communities.Count) communities"
    $WikiRepository.Meetups = $entities | Where-Object { $_ -is [Meetup] } | ConvertTo-Hashtable { $_.Id }
    Write-Information "Load $($WikiRepository.Meetups.Count) meetups"
    $WikiRepository.Talks  = $entities | Where-Object { $_ -is [Talk] } | ConvertTo-Hashtable { $_.Id }
    Write-Information "Load $($WikiRepository.Talks.Count) talks"
    $WikiRepository.Speakers = $entities | Where-Object { $_ -is [Speaker] } | ConvertTo-Hashtable { $_.Id }
    Write-Information "Load $($WikiRepository.Speakers.Count) speakers"
    $WikiRepository.Friends = $entities | Where-Object { $_ -is [Friend] } | ConvertTo-Hashtable { $_.Id }
    Write-Information "Load $($WikiRepository.Friends.Count) friends"
    $WikiRepository.Venues = $entities | Where-Object { $_ -is [Venue] } | ConvertTo-Hashtable { $_.Id }
    Write-Information "Load $($WikiRepository.Venues.Count) venues"

    # Export all
    Export-Home -Communities ($WikiRepository.Communities.Values)
    $WikiRepository.Communities.Values | Select-SortedCommunity | Export-Community
    $WikiRepository.Meetups.Values | Export-Meetup
    $WikiRepository.Friends.Values | Export-Friend -FriendDir (Join-Path $Config.AuditDir 'friends')
    $WikiRepository.Talks.Values | Export-Talk
    $WikiRepository.Speakers.Values | Export-Speaker -SpeakerDir (Join-Path $Config.AuditDir 'speakers')

    Export-DetailedTalkList -Talks $WikiRepository.Talks.Values

    if (-not $Config.IsOffline)
    {
        Export-VideoRatingPage
    }

    $timer | Stop-TimeOperation
}
