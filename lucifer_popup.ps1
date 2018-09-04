#*************************PRE-MIGRATION SCRIPT STARTS FROM HERE********************

#*************************FILE PREPARATION STARTS FROM HERE************************

# Create header for HTML Report
$Head = "<style>"
$Head +="BODY{background-color:#CCCCCC;font-family:Verdana,sans-serif; font-size: x-small;}"
$Head +="TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse; width: 100%;}"
$Head +="TH{border-width: 1px;padding: 0px;border-style: solid;border-color: black;background-color:green;color:white;padding: 5px; font-weight: bold;text-align:left;}"
$Head +="TD{border-width: 1px;padding: 0px;border-style: solid;border-color: black;background-color:#F0F0F0; padding: 2px;}"
$Head +="</style>"

#Check if MRI DB file exists

$mriexists = Test-Path -Path "C:\Temp\MRIFile\MRI_File.csv"

#Replace Headings

if($mriexists -eq $true){

$filedir = "C:\TEMP\MRIFile"
$mrifileraw = Get-ChildItem -Path $filedir -Filter MRI_File.csv -Recurse
$filedblocationraw = $mrifileraw.FullName
$fileconvert = Get-Content -path $filedblocationraw
$fileconvert[0] = $fileconvert[0].replace($fileconvert[0], "ServerName,DatePurchased,Country,Location,BillingStatus,CostCentre,ARNNumber,ARNDescriptionServiceName,SDCName,WorkloadType,WorkloadFunction,Status,Platform,HWManufacturer,HWModel,Classification,CPUNo,CPUSpeed,CPUType,Memory,HDNo,HDSize,RPERF,OperatingSystemType,OSVersion,OSRevision,SerialNo,AssetNo,Comments")
Set-Content -Path $filedir"\mri_file_raw.csv" -Value $fileconvert

#Load MRI CSV file into Memory and populate HTML file

$lookupdb = Get-ChildItem -Path "C:\TEMP\MRIFile" -Filter MRI_File_Raw.csv -Recurse
$filedblocation = $lookupdb.FullName
$mrifile = Import-Csv $filedblocation
}

if($mriexists -eq $false)
{
$filedir = "C:\TEMP\MRIFile"
}

#*************************FILE PREPARATION ENDS FROM HERE**************************

#*************************SCOM VERSION DETECTION STARTS FROM HERE******************

#Check which version of SCOM is installed
#Detect the Operations Managers installation via Registry. WMI dont work well with installed softwares.
$SCOM2012Version = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where {$_.DisplayName -like "*2012*Operations Manager*"} | Select-Object -expand Displayversion

$SCOM2007Version = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where {$_.DisplayName -like "*Operations Manager*2007*"} | Select-Object -expand Displayversion

if ($SCOM2012Version -like "7.*")
{
$ReportOutput =  "<p><u><H1>System Center Operations Manager 2012 R2 Pre-Migration Checklist Report</H1></u></p>"
}

if ($SCOM2007Version -like "6.*")
{
$ReportOutput =  "<p><u><H1>System Center Operations Manager 2007 R2 Pre-Migration Checklist Report</H1></u></p>"
}

#*************************SCOM VERSION DETECTION ENDS FROM HERE********************

#*************************SCRIPT VARIABLES STARTS FROM HERE************************

#Load System Center Operations Manager module
if ($SCOM2012Version)
{
#Initialize SCOM snapin
Import-Module OperationsManager

#Get Management Group Name
$MGName = get-scommanagementserver | select ManagementGroup -unique

#Get the agent class and the each object which is in a grey state
$MSCAgent = Get-SCClass -name "Microsoft.SystemCenter.Agent"
$objects = Get-SCOMMonitoringObject -class:$MSCAgent # | Where-Object {($_.InMaintenanceMode -eq $False)}

#Get Agent Information
$AgentInformation = Get-SCOMMonitoringObject -class:$MSCAgent
}
Elseif ($SCOM2007Version)
{
#Initialize SCOM snapin
$RMS='localhost'
$strSpapin ='Microsoft.EnterpriseManagement.OperationsManager.Client'
$objSnapin = Get-PSSnapin | ?{$_.Name -eq $strSpapin}
if (-not $objSnapin) { Add-PSSnapin $strSpapin }

set-location 'OperationsManagerMonitoring::' | out-null
new-managementGroupConnection -ConnectionString:$RMS | out-null
set-location $RMS

#Get Management Group Name
$MGName = get-managementserver | select ManagementGroup -unique

#Get the Agent Class and each object detail
$MSCAgent = get-monitoringclass -name "Microsoft.SystemCenter.Agent"
$objects = Get-MonitoringObject -monitoringclass:$MSCAgent # | Where-Object {($_.InMaintenanceMode -eq $False)}

#Get Agent Information
$AgentInformation = Get-MonitoringObject -monitoringclass:$MSCAgent
}

#Get Management Group Name

$MgName = $mgname.ManagementGroup.Name
$ReportOutput +=  "<p><H2>Management Group Name: $mgname</H2></p>"

#Agent Count in Management Group:
$agentcount = $objects.count
$ReportOutput +=  "<p><H2>Agent Count in Management Group: $agentcount</H2></p>"
$ReportOutput +=  "<p><u><H1>Migration Readiness and Agent Integrity:</H1></u></p>"

#*************************SCRIPT VARIABLES ENDS FROM HERE**************************

#*************************AGENT INFORMATION STARTS FROM HERE***********************

if ($SCOM2012Version)
{
#Get All Grey Agents
$greylinktomri = $AgentInformation | Where-Object {($_.IsAvailable -eq $false) -and (!($_.HealthState -eq "Uninitialized")) -and ($_.InMaintenanceMode -eq $False)}
$TotalAgentsinGreyStateCount = ($AgentInformation | Where-Object {($_.IsAvailable -eq $false) -and (!($_.HealthState -eq "Uninitialized")) -and ($_.InMaintenanceMode -eq $False)} ).Count
}
Elseif ($SCOM2007Version)
{
#Get All Grey Agents
$greylinktomri =  $AgentInformation | Where-Object {($_.IsAvailable -eq $false) -and (!($_.HealthState -eq "Uninitialized")) -and ($_.InMaintenanceMode -eq $False)}
$TotalAgentsinGreyStateCount = ($AgentInformation | Where-Object {($_.IsAvailable -eq $false) -and (!($_.HealthState -eq "Uninitialized")) -and ($_.InMaintenanceMode -eq $False)} ).Count
}

#Output dependent on MRI DB file being available

if ($mriexists -eq $true){

#Link Output to MRI File and populate line for HTML File

$AgentTable = New-Object System.Data.DataTable "$AvailableTable"
$AgentTable.Columns.Add((New-Object System.Data.DataColumn ServerName,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn PatchList,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn ProxyingEnabled,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn AgentVersion,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn DatePurchased,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn Country,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn Location,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn BillingStatus,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn CostCentre,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn ARNNumber,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn ARNDescriptionServiceName,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn SDCName,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn WorkloadType,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn WorkloadFunction,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn Status,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn Platform,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn HWManufacturer,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn HWModel,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn Classification,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn CPUNo,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn CPUSpeed,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn CPUType,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn Memory,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn HDNo,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn HDSize,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn RPERF,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn OperatingSystemType,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn OSVersion,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn OSRevision,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn SerialNo,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn AssetNo,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn Comments,([string])))

foreach($agent in $greylinktomri){
    $agtdata = $agent.displayname.split('.')[0]
    $mridata = $mrifile | ? {$_.ServerName -match $agtdata}

    if ($SCOM2012Version)
    {
    $PLList = $agent.'[Microsoft.SystemCenter.HealthService].PatchList'.Value
    $ProxyingEnabled = $agent.'[Microsoft.SystemCenter.HealthService].ProxyingEnabled'.Value
    $AgentVersion = $agent.'[Microsoft.SystemCenter.HealthService].Version'.Value
    }
    Elseif ($SCOM2007Version)
    {
    $PLList = $agent.'[Microsoft.SystemCenter.HealthService].PatchList'
    $ProxyingEnabled = $agent.'[Microsoft.SystemCenter.HealthService].ProxyingEnabled'
    $AgentVersion = $agent.'[Microsoft.SystemCenter.HealthService].Version'
    }

#Create HTML Output

        $NewRow = $AgentTable.NewRow()
        $NewRow.ServerName=($agtdata)
        $NewRow.PatchList=($PLList)
        $NewRow.ProxyingEnabled=($ProxyingEnabled)
        $NewRow.AgentVersion=($AgentVersion)
        $NewRow.DatePurchased=($mridata.DatePurchased).ToString()
        $NewRow.Country=($mridata.Country).ToString()
        $NewRow.Location=($mridata.Location).ToString()
        $NewRow.BillingStatus=($mridata.BillingStatus).ToString()
        $NewRow.CostCentre=($mridata.CostCentre).ToString()
        $NewRow.ARNNumber=($mridata.ARNNumber).ToString()
        $NewRow.ARNDescriptionServiceName=($mridata.ARNDescriptionServiceName).ToString()
        $NewRow.SDCName=($mridata.SDCName).ToString()
        $NewRow.WorkloadType=($mridata.WorkloadType).ToString()
        $NewRow.WorkloadFunction=($mridata.WorkloadFunction).ToString()
        $NewRow.Status=($mridata.Status).ToString()
        $NewRow.Platform=($mridata.Platform).ToString()
        $NewRow.HWManufacturer=($mridata.HWManufacturer).ToString()
        $NewRow.HWModel=($mridata.HWModel).ToString()
        $NewRow.Classification=($mridata.Classification).ToString()
        $NewRow.CPUNo=($mridata.CPUNo).ToString()
        $NewRow.CPUSpeed=($mridata.CPUSpeed).ToString()
        $NewRow.CPUType=($mridata.CPUType).ToString()
        $NewRow.Memory=($mridata.Memory).ToString()
        $NewRow.HDNo=($mridata.HDNo).ToString()
        $NewRow.HDSize=($mridata.HDSize).ToString()
        $NewRow.RPERF=($mridata.RPERF).ToString()
        $NewRow.OperatingSystemType=($mridata.OperatingSystemType).ToString()
        $NewRow.OSVersion=($mridata.OSVersion).ToString()
        $NewRow.OSRevision=($mridata.OSRevision).ToString()
        $NewRow.SerialNo=($mridata.SerialNo).ToString()
        $NewRow.AssetNo=($mridata.AssetNo).ToString()
        $NewRow.Comments=($mridata.Comments).ToString()
        $AgentTable.Rows.Add($NewRow)
	}

#Write to Report 

	$ReportOutput +=  "<p><H2>Grey Agent Information:</H2></p>" 
	$ReportOutput +=  "<p><H3>Grey Agent Count: $TotalAgentsinGreyStateCount</H3></p>"
	$ReportOutput += $AgentTable | Sort-Object ServerName | Select ServerName,PatchList,ProxyingEnabled,AgentVersion,DatePurchased,Country,Location,BillingStatus,CostCentre,ARNNumber,ARNDescriptionServiceName,SDCName,WorkloadType,WorkloadFunction,Status,Platform,HWManufacturer,HWModel,Classification,CPUNo,CPUSpeed,CPUType,Memory,HDNo,HDSize,RPERF,OperatingSystemType,OSVersion,OSRevision,SerialNo,AssetNo,Comments | ConvertTo-HTML -fragment

	}

if ($mriexists -eq $false){

#Link Output to MRI File and populate line for HTML File

$AgentTable = New-Object System.Data.DataTable "$AvailableTable"
$AgentTable.Columns.Add((New-Object System.Data.DataColumn DisplayName,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn PatchList,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn ProxyingEnabled,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn AgentVersion,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn HealthState,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn AvailabilityLastModified,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn StateLastModified,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn InMaintenanceMode,([string])))

foreach($agent in $greylinktomri){
    if ($SCOM2012Version)
    {
    $PLList = $agent.'[Microsoft.SystemCenter.HealthService].PatchList'.Value
    $ProxyingEnabled = $agent.'[Microsoft.SystemCenter.HealthService].ProxyingEnabled'.Value
    $AgentVersion = $agent.'[Microsoft.SystemCenter.HealthService].Version'.Value
    }
    Elseif ($SCOM2007Version)
    {
    $PLList = $agent.'[Microsoft.SystemCenter.HealthService].PatchList'
    $ProxyingEnabled = $agent.'[Microsoft.SystemCenter.HealthService].ProxyingEnabled'
    $AgentVersion = $agent.'[Microsoft.SystemCenter.HealthService].Version'
    }

#Create HTML Output

        $NewRow = $AgentTable.NewRow()
        $NewRow.DisplayName=($agent.DisplayName).ToString()
        $NewRow.PatchList=($PLList)
        $NewRow.ProxyingEnabled=($ProxyingEnabled)
        $NewRow.AgentVersion=($AgentVersion)
        $NewRow.HealthState=($agent.HealthState).ToString()
        $NewRow.AvailabilityLastModified=($agent.AvailabilityLastModified).ToString()
        $NewRow.StateLastModified=($agent.StateLastModified).ToString()
        $NewRow.InMaintenanceMode=($agent.InMaintenanceMode).ToString()
        $AgentTable.Rows.Add($NewRow)
	}

#Write to Report 

	$ReportOutput +=  "<p><H2>Grey Agent Information:</H2></p>" 
	$ReportOutput +=  "<p><H3>Grey Agent Count: $TotalAgentsinGreyStateCount</H3></p>"
	$ReportOutput += $AgentTable | Sort-Object ServerName | Select DisplayName,PatchList,ProxyingEnabled,AgentVersion,HealthState,AvailabilityLastModified,StateLastModified,InMaintenanceMode | ConvertTo-HTML -fragment

	}

#*************************AGENT SECTION ENDS HERE**********************************

#*************************AGENT PATCH COMPLIANCE STARTS HERE***********************

if ($SCOM2012Version)
{
#Get All Unpatched Agents
$patchlinktomri = $AgentInformation | Where-Object {($_.'[Microsoft.SystemCenter.HealthService].PatchList'.Value -notmatch ".*UR(9|\d{2,3}).*")-and ($_.InMaintenanceMode -eq $False)}
$TotalAgentsMissingPatch = ($AgentInformation | Where-Object {($_.'[Microsoft.SystemCenter.HealthService].PatchList'.Value -notmatch ".*UR(9|\d{2,3}).*")-and ($_.InMaintenanceMode -eq $False)} ).Count
}
Elseif ($SCOM2007Version)
{
#Get All Unpatched Agents
$patchlinktomri = $AgentInformation | Where-Object {($_.'[Microsoft.SystemCenter.HealthService].PatchList' -notmatch ".*UR(9|\d{2,3}).*")-and ($_.InMaintenanceMode -eq $False)}
$TotalAgentsMissingPatch = ($AgentInformation | Where-Object {($_.'[Microsoft.SystemCenter.HealthService].PatchList' -notmatch ".*UR(9|\d{2,3}).*")-and ($_.InMaintenanceMode -eq $False)} ).Count

}

#Output dependent on MRI DB file being available

if ($mriexists -eq $true){

#Link Output to MRI File and populate line for HTML File

$AgentTable = New-Object System.Data.DataTable "$AvailableTable"
$AgentTable.Columns.Add((New-Object System.Data.DataColumn ServerName,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn PatchList,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn ProxyingEnabled,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn AgentVersion,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn DatePurchased,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn Country,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn Location,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn BillingStatus,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn CostCentre,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn ARNNumber,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn ARNDescriptionServiceName,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn SDCName,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn WorkloadType,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn WorkloadFunction,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn Status,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn Platform,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn HWManufacturer,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn HWModel,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn Classification,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn CPUNo,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn CPUSpeed,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn CPUType,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn Memory,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn HDNo,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn HDSize,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn RPERF,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn OperatingSystemType,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn OSVersion,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn OSRevision,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn SerialNo,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn AssetNo,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn Comments,([string])))

foreach($agent in $patchlinktomri){
    $agtdata = $agent.displayname.split('.')[0]
    $mridata = $mrifile | ? {$_.ServerName -match $agtdata}

    if ($SCOM2012Version)
    {
    $PLList = $agent.'[Microsoft.SystemCenter.HealthService].PatchList'.Value
    $ProxyingEnabled = $agent.'[Microsoft.SystemCenter.HealthService].ProxyingEnabled'.Value
    $AgentVersion = $agent.'[Microsoft.SystemCenter.HealthService].Version'.Value
    }
    Elseif ($SCOM2007Version)
    {
    $PLList = $agent.'[Microsoft.SystemCenter.HealthService].PatchList'
    $ProxyingEnabled = $agent.'[Microsoft.SystemCenter.HealthService].ProxyingEnabled'
    $AgentVersion = $agent.'[Microsoft.SystemCenter.HealthService].Version'
    }

#Create HTML Output

        $NewRow = $AgentTable.NewRow()
        $NewRow.ServerName=($agtdata)
        $NewRow.PatchList=($PLList)
        $NewRow.ProxyingEnabled=($ProxyingEnabled)
        $NewRow.AgentVersion=($AgentVersion)
        $NewRow.DatePurchased=($mridata.DatePurchased).ToString()
        $NewRow.Country=($mridata.Country).ToString()
        $NewRow.Location=($mridata.Location).ToString()
        $NewRow.BillingStatus=($mridata.BillingStatus).ToString()
        $NewRow.CostCentre=($mridata.CostCentre).ToString()
        $NewRow.ARNNumber=($mridata.ARNNumber).ToString()
        $NewRow.ARNDescriptionServiceName=($mridata.ARNDescriptionServiceName).ToString()
        $NewRow.SDCName=($mridata.SDCName).ToString()
        $NewRow.WorkloadType=($mridata.WorkloadType).ToString()
        $NewRow.WorkloadFunction=($mridata.WorkloadFunction).ToString()
        $NewRow.Status=($mridata.Status).ToString()
        $NewRow.Platform=($mridata.Platform).ToString()
        $NewRow.HWManufacturer=($mridata.HWManufacturer).ToString()
        $NewRow.HWModel=($mridata.HWModel).ToString()
        $NewRow.Classification=($mridata.Classification).ToString()
        $NewRow.CPUNo=($mridata.CPUNo).ToString()
        $NewRow.CPUSpeed=($mridata.CPUSpeed).ToString()
        $NewRow.CPUType=($mridata.CPUType).ToString()
        $NewRow.Memory=($mridata.Memory).ToString()
        $NewRow.HDNo=($mridata.HDNo).ToString()
        $NewRow.HDSize=($mridata.HDSize).ToString()
        $NewRow.RPERF=($mridata.RPERF).ToString()
        $NewRow.OperatingSystemType=($mridata.OperatingSystemType).ToString()
        $NewRow.OSVersion=($mridata.OSVersion).ToString()
        $NewRow.OSRevision=($mridata.OSRevision).ToString()
        $NewRow.SerialNo=($mridata.SerialNo).ToString()
        $NewRow.AssetNo=($mridata.AssetNo).ToString()
        $NewRow.Comments=($mridata.Comments).ToString()
        $AgentTable.Rows.Add($NewRow)
	}

#Write to Report

	$ReportOutput +=  "<p><H2>Compliance - Missing Approved Patch Level on Servers:</H2></p>"
	$ReportOutput +=  "<p><H3>Missing Approved Patch Level Count: $TotalAgentsMissingPatch</H3></p>"
	$ReportOutput += $AgentTable | Sort-Object ServerName | Select ServerName,PatchList,ProxyingEnabled,AgentVersion,DatePurchased,Country,Location,BillingStatus,CostCentre,ARNNumber,ARNDescriptionServiceName,SDCName,WorkloadType,WorkloadFunction,Status,Platform,HWManufacturer,HWModel,Classification,CPUNo,CPUSpeed,CPUType,Memory,HDNo,HDSize,RPERF,OperatingSystemType,OSVersion,OSRevision,SerialNo,AssetNo,Comments | ConvertTo-HTML -fragment

	}

if ($mriexists -eq $false){

#Link Output to MRI File and populate line for HTML File

$AgentTable = New-Object System.Data.DataTable "$AvailableTable"
$AgentTable.Columns.Add((New-Object System.Data.DataColumn DisplayName,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn PatchList,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn ProxyingEnabled,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn AgentVersion,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn HealthState,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn AvailabilityLastModified,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn StateLastModified,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn InMaintenanceMode,([string])))

foreach($agent in $patchlinktomri){
    if ($SCOM2012Version)
    {
    $PLList = $agent.'[Microsoft.SystemCenter.HealthService].PatchList'.Value
    $ProxyingEnabled = $agent.'[Microsoft.SystemCenter.HealthService].ProxyingEnabled'.Value
    $AgentVersion = $agent.'[Microsoft.SystemCenter.HealthService].Version'.Value
    }
    Elseif ($SCOM2007Version)
    {
    $PLList = $agent.'[Microsoft.SystemCenter.HealthService].PatchList'
    $ProxyingEnabled = $agent.'[Microsoft.SystemCenter.HealthService].ProxyingEnabled'
    $AgentVersion = $agent.'[Microsoft.SystemCenter.HealthService].Version'
    }

#Create HTML Output

        $NewRow = $AgentTable.NewRow()
        $NewRow.DisplayName=($agent.DisplayName).ToString()
        $NewRow.PatchList=($PLList)
        $NewRow.ProxyingEnabled=($ProxyingEnabled)
        $NewRow.AgentVersion=($AgentVersion)
        $NewRow.HealthState=($agent.HealthState).ToString()
        $NewRow.AvailabilityLastModified=($agent.AvailabilityLastModified).ToString()
        $NewRow.StateLastModified=($agent.StateLastModified).ToString()
        $NewRow.InMaintenanceMode=($agent.InMaintenanceMode).ToString()
        $AgentTable.Rows.Add($NewRow)
	}

#Write to Report

	$ReportOutput +=  "<p><H2>Compliance - Missing Approved Patch Level on Servers:</H2></p>"
	$ReportOutput +=  "<p><H3>Missing Approved Patch Level Count: $TotalAgentsMissingPatch</H3></p>"
	$ReportOutput += $AgentTable | Sort-Object ServerName | Select DisplayName,PatchList,ProxyingEnabled,AgentVersion,HealthState,AvailabilityLastModified,StateLastModified,InMaintenanceMode | ConvertTo-HTML -fragment

	}


#*************************AGENT PATCH COMPLIANCE ENDS HERE*************************

#*************************AGENT VERSION CHECK STARTS HERE**************************

if ($SCOM2012Version)
{
#Get All Unpatched Agents
$versionlinktomri = $AgentInformation | Where-Object {($_.'[Microsoft.SystemCenter.HealthService].Version'.Value -lt "7.1")-and ($_.InMaintenanceMode -eq $False)}
$TotalAgentsVersionCheck = ($AgentInformation | Where-Object {($_.'[Microsoft.SystemCenter.HealthService].Version'.Value -lt "7.1")-and ($_.InMaintenanceMode -eq $False)} ).Count
}
Elseif ($SCOM2007Version)
{
#Get All Unpatched Agents
$versionlinktomri = $AgentInformation | Where-Object {($_.'[Microsoft.SystemCenter.HealthService].Version' -lt "7.1")-and ($_.InMaintenanceMode -eq $False)}
$TotalAgentsVersionCheck = ($AgentInformation | Where-Object {($_.'[Microsoft.SystemCenter.HealthService].Version' -lt "7.1")-and ($_.InMaintenanceMode -eq $False)} ).Count

}

#Output dependent on MRI DB file being available

if ($mriexists -eq $true){

#Link Output to MRI File and populate line for HTML File

$AgentTable = New-Object System.Data.DataTable "$AvailableTable"
$AgentTable.Columns.Add((New-Object System.Data.DataColumn ServerName,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn PatchList,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn ProxyingEnabled,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn AgentVersion,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn DatePurchased,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn Country,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn Location,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn BillingStatus,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn CostCentre,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn ARNNumber,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn ARNDescriptionServiceName,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn SDCName,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn WorkloadType,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn WorkloadFunction,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn Status,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn Platform,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn HWManufacturer,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn HWModel,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn Classification,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn CPUNo,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn CPUSpeed,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn CPUType,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn Memory,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn HDNo,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn HDSize,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn RPERF,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn OperatingSystemType,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn OSVersion,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn OSRevision,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn SerialNo,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn AssetNo,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn Comments,([string])))

foreach($agent in $versionlinktomri){
    $agtdata = $agent.displayname.split('.')[0]
    $mridata = $mrifile | ? {$_.ServerName -match $agtdata}

    if ($SCOM2012Version)
    {
    $PLList = $agent.'[Microsoft.SystemCenter.HealthService].PatchList'.Value
    $ProxyingEnabled = $agent.'[Microsoft.SystemCenter.HealthService].ProxyingEnabled'.Value
    $AgentVersion = $agent.'[Microsoft.SystemCenter.HealthService].Version'.Value
    }
    Elseif ($SCOM2007Version)
    {
    $PLList = $agent.'[Microsoft.SystemCenter.HealthService].PatchList'
    $ProxyingEnabled = $agent.'[Microsoft.SystemCenter.HealthService].ProxyingEnabled'
    $AgentVersion = $agent.'[Microsoft.SystemCenter.HealthService].Version'
    }

#Create HTML Output

        $NewRow = $AgentTable.NewRow()
        $NewRow.ServerName=($agtdata)
        $NewRow.PatchList=($PLList)
        $NewRow.ProxyingEnabled=($ProxyingEnabled)
        $NewRow.AgentVersion=($AgentVersion)
        $NewRow.DatePurchased=($mridata.DatePurchased).ToString()
        $NewRow.Country=($mridata.Country).ToString()
        $NewRow.Location=($mridata.Location).ToString()
        $NewRow.BillingStatus=($mridata.BillingStatus).ToString()
        $NewRow.CostCentre=($mridata.CostCentre).ToString()
        $NewRow.ARNNumber=($mridata.ARNNumber).ToString()
        $NewRow.ARNDescriptionServiceName=($mridata.ARNDescriptionServiceName).ToString()
        $NewRow.SDCName=($mridata.SDCName).ToString()
        $NewRow.WorkloadType=($mridata.WorkloadType).ToString()
        $NewRow.WorkloadFunction=($mridata.WorkloadFunction).ToString()
        $NewRow.Status=($mridata.Status).ToString()
        $NewRow.Platform=($mridata.Platform).ToString()
        $NewRow.HWManufacturer=($mridata.HWManufacturer).ToString()
        $NewRow.HWModel=($mridata.HWModel).ToString()
        $NewRow.Classification=($mridata.Classification).ToString()
        $NewRow.CPUNo=($mridata.CPUNo).ToString()
        $NewRow.CPUSpeed=($mridata.CPUSpeed).ToString()
        $NewRow.CPUType=($mridata.CPUType).ToString()
        $NewRow.Memory=($mridata.Memory).ToString()
        $NewRow.HDNo=($mridata.HDNo).ToString()
        $NewRow.HDSize=($mridata.HDSize).ToString()
        $NewRow.RPERF=($mridata.RPERF).ToString()
        $NewRow.OperatingSystemType=($mridata.OperatingSystemType).ToString()
        $NewRow.OSVersion=($mridata.OSVersion).ToString()
        $NewRow.OSRevision=($mridata.OSRevision).ToString()
        $NewRow.SerialNo=($mridata.SerialNo).ToString()
        $NewRow.AssetNo=($mridata.AssetNo).ToString()
        $NewRow.Comments=($mridata.Comments).ToString()
        $AgentTable.Rows.Add($NewRow)
	}

#Write to Report


	$ReportOutput +=  "<p><H2>Agents Requiring Upgrade:</H2></p>"
	$ReportOutput +=  "<p><H3>Agents Requiring Upgrade Count: $TotalAgentsVersionCheck</H3></p>"
	$ReportOutput += $AgentTable | Sort-Object ServerName | Select ServerName,PatchList,ProxyingEnabled,AgentVersion,DatePurchased,Country,Location,BillingStatus,CostCentre,ARNNumber,ARNDescriptionServiceName,SDCName,WorkloadType,WorkloadFunction,Status,Platform,HWManufacturer,HWModel,Classification,CPUNo,CPUSpeed,CPUType,Memory,HDNo,HDSize,RPERF,OperatingSystemType,OSVersion,OSRevision,SerialNo,AssetNo,Comments | ConvertTo-HTML -fragment

	}

if ($mriexists -eq $false){

#Link Output to MRI File and populate line for HTML File

$AgentTable = New-Object System.Data.DataTable "$AvailableTable"
$AgentTable.Columns.Add((New-Object System.Data.DataColumn DisplayName,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn PatchList,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn ProxyingEnabled,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn AgentVersion,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn HealthState,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn AvailabilityLastModified,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn StateLastModified,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn InMaintenanceMode,([string])))

foreach($agent in $versionlinktomri){
    if ($SCOM2012Version)
    {
    $PLList = $agent.'[Microsoft.SystemCenter.HealthService].PatchList'.Value
    $ProxyingEnabled = $agent.'[Microsoft.SystemCenter.HealthService].ProxyingEnabled'.Value
    $AgentVersion = $agent.'[Microsoft.SystemCenter.HealthService].Version'.Value
    }
    Elseif ($SCOM2007Version)
    {
    $PLList = $agent.'[Microsoft.SystemCenter.HealthService].PatchList'
    $ProxyingEnabled = $agent.'[Microsoft.SystemCenter.HealthService].ProxyingEnabled'
    $AgentVersion = $agent.'[Microsoft.SystemCenter.HealthService].Version'
    }

#Create HTML Output

        $NewRow = $AgentTable.NewRow()
        $NewRow.DisplayName=($agent.DisplayName).ToString()
        $NewRow.PatchList=($PLList)
        $NewRow.ProxyingEnabled=($ProxyingEnabled)
        $NewRow.AgentVersion=($AgentVersion)
        $NewRow.HealthState=($agent.HealthState).ToString()
        $NewRow.AvailabilityLastModified=($agent.AvailabilityLastModified).ToString()
        $NewRow.StateLastModified=($agent.StateLastModified).ToString()
        $NewRow.InMaintenanceMode=($agent.InMaintenanceMode).ToString()
        $AgentTable.Rows.Add($NewRow)
	}

#Write to Report

	$ReportOutput +=  "<p><H2>Agents Requiring Upgrade:</H2></p>"
	$ReportOutput +=  "<p><H3>Agents Requiring Upgrade Count: $TotalAgentsVersionCheck</H3></p>"
	$ReportOutput += $AgentTable | Sort-Object ServerName | Select DisplayName,PatchList,ProxyingEnabled,AgentVersion,HealthState,AvailabilityLastModified,StateLastModified,InMaintenanceMode | ConvertTo-HTML -fragment

	}

#*************************AGENT VERSION CHECK ENDS HERE****************************

#*************************DUAL PATH AGENTS INFORMATION STARTS HERE*****************

if ($SCOM2012Version)
{
#Get All Non Dual Pathed Agents
#Get Dual Homing Agent Information
[void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
$DHMGName = [Microsoft.VisualBasic.Interaction]::InputBox("Dual Homing - Please enter the Legacy SCOM 2007 Management Group Name", "SCOM 2007 Management Group Name", "SCOM 2007 MG2")
$SearchPattern = '(' + $DHMGName + '\,)|(\,' + $DHMGName + '$)' 

#Get the agent class and the each object that is dual pathed
$MGIAgent = Get-SCClass -Name "Management.Group.Information.Class"
$objects = Get-SCOMMonitoringObject -class:$MGIAgent | Where-Object {(($_.InMaintenanceMode -eq $False) -and ($_.'[Management.Group.Information.Class].MGList'.value -notmatch $SearchPattern))}
$TotalAgentsMissingDH = ($Objects | Where-Object {(($_.InMaintenanceMode -eq $False) -and ($_.'[Management.Group.Information.Class].MGList'.value -notmatch $SearchPattern))}).Count

#Get Agent Information
$AgentInformation = Get-SCOMMonitoringObject -class:$MGIAgent | Where-Object {(($_.InMaintenanceMode -eq $False) -and ($_.'[Management.Group.Information.Class].MGList'.value -notmatch $SearchPattern))}
$duallinktomri = $AgentInformation

}
Elseif ($SCOM2007Version)
{
#Get All Non Dual Pathed Agents
#Get Dual Homing Agent Information
[void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
$DHMGName = [Microsoft.VisualBasic.Interaction]::InputBox("Dual Homing - Please enter the New SCOM 2012 Management Group Name", "SCOM 2012 Management Group Name", "SCOM 2012 MG")
$SearchPattern = '(' + $DHMGName + '\,)|(\,' + $DHMGName + '$)' 

#Get the Agent Class and each object detail
$MGIAgent = get-monitoringclass -name "Management.Group.Information.Class"
$objects = Get-MonitoringObject -monitoringclass:$MGIAgent | Where-Object {(($_.InMaintenanceMode -eq $False) -and ($_.'[Management.Group.Information.Class].MGList' -notmatch $SearchPattern))}
$TotalAgentsMissingDH =  ($Objects | Where-Object {(($_.InMaintenanceMode -eq $False) -and ($_.'[Management.Group.Information.Class].MGList' -notmatch $SearchPattern))}).Count

#Get Agent Information
$AgentInformation = Get-MonitoringObject -monitoringclass:$MGIAgent | Where-Object {(($_.InMaintenanceMode -eq $False) -and ($_.'[Management.Group.Information.Class].MGList' -notmatch $SearchPattern))}
$duallinktomri = $AgentInformation
}

if ($mriexists -eq $true){

#Link Output to MRI File and populate line for HTML File

$AgentTable = New-Object System.Data.DataTable "$AvailableTable"
$AgentTable.Columns.Add((New-Object System.Data.DataColumn ServerName,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn PatchList,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn ProxyingEnabled,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn AgentVersion,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn DualHome,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn DatePurchased,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn Country,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn Location,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn BillingStatus,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn CostCentre,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn ARNNumber,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn ARNDescriptionServiceName,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn SDCName,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn WorkloadType,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn WorkloadFunction,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn Status,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn Platform,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn HWManufacturer,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn HWModel,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn Classification,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn CPUNo,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn CPUSpeed,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn CPUType,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn Memory,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn HDNo,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn HDSize,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn RPERF,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn OperatingSystemType,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn OSVersion,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn OSRevision,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn SerialNo,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn AssetNo,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn Comments,([string])))

foreach($agent in $duallinktomri){
    $agtdata = $agent.displayname
    $agtdhdata = $agent.displayname.split('.')[0]
    $mridata = $mrifile | ? {$_.ServerName -match $agtdhdata}

    if ($SCOM2012Version)
    {
    #Get the agent class and the each object 
    $MSCAgent = Get-SCClass -name "Microsoft.SystemCenter.Agent"
    $PLObject = Get-SCOMMonitoringObject -class:$MSCAgent | Where-Object {($_.DisplayName -eq $agtdata)}
    $MGList = $agent.'[Management.Group.Information.Class].MGList'.Value
    $PLList = $PLObject.'[Microsoft.SystemCenter.HealthService].PatchList'.Value
    $ProxyingEnabled = $PLObject.'[Microsoft.SystemCenter.HealthService].ProxyingEnabled'.Value
    $AgentVersion = $PLObject.'[Microsoft.SystemCenter.HealthService].Version'.Value
    }
    Elseif ($SCOM2007Version)
    {
    #Get the Agent Class and each object detail
    $MSCAgent = get-monitoringclass -name "Microsoft.SystemCenter.Agent"
    $PLObject = Get-MonitoringObject -monitoringclass:$MSCAgent | Where-Object {($_.DisplayName -eq $agtdata)}
    $MGList = $agent.'[Management.Group.Information.Class].MGList'
    $PLList = $PLObject.'[Microsoft.SystemCenter.HealthService].PatchList'
    $ProxyingEnabled = $PLObject.'[Microsoft.SystemCenter.HealthService].ProxyingEnabled'
    $AgentVersion = $PLObject.'[Microsoft.SystemCenter.HealthService].Version'
    }
        $NewRow = $AgentTable.NewRow()
        $NewRow.ServerName=($agtdata)     
        $NewRow.PatchList=($PLList)
        $NewRow.ProxyingEnabled=($ProxyingEnabled)
        $NewRow.AgentVersion=($AgentVersion)
        $NewRow.DualHome=($MGList)
        $NewRow.DatePurchased=($mridata.DatePurchased).ToString()
        $NewRow.Country=($mridata.Country).ToString()
        $NewRow.Location=($mridata.Location).ToString()
        $NewRow.BillingStatus=($mridata.BillingStatus).ToString()
        $NewRow.CostCentre=($mridata.CostCentre).ToString()
        $NewRow.ARNNumber=($mridata.ARNNumber).ToString()
        $NewRow.ARNDescriptionServiceName=($mridata.ARNDescriptionServiceName).ToString()
        $NewRow.SDCName=($mridata.SDCName).ToString()
        $NewRow.WorkloadType=($mridata.WorkloadType).ToString()
        $NewRow.WorkloadFunction=($mridata.WorkloadFunction).ToString()
        $NewRow.Status=($mridata.Status).ToString()
        $NewRow.Platform=($mridata.Platform).ToString()
        $NewRow.HWManufacturer=($mridata.HWManufacturer).ToString()
        $NewRow.HWModel=($mridata.HWModel).ToString()
        $NewRow.Classification=($mridata.Classification).ToString()
        $NewRow.CPUNo=($mridata.CPUNo).ToString()
        $NewRow.CPUSpeed=($mridata.CPUSpeed).ToString()
        $NewRow.CPUType=($mridata.CPUType).ToString()
        $NewRow.Memory=($mridata.Memory).ToString()
        $NewRow.HDNo=($mridata.HDNo).ToString()
        $NewRow.HDSize=($mridata.HDSize).ToString()
        $NewRow.RPERF=($mridata.RPERF).ToString()
        $NewRow.OperatingSystemType=($mridata.OperatingSystemType).ToString()
        $NewRow.OSVersion=($mridata.OSVersion).ToString()
        $NewRow.OSRevision=($mridata.OSRevision).ToString()
        $NewRow.SerialNo=($mridata.SerialNo).ToString()
        $NewRow.AssetNo=($mridata.AssetNo).ToString()
        $NewRow.Comments=($mridata.Comments).ToString()
        $AgentTable.Rows.Add($NewRow)
	}

#Write to Report

	$ReportOutput +=  "<p><H2>Dual Pathing - Missing New Management Groups on Server:</H2></p>"
	$ReportOutput +=  "<p><H3>Dual Pathing Not Applied Count: $TotalAgentsMissingDH</H3></p>"
	$ReportOutput += $AgentTable | Sort-Object ServerName | Select ServerName,PatchList,ProxyingEnabled,AgentVersion,DualHome,DatePurchased,Country,Location,BillingStatus,CostCentre,ARNNumber,ARNDescriptionServiceName,SDCName,WorkloadType,WorkloadFunction,Status,Platform,HWManufacturer,HWModel,Classification,CPUNo,CPUSpeed,CPUType,Memory,HDNo,HDSize,RPERF,OperatingSystemType,OSVersion,OSRevision,SerialNo,AssetNo,Comments | ConvertTo-HTML -fragment

	}

if ($mriexists -eq $false){

#Link Output to MRI File and populate line for HTML File

$AgentTable = New-Object System.Data.DataTable "$AvailableTable"
$AgentTable.Columns.Add((New-Object System.Data.DataColumn DisplayName,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn PatchList,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn ProxyingEnabled,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn AgentVersion,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn DualHome,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn HealthState,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn AvailabilityLastModified,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn StateLastModified,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn InMaintenanceMode,([string])))

foreach($agent in $duallinktomri){
    $agtdata = $agent.DisplayName

    if ($SCOM2012Version)
    {
    #Get the agent class and the each object 
    $MSCAgent = Get-SCClass -name "Microsoft.SystemCenter.Agent"
    $PLObject = Get-SCOMMonitoringObject -class:$MSCAgent | Where-Object {($_.DisplayName -eq $agtdata)}
    $MGList = $agent.'[Management.Group.Information.Class].MGList'.Value
    $PLList = $PLObject.'[Microsoft.SystemCenter.HealthService].PatchList'.Value
    $ProxyingEnabled = $PLObject.'[Microsoft.SystemCenter.HealthService].ProxyingEnabled'.Value
    $AgentVersion = $PLObject.'[Microsoft.SystemCenter.HealthService].Version'.Value
    }
    Elseif ($SCOM2007Version)
    {
    #Get the Agent Class and each object detail
    $MSCAgent = get-monitoringclass -name "Microsoft.SystemCenter.Agent"
    $PLObject = Get-MonitoringObject -monitoringclass:$MSCAgent | Where-Object {($_.DisplayName -eq $agtdata)}
    $MGList = $agent.'[Management.Group.Information.Class].MGList'
    $PLList = $PLObject.'[Microsoft.SystemCenter.HealthService].PatchList'
    $ProxyingEnabled = $PLObject.'[Microsoft.SystemCenter.HealthService].ProxyingEnabled'
    $AgentVersion = $PLObject.'[Microsoft.SystemCenter.HealthService].Version'
    }

#Create HTML Output

        $NewRow = $AgentTable.NewRow()
        $NewRow.DisplayName=($agent.DisplayName).ToString()
        $NewRow.PatchList=($PLList)
        $NewRow.ProxyingEnabled=($ProxyingEnabled)
        $NewRow.AgentVersion=($AgentVersion)
        $NewRow.DualHome=($MGList)
        $NewRow.HealthState=($agent.HealthState).ToString()
        $NewRow.AvailabilityLastModified=($agent.AvailabilityLastModified).ToString()
        $NewRow.StateLastModified=($agent.StateLastModified).ToString()
        $NewRow.InMaintenanceMode=($agent.InMaintenanceMode).ToString()
        $AgentTable.Rows.Add($NewRow)
	}

#Write to Report

	$ReportOutput +=  "<p><H2>Dual Pathing - Missing New Management Groups on Server:</H2></p>"
	$ReportOutput +=  "<p><H3>Dual Pathing Not Applied Count: $TotalAgentsMissingDH</H3></p>"
	$ReportOutput += $AgentTable | Sort-Object ServerName | Select DisplayName,PatchList,ProxyingEnabled,AgentVersion,DualHome,HealthState,AvailabilityLastModified,StateLastModified,InMaintenanceMode | ConvertTo-HTML -fragment
	}

#*************************DUAL PATH AGENTS INFORMATION ENDS HERE*******************

#*************************ALERT ANALYSIS OVER LAST 24 HRS STARTS FROM HERE*********

if ($SCOM2012Version)
{
# Get all alerts for the last 24 Hours
write-host "Getting all alerts for the last 24 Hours" -ForegroundColor Yellow
$Date = Get-Date
$StartDate = Get-Date -Date $Date.adddays(-1) -Hour 12 -Minute 0 -Second 0
$EndDate = Get-Date -Date $Date -Hour 12 -Minute 0 -Second 0

$Alerts = Get-SCOMAlert -Criteria 'ResolutionState < "255"' | Where { $_.TimeRaised.ToLocalTime() -ge $StartDate -and $_.TimeRaised.ToLocalTime() -le $EndDate } 
$AlertComp = Get-SCOMAlert | Where { $_.TimeRaised.ToLocalTime() -ge $StartDate -and $_.TimeRaised.ToLocalTime() -le $EndDate } 

# Get alerts for last 24 hour Comparison Criteria needed for BEM Switch Evidence
write-host "Getting alerts for last 24 hours for BEM Switch" -ForegroundColor Yellow
$ReportOutput += "<h2>All Alerts in the last 24 hours Comparison Criteria needed for BEM Switch Evidence</h2>"
$ReportOutput += $AlertComp | Select TimeRaised,MonitoringObjectDisplayName,Name,Description,Priority,Severity,ID | Sort-object TimeRaised -desc | ConvertTo-HTML -fragment

# Get alerts for last 24 hours
write-host "Getting alerts for last 24 hours" -ForegroundColor Yellow
$ReportOutput += "<h2>Top 10 Alerts With Same Name - 24 hours</h2>"
$ReportOutput += $Alerts | Group-Object Name | Sort-object Count -desc | select-Object -first 10 Count, Name | ConvertTo-HTML -fragment

$ReportOutput += "<h2>Top 10 Repeating Alerts for last 24 hours</h2>"
$ReportOutput += $Alerts | Sort-Object -desc RepeatCount | select-Object -first 10 RepeatCount, Name, MonitoringObjectPath, Description | ConvertTo-HTML -fragment

# Get the Top 10 Unresolved alerts still in console and put them into report
write-host "Getting Top 10 Unresolved Alerts With Same Name for last 24 hours" -ForegroundColor Yellow 
$ReportOutput += "<h2>Top 10 Unresolved Alerts for last 24 hours</h2>"
$ReportOutput += $Alerts  | Group-Object Name | Sort-object Count -desc | select-Object -first 10 Count, Name | ConvertTo-HTML -fragment

# Get the Top 10 Repeating Alerts and put them into report
write-host "Getting Top 10 Repeating Alerts for last 24 hours" -ForegroundColor Yellow 
$ReportOutput += "<h2>Top 10 Repeating Alerts for last 24 hours</h2>"
$ReportOutput += $Alerts | Sort -desc RepeatCount | select-object –first 10 Name, RepeatCount, MonitoringObjectPath, Description | ConvertTo-HTML -fragment
}
Elseif ($SCOM2007Version)
{
# Get all alerts for the last 24 Hours
write-host "Getting all alerts for the last 24 Hours" -ForegroundColor Yellow
$Date = Get-Date
$StartDate = Get-Date -Date $Date.adddays(-1) -Hour 12 -Minute 0 -Second 0
$EndDate = Get-Date -Date $Date -Hour 12 -Minute 0 -Second 0

$Alerts = Get-Alert -Criteria 'ResolutionState < "255"' | Where { $_.TimeRaised.ToLocalTime() -ge $StartDate -and $_.TimeRaised.ToLocalTime() -le $EndDate } 
$AlertComp = Get-Alert | Where { $_.TimeRaised.ToLocalTime() -ge $StartDate -and $_.TimeRaised.ToLocalTime() -le $EndDate } 

# Get alerts for last 24 hour Comparison Criteria needed for BEM Switch Evidence
write-host "Getting alerts for last 24 hours for BEM Switch" -ForegroundColor Yellow
$ReportOutput += "<h2>All Alerts in the last 24 hours Comparison Criteria needed for BEM Switch Evidence</h2>"
$ReportOutput += $AlertComp | Select TimeRaised,MonitoringObjectDisplayName,Name,Description,Priority,Severity,ID | Sort-object TimeRaised -desc | ConvertTo-HTML -fragment

# Get alerts for last 24 hours
write-host "Getting alerts for last 24 hours" -ForegroundColor Yellow
$ReportOutput += "<h2>Top 10 Alerts With Same Name - 24 hours</h2>"
$ReportOutput += $Alerts | Group-Object Name | Sort-object Count -desc | select-Object -first 10 Count, Name | ConvertTo-HTML -fragment

$ReportOutput += "<h2>Top 10 Repeating Alerts for last 24 hours</h2>"
$ReportOutput += $Alerts | Sort-Object -desc RepeatCount | select-Object -first 10 RepeatCount, Name, MonitoringObjectPath, Description | ConvertTo-HTML -fragment

# Get the Top 10 Unresolved alerts still in console and put them into report
write-host "Getting Top 10 Unresolved Alerts With Same Name for last 24 hours" -ForegroundColor Yellow 
$ReportOutput += "<h2>Top 10 Unresolved Alerts for last 24 hours</h2>"
$ReportOutput += $Alerts  | Group-Object Name | Sort-object Count -desc | select-Object -first 10 Count, Name | ConvertTo-HTML -fragment

# Get the Top 10 Repeating Alerts and put them into report
write-host "Getting Top 10 Repeating Alerts for last 24 hours" -ForegroundColor Yellow 
$ReportOutput += "<h2>Top 10 Repeating Alerts for last 24 hours</h2>"
$ReportOutput += $Alerts | Sort -desc RepeatCount | select-object –first 10 Name, RepeatCount, MonitoringObjectPath, Description | ConvertTo-HTML -fragment
}

#*************************ALERT ANALYSIS OVER LAST 24 HRS ENDS FROM HERE***********

#*************************OUTPUT THE ENTIRE REPORT INFORMATION STARTS FROM HERE****

# Take all $ReportOutput and combine it with $Body to create completed HTML output
$Body = ConvertTo-HTML -head $Head -body "$ReportOutput"
$time = (Get-Date).ToString("yyyyMMddhh")
$Body | Out-File $filedir\$time.html

#*************************OUTPUT THE ENTIRE REPORT INFORMATION ENDS FROM HERE******