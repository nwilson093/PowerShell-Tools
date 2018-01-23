$Groups = Get-ADGroup -Filter * -SearchBase 'OU=Brivo,OU=Security Groups,OU=MB-INTERNAL,DC=corp,DC=mb-internal,DC=com'

$Results = foreach( $Group in $Groups )
{
    Get-ADGroupMember -Identity $Group | foreach 
        {

        [pscustomobject]@{
            GroupName = $Group.Name
            UserName = $_.Name
            }
        }
}