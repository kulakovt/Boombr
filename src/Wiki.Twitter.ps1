. $PSScriptRoot\Utility.ps1

$TwitterApiEndpoint = 'https://api.twitter.com/1.1/statuses'

function Invoke-TwitterMethod
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
        $token = 'TwitterBearerToken' | Get-Secret
        $headers = @{
            Authorization = "Bearer $token"
        }

        $resourceWithQuery = $Resource
        $query = $QueryParts | Format-UriQuery
        if ($query)
        {
            $resourceWithQuery += "?${query}"
        }

        $url = $TwitterApiEndpoint | Join-Uri -RelativeUri $resourceWithQuery

        Invoke-RestMethod $url -Headers $headers
    }
}

function Get-TwitterStatus
{
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]
        $UserName,

        [Parameter()]
        [int]
        $Count = 10
    )

    process
    {
        $query = @{
            screen_name = $UserName
            count = $Count
            exclude_replies = 1
            trim_user = 1
        }

        $response = 'user_timeline.json' | Invoke-TwitterMethod -QueryParts $query

        $response |
        ForEach-Object {
            $tweet = $_
            [PSCustomObject] @{
                PSTypeName = 'Tweet'
                Id = $tweet.id
                UserId = $tweet.user.id
                Text = $tweet.text
                LikesCount = [int] $tweet.favorite_count
                RepostsCount = [int] $tweet.retweet_count
            }
        }
    }
}


function Get-TwitterRetweet
{
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [PSTypeName('Tweet')]
        $Tweet
    )

    process
    {
        $response = "retweets/$($Tweet.Id).json" | Invoke-TwitterMethod

        $response |
        ForEach-Object {
            $retweet = $_
            [PSCustomObject] @{
                PSTypeName = 'TwitterUser'
                Id = $retweet.user.id
                Name = $retweet.user.name
                ScreenName = $retweet.user.screen_name
            }
        }
    }
}

# 'DotNetRu' |
# Get-TwitterStatus -Count 1 |
# Out-Tee |
# Get-TwitterRetweet |
# Add-NumberToCustomObject |
# Export-Csv -Path (Join-Path $PSScriptRoot '../artifacts/tw-dotnetru-retweets.csv') -NoTypeInformation -Encoding UTF8 -Delimiter ';'
