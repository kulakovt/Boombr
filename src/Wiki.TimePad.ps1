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

        Invoke-RestMethod $url -Headers $headers
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
            $orgEvent = $_

            [PSCustomObject] @{
                PSTypeName = 'TimePadOrganizationEvent'
                Id = [int]$orgEvent.id
                Name = $orgEvent.name
                OrganizationId = $OrganizationId
                StartsAt = [DateTime]::Parse($orgEvent.starts_at)
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
            $padEvent = $_

            [PSCustomObject] @{
                PSTypeName = 'TimePadEvent'
                Id = [int]$padEvent.id
                Name = $padEvent.name
                OrganizationId = $padEvent.organization.id
                CreatedAt = [DateTime]::Parse($padEvent.created_at)
                StartsAt = [DateTime]::Parse($padEvent.starts_at)
                EndsAt = [DateTime]::Parse($padEvent.ends_at)
                Url = [Uri]$padEvent.url
                TicketsTotal = [int]$padEvent.registration_data.tickets_total
                TicketsLimit = [int]$padEvent.tickets_limit
                Questions = $padEvent.questions | Get-TimePadQuestionMap
            }
        }
    }
}

function Get-TimePadOrder
{
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [int]
        $EventId,

        [PSTypeName('TimePadEvent')]
        $TimePadEvent = $null
    )

    begin
    {
        function ReadAnswer([PSCustomObject] $Answers, [Hashtable] $Map, [string] $Key)
        {
            $fieldName = $Map[$Key]

            if ($fieldName -in $Answers.PSObject.Properties.Name)
            {
                $Answers.$fieldName
            }
            else
            {
                $Answers | Out-Host
                $Map | Out-Host
                throw "Can't map answer $Key"
            }
        }
    }
    process
    {
        if (-not $TimePadEvent)
        {
            $TimePadEvent = $EventId | Get-TimePadEvent
        }

        $query = @{
            # TODO: Query all
            limit = 3
        }

        $response = "events/${EventId}/orders" | Invoke-TimePadMethod -QueryParts $query

        $response.values |
        ForEach-Object {
            $order = $_

            [PSCustomObject] @{
                PSTypeName = 'TimePadOrder'
                Name = ReadAnswer -Answers $order.answers -Map $TimePadEvent.Questions -Key 'Name'
                Surname = ReadAnswer -Answers $order.answers -Map $TimePadEvent.Questions -Key 'Surname'
                Mail = $order.mail
                CreatedAt = [DateTime]::Parse($order.created_at)
                Company = ReadAnswer -Answers $order.answers -Map $TimePadEvent.Questions -Key 'Company'
                Position = ReadAnswer -Answers $order.answers -Map $TimePadEvent.Questions -Key 'Position'
            }
        }
    }
}
