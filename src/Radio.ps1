#Requires -Version 5

# TODO:
# - Draw cover.svg with topics
#   - https://khalidabuhakmeh.com/programming-svgs-with-csharp-dotnet

Set-StrictMode -version Latest
$ErrorActionPreference = 'Stop'

. $PSScriptRoot\Utility.ps1
. $PSScriptRoot\YamlCuteSerialization.ps1
. $PSScriptRoot\Model.ps1
. $PSScriptRoot\Serialization.ps1
. $PSScriptRoot\RadioKaiten.ps1

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

function New-PodcastAnnouncementForMave
{
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $Path = (Resolve-LastIndexPath)
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
        [Parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $Path = (Resolve-LastIndexPath)
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
        [Parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $Path = (Resolve-LastIndexPath)
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
    }
}

function New-ManualPodcast
{
    [CmdletBinding()]
    param ()

    process
    {
        $timer = Start-TimeOperation -Name 'Create manual podcast'

        $episodeNumber = 101
        $topics = @()
        $index = 0

        $times = @(
            174.505936
            820.253329
            2221.530925
            3164.258342
            3736.442718
            4488.397521
            4559.623217
        ) | ForEach-Object {
            [TimeSpan]::FromSeconds($_).ToString('hh\:mm\:ss')
        }

        $topics += @{
            Subject = 'Getting started with testing and .NET Aspire'
            Timestamp = $times[$index++]
            Links = @(
                'https://devblogs.microsoft.com/dotnet/getting-started-with-testing-and-dotnet-aspire/'
            )
        }
        $topics += @{
            Subject = 'Заглядываем под капот FrozenDictionary'
            Timestamp = $times[$index++]
            Links = @(
                'https://habr.com/ru/articles/837926/'
             )
        }
        $topics += @{
            Subject = 'Run a Large Language Model (LLM) Locally With C#'
            Timestamp = $times[$index++]
            Links = @(
                'https://code-maze.com/csharp-run-large-language-model-like-chatgpt-locally/'
                'https://www.youtube.com/watch?v=rmxRxpyYtZA&list=PLbxr_aGL4q3QUNRtZjlDArZeTvYB_qp0v'
            )
        }
        $topics += @{
            Subject = 'Differences Between Onion and Clean Architecture'
            Timestamp = $times[$index++]
            Links = @(
                'https://code-maze.com/dotnet-differences-between-onion-architecture-and-clean-architecture/'
            )
        }

        $topics += @{
            Subject = 'Avoid using enums in the domain layer'
            Timestamp = $times[$index++]
            Links = @(
                'https://www.infoworld.com/article/2336631/avoid-using-enums-in-the-domain-layer-in-c-sharp.html'
            )
        }

        $topics += @{
            Subject = 'Подслушано'
            Timestamp = $times[$index++]
            Links = @(
                'https://podlodka.io/374'
            )
        }

        $topics += @{
            Subject = 'Кратко о разном'
            Timestamp = $times[$index++]
            Links = @(
                'https://www.jimmybogard.com/integrating-the-particular-service-platform-with-aspire/'
                'https://steven-giesel.com/blogPost/a807373c-dcc6-42f9-995f-e69dcea1cd47/to-soft-delete-or-not-to-soft-delete'
                'https://github.com/dotnet/roslyn/blob/main/docs/Language%20Feature%20Status.md'
                'https://ardalis.com/interfaces-describe-what-implementations-describe-how/'
                'https://andrewlock.net/major-updates-to-netescapades-aspnetcore-security-headers/'
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

function New-Podcast
{
    [CmdletBinding()]
    param ()

    process
    {
        $timer = Start-TimeOperation -Name 'Create podcast from Kaiten'

        $podcast = New-KaitenPodcast
        $episodeNumber = $podcast.Number

        # Test previous eposode
        if ($episodeNumber -gt 0)
        {
            $prevIndex = $episodeNumber - 1 | Resolve-IndexPath
            $prevPodcast = Get-PodcastFromFile -Path $prevIndex
            Test-PodcastFormat -Podcast $prevPodcast -Full
        }

        $filePath = $episodeNumber | Resolve-IndexPath

        $dirName = Split-Path -Path $filePath
        New-Item -Path $dirName -ItemType Directory | Out-Null

        $filePath | Set-PodcastToFile -Podcast $podcast

        $timer | Stop-TimeOperation

        Write-Information "Please, fill in Timestamps, Title, Authors and Description before the next step in «$(Split-Path -Leaf $filePath)»"
    }
}

# Step 1
# $PodcastTimestamps = @(
#     122.141282
#     335.945975
#     2381.971662
#     3209.131548
#     3726.778737
#     4428.223352
#     4994.495302
#     5229.380653
# ) | ForEach-Object {
#     [TimeSpan]::FromSeconds($_).ToString('hh\:mm\:ss')
# }
# New-Podcast

# Step 2
# New-PodcastAnnouncementForMave

# Step 3
# New-PodcastFromMave
# New-PodcastAnnouncement
#  - YT/DotNetRu
#  - VK/DotNetRu
#  - Tg/DotNetRu

