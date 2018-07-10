[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic') | Out-Null
$computername =  [Microsoft.VisualBasic.Interaction]::InputBox("Enter the Server Name:", "ServerName", "")
$ManagedEntity = $computername
$credential = Get-Credential -Credential Domain\Username
remove-item -Path HKLM:\Software\SABMiller -recurse

[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 

$objForm = New-Object System.Windows.Forms.Form 
$objForm.Text = "Select a Computer"
$objForm.Size = New-Object System.Drawing.Size(300,200) 
$objForm.StartPosition = "CenterScreen"

$objForm.KeyPreview = $True
$objForm.Add_KeyDown({if ($_.KeyCode -eq "Enter") 
    {$x=$objListBox.SelectedItem;$objForm.Close()}})
$objForm.Add_KeyDown({if ($_.KeyCode -eq "Escape") 
    {$objForm.Close()}})

$OKButton = New-Object System.Windows.Forms.Button
$OKButton.Location = New-Object System.Drawing.Size(75,120)
$OKButton.Size = New-Object System.Drawing.Size(75,23)
$OKButton.Text = "OK"
$OKButton.Add_Click({$x=$objListBox.SelectedItem;$objForm.Close()})
$objForm.Controls.Add($OKButton)

$CancelButton = New-Object System.Windows.Forms.Button
$CancelButton.Location = New-Object System.Drawing.Size(150,120)
$CancelButton.Size = New-Object System.Drawing.Size(75,23)
$CancelButton.Text = "Cancel"
$CancelButton.Add_Click({$objForm.Close()})
$objForm.Controls.Add($CancelButton)

$objLabel = New-Object System.Windows.Forms.Label
$objLabel.Location = New-Object System.Drawing.Size(10,20) 
$objLabel.Size = New-Object System.Drawing.Size(280,20) 
$objLabel.Text = "Please select a computer:"
$objForm.Controls.Add($objLabel) 

$objListBox = New-Object System.Windows.Forms.ListBox 
$objListBox.Location = New-Object System.Drawing.Size(10,40) 
$objListBox.Size = New-Object System.Drawing.Size(260,20) 
$objListBox.Height = 80

import-module operationsmanager

$groups = Get-SCOMGroup | ? {($_.DisplayName -match "-class-") -and ($_.Displayname -notmatch "1")}

foreach($Group in $Groups){
	[void] $objListBox.Items.Add("$group")
	}

$objForm.Controls.Add($objListBox) 

$objForm.Topmost = $True

$objForm.Add_Shown({$objForm.Activate()})
[void] $objForm.ShowDialog()

$Session = New-PSSession -ComputerName $computername -Credential $credential
$scriptBlock = {param([String]$x) New-Item -Path HKLM:\Software\SABMiller\Role -Name "ManualClassification" -Force ; New-ItemProperty -Path HKLM:\Software\SABMiller\Role -Name "Classification" -PropertyType "String" -Value $x -Force}
Invoke-Command -Session $session -ScriptBlock $scriptBlock -ArgumentList $(,$x)

remove-PSSession -session $Session

