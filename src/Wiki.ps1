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

function Read-Communities()
{
    Get-ChildItem -Path (Join-Path $Config.AuditDir 'communities') -Filter '*.xml' |
    Read-NiceXml
}

function Read-Meetups()
{
    Get-ChildItem -Path (Join-Path $Config.AuditDir 'meetups') -Filter '*.xml' |
    Read-NiceXml |
    Sort-Object -Property Number
}

function Read-Talks()
{
    Get-ChildItem -Path (Join-Path $Config.AuditDir 'talks') -Filter '*.xml' |
    Read-NiceXml
}

function Read-Speakers()
{
    Get-ChildItem -Path (Join-Path $Config.AuditDir 'speakers') -Filter 'index.xml' -Recurse |
    Read-NiceXml
}

function Read-Friends()
{
    Get-ChildItem -Path (Join-Path $Config.AuditDir 'friends') -Filter 'index.xml' -Recurse |
    Read-NiceXml
}

function Read-Venues()
{
    Get-ChildItem -Path (Join-Path $Config.AuditDir 'venues') -Filter '*.xml' |
    Read-NiceXml
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

        $path = Join-Path $WikiConfig.WikiDir "Meetup-$($meetup.Number).md"
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
        $hash = $hasher.ComputeHash($buff) | % { '{0:x2}' -f $_ }

        "$site-$($hash -join '')"
    }
    end
    {
        $hasher.Dispose()
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
            $value = $meta |
                # This is not the correct search, but the fastest
                ? { $_.outerHTML.Contains("property=`"og:$propertyValue`"") } |
                % { $_.content } |
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
            $json | Get-Member -MemberType NoteProperty | % { $og.Add($_.Name, [string]$json."$($_.Name)") }
        }
        elseif ($Config.IsOffline)
        {
            $og = @{
                SiteName = $null
                Type = $null
                Url = [string]$url
                Title = $null
                Description = $null
                Image = $null
            }
        }
        else
        {
            $og = $url | Get-OpenGraph
            $og | ConvertTo-Json | Set-Content -Path $cachePath -Encoding UTF8 -Force
        }

        # HACK: Choose small image for YouTube
        if ($og.SiteName -eq 'YouTube')
        {
            $og.Image = $og.Image -replace '/maxresdefault\.jpg','/sddefault.jpg' -replace '/hqdefault\.jpg','/sddefault.jpg'
        }

        $og
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
        % { $WikiRepository.Speakers[$_] } |
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

function Format-ImageLink([Uri] $Url = $(throw "Url required"), [string] $Hint = $(throw "Hint required"))
{
    $og = $url | Resolve-OpenGraph
    if (($og.Title -eq $null) -or ($og.Image -eq $null))
    {
        return $url
    }

    "[![$Hint]($($og.Image))]($url)"
}

function Format-FriendImage()
{
    process
    {
        $friend = [Friend]$_
        "[![$($friend.Name)](./Friends/$($friend.Id)-small.png)](./$($friend.Id))"
    }
}

function Get-FriendRank()
{
    process
    {
        $friendId = [string]$_

        if ($friendId -eq 'DotNext')
        {
            # yep, we like DotNext
            return 1000
        }

        $WikiRepository.Meetups.Values |
        % {
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

filter Only-NotNull()
{
    if (($_ -ne $null) -and ($_ -ne ''))
    {
        $_
    }
}

function Format-CommunityPage()
{
    process
    {
        $community = [Community]$_
        $meetups = $WikiRepository.Meetups.Values | ? { $_.CommunityId -eq $community.Id } | Sort-Object -Property Number -Descending

        '## Встречи'
        ''
        $meetups |
        % {
            $meetup = [Meetup]$_
            $speakers = $meetup.TalkIds |
                % { $WikiRepository.Talks[$_].SpeakerIds } |
                % { $WikiRepository.Speakers[$_] } |
                Format-SpeakerLine |
                Select-Object -Unique |
                % { "_$($_)_" }

            "- $($meetup | Format-MeetupLine): $($speakers -join ', ')"
        }

        ''
        '## Друзья'
        ''
        $fiends = $meetups |
            % { $_.FriendIds } |
            Select-Object -Unique |
            Sort-Object -Property @{ Expression = { $_ | Get-FriendRank } } -Descending |
            % { $WikiRepository.Friends[$_] } |
            Format-FriendImage

        $fiends -join ' '
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
        $venue = $WikiRepository.Venues[$_.VenueId]
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

        $WikiRepository.Meetups.Values |
        Sort-Object -Property 'Number' |
        ? { $_.FriendIds -contains $id } |
        Format-MeetupLine |
        % { "- $_" }
    }
}

function Format-TalkPage()
{
    process
    {
        $talk = [Talk]$_

        [array]$speakers = $talk.SpeakerIds | % { $WikiRepository.Speakers[$_] }
        $speakersVerb = if ($speakers.Length -eq 1) { 'представил' } else { 'представили' }

        $id = $talk.Id
        $meetup = $WikiRepository.Meetups.Values |
        ? { $_.TalkIds -contains $id } |
        % { "[[Встречи №$($_.Number)|Meetup-$($_.Number)]]" }

@"
# $($speakers | % { $_.Name } | Format-ChainLine) «$($_.Title)»

$($talk.Description)

---

Доклад $speakersVerb $($speakers | Format-SpeakerLine | Format-ChainLine) в рамках $meetup.

"@
        if ($talk.SeeAlsoTalkIds)
        {
            '## См. также'
            ''
            $talk.SeeAlsoTalkIds |
                % { $WikiRepository.Talks[$_] } |
                % { "- [[$($_.Title)|$($_.Id)]]" }
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

        $links | % {
            $title = $_.Keys | Select-Single
            $url = $_.Values | Select-Single
            "## $title"
            ''
            Format-ImageLink -Url $url -Hint $title
            ''
        }
    }
}

function Select-Single()
{
    begin
    {
        $count = 0
    }
    process
    {
        if ($_)
        {
            $count++
            $_
        }
    }
    end
    {
        if ($count -ne 1)
        {
            throw "Found $count elements in collection"
        }
    }
}

function Get-MeetupByTalk([string] $TalkId)
{
    $WikiRepository.Meetups.Values |
    ? { $_.TalkIds -contains $TalkId } |
    Select-Single
}

function Format-TalkTitle()
{
    process
    {
        $talk = [Talk]$_
        $meetup = Get-MeetupByTalk -TalkId $talk.Id
        $date = Format-RuDate -Date $meetup.Date

        "[[$($talk.Title)|$($talk.Id)]] ($date)"
    }
}

function Format-SpeakerPage()
{
    begin
    {
        $epoch = (Get-Date -Date '2015-01-01T00:00:00Z').Ticks
    }
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

        if ($links)
        {
            '## Контакты'
            ''
            $links | % {
                $title = $_.Keys | Select-Single
                $url = $_.Values | Select-Single
                "- $($title): $url"
            }
            ''
        }

        '## Доклады'
        ''
        $WikiRepository.Talks.Values |
        ? { $_.SpeakerIds -contains $id } |
        Sort-Object -Property @{ Expression = {
            $talkId = $_.Id
            $meetup = Get-MeetupByTalk -TalkId $talkId
            ($meetup.Date.Ticks - $epoch) * 100 + $meetup.TalkIds.IndexOf($talkId)

        } } |
        Format-TalkTitle |
        % { "- $_" }
    }
}

function Build-Wiki()
{
    Test-WikiEnvironment

    $timer = Start-TimeOperation -Name 'Build wiki'

    # Load all
    Read-Communities | % { $WikiRepository.Communities.Add($_.Id, $_) }
    Write-Information "Load $($WikiRepository.Communities.Count) communities"
    Read-Meetups | % { $WikiRepository.Meetups.Add($_.Id, $_) }
    Write-Information "Load $($WikiRepository.Meetups.Count) meetups"
    Read-Talks | % { $WikiRepository.Talks.Add($_.Id, $_) }
    Write-Information "Load $($WikiRepository.Talks.Count) talks"
    Read-Speakers | % { $WikiRepository.Speakers.Add($_.Id, $_) }
    Write-Information "Load $($WikiRepository.Speakers.Count) speakers"
    Read-Friends | % { $WikiRepository.Friends.Add($_.Id, $_) }
    Write-Information "Load $($WikiRepository.Friends.Count) friends"
    Read-Venues | % { $WikiRepository.Venues.Add($_.Id, $_) }
    Write-Information "Load $($WikiRepository.Venues.Count) venues"

    # Export all
    $WikiRepository.Communities.Values | Export-Community
    $WikiRepository.Meetups.Values | Export-Meetup
    $WikiRepository.Friends.Values | Export-Friend -FriendDir (Join-Path $Config.AuditDir 'friends')
    $WikiRepository.Talks.Values | Export-Talk
    $WikiRepository.Speakers.Values | Export-Speaker -SpeakerDir (Join-Path $Config.AuditDir 'speakers')

    $timer | Stop-TimeOperation
}
