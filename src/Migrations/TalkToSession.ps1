Clear-Host

Set-StrictMode -version Latest
$ErrorActionPreference = 'Stop'

$InformationPreference = "Continue"
$DebugPreference = "Continue"
$VerbosePreference = "Continue"

. $PSScriptRoot\..\Model.ps1
. $PSScriptRoot\..\Serialization.ps1

$auditDir = Join-Path $PSScriptRoot '..\..\..\Audit\db' -Resolve

function Read-NiceXml()
{
    process
    {
        $content = $_ | Get-Content -Encoding UTF8 -Raw
        $doc = [System.Xml.Linq.XDocument]::Parse($content)
        ConvertFrom-NiceXml ($doc.Root)
    }
}

function Read-Meetup()
{
    Get-ChildItem -Path (Join-Path $auditDir 'meetups') -Filter '*.xml' |
    Read-NiceXml
}


function Save-Entity()
{
    process
    {
        $entity = $_
        $id = $entity.Id
        $fileName = $null

        switch ($entity.GetType())
        {
            ([Meetup])      { $fileName = "meetups/$id.xml" }
            default       { throw "Entity not detected: $($_.FullName)" }
        }

        $file = Join-Path $auditDir $fileName
        if (-not (Test-Path $file -PathType Leaf))
        {
            throw "Can't find existing file: $file"
        }

        Write-Information "Save $($entity.Id)"

        (ConvertTo-NiceXml -Entity $entity).ToString() | Out-File -FilePath $file -Encoding UTF8
    }
}

function Get-Sessions([Meetup] $Meetup)
{
    $defaultStartTime = [TimeSpan]::FromHours(19) - [DateTimeOffset]::Now.Offset
    if ($Meetup.TalkIds.Count -eq 2)
    {
        $s1 = [Session]::new()
        $s1.TalkId = $Meetup.TalkIds[0]
        $s1.StartTime = $Meetup.Date.Date.Add($defaultStartTime)
        $s1.EndTime = $s1.StartTime.AddHours(1)

        $s2 = [Session]::new()
        $s2.TalkId = $Meetup.TalkIds[1]
        $s2.StartTime = $s1.EndTime.AddMinutes(30)
        $s2.EndTime = $s2.StartTime.AddHours(1)

        return @($s1, $s2)
    }

    if ($Meetup.FriendIds.Contains('ITGM'))
    {
        $sessions = @()
        $start = $Meetup.Date.Date.Add([TimeSpan]::FromHours(12) - [DateTimeOffset]::Now.Offset)
        $end = $start.AddMinutes(-30)
        foreach ($talkId in $Meetup.TalkIds)
        {
            $s = [Session]::new()
            $s.TalkId = $talkId
            $s.StartTime = $end.AddMinutes(30)
            $s.EndTime = $s.StartTime.AddHours(1)
            $sessions += $s
            $end = $s.EndTime
        }

        return $sessions
    }

    switch ($Meetup.Id)
    {
        'SpbDotNet-11' {

            $s1 = [Session]::new()
            $s1.TalkId = $Meetup.TalkIds[0]
            $s1.StartTime = $Meetup.Date.Date.Add($defaultStartTime)
            $s1.EndTime = $s1.StartTime.AddMinutes(45)

            $s2 = [Session]::new()
            $s2.TalkId = $Meetup.TalkIds[1]
            $s2.StartTime = $s1.EndTime
            $s2.EndTime = $s2.StartTime.AddMinutes(30)

            $s3 = [Session]::new()
            $s3.TalkId = $Meetup.TalkIds[2]
            $s3.StartTime = $s2.EndTime.AddMinutes(30)
            $s3.EndTime = $s3.StartTime.AddMinutes(75)

            return ($s1, $s2, $s3)
        }
        'SpbDotNet-14' {

            $s1 = [Session]::new()
            $s1.TalkId = $Meetup.TalkIds[0]
            $s1.StartTime = $Meetup.Date.Date.Add($defaultStartTime)
            $s1.EndTime = $s1.StartTime.AddHours(1)

            $s2 = [Session]::new()
            $s2.TalkId = $Meetup.TalkIds[1]
            $s2.StartTime = $s1.EndTime.AddMinutes(30)
            $s2.EndTime = $s2.StartTime.AddHours(1)

            $s3 = [Session]::new()
            $s3.TalkId = $Meetup.TalkIds[2]
            $s3.StartTime = $s2.EndTime
            $s3.EndTime = $s3.StartTime.AddMinutes(30)

            return ($s1, $s2, $s3)
        }
        'SpbDotNet-4' {

            $sessions = @()
            $start = $Meetup.Date.Date.Add($defaultStartTime)
            $end = $start
            foreach ($talkId in $Meetup.TalkIds)
            {
                if ($talkId -eq 'Roslyn-Code-Analysis')
                {
                    $end = $end.AddMinutes(30)
                }
                $s = [Session]::new()
                $s.TalkId = $talkId
                $s.StartTime = $end
                $s.EndTime = $s.StartTime.AddMinutes(30)
                $sessions += $s
                $end = $s.EndTime
            }

            return $sessions
        }
        'SpbDotNet-6' {

            $s1 = [Session]::new()
            $s1.TalkId = $Meetup.TalkIds[0]
            $s1.StartTime = $Meetup.Date.Date.Add($defaultStartTime)
            $s1.EndTime = $s1.StartTime.AddHours(1)

            $s2 = [Session]::new()
            $s2.TalkId = $Meetup.TalkIds[0]
            $s2.StartTime = $s1.EndTime.AddMinutes(30)
            $s2.EndTime = $s2.StartTime.AddHours(1)

            return @($s1, $s2)
        }
        'SarDotNet-1' {

            $start = $Meetup.Date.Date.Add([TimeSpan]::FromHours(14) - [DateTimeOffset]::Now.Offset)

            $s1 = [Session]::new()
            $s1.TalkId = $Meetup.TalkIds[0]
            $s1.StartTime = $start
            $s1.EndTime = $s1.StartTime.AddHours(1)

            $s2 = [Session]::new()
            $s2.TalkId = $Meetup.TalkIds[1]
            $s2.StartTime = $s1.EndTime
            $s2.EndTime = $s2.StartTime.AddHours(1)

            $s3 = [Session]::new()
            $s3.TalkId = $Meetup.TalkIds[2]
            $s3.StartTime = $s2.EndTime.AddMinutes(30)
            $s3.EndTime = $s3.StartTime.AddHours(1)

            return @($s1, $s2, $s3)
        }
    }

    throw "Unknow $($Meetup.Id) meetup format"
}

function Invoke-ReSession()
{
    process
    {
        $meetup = [Meetup]$_

        $meetup.Sessions = Get-Sessions -Meetup $meetup

        $meetup.Id | Out-Host
        $meetup.Sessions |
        ForEach-Object {
            "  {0}: {1}-{2}" -f $_.TalkId,$_.StartTime.ToLocalTime(),$_.EndTime.ToLocalTime() | Out-Host
        }

        $meetup
    }
}

### Convert

Read-Meetup | Invoke-ReSession | Out-Null #| Save-Entity

