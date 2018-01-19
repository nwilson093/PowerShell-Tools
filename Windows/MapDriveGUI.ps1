#Script to map a system's C: drive on the machine from which it is being run, but meant to be user-friendly(ish).

Add-Type -AssemblyName Microsoft.VisualBasic
$Letter = [Microsoft.VisualBasic.Interaction]::InputBox("Enter an unused letter on which to map the drive (e.g. X)", "Drive Letter", "X")
$DriveLetter = "$Letter`:"
[System.Net.IPAddress]$IPAddress = [Microsoft.VisualBasic.Interaction]::InputBox("Enter the IP address of the vSphere VM that you wish to share files with (e.g. 10.12.34.56)", "vSphere VM IP Address")
#$Username = [Microsoft.VisualBasic.Interaction]::InputBox("Enter the username of the destination vSphere VM (e.g. Administrator)", "vSphere VM Username")

<############################################################
This function will validate that the IP Address is reachable.
############################################################>

function Test-IPaddress
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [ValidateScript({$_ -match [IPAddress]$_ })]  
        [string]
        $IPAddress5
    )

    Begin
    {
    }
    Process
    {
        [ipaddress]$IPAddress5
    }
    End
    {
    }
}

try
{Test-IPaddress -IPAddress5 $IPAddress | Out-Null}
catch
{Write-Host "An error has occurred.  Please contact the Help Desk for assistance." -ForegroundColor Red -BackgroundColor White}

try
{Test-Connection $IPAddress -ErrorAction Stop | Out-Null}
catch
{Write-Host "An error has occurred.  Please contact the Help Desk for assistance." -ForegroundColor Red -BackgroundColor White}

#Maps the drive if everything is successful.

net use $DriveLetter \\$IPAddress\c$ /persistent:yes
