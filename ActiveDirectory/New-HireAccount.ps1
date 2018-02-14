                                    ######TO-DO LIST######
                                    ######################
#######################################################################################################
## 1. Complete list of groups for each department.                                                   ##                                             
## 2. Add a logging location on a share (probably PowerShell host)                                   ##
#######################################################################################################

<#
  .SYNOPSIS
   This script is a user creation script for use by company IT staff.

  .DESCRIPTION
   The ultimate purpose of this script is to accomplish several things:

   1. Generate a proper username if not provided (non-mandatory parameter);
   2. Create the AD user account;
   3. Add user to proper groups based on the department (mandatory parameter);
   4. Force an AD -> Office 365 sync;
   5. Connect to Office 365 PowerShell;
   6. Assign the new user an E4 license;

  .EXAMPLE
   PS C:\> Import-Module .\New-HireAccount.ps1
   PS C:\> New-HireAccount -FirstName "Nick" -LastName "Wilson" -Manager "dvader" -Department "IT" -Title "Senior Systems Engineer" -Office "Death Star"

  .EXAMPLE
   New-HireAccount -FirstName "WuTang" -LastName "Clan" -Manager "nwilson" -Department "IT" -Title "Aint nothin' to mess with" -Office "The Hood"

  .PARAMETER FirstName
   The new user's first name. This parameter is mandatory.

  .PARAMETER LastName
   The new user's last name. This parameter is mandatory.

  .PARAMETER Username
   The new user's username (first initial + last name).  This parameter is not mandatory.
   The username will be generated based on the first name and last name values.
   For example, the username will be first initial + last name.  If that exists, then it will be first initial + second initial (of first name) + last name.

  .PARAMETER Manager
   The name of the new user's direct manager. This parameter is not mandatory, but should be filled.

  .PARAMETER Department
   The new user's department. This paramteter is mandatory.

  .PARAMETER Office
   The new user's office location (e.g. Santa Clara, CA). This paramteter is mandatory.
   
  .PARAMETER State
   The new user's state. This paramteter is not mandatory, but should be used for remote users.

#>

function New-HireAccount
{
[CmdletBinding()]
    
param 
(
    [Alias('First')][Parameter(Mandatory=$true)][string]$FirstName,
    [Alias('Last')][Parameter(Mandatory=$true)][string]$LastName,
    [Alias('User')][ValidateLength(1,32)]$Username,
    [Alias('Mgr')][string]$Manager,
    [Alias('Dept')][Parameter(Mandatory=$true)][string]$Department,
    [Parameter(Mandatory=$true)][string]$Title,
    [Parameter(Mandatory=$true)][string]$Office,
    [Parameter(Mandatory=$false)][string]$State
)

function ErrorHandler($error) 
    {
        Write-Host "Script has failed" -ForegroundColor White -BackgroundColor Red
        Send-MailMessage -To "nwilson@company.com" -From "new-hire_creation@company.com" -Body "$env:username ran a script and it failed!" -Subject "$env:username ran a script and it failed!" -SmtpServer "smtp-server.com" -Port "25"
    }

trap { ErrorHandler $_; break }
    
#Logic to decide which country the user belongs to.
#If unknown (RMT), country will be set to US.  
#This can be corrected at an time in Office 365 "Usage Location" for the user.

Install-Module MSOnline

if ($Location -eq $null)
    {
        if ($Office -match 'SC5' -or $Office -match 'SC' -or $Office -match 'Santa' ){$Location = 'US'}
        if ($Office -match 'TMB' -or $Office -match 'Tampa'){$Location = 'US'}
        if ($Office -match 'RMT' -or $Office -match 'Remote'){$Location = 'US'}
        if ($Office -match 'Tal' -or $Office -match 'Eston'){$Location = 'EUR'}
    }

    if ($State -ne $null)
    {
        if ($Office -match 'RMT' -or $Office -match 'Remote') 
        {
            $State = Read-Host 'You selected remote or home office for this user. Enter the state in which they will be working from'
            $UserOffice = "$State - Home Office"
        }
    }

$Activity = "Company New User Creation"
$Id = 1
$Task = "Generating username..."
$Percent = 5
Write-Progress -Id $Id -Activity $Activity -Status $Task -PercentComplete $Percent

#Logic to build username if not specified as a parameter.
if ($Username -eq $null -or (Get-ADUser -Filter {sAMAccountName -eq $Username -Server 'ad-dc1.company.com'}) -ne $null)
{
    $FirstInitial = $FirstName.substring(0,1)
    $Username = $FirstInitial+$LastName
    $Username = $Username.Replace(' ','')

    #Detects duplicate username and uses first and second initial (of first name) + last name for the new user.
    if ((Get-ADUser -Filter {sAMAccountName -eq $Username}) -ne $null)
    {  
        $FirstInitial = $FirstName.substring(0,2)
        $Username = $FirstInitial+$LastName
        $Username = $Username.Replace(' ','')

        #Detects duplicate username (come on, really????) and uses first, second, and third initial (of first name) + last name for the new user.
        if ((Get-ADUser -Filter {sAMAccountName -eq $Username}) -ne $null)
        {  
            $FirstInitial = $FirstName.substring(0,3)
            $Username = $FirstInitial+$LastName
            $Username = $Username.Replace(' ','')
        }
    }

}

$Username = $Username.ToLower()

#Group memberships for different deparments.  
#This can be a Git repo in the future for easier maintenance.
#Using the same section for configuring OU path.
$DateTime = (Get-Date -format s).Replace('T','_').Replace(':','')
$groupFile = "C:\temp\group_$DateTime.txt "

$Activity = "Company New User Creation"
$Id = 1
$Task = "Gathering AD group membership info..."
$Percent = 10
Write-Progress -Id $Id -Activity $Activity -Status $Task -PercentComplete $Percent

#IT
if ($Department -eq 'IT' -or $Department -match 'Information Technology')
    {
        Invoke-WebRequest https://github.company.com/raw/IT/PowerShell-Tools/master/Windows/DepartmentGroups/IT.txt?token=AAABF7Ok1pFF_tWtHwA%3D%3D -OutFile $groupFile
        $groupContent = Get-Content $groupFile
        $OU = 'OU=IT,OU=Employees - North America,OU=People,DC=company,DC=com'
    }

#DSE
if ($Department -eq 'DSE' -or $Department -match 'Data Science')
    {
        Invoke-WebRequest https://github.company.com/raw/IT/PowerShell-Tools/master/Windows/DepartmentGroups/DSE.txt?token=AAABl7_chtIIR1M9yDYwA%3D%3D -OutFile $groupFile
        $groupContent = Get-Content $groupFile
        $OU = 'OU=Engineering,OU=Employees - North America,OU=People,DC=company,DC=com'
    }

#Engineering
if ($Department -match 'Engineering')
    {
        Invoke-WebRequest https://github.company.com/raw/IT/PowerShell-Tools/master/Windows/DepartmentGroups/Engineering.txt?token=AAABl8kvvS3wA%3D%3D -OutFile $groupFile
        $groupContent = Get-Content $groupFile
        $OU = 'OU=Engineering,OU=Employees - North America,OU=People,DC=company,DC=com'
    }

#Marketing
if ($Department -match 'Marketing')
    {
        Invoke-WebRequest https://github.company.com/raw/IT/PowerShell-Tools/master/Windows/DepartmentGroups/Marketing.txt?token=AAABl8kvvS3wA%3D%3D -OutFile $groupFile
        $groupContent = Get-Content $groupFile
        $OU = 'OU=Marketing,OU=Employees - North America,OU=People,DC=company,DC=com'
    }

#Product Management
if ($Department -match 'Product Management')
    {
        Invoke-WebRequest https://github.company.com/raw/IT/PowerShell-Tools/master/Windows/DepartmentGroups/ProdMan.txt?token=AAABl8kvvS3wA%3D%3D -OutFile $groupFile
        $groupContent = Get-Content $groupFile
        $OU = 'OU=Product Management,OU=Employees - North America,OU=People,DC=company,DC=com'
    }

#Support
if ($Department -match 'Support')
    {
        Invoke-WebRequest https://github.company.com/raw/IT/PowerShell-Tools/master/Windows/DepartmentGroups/Support.txt?token=AAABl8kvvS3wA%3D%3D -OutFile $groupFile
        $groupContent = Get-Content $groupFile
        $OU = 'OU=Product Support,OU=Employees - North America,OU=People,DC=company,DC=com'
    }

#QA
if ($Department -match 'QA' -or $Department -match 'Quality')
    {
        Invoke-WebRequest https://github.company.com/raw/IT/PowerShell-Tools/master/Windows/DepartmentGroups/QA.txt?token=AAABl8kvvS3wA%3D%3D -OutFile $groupFile
        $groupContent = Get-Content $groupFile
        $OU = 'OU=QA,OU=Employees - North America,OU=People,DC=company,DC=com'
    }

#Research
if ($Department -match 'Research')
    {
        Invoke-WebRequest https://github.company.com/raw/IT/PowerShell-Tools/master/Windows/DepartmentGroups/Research.txt?token=AAABl8kvvS3wA%3D%3D -OutFile $groupFile
        $groupContent = Get-Content $groupFile
        $OU = 'OU=Research,OU=Employees - North America,OU=People,DC=company,DC=com'
    }

#Intelligence
if ($Department -match 'Protection Lab' -or $Department -match 'Intelligence')
    {
        Invoke-WebRequest https://github.company.com/raw/IT/PowerShell-Tools/master/Windows/DepartmentGroups/Intelligence.txt?token=AAABl8kvvS3wA%3D%3D -OutFile $groupFile
        $groupContent = Get-Content $groupFile
        $OU = 'OU=Intelligence,OU=Employees - North America,OU=People,DC=company,DC=com'
    }

#Sales
if ($Department -match 'Sales')
    {
        Invoke-WebRequest https://github.company.com/raw/IT/PowerShell-Tools/master/Windows/DepartmentGroups/Sales.txt?token=AAABl8kvvS3wA%3D%3D -OutFile $groupFile
        $groupContent = Get-Content $groupFile
        $OU = 'OU=Sales,OU=Employees - North America,OU=People,DC=company,DC=com'
    }

#Operations
if ($Department -match 'Growth' -or $Department -match 'Brand' -or $Department -match 'Development')
    {
        Invoke-WebRequest https://github.company.com/raw/IT/PowerShell-Tools/master/Windows/DepartmentGroups/Growth.txt?token=AAABl8kvvS3wA%3D%3D -OutFile $groupFile
        $groupContent = Get-Content $groupFile
        $OU = 'OU=Operations,OU=Employees - North America,OU=People,DC=company,DC=com'
    }

#Administration
if ($Department -match 'Recruiting' -or $Department -match 'Finance' -or $Department -match 'G&A' -or $Department -match 'Global Comm')
    {
        Invoke-WebRequest https://github.company.com/raw/IT/PowerShell-Tools/master/Windows/DepartmentGroups/Admin.txt?token=AAABl8kvvS3wA%3D%3D -OutFile $groupFile
        $groupContent = Get-Content $groupFile
        $OU = 'OU=Administration,OU=Employees - North America,OU=People,DC=company,DC=com'
    }

#General Bucket
if ($OU -eq $null)
    {
        Invoke-WebRequest https://github.company.com/raw/IT/PowerShell-Tools/master/Windows/DepartmentGroups/General.txt?token=AAABl8kvvS3wA%3D%3D -OutFile $groupFile
        $groupContent = Get-Content $groupFile
        $OU = 'OU=Administration,OU=Employees - North America,OU=People,DC=company,DC=com'
    }

#Office 365 Credentials
#Clear-Host
Write-Output 'Enter your company Office 365 username and password (e.g. bwayne@company.com)'

$AdminUser = Get-Credential

#Confirming details with the console and require user action (yes/no) to continue after confirming.
Clear-Host
Write-Host ' '
Write-Host ' '
Write-Host ' '
Write-Host ' '
Write-Host ' '
Write-Host ' '
Write-Host ' '
Write-Host ' '
Write-Host ' '
Write-Host "Username = $Username" -ForegroundColor Green -BackgroundColor Black
Write-Host "First name = $FirstName" -ForegroundColor Green -BackgroundColor Black
Write-Host "Last name = $LastName" -ForegroundColor Green -BackgroundColor Black
Write-Host "Manager = $Manager" -ForegroundColor Green -BackgroundColor Black
Write-Host "Title = $Title" -ForegroundColor Green -BackgroundColor Black
Write-Host "Office = $Office" -ForegroundColor Green -BackgroundColor Black
Write-Host "Department = $Department" -ForegroundColor Green -BackgroundColor Black
Write-Host ' '
Write-Host 'User will be created with the details above. Please validate the data before proceeding.' -ForegroundColor Green -BackgroundColor Black
Write-Host ' '
Write-Host 'Type y to continue or n to cancel.' -ForegroundColor Green -BackgroundColor Black

$Continue = Read-Host 'Continue y/n?'

if ($Continue -eq 'y')
{}
else
    {
        Write-Host 'User creation cancelled.'
        break
        exit
    }

$Activity = "company New User Creation"
$Id = 1
$Task = "Connecting to Office 365 API..."
$Percent = 15
Write-Progress -Id $Id -Activity $Activity -Status $Task -PercentComplete $Percent

#Connect to Office 365 PowerShell
Connect-MsolService -Credential $AdminUser

#AD user account creation
$UserPassword = Get-Content -Path C:\Creds\secure-creds.txt | ConvertTo-SecureString -AsPlainText -force

$Activity = "Company New User Creation"
$Id = 1
$Task = "Creating AD user account and setting properties..."
$Percent = 30
Write-Progress -Id $Id -Activity $Activity -Status $Task -PercentComplete $Percent

if ($State -ne $null)
{ New-ADUser -Name $Username -UserPrincipalName "$Username@company.com" -GivenName $FirstName -Surname $LastName -EmailAddress "$Username@company.com" -DisplayName "$FirstName $LastName" -Company 'company' -Office $UserOffice -Department $Department -Manager $Manager -Title $Title -Server 'ad-dc1.company.com' -Path $OU -ChangePasswordAtLogon $false -AccountPassword $UserPassword -Description $Title }

if ($Manager -ne $null)
{ New-ADUser -Name $Username -UserPrincipalName "$Username@company.com" -GivenName $FirstName -Surname $LastName -EmailAddress "$Username@company.com" -DisplayName "$FirstName $LastName" -Company 'company' -Office $UserOffice -Department $Department -Manager $Manager -Title $Title -Server 'ad-dc1.company.com' -Path $OU -ChangePasswordAtLogon $false -AccountPassword $UserPassword -Description $Title }

if ($State -eq $null)
{ New-ADUser -Name $Username -UserPrincipalName "$Username@company.com" -GivenName $FirstName -Surname $LastName -EmailAddress "$Username@company.com" -DisplayName "$FirstName $LastName" -Company 'company' -Department $Department -Manager $Manager -Title $Title -Server 'ad-dc1.company.com' -Path $OU -ChangePasswordAtLogon $false -AccountPassword $UserPassword -Description $Title }

if ($Manager -eq $null)
{ New-ADUser -Name $Username -UserPrincipalName "$Username@company.com" -GivenName $FirstName -Surname $LastName -EmailAddress "$Username@company.com" -DisplayName "$FirstName $LastName" -Company 'company' -Office $UserOffice -Department $Department -Title $Title -Server 'ad-dc1.company.com' -Path $OU -ChangePasswordAtLogon $false -AccountPassword $UserPassword -Description $Title }

if ($Manager -ne $null -and $State -ne $null)
{ New-ADUser -Name $Username -UserPrincipalName "$Username@company.com" -GivenName $FirstName -Surname $LastName -EmailAddress "$Username@company.com" -DisplayName "$FirstName $LastName" -Company 'company' -Office $UserOffice -Department $Department -Manager $Manager -Title $Title -Server 'ad-dc1.company.com' -Path $OU -ChangePasswordAtLogon $false -AccountPassword $UserPassword -Description $Title }

if ($Manager -eq $null -and $State -eq $null)
{ New-ADUser -Name $Username -UserPrincipalName "$Username@company.com" -GivenName $FirstName -Surname $LastName -EmailAddress "$Username@company.com" -DisplayName "$FirstName $LastName" -Company 'company' -Department $Department -Title $Title -Server 'ad-dc1.company.com' -Path $OU -ChangePasswordAtLogon $false -AccountPassword $UserPassword -Description $Title }

Start-Sleep -Seconds 30

Set-ADUser -Identity $Username -Replace @{Proxyaddresses="SMTP:"+$Username+"@company.com"} -Server 'ad-dc1.company.com'
Set-ADUser -Identity $Username -Add @{Proxyaddresses="smtp:"+$Username+"@company.org"} -Server 'ad-dc1.company.com'
Set-ADUser -Identity $Username -Enabled:$true -Confirm:$false -Server 'ad-dc1.company.com'
Get-ADUser -Identity $Username -Server 'ad-dc1.company.com' | Rename-ADObject -NewName "$FirstName $LastName" -Server 'ad-dc1.company.com'
Get-ADUser $Username -Properties MailNickName -Server 'ad-dc1.company.com' | Set-ADUser -Replace @{MailNickName = "$Username@company.com"} -Server 'ad-dc1.company.com'

if ($Location -match 'SC1' -or $Location -match 'Santa' -or $Location -match 'RMT' -or $Location -match 'Remote' -or $Location -match 'CLW' -or $Location -match 'Clear')
    {
        if ($Location -match 'SC1' -or $Location -match 'Santa')
            {
                Set-ADUser -Identity $Username -Country 'United States' -StreetAddress '1234 Happy St' -City 'Santa Clara' -State 'California' -PostalCode '95052'
            }
        
        if ($Location -match 'Clear' -or $Location -match 'CLW')
            {
                Set-ADUser -Identity $Username -Country 'United States' -StreetAddress '1212 Unicorn Blvd' -City 'Tampa Bay' -State 'Florida' -PostalCode '12345'
            }

        if ($Location -match 'RMT' -or $Location -match 'Remote' -and $State -ne $null)
            {
                Set-ADUser -Identity $Username -Country 'United States' -State $State
            }
    }

$Activity = "Company New User Creation"
$Id = 1
$Task = "Adding user to proper groups..."
$Percent = 60
Write-Progress -Id $Id -Activity $Activity -Status $Task -PercentComplete $Percent

#Add new user to groups gathered from Git repo.
foreach ($Group in $groupContent)
    { 
        Add-ADGroupMember -Identity $Group -Members $Username -Server 'ad-dc1.company.com'
    }

#Clean up C:\Temp file(s).
Get-ChildItem "C:\Temp" | Remove-Item -Filter "*.txt" -Recurse -Force -Confirm:$false

#Force AD to O365 Sync
$Activity = "Company New User Creation"
$Id = 1
$Task = "Forcing AD sync to Office 365..."
$Percent = 70
Write-Progress -Id $Id -Activity $Activity -Status $Task -PercentComplete $Percent

Invoke-Command -ComputerName 'o365-sync.company.com' -ScriptBlock { Import-Module ADSync; Start-ADSyncSyncCycle -PolicyType Delta }

#This will loop the script until the user is visible in Office 365; it will timeout after 15 minutes.
$Timeout = 0

do 
    {
        #Waiting for O365 to Sync
        #Clear-Host
        Write-Output 'Sleeping for 30 seconds...'
        Start-Sleep -Seconds 30
        Write-Output 'Verifying if user successfully synced to Office 365...'  
        $Timeout++
    }

until 
    ( 
        (Get-MsolUser -UserPrincipalName "$Username@company.com" -ErrorAction SilentlyContinue).UserPrincipalName -ne $null -or $Timeout -ge '30'
    )


#Assign properties and E4 license to newly created user account
$Activity = "Company New User Creation"
$Id = 1
$Task = "Creating AD user account and setting properties..."
$Percent = 80
Write-Progress -Id $Id -Activity $Activity -Status $Task -PercentComplete $Percent

$LO = New-MsolLicenseOptions -AccountSkuId 'company:ENTERPRISEWITHSCAL' -DisabledPlans "YAMMER_ENTERPRISE", "RMS_S_ENTERPRISE", "MCOSTANDARD", "SWAY"

Set-MsolUser -UserPrincipalName "$Username@company.com" -UsageLocation $Location
Set-MsolUserLicense -UserPrincipalName "$Username@company.com" -AddLicenses 'company:ENTERPRISEWITHSCAL'
Set-MsolUserLicense -UserPrincipalName "$Username@company.com" -AddLicenses 'company:POWER_BI_STANDARD'
Set-MsolUserLicense -UserPrincipalName "$Username@company.com" -LicenseOptions $LO

$Activity = "Company New User Creation"
$Id = 1
$Task = "Finalizing user..."
$Percent = 100
Write-Progress -Id $Id -Activity $Activity -Status $Task -PercentComplete $Percent

Clear-Host
Write-Host ''
Write-Host ''
Write-Host 'Successfully created user with the below information:' -ForegroundColor White -BackgroundColor DarkGreen
Write-Host ''
Write-Host "Username = $Username" -ForegroundColor Green -BackgroundColor Black
Write-Host "First name = $FirstName" -ForegroundColor Green -BackgroundColor Black
Write-Host "Last name = $LastName" -ForegroundColor Green -BackgroundColor Black
Write-Host "Manager = $Manager" -ForegroundColor Green -BackgroundColor Black
Write-Host "Title = $Title" -ForegroundColor Green -BackgroundColor Black
Write-Host "Office = $Office" -ForegroundColor Green -BackgroundColor Black
Write-Host "Department = $Department" -ForegroundColor Green -BackgroundColor Black

}