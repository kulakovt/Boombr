Set-StrictMode -version Latest
$ErrorActionPreference = 'Stop'

$src = Join-Path $PSScriptRoot '..\src'
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. (Join-Path $src $sut)

. (Join-Path $src 'Utility.ps1')


class TextTestEntity
{
    [string] $Id
    [string] $Name
    [DateTime] $Date
    [string] $ReferenceId
    [string] $PluralIds
    [string[]] $StringList
}

$nl = [System.Environment]::NewLine

Describe 'Text serialization' {

    Context 'Convert Nice Text to Dict' {

        $text =
@"
A : 1
B:1 2 3
F : 1 : 2 : 3
C:   `t   1`t2 `t

D: 1
2


3

E:

  `t
1
 2
  3 4

  `t



G: 1
2 3 : is not key

"@
        $dict = $text -split $nl | ConvertFrom-NiceTextToDict

        It 'Should read simple value' {
            $dict['A'] | Should Be '1'
        }

        It 'Should read value with spaces' {
            $dict['B'] | Should Be '1 2 3'
        }

        It 'Should trim whitespaces' {
            $dict['C'] | Should Be "1`t2"
        }

        It 'Should read multiline value' {
            $dict['D'] | Should Be "1${nl}2${nl}${nl}${nl}3"
        }

        It 'Should trim multiline value' {
            $dict['E'] | Should Be "1${nl} 2${nl}  3 4"
        }

        It 'Should suppot colon in value' {
            $dict['F'] | Should Be "1 : 2 : 3"
        }

        It 'Should suppot colon in multiline value' {
            $dict['G'] | Should Be "1${nl}2 3 : is not key"
        }
    }


    Context 'Convert Entity to Nice Text' {

        $enity = [TextTestEntity]::new()
        $enity.Id = 'Posh'
        $enity.Name = "PowerShell Community"

        $text = ($enity | ConvertTo-NiceText) -join $nl

        It 'Should starts with entity type' {
            $title = $text -split $nl | Select-Object -First 1

            $title | Should BeLike '#* TextTestEntity *'
        }

        It 'Should contains all property values' {

            $text.Contains('Id: Posh') | Should Be $true
            $text.Contains('Name: PowerShell') | Should Be $true
        }
    }


    Context 'Format Nice Text property' {

        $enity = [TextTestEntity]::new()
        $enity.Id = 'Posh'
        $enity.Name = "PowerShell${nl}Community"
        $enity.Date = Get-Date -Year 2017 -Month 1 -Day 1
        $enity.ReferenceId = '1'
        $enity.PluralIds = '2'
        $enity.StringList = @('id1', 'id2', 'id3')

        function Format-Property($entity, [string] $PropertyName)
        {
            $property = Get-EntityProperties -EntityType ($enity.GetType()) |
                Where-Object { $_.Name -eq $PropertyName } |
                Select-Single

            $value = $entity."$($property.Name)"
            Format-NiceTextProperty -Property $property -Value $value
        }

        It 'Should trim end ID suffix' {
            $view = Format-Property $enity 'ReferenceId'

            $view | Should Be 'Reference: 1'
        }

        It 'Should trim end IDs suffix' {
            $view = Format-Property $enity 'PluralIds'

            $view | Should Be 'Plurals: 2'
        }

        It 'Should preserve ID name' {
            $view = Format-Property $enity 'Id'

            $view | Should Be 'Id: Posh'
        }

        It 'Should format DateTime as date only' {
            $view = Format-Property $enity 'Date'

            $view | Should Be 'Date: 2017.01.01'
        }

        It 'Should join string array property value' {
            $view = Format-Property $enity 'StringList'

            $view | Should Be 'StringList: id1, id2, id3'
        }

        It 'Should wrap multiline velue' {
            $view = Format-Property $enity 'Name'

            $view | Should Be "${nl}Name: ${nl}PowerShell${nl}Community${nl}"
        }
    }


    Context 'Convert Entity from Nice Text' {

        $title = '### TextTestEntity ###'
        $body =
@"
Id: Posh

Name:
PowerShell
Community

Date: 2017.01.01
Reference: 1
Plurals: 2
StringList: id1, id2 ,id3
"@

        $entity = $body -split $nl | ConvertFrom-NiceTextEntity -TypeText $title

        It 'Should has valid type' {
            $entity.GetType().Name | Should Be 'TextTestEntity'
        }

        It 'Should find ID suffix' {
            $entity.ReferenceId | Should Be 1
        }

        It 'Should find IDs suffix' {
            $entity.PluralIds | Should Be 2
        }

        It 'Should find simple name' {
            $entity.Id | Should Be 'Posh'
        }

        It 'Should read date' {
            $expectedDate = (Get-Date -Year 2017 -Month 1 -Day 1).Date

            $entity.Date | Should Be $expectedDate
            $entity.Date.Kind | Should Be 'Utc'
        }

        It 'Should read string array' {
            $entity.StringList |
                Compare-Object @('id1', 'id2', 'id3') |
                #Should Be $null
                Out-Host
        }

        It 'Should read multiline velue' {
            $entity.Name | Should Be "PowerShell${nl}Community"
        }
    }


    Context 'Convert Entities from Nice Text' {

        $text =
@"
### TextTestEntity ###
Id: 1
Name: One

Two

### TextTestEntity ###
Id: 2

"@
        $entities = $text -split $nl | ConvertFrom-NiceText

        It 'Should read all entities' {
            $entities |
                Select-Object -ExpandProperty 'Id' |
                Compare-Object @(1, 2) |
                Should Be $null
        }

        It 'Should read multiline property value' {
            $entities |
                Select-Object -First 1 -ExpandProperty 'Name' |
                Should Be "One${nl}${nl}Two"
        }

        It 'Should skip unfound property value' {
            $entities |
                Select-Object -Skip 1 -First 1 -ExpandProperty 'Name' |
                Should Be $null
        }
    }
}
