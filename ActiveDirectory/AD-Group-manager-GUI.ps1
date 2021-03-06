Add-Type -AssemblyName System.Windows.Forms

$ADGroupManagement = New-Object system.Windows.Forms.Form
$ADGroupManagement.Text = "AD Group Manager"
$ADGroupManagement.TopMost = $true
$ADGroupManagement.Width = 457
$ADGroupManagement.Height = 320

$buttonAddUser = New-Object system.windows.Forms.Button
$buttonAddUser.BackColor = "#0673e9"
$buttonAddUser.Text = "Add User"
$buttonAddUser.ForeColor = "#f8f2f2"
$buttonAddUser.Width = 90
$buttonAddUser.Height = 47
$buttonAddUser.location = new-object system.drawing.point(97,200)
$buttonAddUser.Font = "Calibri,14,style=Bold"
$ADGroupManagement.controls.Add($buttonAddUser)

$txtUsername = New-Object system.windows.Forms.TextBox
$txtUsername.Width = 243
$txtUsername.Height = 20
$txtUsername.location = new-object system.drawing.point(126,20)
$txtUsername.Font = "Microsoft Sans Serif,10"
$ADGroupManagement.controls.Add($txtUsername)

$txtGroupName = New-Object system.windows.Forms.ComboBox
$txtGroupName.Text = ""
$txtGroupName.Width = 241
$txtGroupName.Height = 20
$txtGroupName.location = new-object system.drawing.point(126,64)
$txtGroupName.Font = "Microsoft Sans Serif,10"
$ADGroupManagement.controls.Add($txtGroupName)

$UsernameLabel = New-Object system.windows.Forms.Label
$UsernameLabel.Text = "Username:"
$UsernameLabel.AutoSize = $true
$UsernameLabel.Width = 25
$UsernameLabel.Height = 10
$UsernameLabel.location = new-object system.drawing.point(30,20)
$UsernameLabel.Font = "Microsoft Sans Serif,10"
$ADGroupManagement.controls.Add($UsernameLabel)

$GroupNameLabel = New-Object system.windows.Forms.Label
$GroupNameLabel.Text = "Group Name:"
$GroupNameLabel.AutoSize = $true
$GroupNameLabel.Width = 25
$GroupNameLabel.Height = 10
$GroupNameLabel.location = new-object system.drawing.point(30,64)
$GroupNameLabel.Font = "Microsoft Sans Serif,10"
$ADGroupManagement.controls.Add($GroupNameLabel)

$labelSuccess = New-Object system.windows.Forms.Label
$labelSuccess.Text = "Success!"
$labelSuccess.AutoSize = $true
$labelSuccess.ForeColor = "#38dd5e"
$labelSuccess.visible = $false
$labelSuccess.Width = 25
$labelSuccess.Height = 10
$labelSuccess.location = new-object system.drawing.point(170,130)
$labelSuccess.Font = "Microsoft Sans Serif,18"
$ADGroupManagement.controls.Add($labelSuccess)

$buttonExit = New-Object system.windows.Forms.Button
$buttonExit.Text = "Exit"
$buttonExit.Width = 90
$buttonExit.Height = 47
$buttonExit.BackColor = "#0673e9"
$buttonExit.ForeColor = "#f8f2f2"
$buttonExit.location = new-object system.drawing.point(251,200)
$buttonExit.Font = "Microsoft Sans Serif,14"
$ADGroupManagement.controls.Add($buttonExit)

$labelFailure = New-Object system.windows.Forms.Label
$labelFailure.Text = "Failure! Contact IT "
$labelFailure.AutoSize = $true
$labelFailure.ForeColor = "#dd3844"
$labelFailure.visible = $false
$labelFailure.Width = 25
$labelFailure.Height = 10
$labelFailure.location = new-object system.drawing.point(126,129)
$labelFailure.Font = "Microsoft Sans Serif,18"
$ADGroupManagement.controls.Add($labelFailure)

$Icon = [system.drawing.icon]::ExtractAssociatedIcon($PSHOME + "\powershell.exe")
$ADGroupManagement.Icon = $Icon

$dateTime = Get-Date

$buttonAddUser.Add_Click({

if ($txtUsername.Text -ge 1 -and $txtGroupName.Text -ge 1)
    {

        $labelSuccess.Visible = $true
        $buttonAddUser.Enabled = $false
        $labelSuccess.text = "Success!"

        $ADUsername = $txtUsername.text
        $ADGroupName = $txtGroupName.text


        $Username = 'company\username'
        $Password = Get-Content "C:\Scripts\vmwpass.txt"
        $pass = ConvertTo-SecureString -AsPlainText $Password -Force
        $Cred = New-Object System.Management.Automation.PSCredential -ArgumentList $Username,$pass

        Invoke-Command -ScriptBlock {param($ADUsername, $ADGroupName) Add-ADGroupMember -Identity "$ADGroupName" -Members "$ADUsername" -Confirm:$false } -ComputerName "domain-controller.company.com" -Credential $Cred -ArgumentList $ADUsername, $ADGroupName

    }

if ($txtUsername.Text -lt 1 -or$txtGroupName.Text -lt 1)
    {
        $labelFailure.Visible = $true
        $buttonAddUser.Enabled = $false
    }


Send-MailMessage -To "user@company.com" -From "otheruser@company.com" -Body "$env:Username ran the AD Group Manager at $dateTime - Added $ADUsername to $ADGroupName" -Subject "$env:Username ran the AD Group Manager" -SmtpServer "smtp.company.com" -Port "25"

})


$buttonExit.Add_Click({ # closes the form
    $ADGroupManagement.Close()
})

$ADGroupManagement.Add_Load({
    $txtGroupName.items.add("sec_AD_engineer")
    $txtGroupName.items.add("sec_AD_facilities")
    $txtGroupName.items.add("sec_AD_fitness-center")
    $txtGroupName.items.add("sec_AD_finance-hr")
    $txtGroupName.items.add("sec_AD_general")
    $txtGroupName.items.add("sec_AD_general-under21")
    $txtGroupName.items.add("sec_AD_limited")
    $txtGroupName.items.add("sec_AD_marketing")
    $txtGroupName.items.add("sec_AD_training")
})

[void]$ADGroupManagement.ShowDialog()
$ADGroupManagement.Dispose()