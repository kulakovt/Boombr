class Entity
{
    [string] $Id
}

class Speaker : Entity
{
    [string] $Name
    [string] $CompanyName
    [Uri] $CompanyUrl
    [string] $Description

    [Uri] $BlogUrl
    [Uri] $ContactsUrl
    [Uri] $TwitterUrl
    [Uri] $HabrUrl
}

class Talk : Entity
{
    [string[]] $SpeakerIds
    [string] $Title
    [string] $Description
    [string[]] $SeeAlsoTalkIds

    [Uri] $CodeUrl
    [Uri] $SlidesUrl
    [Uri] $VideoUrl
}

class Friend: Entity
{
    [string] $Name
    [Uri] $Url
    [string] $Description
}

class Venue : Entity
{
    [string] $Name
    [string] $Address
    [Uri] $MapUrl
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
    [string[]] $FriendIds
    [string] $VenueId
    [Session[]] $Sessions

    # Obsolete. Use Sessions property
    [string[]] $TalkIds
    # Obsolete. Use Sessions property
    [DateTime] $Date
}

class Community : Entity
{
    [string] $Name
}
