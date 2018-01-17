#VM Deployment Menu - Deploys VMs from Template w/ various customization options.
#v0.27

<#
  .SYNOPSIS
  The intention of this tool is for those of all skill levels (entry-beginner) for a very fast way to deploy any OS from a template.  The tool is built as a menu-driven script rather than module in order to support a simpler user experience.
  .DESCRIPTION
  This is built to be a no-update tool, so there will be easy continuity when templates are updated.  All vCenter object names such as folders, templates, and networks need to be updated to match your environment.
  .EXAMPLE
  C:\> .\Deploy-new-vm-menu.ps1
  C:\> Select an OS by entering a number (e.g. 2 for Windows Server 2016): 2
  C:\> Does this VM need to be on the domain?  Decide by entering a number: 1
  C:\> Enter a name for the new VM. Note this will set the Windows hostname to match your entry: nwilsonvm12
#>

[CmdletBinding()]
$ErrorActionPreference = "Stop"

function ErrorHandler($error) 
{
Write-Host "Script has failed" -ForegroundColor White -BackgroundColor Red
Send-MailMessage -To "user@company.com" -From "otheruser@company.com" -Body "$env:username ran a script and it failed!" -Subject "$env:username ran a script and it failed!" -SmtpServer "smtpserver.company.com" -Port "25"
}

trap { ErrorHandler $_; break }

Clear-Host

#OS deployment menu
Write-Host '1. Windows Server 2012 R2'
Write-Host '2. Windows Server 2016'
Write-Host '3. Windows 10'
Write-Host '4. Windows 8 64-bit'
Write-Host '5. Windows 7 64-bit'

try 
{ [ValidateRange(1,5)][uint32]$OSSelection = Read-Host -Prompt 'Select an OS by entering a number (e.g. 2 for Windows Server 2016)' }
catch 
{ throw "A valid selection was not entered and the script has halted.  Please contact Systems Engineering for assistance." }
Clear-Host


#Menu to choose which vSphere customization profile to use (domain versus no domain)
Write-Host '1. Yes, join VM to domain'
Write-Host '2. No, do NOT join VM to domain'

try
{ [uint32]$DomainJoined = Read-Host -Prompt 'Does this VM need to be on the domain?  Decide by entering a number'}
catch
{ throw "A valid selection was not entered and the script has halted.  Please contact Systems Engineering for assistance." }
Clear-Host


#Menu to choose which department this VM is to be used for, mostly to decide what datastore to deploy on
Write-Host '1. IT'
Write-Host '2. False Positive'
Write-Host '3. Sales'
Write-Host '4. Builds'
Write-Host '5. QA'
Write-Host '6. Support'

try 
{ [ValidateRange(1,6)][uint32]$Department = Read-Host -Prompt 'Select a department by entering a number (e.g. 3 for Sales)' }
catch 
{ throw "A valid selection was not entered and the script has halted.  Please contact Systems Engineering for assistance." }
Clear-Host


#VM name - this will be used to set the OS hostname, so the user really needs to get this right.  We're validating that it at least stays under 15 characters.
try 
{ [ValidateLength(1,15)][string]$NewVmName = Read-Host -Prompt 'Enter a name for the new VM. Note this will set the Windows hostname to match your entry.' }
catch 
{ throw "A valid selection was not entered and the script has halted.  Please contact Systems Engineering for assistance." }
Clear-Host


#This cluster will be default if the criteria below are not met for an alternate setting.
#TargetNetwork is the literal name of a vCenter/ESXi network/port group.
$TargetCluster = "SCC1"

if ($Department -eq "5") {$TargetCluster = "SCCVC3-1"}
if ($Department -eq "6") {$TargetCluster = "SCCVC3-1"}

if ($Department -eq "1" -and $TargetCluster -eq "SCC1") {$TargetNetwork = "PRIVATE"}
if ($Department -eq "1" -and $TargetCluster -eq "SCCVC3-1") {$TargetNetwork = "PRIVATE2"}
if ($Department -eq "2" -and $TargetCluster -eq "SCC1") {$TargetNetwork = "Research"}
if ($Department -eq "2" -and $TargetCluster -eq "SCCVC3-1") {$TargetNetwork = "Research"}
if ($Department -eq "3" -and $TargetCluster -eq "SCC1") {$TargetNetwork = "QA"}
if ($Department -eq "3" -and $TargetCluster -eq "SCCVC3-1") {$TargetNetwork = "QA"}
if ($Department -eq "4" -and $TargetCluster -eq "SCC1") {$TargetNetwork = "QA"}
if ($Department -eq "4" -and $TargetCluster -eq "SCCVC3-1") {$TargetNetwork = "QA"}
if ($Department -eq "5" -and $TargetCluster -eq "SCC1") {$TargetNetwork = "QA"}
if ($Department -eq "5" -and $TargetCluster -eq "SCCVC3-1") {$TargetNetwork = "QA"}
if ($Department -eq "6" -and $TargetCluster -eq "SCC1") {$TargetNetwork = "QA"}
if ($Department -eq "6" -and $TargetCluster -eq "SCCVC3-1") {$TargetNetwork = "QA"}


#Setting parameters based on user selections
if ($OSSelection -eq "1"){$VMTemplate = "ITW2k12x64"}
if ($OSSelection -eq "2"){$VMTemplate = "ITW2K16STDX64"}
if ($OSSelection -eq "3"){$VMTemplate = "ITW10Prox64"}
if ($OSSelection -eq "4"){$VMTemplate = "ITW8.1Prox64"}
if ($OSSelection -eq "5"){$VMTemplate = "ITW7Prox64"}

if ($DomainJoined -eq "1"){$SourceCustomSpec = "Windows-Domain"}
if ($DomainJoined -eq "2"){$SourceCustomSpec = "Windows-NoDomain"}

#You need to use a Datastore Cluster ID like I have here if there are multiple datastores/datastore clusters with the same name.
if ($Department -eq "1" -and $TargetCluster -eq "SCC1") {$TargetStorage = Get-DatastoreCluster -ID "StoragePod-group-p3530"}
if ($Department -eq "1" -and $TargetCluster -eq "SCCVC3-1") {$TargetStorage = Get-DatastoreCluster -ID "StoragePod-group-p4886"}
if ($Department -eq "2") {$TargetStorage = "FP"}
if ($Department -eq "3") {$TargetStorage = "SE"}
if ($Department -eq "4") {$TargetStorage = "BLDS"}
if ($Department -eq "5") {$TargetStorage = "QA"}
if ($Department -eq "6") {$TargetStorage = "Support"}

if ($Department -eq "1" -and $TargetCluster -eq "SCC1") {$TargetFolder = Get-Folder -ID "Folder-group-v28"}
if ($Department -eq "1" -and $TargetCluster -eq "SCCVC3-1") {$TargetFolder = Get-Folder -ID "Folder-group-v3610"}
if ($Department -eq "2") {$TargetFolder = "Research"}
if ($Department -eq "3") {$TargetFolder = "SE"}
if ($Department -eq "4") {$TargetFolder = "Build"}
if ($Department -eq "5") {$TargetFolder = "QA-Team"}
if ($Department -eq "6") {$TargetFolder = "Support"}


#vCenter connection and service account with credentials
$vCenterInstance = "vcenterserver.company.com"
$vCenterUser = "vcenter_serviceaccount"
$vCenterPass = Get-Content -Path 'C:\vcenteruserpassword\password.txt'

Get-Module -ListAvailable VMware* | Import-Module | Out-Null
Connect-VIServer $vCenterInstance -User $vCenterUser -Password $vCenterPass -WarningAction SilentlyContinue

New-VM -Name $NewVmName -Template $VMTemplate -ResourcePool $TargetCluster -OSCustomizationSpec $SourceCustomSpec -Datastore $TargetStorage -Location $TargetFolder
Write-Verbose -Message "Virtual Machine $NewVmName deployed. Powering on." -Verbose

Start-VM -VM $NewVmName

Get-VM -Name $NewVmName | Get-NetworkAdapter | Set-NetworkAdapter -NetworkName $TargetNetwork -Confirm:$false

#Checks on status and verifies customization is complete before proceeding.
Write-Verbose -Message "Verifying that customization for VM $NewVmName has started..." -Verbose

while($True)
{
$VmEvents = Get-VIEvent -Entity $NewVmName
$VmStartedEvent = $VmEvents | Where-Object { $_.GetType().Name -eq "CustomizationStartedEvent" }

if ($VmStartedEvent)
{
break
}

else
{
Start-Sleep -Seconds 5
}
}


#Error handing for success versus failure, based on the vSphere event (success/failure)
Write-Verbose -Message "Customization of VM $NewVmName has started. Checking for completed status..." -Verbose

while($True)
{
$VmEvents = Get-VIEvent -Entity $NewVmName
$VmSucceededEvent = $VmEvents | Where-Object { $_.GetType().Name -eq "CustomizationSucceeded" }
$VmFailureEvent = $VmEvents | Where-Object { $_.GetType().Name -eq "CustomizationFailed" }

if ($VmFailureEvent)
{
Write-Warning -Message "Customization of VM $NewVmName failed.  Please contact Systems Engineering for assistance." -Verbose
return $False
}

if ($VmSucceededEvent)
{
break
}
Start-Sleep -Seconds 5
}


#Grace period/sleep to ensure the VM is done rebooting and is ready to go.
Start-Sleep -Seconds 30
Write-Verbose -Message "Waiting for VM $NewVmName to complete post-customization reboot." -Verbose
Wait-Tools -VM $NewVmName -TimeoutSeconds 300

Start-Sleep -Seconds 30
Write-Verbose -Message "$NewVmName setup complete." -Verbose