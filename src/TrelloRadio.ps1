#Requires -Version 5
#Requires -Modules PowerTrello

# TODO:
# - Draw cover.svg with topics
#   - https://khalidabuhakmeh.com/programming-svgs-with-csharp-dotnet

Set-StrictMode -version Latest
$ErrorActionPreference = 'Stop'

. $PSScriptRoot\Utility.ps1
. $PSScriptRoot\YamlCuteSerialization.ps1
. $PSScriptRoot\Model.ps1
. $PSScriptRoot\Serialization.ps1

$TrelloBoardName = 'RadioDotNet'
$TrelloNewCardListName = 'Обсуждаем-'
$PodcastHome = Join-Path $PSScriptRoot '..\..\Audit\db\podcasts' -Resolve
$AuditDir = Join-Path $PSScriptRoot '..\..\Audit\db' -Resolve
$InformationPreference = 'Continue'

$EpisodeSorter = { @('Number', 'Title', 'PublishDate', 'Authors', 'Mastering', 'Music', 'Patrons', 'Home', 'Audio', 'Topics', 'Subject', 'Timestamp', 'Links').IndexOf($_) }


class FormatString
{
    [bool] $AsHtml
    [Text.StringBuilder] $Writer

    FormatString([bool] $AsHtml)
    {
        $this.AsHtml = $AsHtml
        $this.Writer = New-Object -TypeName 'System.Text.StringBuilder'
    }

    [String] ToString()
    {
        return $this.Writer.ToString().Trim()
    }

    [string] Encode([string] $text)
    {
        if ($this.AsHtml)
        {
            return [System.Net.WebUtility]::HtmlEncode($text)
        }
        else
        {
            return $text
        }
    }

    [string] Wrap([string] $openTag, [string] $text, [string] $closeTag)
    {
        if ($this.AsHtml)
        {
            return $openTag + $text + $closeTag
        }
        else
        {
            return $text
        }
    }

    [string] Strong([string] $text)
    {
        return $this.Wrap('<strong>', $text, '</strong>')
    }

    static [string] GetTextByUrl([string] $url)
    {
        $uri = [Uri] $url
        $max = 42
        $tail = $uri.AbsolutePath

        # Remove lang segment
        $tail = $tail.Replace('/en-us/', '/').Replace('/ru-ru/', '/')
        # Remove date segment
        $tail = $tail -replace '/\d{4}/\d{2}/\d{2}/','/'
        # Remove short date segment
        $tail = $tail -replace '/\d{4}/\d{2}/','/'
        # Remove file extension
        $tail = $tail -replace '\.\w{3,4}$',''

        $tail = $tail.TrimEnd('/', '-')
        $tail = if ($tail.Length -le $max)
        {
            $tail
        }
        else
        {
            $suffix = '...'
            $tail.Substring(0, $max - $suffix.Length) + $suffix
        }

        $authority = $uri.Authority
        # Remove www segment
        $authority = $authority.TrimStart('www.')

        return $authority + $tail
    }

    [string] Link([string] $url)
    {
        return $this.Link($url, $null)
    }

    [string] Link([string] $url, [string] $text)
    {
        $h = if ($this.AsHtml) { 'h' } else { '_' }
        $u = if ($url) { 'u' } else { '_' }
        $t = if ($text) { 't' } else { '_' }
        $mask = "$h$u$t"

        switch ($mask)
        {
            '__t' { return $text }
            '_u_' { return $url }
            '_ut' { return "$text ($url)" }
            'h_t' { return $text }
            'hu_' { return '<a href="{0}">{1}</a>' -f $url,[FormatString]::GetTextByUrl($url) }
            'hut' { return '<a href="{0}">{1}</a>' -f $url,$text }
            # '___'
            # 'h__'
        }

        throw "Impossible: $mask"
    }

    BeginList()
    {
        $this.BeginList($null)
    }

    BeginList([string] $title)
    {
        if ($this.AsHtml)
        {
            if ($title)
            {
                $this.Paragraph($title)
            }

            $this.Writer.AppendLine('<ul>')
        }
        else
        {
            if ($title)
            {
                $this.Writer.AppendLine($title)
            }
        }
    }

    EndList()
    {
        if ($this.AsHtml)
        {
            $this.Writer.AppendLine('</ul>')
        }
        else
        {
            $this.Writer.AppendLine()
        }
    }

    ListItem([string] $text)
    {
        if ($this.AsHtml)
        {
            $format = "  <li>$text</li>"
        }
        else
        {
            $format = "• $text"
        }

        $this.Writer.AppendLine($format)
    }

    Paragraph([string] $text)
    {
        if ($this.AsHtml)
        {
            $format = "<p>$text</p>"
            $this.Writer.AppendLine($format)
        }
        else
        {
            $this.Writer.AppendLine($text)
            $this.Writer.AppendLine()
        }
    }
}


class PodcastAnnouncement
{
    static [string] $PodcastName = 'RadioDotNet'
    static [string] $SiteUrl = 'http://Radio.DotNet.Ru'
    static [string] $EMail = 'Radio@DotNet.Ru'
    static [string] $RssUrl = 'https://cloud.mave.digital/37167'
    static [string] $VideoUrl = 'https://www.youtube.com/playlist?list=PLbxr_aGL4q3SpQ9GRn2jv-NEpvN23CUC5'
    static [string] $GoogleUrl = 'https://podcasts.google.com/feed/aHR0cHM6Ly9hbmNob3IuZm0vcy9mMGMwZWY0L3BvZGNhc3QvcnNz'
    static [string] $AppleUrl = 'https://podcasts.apple.com/us/podcast/radiodotnet/id1484348948'
    static [string] $YandexUrl = 'https://music.yandex.ru/album/12041961'
    static [string] $PatreonUrl = 'https://www.patreon.com/RadioDotNet'
    static [string] $BoostyUrl = 'https://boosty.to/RadioDotNet'

    [hashtable] $Podcast
    [hashtable] $Links
    [FormatString] $Report

    PodcastAnnouncement([hashtable] $Podcast)
    {
        $this.Init($Podcast, @{}, $false)
    }
    PodcastAnnouncement([hashtable] $Podcast, [hashtable] $Links)
    {
        $this.Init($Podcast, $Links, $false)
    }
    PodcastAnnouncement([hashtable] $Podcast, [hashtable] $Links, [bool] $AsHtml)
    {
        $this.Init($Podcast, $Links, $AsHtml)
    }

    hidden Init([hashtable] $Podcast, [hashtable] $Links, [bool] $AsHtml)
    {
        $this.Podcast = $Podcast
        $this.Links = $Links
        $this.Report = [FormatString]::new($AsHtml)
    }

    [String] ToString()
    {
        return $this.Report.ToString()
    }

    [DateTime] GetForcePublishDate()
    {
        if ($this.Podcast.Contains('PublishDate'))
        {
            return $this.Podcast['PublishDate']
        }

        $date = Get-Date
        $left = 23 - $date.Hour
        if ($left -lt 3)
        {
            $date = $date.AddDays(1)
        }

        return $date
    }

    [string] FormatDate([string] $template)
    {
        $date = $this.GetForcePublishDate()
        $localPubDate = $date | ConvertTo-LocalTime
        return $localPubDate.ToString($template, [System.Globalization.CultureInfo]::GetCultureInfo('ru-RU'))
    }

    [PodcastAnnouncement] ShortDate()
    {
        $textPubDate = $this.FormatDate('d MMM yyyy')
        $format = $this.Report.Encode($textPubDate)
        $this.Report.Paragraph($format)
        return $this
    }

    [PodcastAnnouncement] Identity()
    {
        $textPubDate = $this.FormatDate('d MMMM yyyy')
        $text = "Подкаст $($this::PodcastName) выпуск №$($this.Podcast['Number']) от $textPubDate года"
        $format = $this.Report.Strong($this.Report.Encode($text))
        $this.Report.Paragraph($format)
        return $this
    }

    [PodcastAnnouncement] Slogan()
    {
        $format = $this.Report.Encode('Разговоры на тему .NET во всех его проявлениях, новости, статьи, библиотеки, конференции, личности и прочее интересное из мира IT.')
        $this.Report.Paragraph($format)
        return $this
    }

    [PodcastAnnouncement] Description()
    {
        if ($this.Podcast.Contains('Description'))
        {
            $this.Podcast['Description'] -split "`r`n`r`n" |
            ForEach-Object {
                $format = $this.Report.Encode($_)
                $this.Report.Paragraph($format)
            }
        }

        return $this
    }

    [PodcastAnnouncement] Home()
    {
        $ref = $this.Podcast['Home']
        if ($ref)
        {
            $link = $this.Report.Link($ref)
            $this.Report.Paragraph($link)
        }
        else
        {
            Write-Warning "Home link not found, skip it"
        }
        return $this
    }

    [PodcastAnnouncement] Audio()
    {
        $ref = $this.Podcast['Audio']
        if ($ref)
        {
            $link = $this.Report.Link($ref)
            $this.Report.Paragraph("Аудиоверсия: $link")
        }
        else
        {
            Write-Warning "Audio link not found, skip it"
        }
        return $this
    }

    [PodcastAnnouncement] PlayResources()
    {
        return $this.PlayResources($false)
    }

    [PodcastAnnouncement] PlayResources($Short)
    {
        [ordered]@{
            'Сайт подкаста' = $this::SiteUrl
            'RSS подписка' = $this::RssUrl
            'Google Podcasts' = $this::GoogleUrl
            'Apple Podcasts' = $this::AppleUrl
            'Яндекс Музыка' = $this::YandexUrl
            'YouTube Playlist' = $this::VideoUrl
        } |
        Select-Many |
        ForEach-Object {
            $name = $_.Key
            $link = $this.Report.Link($_.Value)
            if ($Short)
            {
                $name = $name -split ' ' | Select-Object -First 1
            }
            $this.Report.Paragraph("${name}: $link")
        }

        return $this
    }

    [PodcastAnnouncement] DonatResources()
    {
        $link = $this.Report.Link($this::BoostyUrl)
        $this.Report.Paragraph("Boosty (₽): $link")
        # $link = $this.Report.Link($this::PatreonUrl)
        # $this.Report.Paragraph("Patreon ($): $link")
        return $this
    }

    [PodcastAnnouncement] Site()
    {
        $link = $this.Report.Link($this::SiteUrl)
        $this.Report.Paragraph("Сайт подкаста: $link")
        return $this
    }

    [PodcastAnnouncement] EMail()
    {
        $text = 'Почта: '
        $text += $this.Report.Encode($this::EMail)
        $this.Report.Paragraph($text)
        return $this
    }

    [PodcastAnnouncement] Authors()
    {
        $this.Report.BeginList('Голоса выпуска:')

        foreach ($author in $this.Podcast['Authors'])
        {
            $link = $this.Links[$author]
            $text = $this.Report.Encode($author)
            $format = $this.Report.Link($link, $text)
            $this.Report.ListItem($format)
        }

        $this.Report.EndList()
        return $this
    }

    [PodcastAnnouncement] Mastering()
    {
        $mastering = $this.Podcast['Mastering']
        if ($mastering)
        {
            $link = $this.Links[$mastering]
            $text = $this.Report.Encode($mastering)
            $format = $this.Report.Link($link, $text)
            $this.Report.BeginList('Звукорежиссёр:')
            $this.Report.ListItem($format)
            $this.Report.EndList()
        }
        return $this
    }

    [PodcastAnnouncement] Music()
    {
        $music = $this.Podcast['Music']
        if ($music)
        {
            foreach ($name in $music.Keys)
            {
                $link = $music[$name]
                $text = $this.Report.Encode($name)
                $format = $this.Report.Link($link, $text)
                $this.Report.BeginList('Фоновая музыка:')
                $this.Report.ListItem($format)
                $this.Report.EndList()
            }
        }
        return $this
    }

    [PodcastAnnouncement] Patrons()
    {
        $patrons = $this.Podcast['Patrons']
        if (-not $patrons)
        {
            return $this
        }

        $this.Report.BeginList('Спасибо за помощь:')

        foreach ($patron in $patrons)
        {
            $link = $this.Links[$patron]
            $text = $this.Report.Encode($patron)
            $format = $this.Report.Link($link, $text)
            $this.Report.ListItem($format)
        }

        $this.Report.EndList()
        return $this
    }

    [PodcastAnnouncement] TopicsWithZeroBase()
    {
        return $this.Topics($true, $true)
    }

    [PodcastAnnouncement] Topics()
    {
        return $this.Topics($true, $false)
    }

    [PodcastAnnouncement] Topics([bool] $IncludeLinks, [bool] $zeroBase)
    {
        $formatTitle = $this.Report.Strong('Темы:')
        $this.Report.Paragraph($formatTitle)

        $topics = $this.Podcast['Topics']
        if ($zeroBase)
        {
            $zero = @{
                Subject = 'Приветствие'
                Timestamp = "$([TimeSpan]::Zero)"
                Links = @($this::SiteUrl)
            }

            $topics = @($zero) + $topics
        }

        foreach ($topic in $topics)
        {
            $formatTopic = $this.Report.Encode("[$($topic.Timestamp)] — $($topic.Subject)")
            if ($IncludeLinks)
            {
                $this.Report.BeginList($formatTopic)
                foreach ($link in $topic.Links)
                {
                    $formatLink = $this.Report.Link($link)
                    $this.Report.ListItem($formatLink)
                }
                $this.Report.EndList()
            }
            else
            {
                $this.Report.Paragraph($formatTopic)
            }
        }

        return $this
    }
}


function Select-EpisodeNumber
{
    [CmdletBinding()]
    [OutputType([int])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $EpisodeId
    )

    process
    {
        if ($EpisodeId -match '\w+-(?<number>\d+)')
        {
            return [int]$Matches['number']
        }

        throw "Can't extract episode number from «$EpisodeId»"
    }
}

function Format-PodcastHeader
{
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [int] $EpisodeNumber
    )

    process
    {
        @{
            Number = $EpisodeNumber
            Title = "$([PodcastAnnouncement]::PodcastName) №${EpisodeNumber}"
            Authors = @('Анатолий Кулаков', 'Игорь Лабутин')
            Mastering = 'Игорь Лабутин' # 'Максим Шошин'
            Music = @{ 'Максим Аршинов «Pensive yeti.0.1»' = 'https://hightech.group/ru/about' }
            Patrons = @(
                'Александр', 'Сергей', 'Владислав', 'Шевченко Антон', 'Лазарев Илья', 'Гурий Самарин',
                'Виктор', 'Руслан Артамонов', 'Александр Ерыгин', 'Сергей Бензенко', 'Александр Лапердин',
                'Ольга Бондаренко', 'Дмитрий Сорокин', 'Сергей Краснов', 'Константин Ушаков',
                'Андрей Фазлеев', 'Басим Аль-Джевахири', 'Андрей Маслов', 'Дмитрий Павлов',
                 'Постарнаков Андрей')
        }
    }
}

function Get-LinksFromMarkDown()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $Description
    )

    process
    {
        $Description -split "`n" |
        ForEach-Object {

            $line = $_.Trim()
            if ($line -match '\[(?<Link>https?://[^\]]+)')
            {
                $Matches['Link']
            }
            elseif ($line -match '^https?://')
            {
                $line
            }
        }
    }
}

function Format-PodcastTopic
{
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [object] $Card
    )

    begin
    {
        $topicCount = 0
        $linkCount = 0
    }
    process
    {
        $subject = $Card.name.Trim()
        Write-Information "- $subject"

        [string[]] $links = $Card.desc | Get-LinksFromMarkDown

        @{
            Subject = $subject
            Timestamp = '00:00:00'
            Links = $links
        }

        $topicCount++
        $linkCount += $links.Count
    }
    end
    {
        Write-Information "Found: $topicCount topics, $linkCount links"
    }
}

function ConvertTo-RssPodcastItem
{
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [Xml.XmlElement] $RssItem
    )

    process
    {
        # HACK: We have to use this hack because the element is missing for episode number zero
        $hackEpisode = $RssItem.ChildNodes.GetEnumerator() |
            Where-Object { $_.Name -eq 'itunes:episode' } |
            ForEach-Object { [int]$_.InnerText } |
            Select-Object -First 1

        $title = $RssItem.title[0].'#cdata-section'.Trim()
        @{
            Number = [int]$hackEpisode
            Title = $title
            PublishDate = [datetime]$RssItem.pubDate
            Home = $RssItem.link.Trim()
            Audio = $RssItem.enclosure.url.Trim()
            AudioLength = $RssItem.enclosure.length.Trim()
        }
    }
}

function Format-PodcastRssHeader
{
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [hashtable]
        $Podcast
    )

    process
    {
        $rssItem = Invoke-RestMethod -Method Get -Uri ([PodcastAnnouncement]::RssUrl) |
            ConvertTo-RssPodcastItem |
            Where-Object { $_['Number'] -eq $Podcast['Number'] }

        if (-not $rssItem)
        {
            return
        }

        $Podcast['PublishDate'] = $rssItem['PublishDate']
        $Podcast['Home'] = $rssItem['Home']
        $Podcast['Audio'] = $rssItem['Audio']

        $Podcast
    }
}

function ConvertTo-PodcastMarkDowm
{
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [hashtable]
        $Podcast
    )

    process
    {
        $description = ''
        if ($Podcast.Contains('Description'))
        {
            $description = $Podcast['Description']
            $podcast.Remove('Description')
        }

        '---'
        ConvertTo-CuteYaml -Data $Podcast -KeyOrderer $EpisodeSorter
        '---'
        $description.Trim()
    }
}

function ConvertFrom-PodcastMarkDowm
{
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param (
        [Parameter(ValueFromPipeline)]
        [string]
        $Line
    )

    begin
    {
        $yaml = ''
        $frontMatter = $false
        $frontMatterSplitter = '---'
        $markdown = ''
        $nl = [System.Environment]::NewLine
    }
    process
    {
        if ($frontMatter)
        {
            if ($Line -eq $frontMatterSplitter)
            {
                $frontMatter = $false
            }
            else
            {
                $yaml += $Line + $nl
            }
        }
        else
        {
            if ($Line -eq $frontMatterSplitter)
            {
                $frontMatter = $true
            }
            else
            {
                $markdown += $Line + $nl
            }
        }
    }
    end
    {
        $podcast = $yaml | ConvertFrom-Yaml
        $markdown = $markdown.Trim()
        if ($markdown)
        {
            $podcast['Description'] = $markdown
        }

        $podcast
    }
}

function Read-PersonLink
{
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]
        $AuditPath
    )

    process
    {
        Read-Speaker -AuditDir $AuditPath |
            Where-Object { $_.TwitterUrl } |
            ConvertTo-Hashtable { $_.Name } { $_.TwitterUrl }
    }
}

function Format-MaveAnnouncement
{
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [hashtable]
        $Podcast
    )

    process
    {
        [PodcastAnnouncement]::new($Podcast, @{}, $true).
            Identity().
            Description().
            Site().
            DonatResources().
            Topics().
            Music().
            ToString()
    }
}

function Format-VKAnnouncement
{
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [hashtable]
        $Podcast,

        [Parameter(Mandatory)]
        [hashtable]
        $Links
    )

    process
    {
        [PodcastAnnouncement]::new($Podcast, $Links).
            Identity().
            Home().
            Description().
            Topics().
            Authors().
            Mastering().
            Music().
            Patrons().
            EMail().
            PlayResources().
            DonatResources().
            ToString()
    }
}

function Format-YouTubeAnnouncement
{
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [hashtable]
        $Podcast,

        [Parameter(Mandatory)]
        [hashtable]
        $Links
    )

    process
    {
        [PodcastAnnouncement]::new($Podcast, $Links).
            Identity().
            Slogan().
            Description().
            Audio().
            TopicsWithZeroBase().
            Authors().
            Mastering().
            Music().
            Patrons().
            EMail().
            PlayResources().
            DonatResources().
            ToString()
    }
}

function Format-TwitterAnnouncement
{
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [hashtable]
        $Podcast,

        [Parameter(Mandatory)]
        [hashtable]
        $Links
    )

    process
    {
        [PodcastAnnouncement]::new($Podcast, $Links).
            Identity().
            Home().
            PlayResources($true).
            ToString()
    }
}

function Format-PodcastCover
{
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [hashtable]
        $Podcast,

        [Parameter(Mandatory)]
        [string]
        $PodcastHome
    )

    process
    {
        [PodcastAnnouncement]::new($Podcast, @{}).
            Identity().
            ShortDate().
            Topics($false, $false).
            ToString()

        $coverPath = Join-Path $PodcastHome 'cover.svg'
        ''
        'Optimized SVG:'
        "$coverPath"
        'PNG: 1920 × 1080'
        'https://www.headliner.app/'
        'https://www.onlineconverter.com/audio-to-video'
        'Rss: https://cloud.mave.digital/37167'
    }
}

function Set-PodcastToFile
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [hashtable]
        $Podcast
    )

    process
    {
        ConvertTo-PodcastMarkDowm -Podcast $podcast |
        Set-Content -Path $Path -Encoding UTF8
    }
}

function Get-PodcastFromFile
{
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    process
    {
        Get-Content -Path $Path -Encoding UTF8 |
        ConvertFrom-PodcastMarkDowm
    }
}

function Test-PodcastFormat
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [hashtable]
        $Podcast,

        [switch]
        $Full
    )

    process
    {
        $prevTimestamp = [TimeSpan]::Zero
        foreach ($topic in $Podcast.Topics)
        {
            if ($topic.Timestamp -eq [TimeSpan]::Zero)
            {
                throw "Timestamp not found for «$($topic.Subject)»"
            }

            if ($topic.Timestamp -le $prevTimestamp)
            {
                throw "Timestamp doesn't grow for «$($topic.Subject)»"
            }

            $prevTimestamp = $topic.Timestamp
        }

        if ($Full)
        {
            $missingFields = @(
                'PublishDate',
                'Home',
                'Audio',
                'Video'
            ) |
            Where-Object { -not $Podcast.ContainsKey($_) } |
            Join-ToString

            if ($missingFields)
            {
                throw "Missing fields from «$($podcast.Number)»: $missingFields"
            }
        }
    }
}

function Resolve-IndexPath
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [int]
        $Number
    )

    process
    {
        Join-Path $PodcastHome "RadioDotNet-$Number" | Join-Path -ChildPath 'index.md'
    }
}

function Resolve-LastIndexPath()
{
    Get-ChildItem $PodcastHome |
    ForEach-Object {
        if ($_.Name -match 'RadioDotNet-(?<number>\d+)')
        {
            [int] $Matches['number']
        }
     } |
     Measure-Object -Maximum |
     Select-Object -ExpandProperty 'Maximum' |
     Resolve-IndexPath
}

function New-PodcastFromTrello
{
    [CmdletBinding()]
    param ()

    process
    {
        $timer = Start-TimeOperation -Name 'Create podcast from Trello'

        $board = Get-TrelloBoard -Name $TrelloBoardName
        if (-not $board) { throw "Trello board «$TrelloBoardName» not found" }

        $list = $board | Get-TrelloList | Where-Object { $_.name.StartsWith($TrelloNewCardListName) }
        if (-not $list) { throw "Trello list «$TrelloNewCardListName» in board «$TrelloBoardName» not found" }

        $episodeNumber = $list.name | Select-EpisodeNumber

        if ($episodeNumber -gt 0)
        {
            $prevIndex = $episodeNumber - 1 | Resolve-IndexPath
            $prevPodcast = Get-PodcastFromFile -Path $prevIndex
            Test-PodcastFormat -Podcast $prevPodcast -Full
        }

        $filePath = $episodeNumber | Resolve-IndexPath

        $dirName = Split-Path -Path $filePath
        New-Item -Path $dirName -ItemType Directory | Out-Null

        Write-Information "Scan «$($list.name)» list in «$($board.name)» board for episode №$episodeNumber"

        $podcast = $episodeNumber | Format-PodcastHeader
        $podcast['Topics'] = $board |
             Get-TrelloCard -List $list |
             Format-PodcastTopic

        $filePath | Set-PodcastToFile -Podcast $podcast

        $timer | Stop-TimeOperation

        Write-Information "Please, fill in Title, Authors, Description and Timestamps before the next step in «$(Split-Path -Leaf $filePath)»"
    }
}

function New-PodcastFromHand
{
    [CmdletBinding()]
    param ()

    process
    {
        $timer = Start-TimeOperation -Name 'Create podcast from hand'

        $episodeNumber = 94
        $topics = @()
        $index = 0

        $times = @(
            65.845520
            1252.028559
            3365.906391
            3830.579203
            5220.998387
            5490.222106
            5680.612332
        ) | ForEach-Object {
            [TimeSpan]::FromSeconds($_).ToString('hh\:mm\:ss')
        }

        $topics += @{
            Subject = 'General Availability of .NET Aspire'
            Timestamp = $times[$index++]
            Links = @(
                'https://devblogs.microsoft.com/dotnet/dotnet-aspire-general-availability/'
            )
        }
        $topics += @{
            Subject = "What's new in C# 13"
            Timestamp = $times[$index++]
            Links = @(
                'https://build.microsoft.com/en-US/sessions/689e5104-72e9-4d02-bb52-77676d1ec5bc'
             )
        }
        $topics += @{
            Subject = '.NET Announcements and Updates from Microsoft Build 2024'
            Timestamp = $times[$index++]
            Links = @(
                'https://devblogs.microsoft.com/dotnet/dotnet-build-2024-announcements/'
                'https://devblogs.microsoft.com/dotnet/catching-up-on-microsoft-build-2024-essential-sessions-for-dotnet-developers/'
            )
        }
        $topics += @{
            Subject = '.NET 9 Preview 4'
            Timestamp = $times[$index++]
            Links = @(
                'https://github.com/dotnet/core/discussions/9318'
                'https://github.com/dotnet/core/blob/main/release-notes/9.0/preview/preview4/libraries.md'
                'https://github.com/dotnet/core/blob/main/release-notes/9.0/preview/preview4/runtime.md'
                'https://github.com/dotnet/core/blob/main/release-notes/9.0/preview/preview4/efcoreanddata.md'
                'https://github.com/dotnet/core/blob/main/release-notes/9.0/preview/preview4/aspnetcore.md'
            )
        }
        $topics += @{
            Subject = 'Visual Studio 2022 17.10 and GitHub Copilot, First preview of Visual Studio 2022 v17.11'
            Timestamp = $times[$index++]
            Links = @(
                'https://devblogs.microsoft.com/visualstudio/visual-studio-2022-17-10-now-available/'
                'https://devblogs.microsoft.com/visualstudio/first-preview-of-visual-studio-2022-v17-11/'
            )
        }
        $topics += @{
            Subject = 'Announcing NuGet 6.10'
            Timestamp = $times[$index++]
            Links = @(
                'https://devblogs.microsoft.com/nuget/announcing-nuget-6-10/'
            )
        }
        $topics += @{
            Subject = 'Кратко о разном'
            Timestamp = $times[$index++]
            Links = @(
                'https://www.youtube.com/watch?v=TRFfTdzpk-M'
                'https://habr.com/ru/companies/pvs-studio/articles/816221/'
                'https://xunit.net/releases/v2/2.8.1'
            )
        }

        $filePath = $episodeNumber | Resolve-IndexPath

        $dirName = Split-Path -Path $filePath
        New-Item -Path $dirName -ItemType Directory | Out-Null

        $podcast = $episodeNumber | Format-PodcastHeader

        $podcast['Topics'] = $topics

        $filePath | Set-PodcastToFile -Podcast $podcast

        $timer | Stop-TimeOperation

        Write-Information "Please, fill in Title, Authors, Description and Timestamps before the next step in «$(Split-Path -Leaf $filePath)»"
    }
}

function New-PodcastAnnouncementForMave
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    process
    {
        if (-not (Test-Path -Path $Path -PathType Leaf)) { throw "Index file «$Path» not found" }

        Write-Information "Format Mave announcement from «$Path»"

        $podcast = Get-PodcastFromFile -Path $Path
        $podcastHome = Split-Path $Path

        Test-PodcastFormat -Podcast $podcast

        Format-MaveAnnouncement -Podcast $podcast |
        Set-Content -Path ([IO.Path]::ChangeExtension($Path, 'mave.html')) -Encoding UTF8

        # TODO: Format SVG cover
        Format-PodcastCover -Podcast $podcast -PodcastHome $podcastHome |
        Set-Content -Path ([IO.Path]::ChangeExtension($Path, 'cover.txt')) -Encoding UTF8
    }
}

function New-PodcastFromMave
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    process
    {
        if (-not (Test-Path -Path $Path -PathType Leaf)) { throw "Index file «$Path» not found" }

        $podcast = Get-PodcastFromFile -Path $Path

        $episodeNumber = $podcast.Number
        Write-Information "Enrich episode №$episodeNumber"

        $podcast = Format-PodcastRssHeader -Podcast $podcast

        if (-not $podcast)
        {
            Write-Warning "Can't found episode №$episodeNumber in RSS feed"
            return
        }

        $uniqSuffix = Get-Date -Format 'mmssfffffff'
        Copy-Item -Path $Path -Destination ([IO.Path]::ChangeExtension($Path, "${uniqSuffix}.bak")) -Force | Out-Null

        $Path | Set-PodcastToFile -Podcast $podcast
    }
}

function New-PodcastAnnouncement
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    process
    {
        if (-not (Test-Path -Path $Path -PathType Leaf)) { throw "Index file «$Path» not found" }

        Write-Information "Format announcements from «$($Path)»"

        $podcast = Get-PodcastFromFile -Path $Path
        $links = Read-PersonLink -AuditPath $AuditDir

        Format-YouTubeAnnouncement -Podcast $podcast -Links $links |
        Set-Content -Path ([IO.Path]::ChangeExtension($Path, 'youtube.txt')) -Encoding UTF8

        Format-VKAnnouncement -Podcast $podcast -Links $links |
        Set-Content -Path ([IO.Path]::ChangeExtension($Path, 'vk.txt')) -Encoding UTF8

        Format-TwitterAnnouncement -Podcast $podcast -Links $links |
        Set-Content -Path ([IO.Path]::ChangeExtension($Path, 'twitter.txt')) -Encoding UTF8
    }
}

# $PodcastIndex = Resolve-LastIndexPath

# Step 1
# Get-TrelloConfiguration | Out-Null
# New-PodcastFromHand

# Step 2
# New-PodcastAnnouncementForMave -Path $PodcastIndex

# Step 3
# New-PodcastFromMave -Path $PodcastIndex
# New-PodcastAnnouncement -Path $PodcastIndex
#  - YT/DotNetRu (https://www.headliner.app/)
#  - VK/DotNetRu
#  - Tg/DotNetRu

