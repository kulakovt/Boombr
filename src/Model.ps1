class Entity
{
    [string] $Id
}

class Speaker : Entity
{
    [string] $Name
    [string] $CompanyName
    [string] $CompanyUrl
    [string] $Description

    [string] $BlogUrl
    [string] $ContactsUrl
    [string] $TwitterUrl
    [string] $HabrUrl
    [string] $GitHubUrl
}

class Talk : Entity
{
    [string[]] $SpeakerIds
    [string] $Title
    [string] $Description
    [string[]] $SeeAlsoTalkIds

    [string] $CodeUrl
    [string] $SlidesUrl
    [string] $VideoUrl
}

class Friend: Entity
{
    [string] $Name
    [string] $Url
    [string] $Description
}

class Venue : Entity
{
    [string] $Name
    [string] $Address
    [string] $MapUrl
}

class Session
{
    [string] $TalkId
    [DateTime] $StartTime
    [DateTime] $EndTime
}

class Meetup : Entity
{
    [string] $Name
    [string] $CommunityId

    # Obsolete. Use Sessions property
    [DateTime] $Date

    [string[]] $FriendIds
    [string] $VenueId
    [Session[]] $Sessions

    # Obsolete. Use Sessions property
    [string[]] $TalkIds
}

class Community : Entity
{
    [string] $Name
    [string] $City
    [string] $TimeZone
}
