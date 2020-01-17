. $PSScriptRoot\Utility.ps1

$TimePadApiEndpoint = 'https://api.timepad.ru/v1'

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

function Get-TimePadEvent
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
        } |
        Format-UriQuery

        $eventUrl = $TimePadApiEndpoint | Join-Uri -RelativeUri "events"

        $response = Invoke-RestMethod -Uri "${eventUrl}?${query}"

        $response.values |
        ForEach-Object {
            $event = $_

            [PSCustomObject] @{
                PSTypeName = 'TimePadEvent'
                Id = $event.id
                Name = $event.name
                OrganizationId = $OrganizationId
                StartsAt = [DateTime]::Parse($event.starts_at)
            }
        }
    }
}
