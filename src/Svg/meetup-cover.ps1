#Requires -Version 5

Set-StrictMode -version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

. $PSScriptRoot\..\Model.ps1
. $PSScriptRoot\..\Utility.ps1
. $PSScriptRoot\..\Serialization.ps1

$AuditDir = Join-Path -Resolve $PSScriptRoot '..\..\..\Audit\db'
$ConverPath = Join-Path $PSScriptRoot 'Convers'

enum SpeakerPosition
{
    First
    First1
    First2
    Second
    Second1
    Second2
}

class SpeakerPart
{
    [string] $SpeakerName
    [string] $SpeakerSurname
    [string] $ImagePath
    [SpeakerPosition] $Position

    SpeakerPart([string] $SpeakerName, [string] $SpeakerSurname, [string] $ImagePath, [SpeakerPosition] $Position)
    {
        $this.SpeakerName = $SpeakerName
        $this.SpeakerSurname = $SpeakerSurname
        $this.ImagePath = $ImagePath
        $this.Position = $Position
    }

    [string] RenderImage()
    {
        $x = 0
        $width = 0
        switch ($this.Position)
        {
            'First'
            {
                $x = 0
                $width = 320
            }
            'First1'
            {
                $x = 0
                $width = 160
            }
            'First2'
            {
                $x = 160
                $width = 160
            }
            'Second'
            {
                $x = 320
                $width = 320
            }
            'Second1'
            {
                $x = 320
                $width = 160
            }
            'Second2'
            {
                $x = 480
                $width = 160
            }
            default
            {
                throw "Unknown $($this.Position) position"
            }
        }
        return '  <image x="{0}" y="0" height="300px" width="{1}px" preserveAspectRatio="xMidYMid slice" xlink:href="{2}"/>' -f $x,$width,$this.ImagePath
    }

    [string] RenderBackground()
    {
        $x = 0
        $width = 0
        switch ($this.Position)
        {
            'First'
            {
                $x = 0
                $width = 300
            }
            'First1'
            {
                $x = 0
                $width = 150
            }
            'First2'
            {
                $x = 160
                $width = 150
            }
            'Second'
            {
                $x = 340
                $width = 300
            }
            'Second1'
            {
                $x = 330
                $width = 150
            }
            'Second2'
            {
                $x = 490
                $width = 150
            }
            default
            {
                throw "Unknown $($this.Position) position"
            }
        }
        return '    <rect x="{0}" y="220" width="{1}" height="70" />' -f $x,$width
    }

    [string] RenderName()
    {
        $y = -1
        if (($this.Position -eq [SpeakerPosition]::First) -or
            ($this.Position -eq [SpeakerPosition]::First1))
        {
            $y = 0
        }

        $x = 0
        switch ($this.Position)
        {
            'First'
            {
                $x = 20
            }
            'First1'
            {
                $x = 10
            }
            'First2'
            {
                $x = 170
            }
            'Second'
            {
                $x = 360
            }
            'Second1'
            {
                $x = 340
            }
            'Second2'
            {
                $x = 500
            }
            default
            {
                throw "Unknown $($this.Position) position"
            }
        }
        $name1 = '      <tspan x="{0}" dy="{1}em">{2}</tspan>' -f $x,$y,$this.SpeakerName
        $name2 = '      <tspan x="{0}" dy="1em">{1}</tspan>' -f $x,$this.SpeakerSurname

        return $name1 + [System.Environment]::NewLine + $name2
    }
}

function Get-TalksPosition([int] $FirstCount, [int] $SecondCount)
{
    if ($FirstCount -eq 1)
    {
         [SpeakerPosition]::First
    }
    elseif ($FirstCount -eq 2)
    {
        [SpeakerPosition]::First1
        [SpeakerPosition]::First2
    }
    if ($SecondCount -eq 1)
    {
         [SpeakerPosition]::Second
    }
    elseif ($SecondCount -eq 2)
    {
        [SpeakerPosition]::Second1
        [SpeakerPosition]::Second2
    }
}

function New-MeetupConver([Meetup] $Meetup, [SpeakerPart[]] $Parts)
{
    $nl = [System.Environment]::NewLine
    $images = $Parts | ForEach-Object { $_.RenderImage() } | Join-ToString -Delimeter $nl
    $bg = $Parts | ForEach-Object { $_.RenderBackground() } | Join-ToString -Delimeter $nl
    $text = $Parts | ForEach-Object { $_.RenderName() } | Join-ToString -Delimeter $nl
@'
<svg width="640" height="360" xmlns="http://www.w3.org/2000/svg" xmlns:xlink= "http://www.w3.org/1999/xlink">
  <rect x="0" y="300" width="640" height="60" fill="#3E4E86" />
  <rect x="10" y="310" width="40" height="40" fill="#68217a" stroke="white" />

{0}

  <g id="bg" fill="#68217a" opacity="0.9">
{1}
  </g>

  <g id="text" font-family="Consolas" font-size="25" fill="white">
    <text y="250">
{2}
    </text>

    <text x="100" y="340">{3}</text>
  </g>

</svg>
'@ -f $images,$bg,$text,$Meetup.Name
}

function New-MeetupPage()
{
    $entities = Read-All -AuditDir $AuditDir

    $meetups = $entities | Where-Object { $_ -is [Meetup] } | Where-Object { $_.CommunityId -eq 'SpbDotNet' } | ConvertTo-Hashtable { $_.Id }
    $talks  = $entities | Where-Object { $_ -is [Talk] } | ConvertTo-Hashtable { $_.Id }
    $speakers = $entities | Where-Object { $_ -is [Speaker] } | ConvertTo-Hashtable { $_.Id }

    if (-not (Test-Path $ConverPath))
    {
        New-Item $ConverPath -ItemType Directory | Out-Null
    }

    foreach ($meetup in $meetups.Values)
    {
        $outPath = Join-Path $ConverPath "$($meetup.Id).svg"
        if (Test-Path $outPath)
        {
            Write-Information "####### Skip $($meetup.Id)"
            continue
        }

        Write-Information "####### Save $($meetup.Id)"

        [array] $talkIds = $meetup.Sessions.TalkId | Select-Object -First 2
        if ($talkIds.Count -ne 2)
        {
            continue
        }

        $talk1 = $talks[$talkIds[0]]
        $talk2 = $talks[$talkIds[1]]

        [array] $talk1Speakers = $talk1.SpeakerIds | Select-Object -First 2
        [array] $talk2Speakers = $talk2.SpeakerIds | Select-Object -First 2

        $positions = Get-TalksPosition -FirstCount ($talk1Speakers.Count) -SecondCount ($talk2Speakers.Count)

        $i = 0
        $parts = $talk1Speakers + $talk2Speakers |
        ForEach-Object {

            $speakerId = $_
            $speaker = $speakers[$speakerId]
            $speakerPosition = $positions[$i++]
            $avatarPath = Join-Path $AuditDir "speakers/$speakerId/avatar.small.jpg"
            $avatarUri = [Uri]::new($avatarPath).AbsoluteUri

            $names = $speaker.Name.Split(' ')
            [SpeakerPart]::new($names[0], $names[1], $avatarUri, $speakerPosition)
        }

        New-MeetupConver -Meetup $meetup -Parts $parts |
        Set-Content -Path $outPath -Encoding UTF8

        C:\Users\akulakov\Desktop\inkscape\bin\inkscape.com --export-type="png" $outPath
    }
}

New-MeetupPage
