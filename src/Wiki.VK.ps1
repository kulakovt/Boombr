. $PSScriptRoot\Utility.ps1

$VKApiEndpoint = 'https://api.vk.com/method'

function Invoke-VKMethod
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Resource,

        [Hashtable]
        $QueryParts = @{}
    )

    process
    {
        $QueryParts['access_token'] = 'VKAccessToken' | Get-Secret
        $QueryParts['v'] = '5.103'
        $query = $QueryParts | Format-UriQuery

        $url = "${VKApiEndpoint}/${Resource}?${query}"

        Invoke-RestMethod $url
    }
}

function Get-VKWall
{
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]
        $DomainName,

        [Parameter()]
        [int]
        $Count = 10
    )

    process
    {
        # https://vk.com/dev/wall.get
        $query = @{
            domain = $DomainName
            count = $Count
            filter = 'owner'
            extended = 1
        }

        $response = 'wall.get' | Invoke-VKMethod -QueryParts $query

        $response.response.items |
        ForEach-Object {
            $post = $_
            [PSCustomObject] @{
                PSTypeName = 'VKPost'
                Id = $post.id
                OwnerId = $post.owner_id
                CommentsCount = $post.comments.count
                LikesCount = $post.likes.count
                RepostsCount = $post.reposts.count
                ViewsCount = $post.views.count
                Text = $post.text
            }
        }
    }
}

function Get-VKPostLike
{
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [PSTypeName('VKPost')]
        $Post
    )

    process
    {
        # https://vk.com/dev/likes.getList
        $query = @{
            type = 'post'
            owner_id = $Post.OwnerId
            item_id = $Post.Id
            count = 1000
            filter = 'likes'
            friends_only = 0
            skip_own = 0
            extended = 1
        }

        $response = 'likes.getList' | Invoke-VKMethod -QueryParts $query

        $response.response.items |
        ForEach-Object {
            $actor = $_
            [PSCustomObject] @{
                PSTypeName = 'VKActor'
                Id = $actor.id
                Name = @($actor.first_name, $actor.last_name) -join ' '
                ScreenName = 'id' + $actor.id
            }
        }
    }
}

function Get-VKRepost
{
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [PSTypeName('VKPost')]
        $Post
    )

    process
    {
        # https://vk.com/dev/wall.getReposts
        $query = @{
            owner_id = $Post.OwnerId
            post_id = $Post.Id
            count = 1000
        }

        $response = 'wall.getReposts' | Invoke-VKMethod -QueryParts $query

        $response.response.profiles |
        ForEach-Object {
            $actor = $_
            [PSCustomObject] @{
                PSTypeName = 'VKActor'
                Id = $actor.id
                Name = @($actor.first_name, $actor.last_name) -join ' '
                ScreenName = $actor.screen_name
            }
        }

        $response.response.groups |
        ForEach-Object {
            $actor = $_
            [PSCustomObject] @{
                PSTypeName = 'VKActor'
                Id = $actor.id
                Name = $actor.name
                ScreenName = $actor.screen_name
            }
        }
    }
}

# $post = 'DotNetRu' | Get-VKWall -Count 1
# $post | Get-VKPostLike | Export-Csv -Path (Join-Path $PSScriptRoot '../artifacts/vk-dotnetru-likes.csv') -NoTypeInformation -Encoding UTF8 -Delimiter ';'
# $post | Get-VKRepost   | Export-Csv -Path (Join-Path $PSScriptRoot '../artifacts/vk-dotnetru-reposts.csv') -NoTypeInformation -Encoding UTF8 -Delimiter ';'
