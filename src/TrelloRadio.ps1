#Requires -Version 5
#Requires -Modules PowerTrello

Set-StrictMode -version Latest
$ErrorActionPreference = 'Stop'

. $PSScriptRoot\Utility.ps1
. $PSScriptRoot\YamlCuteSerialization.ps1
. $PSScriptRoot\Model.ps1
. $PSScriptRoot\Serialization.ps1

$TrelloBoardName = 'RadioDotNet'
$TrelloNewCardListName = 'Обсуждаем-'
$AuditDir = Join-Path $PSScriptRoot '..\..\Audit\db' -Resolve
$InformationPreference = 'Continue'

$EpisodeSorter = { @('Number', 'Title', 'PublishDate', 'Authors', 'Mastering', 'Home', 'Audio', 'Topics', 'Subject', 'Timestamp', 'Links').IndexOf($_) }

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
            Mastering = 'Максим Шошин'
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

        [string[]] $links = $Card.desc -split "`n" |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -match '^https?://' }

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
        $title = $RssItem.title.'#cdata-section'.Trim()
        @{
            Number = $title | Select-EpisodeNumber
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

class PodcastAnnouncement
{
    static [string] $PodcastName = 'RadioDotNet'
    static [string] $SiteUrl = 'http://Radio.DotNet.Ru'
    static [string] $RssUrl = 'https://anchor.fm/s/f0c0ef4/podcast/rss'

    [hashtable] $Podcast
    [hashtable] $Links
    [Text.StringBuilder] $Report

    PodcastAnnouncement([hashtable] $Podcast, [hashtable] $Links)
    {
        $this.Podcast = $Podcast
        $this.Links = $Links
        $this.Report = New-Object -TypeName 'System.Text.StringBuilder'
    }

    [String] ToString()
    {
        return $this.Report.ToString().Trim()
    }

    Append()
    {
        $this.Append('')
    }

    Append([string] $line = '')
    {
        $this.Line($line) | Out-Null
    }

    [PodcastAnnouncement] Line()
    {
        return $this.Line('')
    }

    [PodcastAnnouncement] Line([string] $line)
    {
        $this.Report.AppendLine($line)
        return $this
    }

    [string] FormatDate([string] $template)
    {
        $localPubDate = $this.Podcast['PublishDate'] | ConvertTo-LocalTime
        return $localPubDate.ToString($template, [System.Globalization.CultureInfo]::GetCultureInfo('ru-RU'))
    }

    [PodcastAnnouncement] Identity()
    {
        $textPubDate = ''
        if ($this.Podcast.Contains('PublishDate'))
        {
            $textPubDate = $this.FormatDate(' от d MMMM yyyy года')
        }

        return $this.Line("Подкаст $($this::PodcastName) выпуск №$($this.Podcast['Number'])$textPubDate")
    }

    [PodcastAnnouncement] ShortDate()
    {
        $textPubDate = $this.FormatDate('d MMM yyyy')
        return $this.Line($textPubDate)
    }

    [PodcastAnnouncement] Slogan()
    {
        return $this.Line('Разговоры на тему .NET во всех его проявлениях, новости, статьи, библиотеки, конференции, личности и прочее интересное из мира IT.')
    }

    [PodcastAnnouncement] Description()
    {
        if ($this.Podcast.Contains('Description'))
        {
            $this.Line($this.Podcast['Description']).Append()
        }

        return $this
    }

    [PodcastAnnouncement] Home()
    {
        return $this.Line($this.Podcast['Home'])
    }

    [PodcastAnnouncement] Audio()
    {
        return $this.Line("Аудиоверсия: $($this.Podcast['Audio'])")
    }

    [PodcastAnnouncement] Rss()
    {
        return $this.Line("RSS подписка на подкаст: $($this::RssUrl)")
    }

    [PodcastAnnouncement] VideoPlayList()
    {
        # TODO: Line video playlist link
        return $this.Line("Все видео выпуски: <TODO>")
    }

    [PodcastAnnouncement] Site()
    {
        return $this.Line("Сайт подкаста: $($this::SiteUrl)")
    }

    [PodcastAnnouncement] Authors()
    {
        $this.Append('Ведущие:')
        foreach ($author in $this.Podcast['Authors'])
        {
            $link = $this.Links[$author]
            $link = if ($link) { " ($link)" } else  { '' }
            $this.Append("• ${author}${link}")
        }
        return $this
    }

    [PodcastAnnouncement] Mastering()
    {
        $mastering = $this.Podcast['Mastering']
        if ($mastering)
        {
            $link = $this.Links[$mastering]
            $link = if ($link) { " ($link)" } else  { '' }

            $this.
                Line('Звукорежиссёр:').
                Append("• ${mastering}${link}")

        }
        return $this
    }

    [PodcastAnnouncement] Topics()
    {
        return $this.Topics($true)
    }

    [PodcastAnnouncement] Topics([bool] $IncludeLinks)
    {
        $this.Line('Темы:').Append()
        foreach ($topic in $this.Podcast['Topics'])
        {
            $this.Append("[$($topic.Timestamp)] — $($topic.Subject)")
            if ($IncludeLinks)
            {
                foreach ($link in $topic.Links)
                {
                    $this.Append("• $link")
                }
                $this.Append()
            }
        }
        return $this
    }

    [PodcastAnnouncement] Tags()
    {
        return $this.Line('#Podcast #DotNet')
    }
}

function Format-AnchorAnnouncement
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
        # TODO: Format as Anchor HTML
        [PodcastAnnouncement]::new($Podcast, $Links).
            Identity().
            Line().
            Description().
            Site().
            Line().
            Topics().
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
            Line().
            Home().
            Line().
            Description().
            Site().
            Rss().
            Line().
            Topics().
            Line().
            Tags().
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
            Line().
            Slogan().
            Line().
            Description().
            Audio().
            Line().
            Topics().
            Authors().
            Line().
            Mastering().
            Line().
            Site().
            VideoPlayList().
            Line().
            Tags().
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
        [hashtable]
        $Links
    )

    process
    {
        [PodcastAnnouncement]::new($Podcast, $Links).
            Identity().
            Line().
            ShortDate().
            Line().
            Topics($false).
            ToString()
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

function New-PodcastFromTrello
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    process
    {
        $timer = Start-TimeOperation -Name 'Create podcast from Trello'

        $board = Get-TrelloBoard -Name $TrelloBoardName
        if (-not $board) { throw "Trello board «$TrelloBoardName» not found" }

        $list = $board | Get-TrelloList | Where-Object { $_.name.StartsWith($TrelloNewCardListName) }
        if (-not $list) { throw "Trello list «$TrelloNewCardListName» in board «$TrelloBoardName» not found" }

        $episodeNumber = $list.name | Select-EpisodeNumber
        $filePath = Join-Path -Path $Path ('{0:D3}.md' -f $episodeNumber)

        Write-Information "Scan «$($list.name)» list in «$($board.name)» board for episode №$episodeNumber"

        $podcast = $episodeNumber | Format-PodcastHeader
        $podcast['Topics'] = $board |
             Get-TrelloCard -List $list |
             Format-PodcastTopic

        $filePath | Set-PodcastToFile -Podcast $podcast

        $timer | Stop-TimeOperation

        Write-Information "Please, fill in Description and Timestamps before the next step in «$(Split-Path -Leaf $filePath)»"
    }
}

function New-PodcastAnnouncementForAnchor
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

        Write-Information "Format Anchor announcement from «$(Split-Path -Leaf $Path)»"

        $podcast = Get-PodcastFromFile -Path $Path

        Format-AnchorAnnouncement -Podcast $podcast -Links @{} |
        Set-Content -Path ([IO.Path]::ChangeExtension($Path, 'anchor.txt')) -Encoding UTF8
    }
}

function New-PodcastFromAchor
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

        Write-Information "Format announcements from «$(Split-Path -Leaf $Path)»"

        $podcast = Get-PodcastFromFile -Path $Path
        $links = Read-PersonLink -AuditPath $AuditDir

        # TODO: Format SVG cover
        Format-PodcastCover -Podcast $podcast -Links $links |
        Set-Content -Path ([IO.Path]::ChangeExtension($Path, 'cover.txt')) -Encoding UTF8

        Format-YouTubeAnnouncement -Podcast $podcast -Links $links |
        Set-Content -Path ([IO.Path]::ChangeExtension($Path, 'youtube.txt')) -Encoding UTF8

        Format-VKAnnouncement -Podcast $podcast -Links $links |
        Set-Content -Path ([IO.Path]::ChangeExtension($Path, 'vk.txt')) -Encoding UTF8
    }
}

# $PodcastHome = Join-Path $PSScriptRoot '..\..\Site\input\Radio' -Resolve
# $PodcastIndex = Join-Path $PodcastHome '000.md'

# Step 1
# Get-TrelloConfiguration | Out-Null
# $PodcastHome | New-PodcastFromTrello

# Step 2
# New-PodcastAnnouncementForAnchor -Path $PodcastIndex

# Step 3
# New-PodcastFromAchor -Path $PodcastIndex

# Step 4
# New-PodcastAnnouncement -Path $PodcastIndex
