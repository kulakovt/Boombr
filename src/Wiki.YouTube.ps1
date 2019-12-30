# Thanks:
# - https://lazywinadmin.com/2019/04/retrieving_youtube_videos_information_with_powershell.html

. $PSScriptRoot\Utility.ps1

$YouTubeApiEndpoint = 'https://www.googleapis.com/youtube/v3'
$VideoItemBatchSize = 50

function Group-ToStringBatch([int] $BatchSize = $VideoItemBatchSize, [string] $Separator = ',')
{
    begin
    {
        $items = @()
    }
    process
    {
        $items += $_
        if ($items.Count -ge $BatchSize)
        {
            $items -join $Separator
            $items = @()
        }
    }
    end
    {
        if ($items)
        {
            $items -join $Separator
            $items = @()
        }
    }
}

function Get-YouTubePlaylist
{
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ChannelId
    )

    process
    {
        $query = @{
            part = 'snippet'
            channelId = $ChannelId
            maxResults = $VideoItemBatchSize
            key = $YouTubeApiKey
        } |
        Format-UriQuery

        $url = "${YouTubeApiEndpoint}/playlists?${query}"
        $responce = Invoke-RestMethod $url

        $responce.items |
        ForEach-Object {
            $palylist = $_
            [PSCustomObject] @{
                PSTypeName = 'YouTubePlaylist'
                Id = $palylist.id
                Title = $palylist.snippet.title
            }
        }
    }
}

function Get-YouTubePlaylistItem
{
    [CmdletBinding()]
    [OutputType([string[]])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [PSTypeName('YouTubePlaylist')]
        $Playlist
    )

    process
    {
        $next = $null

        do
        {
            $query = @{
                part = 'contentDetails'
                playlistId = $Playlist.Id
                maxResults = $VideoItemBatchSize
                key = $YouTubeApiKey
            }

            if ($next)
            {
                $query['pageToken'] = $next
            }

            $url = "${YouTubeApiEndpoint}/playlistItems?$($query | Format-UriQuery)"
            $responce = Invoke-RestMethod $url

            if ('nextPageToken' -in $responce.PSObject.Properties.Name)
            {
                $next = $responce.nextPageToken
            }
            else
            {
                $next = $null
            }

            $responce.items |
            ForEach-Object {
                $palylistItem = $_
                $palylistItem.contentDetails.videoId
            }

        } while ($next)
    }
}

function Get-YouTubeVideStatistic
{
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        $VideoId
    )

    process
    {
        $query = @{
            part = 'snippet,statistics'
            id = $VideoId
            maxResults = $VideoItemBatchSize
            key = $YouTubeApiKey
        } |
        Format-UriQuery

        $url = "${YouTubeApiEndpoint}/videos?${query}"
        $responce = Invoke-RestMethod $url

        $responce.items |
        ForEach-Object {
            $video = $_
            [PSCustomObject] @{
                PSTypeName = 'YouTubeVideo'
                Id = $video.id
                Title = $video.snippet.title
                ViewCount = [int]$video.statistics.viewCount
                LikeCount = [int]$video.statistics.likeCount
                DislikeCount = [int]$video.statistics.dislikeCount
                FavoriteCount = [int]$video.statistics.favoriteCount
                CommentCount = [int]$video.statistics.commentCount
            }
        }
    }
}
