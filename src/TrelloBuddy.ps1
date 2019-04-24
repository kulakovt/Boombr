#Requires -Version 5
#Requires -Modules powershell-yaml
#Requires -Modules PowerTrello

Set-StrictMode -version Latest
$ErrorActionPreference = 'Stop'

. $PSScriptRoot\Utility.ps1

$TrelloBoardName = 'SpbDotNet Meetups'
$TrelloNewCardListName = 'Надо'
$ActionsPath = Join-Path $PSScriptRoot '.\Actions.yaml' -Resolve

class MeetupTask
{
    [string] $Title
    [string[]] $Tags
}

function Select-SubstituteVariables
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

function Select-Tags
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

function Get-ActionTemplates
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

function New-MeetupTask
{
    [CmdletBinding()]
    [OutputType([MeetupTask])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Template,

        [Parameter(Mandatory)]
        [Hashtable]
        $Context,

        [Parameter(Mandatory)]
        [Hashtable]
        $Tags
    )

    process
    {
        $Task = [MeetupTask]::New()
        $Task.Title = $Template | Select-SubstituteVariables -Values $Context
        $Task.Tags = $Template | Select-Tags
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

function Resolve-CardTags
{
    [CmdletBinding()]
    [OutputType([string[]])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [MeetupTask]
        $Task,

        [Parameter(Mandatory)]
        [Hashtable]
        $TrelloTagsDict
    )

    process
    {
        $Task.Tags |
            ForEach-Object {
                $tagId = $TrelloTagsDict[$_]
                if (-not $tagId) { throw "Can't found tag «$_» in Trello list: $($TrelloTagsDict.Keys | Join-ToString)" }

                $tagId
            }
    }
}

function Save-MeetupTask
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [MeetupTask]
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

        $trelloTags = $Task | Resolve-CardTags -TrelloTagsDict $TrelloTagsDict

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

function New-Meetup
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]
        $MeetupKey
    )

    process
    {
        Write-Information ':::: Create Meetup'

        $board = Get-TrelloBoard -Name $TrelloBoardName
        if (-not $board) { throw "Trello board «$TrelloBoardName not found" }

        $list = $board | Get-TrelloList | Where-Object { $_.name -eq $TrelloNewCardListName }
        if (-not $list) { throw "Trello list «$TrelloNewCardListName in board «$TrelloBoardName not found" }

        $labels = $board | Get-TrelloBoardLabel
        $tagDict = $labels | ConvertTo-Hashtable -KeySelector { $_.name } -ElementSelector { $_.id }

        Write-Information "Use «$($board.name)» board"

        $Context = @{
            MeetupKey = $MeetupKey
        }

        $Context | Write-Context

        Get-ActionTemplates -Path $ActionsPath -Section 'Meetup' |
            New-MeetupTask -Context $Context -Tags @{} |
            Save-MeetupTask -TrelloList $list -TrelloTagsDict $tagDict
    }
}
