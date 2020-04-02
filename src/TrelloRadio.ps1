#Requires -Version 5
#Requires -Modules PowerTrello

Set-StrictMode -version Latest
$ErrorActionPreference = 'Stop'

. $PSScriptRoot\Utility.ps1
. $PSScriptRoot\YamlCuteSerialization.ps1

$TrelloBoardName = 'RadioDotNet'
$TrelloNewCardListName = 'Обсуждаем-'

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
            # TODO: Import Timestamps
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
        $rssItem = Invoke-RestMethod -Method Get -Uri $RssUrl |
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
        [Parameter(ValueFromPipeline)]
        [string] $Yaml
    )

    begin
    {
        '---'
    }
    process
    {
        # TODO: Move Description to the end
        $Yaml
    }
    end
    {
        '---'
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

class PodcastAnnouncement
{
    static [string] $PodcastName = 'RadioDotNet'
    static [string] $SiteUrl = 'http://Radio.DotNet.Ru'
    static [string] $RssUrl = 'https://anchor.fm/s/f0c0ef4/podcast/rss'

    [hashtable] $Podcast
    [Text.StringBuilder] $Report

    PodcastAnnouncement([hashtable] $Podcast)
    {
        $this.Report = New-Object -TypeName 'System.Text.StringBuilder'
        $this.Podcast = $Podcast
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

    [PodcastAnnouncement] Identity()
    {
        $textPubDate = ''
        if ($this.Podcast.Contains('PublishDate'))
        {
            $localPubDate = $this.Podcast['PublishDate'] | ConvertTo-LocalTime
            $textPubDate = $localPubDate.ToString(' от d MMMM yyyy года', [System.Globalization.CultureInfo]::GetCultureInfo('ru-RU'))
        }

        return $this.Line("Подкаст $($this::PodcastName) выпуск №$($this.Podcast['Number'])$textPubDate")
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
        return $this.Line($this.Podcast['Home']).Line()
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
            # TODO: Add Twitters
            $this.Append("• $author")
        }
        return $this
    }

    [PodcastAnnouncement] Mastering()
    {
        # TODO: Get Approval
        return $this.
            Line('Звукорежиссёр:').
            Line("• $($this.Podcast['Mastering'])")
    }

    [PodcastAnnouncement] Topics()
    {
        $this.Line('Темы:').Append()
        foreach ($topic in $this.Podcast['Topics'])
        {
            $this.Append("[$($topic.Timestamp)] — $($topic.Subject)")
            foreach ($link in $topic.Links)
            {
                $this.Append("• $link")
            }
            $this.Append()
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
        $Podcast
    )

    process
    {
        # TODO: Format as Anchor HTML
        [PodcastAnnouncement]::new($Podcast).
            Identity().
            Line().
            Description().
            Site().
            Line().
            Topics().
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
        $Podcast
    )

    process
    {
        [PodcastAnnouncement]::new($Podcast).
            Identity().
            Line().
            Slogan().
            Line().
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
        $filePath = Join-Path -Path $Path ('e{0:D3}.md' -f $episodeNumber)

        Write-Information "Scan «$($list.name)» list in «$($board.name)» board for episode №$episodeNumber"

        $podcast = $episodeNumber | Format-PodcastHeader
        $podcast['Topics'] = $board |
             Get-TrelloCard -List $list |
             Format-PodcastTopic

        ConvertTo-CuteYaml -Data $podcast -KeyOrderer $EpisodeSorter |
        ConvertTo-PodcastMarkDowm |
        Set-Content -Path $filePath -Encoding UTF8

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

        $podcast = Get-Content -Path $Path -Encoding UTF8 |
            ConvertFrom-PodcastMarkDowm

        Format-AnchorAnnouncement -Podcast $podcast |
        Set-Content -Path "${Path}.anchor.txt" -Encoding UTF8
    }
}

function New-PodcastNote
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    process
    {
        $timer = Start-TimeOperation -Name 'Create podcast show notes'

        $baseFile = Get-Item -Path "${Path}/*" -Filter 'e*.yaml'
        if (-not ($baseFile -is [IO.FileInfo]))
        {
            Write-Warning "Base file not found at $Path"
            return
        }

        $podcast = $baseFile |
            Get-Content -Encoding UTF8 -Raw |
            ConvertFrom-Yaml

        $episodeNumber = $podcast.Number
        Write-Information "Enrich episode №$episodeNumber"
        $filePath = Join-Path -Path $Path ('e{0:D3}.md' -f $episodeNumber)

        if (Test-Path -Path $filePath)
        {
            # TODO: Preserve markdown description
            Write-Warning "Episode notes already exist at $filePath"
            return
        }

        $podcast = Format-PodcastRssHeader -Podcast $Podcast

        if (-not $podcast)
        {
            Write-Warning "Can't found episode №$episodeNumber in RSS feed"
            return
        }

        ConvertTo-CuteYaml -Data $podcast -KeyOrderer $EpisodeSorter |
        ConvertTo-PodcastMarkDowm |
        Set-Content -Path $filePath -Encoding UTF8

        Format-PodcastAnnouncement -Podcast $podcast |
        Set-Content -Path ([IO.Path]::ChangeExtension($filePath, 'txt')) -Encoding UTF8
        Write-Information "Write file $([System.IO.Path]::GetFileName($filePath))"

        $timer | Stop-TimeOperation
    }
}

$PodcastHome = Join-Path $PSScriptRoot '..\..\Site\input\Radio' -Resolve
$PodcastIndex = Join-Path $PodcastHome '007.md'
# Step 1
# Get-TrelloConfiguration | Out-Null
# $PodcastHome | New-PodcastFromTrello

# Step 2
New-PodcastAnnouncementForAnchor -Path $PodcastIndex
<#
$PodcastHome | New-PodcastNote
#>

<#
$p = ls (Join-Path $PodcastHome '002.md' -Resolve) |
    Get-Content -Encoding UTF8 |
    ConvertFrom-PodcastMarkDowm

Format-YouTubeAnnouncement -Podcast $p |
Set-Content -Path (Join-Path $PodcastHome 'youtube.txt' -Resolve) -Encoding UTF8
#>
