. $PSScriptRoot\Utility.ps1

$TimePadApiEndpoint = 'https://api.timepad.ru/v1'

function Invoke-TimePadMethod
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
        $token = 'TimePadToken' | Get-Secret
        $headers = @{
            Authorization = "Bearer ${token}"
        }

        $resourceWithQuery = $Resource
        $query = $QueryParts | Format-UriQuery
        if ($query)
        {
            $resourceWithQuery += "?${query}"
        }

        $url = $TimePadApiEndpoint | Join-Uri -RelativeUri $resourceWithQuery

        Invoke-RestMethod $url -Headers $headers -Proxy 'http://10.161.80.50:8081'
    }
}

function Get-TimePadOrganizationId
{
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $OrganizationTimePadUrl
    )

    # You can't just take it and find out the identifier of the Organization
    $pattern = '<a\ href="https://welcome\.timepad\.ru/feedbacks/new/\?org_id=(?<OrgId>\d+)"\ target="_blank">Связаться\ со\ службой\ поддержки</a>'
    $eventUrl = $OrganizationTimePadUrl | Join-Uri -RelativeUri "events/"

    $response = Invoke-WebRequest $eventUrl -UseBasicParsing

    [array] $orgLink = $response.Links.outerHTML | Where-Object { $_ -like '*org_id=*' }
    if ($orgLink -and ($orgLink[0] -match $pattern))
    {
        $Matches['OrgId']
    }
    else
    {
        throw "Can't find organization id at $OrganizationTimePadUrl"
    }
}

function Get-TimePadOrganizationEvent
{
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]
        $OrganizationId
    )

    process
    {
        $query = @{
            organization_ids = $OrganizationId
            # TODO: Load all
            limit = 100
            access_statuses = 'public'
            # Events of the current year
            starts_at_min = [DateTime]::new([DateTime]::UtcNow.Year, 1, 1).ToString("s")
        }

        $response = 'events' | Invoke-TimePadMethod -QueryParts $query

        $response.values |
        ForEach-Object {
            $event = $_

            [PSCustomObject] @{
                PSTypeName = 'TimePadOrganizationEvent'
                Id = [int]$event.id
                Name = $event.name
                OrganizationId = $OrganizationId
                StartsAt = [DateTime]::Parse($event.starts_at)
            }
        }
    }
}

function Get-TimePadQuestionMap
{
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject]
        $FormalQuestion
    )

    begin
    {
        $map = @{}
    }
    process
    {
        if ($FormalQuestion.type -eq 'text')
        {
            $name = switch -Exact ($FormalQuestion.name)
            {
                'E-mail'   { 'Email' }
                'Имя'      { 'Name'}
                'Фамилия'  { 'Surname' }
                'Компания' { 'Company' }
                'Должность' { 'Position' }
                default { throw "Can't map question $($FormalQuestion.name)" }
            }

            $map[$name] = $FormalQuestion.field_id
        }

    }
    end
    {
        $map
    }
}

function Get-TimePadEvent
{
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [int]
        $EventId
    )

    process
    {
        $response = "events/${EventId}" | Invoke-TimePadMethod

        $response |
        ForEach-Object {
            $event = $_

            [PSCustomObject] @{
                PSTypeName = 'TimePadEvent'
                Id = [int]$event.id
                Name = $event.name
                OrganizationId = $event.organization.id
                CreatedAt = [DateTime]::Parse($event.created_at)
                StartsAt = [DateTime]::Parse($event.starts_at)
                EndsAt = [DateTime]::Parse($event.ends_at)
                Url = [Uri]$event.url
                TicketsTotal = [int]$event.registration_data.tickets_total
                TicketsLimit = [int]$event.tickets_limit
                Questions = $event.questions | Get-TimePadQuestionMap
            }
        }
    }
}
