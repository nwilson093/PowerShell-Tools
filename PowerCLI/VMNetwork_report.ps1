$vCenterInstance = "vcenterserver.company.com"
$vCenterUser = "vcenter_serviceaccount"
$vCenterPass = Get-Content -Path 'C:\vcenteruserpassword\password.txt'

Get-Module -ListAvailable VMware* | Import-Module | Out-Null
Connect-VIServer $vCenterInstance -User $vCenterUser -Password $vCenterPass -WarningAction SilentlyContinue

$ExportPath = "C:\reports\report.csv"
$vm = Get-VM | where {$_.PowerState -eq "PoweredOn"}

foreach ($virtmach in $vm)
{

$subnetmask = @()

$row = "" | Select Name,Host,OS,NicType,VLAN,IP,Gateway,Subnetmask,DNS

$row.Name = $virtmach.Name
$row.Host = $virtmach.VMHost.Name
$row.OS = $virtmach.Guest.OSFullName
$row.NicType = [string]::Join(',',(Get-NetworkAdapter -Vm $virtmach | Select -ExpandProperty Type))
$row.VLAN = [string]::Join(',',((Get-VirtualPortGroup -VM $virtmach ).Name))
$row.IP = [string]::Join(',',$virtmach.Guest.IPAddress)
$row.Gateway = $virtmach.ExtensionData.Guest.IpStack.IpRouteConfig.IpRoute.Gateway.IpAddress | where {$_ -ne $null}

foreach ($iproute in $virtmach.ExtensionData.Guest.IpStack.IpRouteConfig.IpRoute) {

    if (($virtmach.Guest.IPAddress -replace "[0-9]$|[1-9][0-9]$|1[0-9][0-9]$|2[0-4][0-9]$|25[0-5]$", "0" | select -uniq) -contains $iproute.Network) {

        $subnetmask += $iproute.Network + "/" + $iproute.PrefixLength

    }

}


$row.Subnetmask = [string]::Join(',',($subnetmask))


$row | Export-CSV -Path $ExportPath -NoClobber -Append -NoTypeInformation

}