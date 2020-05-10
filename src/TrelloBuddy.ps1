#Requires -Version 5
#Requires -Modules powershell-yaml
#Requires -Modules PowerTrello

Set-StrictMode -version Latest
$ErrorActionPreference = 'Stop'

. $PSScriptRoot\Utility.ps1

$TrelloBoardName = 'SpbDotNet Meetups'
$TrelloNewCardListName = 'Надо'
$ActionsPath = Join-Path $PSScriptRoot '.\Actions.yaml' -Resolve


class Task
{
    [string] $Title
    [string[]] $Tags
}

class MeetupTask : Task
{
}

class SpeakerTask : Task
{
}

function Select-SubstituteVariable
{
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Template,

        [Parameter(Mandatory)]
        [Hashtable]
        $Values
    )

    process
    {
        Write-Verbose "Substitute template: $Template"

        # Substitute variables
        foreach ($key in $Values.Keys)
        {
            $mask = '${' + $key + '}'
            $value = $Values[$key]
            $Template = $Template.Replace($mask, $Value)
        }

        # Remove all Tags
        $Template = $Template -replace '#\w+'

        $Template = $Template.Trim()

        Write-Verbose "Substitute result: $Template"

        $Template
    }
}

function Select-Tag
{
    [CmdletBinding()]
    [OutputType([string[]])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Template
    )

    begin
    {
        $parser = [Regex]::New('#(?<Tag>\w+)')
    }
    process
    {
        $parser.Matches($Template) |
            ForEach-Object { $_.Groups['Tag'].Value }
    }
}

function Get-ActionTemplate
{
    [CmdletBinding()]
    [OutputType([string[]])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Section
    )

    process
    {
        $text = Get-Content -Path $Path -Encoding UTF8 -Raw
        $actions = ConvertFrom-Yaml -Yaml $text
        $actions[$Section]
    }
}

function Expand-Template
{
    [CmdletBinding()]
    [OutputType([MeetupTask])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Task]
        $Task,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $TitleTemplate,

        [Parameter(Mandatory)]
        [Hashtable]
        $Context
    )

    process
    {
        $Task.Title = $TitleTemplate | Select-SubstituteVariable -Values $Context
        $Task.Tags = $TitleTemplate | Select-Tag
        $Task
    }
}

function Write-Context
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [hashtable]
        $Context
    )

    process
    {
        Write-Information 'Running context:'
        foreach ($key in $Context.Keys)
        {
            $value = $Context[$key]
            Write-Information "  $key = $value"
        }
    }
}

function Resolve-Tag
{
    [CmdletBinding()]
    [OutputType([string[]])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [Task]
        $Task,

        [Parameter(Mandatory)]
        [Hashtable]
        $TrelloTagsDict
    )

    process
    {
        if ($TrelloTagsDict)
        {
            # Ignore analyzer bug
        }

        $Task.Tags |
            ForEach-Object {
                $tagId = $TrelloTagsDict[$_]
                if (-not $tagId) { throw "Can't found tag «$_» in Trello list: $($TrelloTagsDict.Keys | Join-ToString)" }

                $tagId
            }
    }
}

function Save-Task
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [Task]
        $Task,

        [Parameter(Mandatory)]
        $TrelloList,

        [Parameter(Mandatory)]
        [Hashtable]
        $TrelloTagsDict
    )

    begin
    {
        $taskCount = 0
    }
    process
    {
        Write-Information "Create card «$($Task.Title)»"

        $trelloTags = $Task | Resolve-Tag -TrelloTagsDict $TrelloTagsDict

        $list |
            New-TrelloCard -Name $Task.Title -LabelId $trelloTags |
            Out-Null

        $taskCount++
    }
    end
    {
        Write-Information "Added $taskCount tasks to «$($TrelloList.name)» list"
    }
}

function New-Task
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $TypeName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Section,

        [Parameter(Mandatory)]
        [Hashtable]
        $Context
    )

    process
    {
        Write-Information ":::: Create $TypeName"

        $board = Get-TrelloBoard -Name $TrelloBoardName
        if (-not $board) { throw "Trello board «$TrelloBoardName not found" }

        $list = $board | Get-TrelloList | Where-Object { $_.name -eq $TrelloNewCardListName }
        if (-not $list) { throw "Trello list «$TrelloNewCardListName in board «$TrelloBoardName not found" }

        $labels = $board | Get-TrelloBoardLabel
        $tagDict = $labels | ConvertTo-Hashtable -KeySelector { $_.name } -ElementSelector { $_.id }

        Write-Information "Use «$($board.name)» board"

        $Context | Write-Context

        Get-ActionTemplate -Path $ActionsPath -Section $Section |
        ForEach-Object {

            $template = $_
            $task = New-Object -TypeName $TypeName

            Expand-Template -Task $task -TitleTemplate $template -Context $Context |
            Save-Task -TrelloList $list -TrelloTagsDict $tagDict
        }
    }
}

function New-Meetup
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Key
    )

    process
    {
        $Context = @{
            MeetupKey = $Key
        }

        New-Task -TypeName 'MeetupTask' -Section 'Meetup' -Context $Context
    }
}

function New-Speaker
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $MeetupKey
    )

    process
    {
        $Context = @{
            MeetupKey = $MeetupKey
            SpeakerName = $Name
        }

        New-Task -TypeName 'SpeakerTask' -Section 'Speaker' -Context $Context
    }
}

