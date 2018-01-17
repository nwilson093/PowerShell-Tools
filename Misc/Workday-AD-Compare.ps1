#Connect to the Workday Web API and run the AD report with provided credentials
#URI needs to be a preconfigured Workday report - these can be exported in XML, CSV, etc.  We use XML in this scenario.
#Update the username, password, and URI in this section with your values.

$dateTime = (Get-Date -format s).Replace('T','_').Replace(':','')
$username = "workday_username"
$password = Get-Content "C:\workdaypasswordlocation\password.txt" | ConvertTo-SecureString -AsPlainText -Force
$Creds = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $password
$uri = "https://workdaywebsite.com/workdayreport.xml"
#Example URI: "https://services1.myworkday.com/ccx/service/customreport2/companyname/userthatgeneratedthereport/REPORT_NAME?format=simplexml"
#Company name is the name of your Workday instance
$response = Invoke-RestMethod -Method Get -Uri $uri -Credential $Creds -Headers $headers


#Build the user reports in AD and Workday; fields match between the two for consistency (note: DepartmentNumber seems to not be populated in AD)

$WDreport = $response.Report_Data.Report_Entry
$DateTime = (Get-Date -format s).Replace('T','_').Replace(':','')

#Creating SAMAccountname to be first initial + last name
foreach ($user in $WDreport)
 { 
    $userfirstname = $user.firstname
    $userlastname = $user.lastname
    $firstinitial = $userfirstname.substring(0,1)
    $accountname = $firstinitial+$userlastname
    $accountname = $accountname.Replace(' ','')

    if ($_.SamAccountName -notmatch $accountname)
    {Add-Member -InputObject $user -NotePropertyName SamAccountName -NotePropertyValue $accountname}
}

#The property name changes in this line are important- it's done so they match the Workday export

$ADusername = "ADusername@domain.com"
$ADpassword = Get-Content "C:\adcredentials\password.txt" | ConvertTo-SecureString -AsPlainText -Force
$ADCreds = New-Object System.Management.Automation.PSCredential -ArgumentList $ADusername, $ADpassword

$ADreport = Get-Aduser -Filter * -Properties * -Credential $ADCreds | Select-Object SamAccountName,EmployeeID,EmployeeNumber,DisplayName,@{ l="LastName";e={$_.Surname} },@{ l="FirstName";e={$_.GivenName} },@{ l="Email";e={$_.EmailAddress} },Office,@{ l="Street";e={$_.StreetAddress} },City,State,PostalCode,@{ l="Country";e={$_.Co} },@{ l="c";e={$_.CountryCode} },@{l="CountryCode";e={$_.Country} },Department,Description,Title,Company

#Set CSV path and export, excluding object type

$WDExport = "C:\Reports\Workday\WDReporttemp_$DateTime.csv"
$WDExportEdited = "C:\Reports\Workday\WDReport_$DateTime.csv"
$ADExport = "C:\Reports\Workday\ADReporttemp_$Datetime.csv"
$ADExportEdited =  "C:\Reports\Workday\ADReport_$Datetime.csv"


$WDreport | Sort DisplayName | Export-CSV -Path $WDExport -NoTypeInformation -Encoding utf8
$ADreport | Where {$_.EmployeeID -ne $null} | Sort DisplayName | Export-CSV -Path $ADExport -NoTypeInformation

Get-Content -Path $WDExport | ForEach-Object {$_ -replace '\?','' } | Export-CSV -Path $WDExportEdited -NoTypeInformation
Get-Content -Path $ADExport | ForEach-Object {$_ -replace '\?','' } | Export-CSV -Path $WDExportEdited -NoTypeInformation

function Compare-CsvFile {
		[CmdletBinding()]
		param (
			[Parameter(Mandatory)]
			[string]$UniqueIdentifier,
			[Parameter(Mandatory)]
			[ValidateScript({
				if (!(Test-Path -Path $_ -PathType Leaf)) {
					throw "The reference CSV file $($_) cannot be found"
				} else {
					$true
				}
			})]
			[string]$ReferenceCsv,
			[Parameter(Mandatory)]
			[ValidateScript({
				if (!(Test-Path -Path $_ -PathType Leaf)) {
					throw "The difference CSV file $($_) cannot be found"
				} else {
					$true
				}
			})]
			[string]$DifferenceCsv
		)
		process {
			try {
				## Import both CSV to begin comparisons
				$RefCsvData = Import-Csv -Path $ReferenceCsv
				$DiffCsvData = Import-Csv -Path $DifferenceCsv
				## Begin checking each row in the reference CSV
				foreach ($RefCsvRow in $RefCsvData) {
					## Find the row match in the difference CSV from the unique ID specified
					$DiffCsvRow = $DiffCsvData | where { $_.$UniqueIdentifier -eq $RefCsvRow.$UniqueIdentifier }
					## If any matches were found
					if ($DiffCsvRow) {
						## There should be only be a single match.  If the UniqueIdentifier param is actually unique
						## there should always be only one match
						if ($DiffCsvRow -is [array]) {
							throw "Multiple matches found in difference CSV for unique ID $UniqueIdentifier"
						} else {
							## Beging checking each column (property) in the reference CSV excluding the unique ID property
							foreach ($RefCsvProp in ($RefCsvRow.PsObject.Properties | where { $_.Name -ne $UniqueIdentifier})) {
								## Begin comparing the difference CSV columns (properties) for each row
								foreach ($DiffCsvProp in $DiffCsvRow.PSObject.Properties) {
									## If the field names match we can then compare the values
									if ($RefCsvProp.Name -eq $DiffCsvProp.Name) {
										## Create the output object
										$CompareObject = @{
											$UniqueIdentifier = $RefCsvRow.$UniqueIdentifier
											'Property' = $RefCsvProp.Name
                                            'Workday Value' = $DiffCsvProp.Value
											'Active Directory Value' = $RefCsvProp.Value
											
										}
										if ($RefCsvProp.Value -ne $DiffCsvProp.Value) {
											$CompareObject.Result = ''
										} else {
											$CompareObject.Result = '=='
										}
										[pscustomobject]$CompareObject
									}
								}
							}
						}
					} else {
						Write-Verbose -Message "No matches found for $UniqueIdentifier in difference CSV"
					}
				}
			} catch {
				Write-Error -Message "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
				$false
			}
		}
	}

$CsvCompare = Compare-CsvFile -UniqueIdentifier Email -ReferenceCsv $ADExport -DifferenceCsv $WDExport | Where {$_.Result -ne '=='}

$CsvComparePath = "C:\Reports\Workday\differences_temp_$dateTime.csv"
$CsvComparePathTemp2 = "C:\Reports\Workday\differences_temp2_$dateTime.csv"
$CsvComparePathNew = "C:\Reports\Workday\WD-AD-Differences_$dateTime.csv"

$CsvCompare | Sort Email | Export-Csv -Path $CsvComparePath -NoTypeInformation

Get-Content $CsvComparePath | Where {$_ -notmatch "SamAccountName"} | Out-File $CsvComparePathTemp2
Get-Content $CsvComparePathTemp2 | ForEach-Object {$_ -replace '\?','' } | Out-File $CsvComparePathNew

#Email the report with the CSV included as an attachment

$Smtp = "smtpserver.com" 
$To = $emailAddress
$From = "fromaddress@server.com" 
$Subject = "Daily Workday-AD Comparison Report - $dateTime"  
$Body = "File is attached."

Send-MailMessage -SmtpServer $Smtp -To $To -From $From -Subject $Subject -Body $Body -BodyAsHtml -Priority High -Port "25" -Attachments $CsvComparePathNew


#Clean up all of the generated files

Get-ChildItem "C:\Reports\Workday" | Remove-Item -Filter "*.csv" -Recurse -Force -Confirm:$false