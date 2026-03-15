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
        $oEmbedUrl = [Uri]"https://www.youtube.com/oembed?url=${url}&format=json"

        try
        {
            $response = Invoke-RestMethod -Uri $oEmbedUrl -UseBasicParsing
        }
        catch
        {
            Write-Verbose "Error while read YouTube OEmbed data"
            return
        }

        @{
            SiteName = $response.provider_name
            Type = $response.type
            Url = [string]$url
            Title = $response.title
            Description = $null
            Image = $response.thumbnail_url
        }
    }
}

function Get-OpenGraph()
{
    process
    {
        $url = [Uri]$_

        $prevProgressPreference = $global:ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        try
        {
            # BUG: hangs in some cases, unless -UseBasicParsing is used
            # https://github.com/PowerShell/PowerShell/issues/2812
            $response = Invoke-WebRequest -Uri $url -UseBasicParsing
        }
        catch
        {
            Write-Verbose "Error while read Open Graph data"
            return
        }
        finally
        {
            $global:ProgressPreference = $prevProgressPreference
        }

        $html = New-Object -ComObject 'HTMLFile'
        $html.IHTMLDocument2_write($response.Content)
        $meta = $html.getElementsByTagName('meta') | Where-Object { ($_.outerHTML) -and ($_.outerHTML.Contains("property=`"og:")) }
        if (-not $meta)
        {
            Write-Verbose "Error while read Open Graph meta data"
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
