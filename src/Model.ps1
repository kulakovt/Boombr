class Entity
{
    [string] $Id
}

enum LinkRelation
{
    Twitter
    Blog
    Contact
    Code
    Slide
    Video
    Habr
}

class Link
{
    [LinkRelation] $Relation
    [Uri] $Url

    [string] ToString()
    {
        return "$($this.Relation)=$($this.Url)"
    }
}

class Speaker : Entity
{
    [string] $Name
    [string] $CompanyName
    [Uri] $CompanyUrl
    [string] $Description
    [Link[]] $Links
}

class Talk : Entity
{
    [string[]] $SpeakerIds
    [string] $Title
    [string] $Description
    [Link[]] $Links
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

class Meetup : Entity
{
    [int] $Number
    [string] $CommunityId
    [DateTime] $Date
    [string[]] $FriendIds
    [string] $VenueId
    [string[]] $TalkIds
}

class Community : Entity
{
    [string] $Name
}