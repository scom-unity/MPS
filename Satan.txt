#*************************PRE-MIGRATION SCRIPT STARTS FROM HERE********************

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

#Temp Directory Check and Variable Setting
$filedir = "C:\TEMP\MRIFile"
$mrifldrexists = Test-Path -Path $filedir

if($mrifldrexists -eq $false)
	{
	New-Item -ItemType directory -Path $filedir
	}

#Load System Center Operations Manager module
if ($SCOM2012Version)
{
#Initialize SCOM snapin
Import-Module OperationsManager

#Get Management Group Name
$MGName = get-scommanagementserver | select ManagementGroup -unique

#Get HealthService Agent Information
$MSCAgent = Get-SCClass -name "Microsoft.SystemCenter.Agent"
$HSObjects = Get-SCOMMonitoringObject -class:$MSCAgent

#Get Dual Homing Agent Information
$MGIAgent = Get-SCClass -Name "Management.Group.Information.Class"
$DHObjects = Get-SCOMMonitoringObject -class:$MGIAgent 
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

#Get HealthService Agent Information
$MSCAgent = get-monitoringclass -name "Microsoft.SystemCenter.Agent"
$HSObjects = Get-MonitoringObject -monitoringclass:$MSCAgent

#Get Dual Homing Agent Information
$MGIAgent = get-monitoringclass -name "Management.Group.Information.Class"
$DHObjects = Get-MonitoringObject -monitoringclass:$MGIAgent
}

#Get Management Group Name

$MgName = $mgname.ManagementGroup.Name
$ReportOutput +=  "<p><H2>Management Group Name: $mgname</H2></p>"

#Agent Count in Management Group:
$agentcount = $HSObjects.count
$ReportOutput +=  "<p><H2>Agent Count in Management Group: $agentcount</H2></p>"
$ReportOutput +=  "<p><u><H1>Migration Readiness and Agent Integrity:</H1></u></p>"

#*************************SCRIPT VARIABLES ENDS FROM HERE**************************

#*************************COMBINE CLASS DATA STARTS FROM HERE**********************

#Construct Table for Output for HealthService Lookup

	#HSDataTable definition
	$hstable = New-Object System.Data.DataTable
	$hstable.Columns.Add("DisplayName", "System.String") | Out-Null
	$hstable.Columns.Add("NetBIOSName", "System.String") | Out-Null
	$hstable.Columns.Add("HealthState", "System.String") | Out-Null
	$hstable.Columns.Add("AvailabilityLastModified", "System.String") | Out-Null
	$hstable.Columns.Add("StateLastModified", "System.String") | Out-Null
	$hstable.Columns.Add("InMaintenanceMode", "System.String") | Out-Null
	$hstable.Columns.Add("PatchList", "System.String") | Out-Null
	$hstable.Columns.Add("ProxyingEnabled", "System.String") | Out-Null
	$hstable.Columns.Add("AgentVersion", "System.String") | Out-Null
	$hstable.Columns.Add("ID", "System.String") | Out-Null

#Construct Table for Output for Dual Homed Lookup

	#DHDataTable definition
	$dhtable = New-Object System.Data.DataTable
	$dhtable.Columns.Add("DisplayName", "System.String") | Out-Null
	$dhtable.Columns.Add("MGList", "System.String") | Out-Null
	$dhtable.Columns.Add("ID", "System.String") | Out-Null

#Get HealthService and Dual Homed Objects for Report

if ($SCOM2012Version)
	{
	$HSObjects | ForEach-Object {
    	$HSAgent = New-Object system.object
    	$HSAgent | Add-Member -Type NoteProperty -Name 'DisplayName' -Value $_.displayname -Force
    	$HSAgent | Add-Member -Type NoteProperty -Name 'NetBIOSName' -Value $_.displayname.split('.')[0] -Force
    	$HSAgent | Add-Member -Type NoteProperty -Name 'HealthState' -Value $_.HealthState -Force
    	$HSAgent | Add-Member -Type NoteProperty -Name 'AvailabilityLastModified' -Value $_.AvailabilityLastModified -Force
    	$HSAgent | Add-Member -Type NoteProperty -Name 'StateLastModified' -Value $_.StateLastModified -Force
    	$HSAgent | Add-Member -Type NoteProperty -Name 'InMaintenanceMode' -Value $_.InMaintenanceMode -Force
	$HSAgent | Add-Member -Type NoteProperty -Name 'PatchList' -Value $_.'[Microsoft.SystemCenter.HealthService].PatchList'.Value -Force
    	$HSAgent | Add-Member -Type NoteProperty -Name 'ProxyingEnabled' -Value $_.'[Microsoft.SystemCenter.HealthService].ProxyingEnabled'.Value -Force
    	$HSAgent | Add-Member -Type NoteProperty -Name 'AgentVersion' -Value $_.'[Microsoft.SystemCenter.HealthService].Version'.Value -Force
    	$HSAgent | Add-Member -Type NoteProperty -Name 'ID' -Value $_.ID -Force

#Insert detail of HealthService into HSDataTable

        $hsRow = $hstable.NewRow()
        $hsRow.DisplayName = $HSAgent.DisplayName
        $hsRow.NetBIOSName = $HSAgent.NetBIOSName
        $hsRow.HealthState = $HSAgent.HealthState
        $hsRow.AvailabilityLastModified = $HSAgent.AvailabilityLastModified
        $hsRow.StateLastModified = $HSAgent.StateLastModified
        $hsRow.InMaintenanceMode = $HSAgent.InMaintenanceMode
        $hsRow.PatchList = $HSAgent.PatchList
        $hsRow.ProxyingEnabled = $HSAgent.ProxyingEnabled
        $hsRow.AgentVersion = $HSAgent.AgentVersion
        $hsRow.ID = $HSAgent.ID
        $hstable.Rows.Add($hsRow)
	}
	$DHObjects | ForEach-Object {
    	$DHAgent = New-Object system.object
    	$DHAgent | Add-Member -Type NoteProperty -Name 'DisplayName' -Value $_.displayname -Force
	$DHAgent | Add-Member -Type NoteProperty -Name 'MGList' -Value $_.'[Management.Group.Information.Class].MGList'.Value -Force
    	$DHAgent | Add-Member -Type NoteProperty -Name 'ID' -Value $_.ID -Force

#Insert detail of Management Group Dual Home Info into HSDataTable

        $dhRow = $dhtable.NewRow()
        $dhRow.DisplayName = $DHAgent.DisplayName
        $dhRow.MGList = $DHAgent.MGList
        $dhRow.ID = $DHAgent.ID
        $dhtable.Rows.Add($dhRow)
	}
	}
	Elseif ($SCOM2007Version)
	{
	$HSObjects | ForEach-Object {
    	$HSAgent = New-Object system.object
    	$HSAgent | Add-Member -Type NoteProperty -Name 'DisplayName' -Value $_.displayname -Force
    	$HSAgent | Add-Member -Type NoteProperty -Name 'NetBIOSName' -Value $_.displayname.split('.')[0] -Force
    	$HSAgent | Add-Member -Type NoteProperty -Name 'HealthState' -Value $_.HealthState -Force
    	$HSAgent | Add-Member -Type NoteProperty -Name 'AvailabilityLastModified' -Value $_.AvailabilityLastModified -Force
    	$HSAgent | Add-Member -Type NoteProperty -Name 'StateLastModified' -Value $_.StateLastModified -Force
    	$HSAgent | Add-Member -Type NoteProperty -Name 'InMaintenanceMode' -Value $_.InMaintenanceMode -Force
	$HSAgent | Add-Member -Type NoteProperty -Name 'PatchList' -Value $_.'[Microsoft.SystemCenter.HealthService].PatchList' -Force
    	$HSAgent | Add-Member -Type NoteProperty -Name 'ProxyingEnabled' -Value $_.'[Microsoft.SystemCenter.HealthService].ProxyingEnabled' -Force
    	$HSAgent | Add-Member -Type NoteProperty -Name 'AgentVersion' -Value $_.'[Microsoft.SystemCenter.HealthService].Version' -Force
    	$HSAgent | Add-Member -Type NoteProperty -Name 'ID' -Value $_.ID -Force

#Insert detail of HealthService into HSDataTable

        $hsRow = $hstable.NewRow()
        $hsRow.DisplayName = $HSAgent.DisplayName
        $hsRow.NetBIOSName = $HSAgent.NetBIOSName
        $hsRow.HealthState = $HSAgent.HealthState
        $hsRow.AvailabilityLastModified = $HSAgent.AvailabilityLastModified
        $hsRow.StateLastModified = $HSAgent.StateLastModified
        $hsRow.InMaintenanceMode = $HSAgent.InMaintenanceMode
        $hsRow.PatchList = $HSAgent.PatchList
        $hsRow.ProxyingEnabled = $HSAgent.ProxyingEnabled
        $hsRow.AgentVersion = $HSAgent.AgentVersion
        $hsRow.ID = $HSAgent.ID
        $hstable.Rows.Add($hsRow)
	}
	$DHObjects | ForEach-Object {
    	$DHAgent = New-Object system.object
    	$DHAgent | Add-Member -Type NoteProperty -Name 'DisplayName' -Value $_.displayname -Force
	$DHAgent | Add-Member -Type NoteProperty -Name 'MGList' -Value $_.'[Management.Group.Information.Class].MGList' -Force
    	$DHAgent | Add-Member -Type NoteProperty -Name 'ID' -Value $_.ID -Force

#Insert detail of Management Group Dual Home Info into HSDataTable
	
        $dhRow = $dhtable.NewRow()
        $dhRow.DisplayName = $DHAgent.DisplayName
        $dhRow.MGList = $DHAgent.MGList
        $dhRow.ID = $DHAgent.ID
        $dhtable.Rows.Add($dhRow)
	}
	}

#*************************FILE PREPARATION STARTS FROM HERE************************

# Create header for HTML Report
$Head = "<style>"
$Head +="BODY{background-color:#CCCCCC;font-family:Verdana,sans-serif; font-size: x-small;}"
$Head +="TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse; width: 100%;}"
$Head +="TH{border-width: 1px;padding: 0px;border-style: solid;border-color: black;background-color:green;color:white;padding: 5px; font-weight: bold;text-align:left;}"
$Head +="TD{border-width: 1px;padding: 0px;border-style: solid;border-color: black;background-color:#F0F0F0; padding: 2px;}"
$Head +="</style>"

#Export Tables for Join to Master Table

$DHExport = $dhtable | Export-CSV -Path $filedir"\dh_file_raw.csv" -NoTypeInformation
$HSExport = $hstable | Export-CSV -Path $filedir"\hs_file_raw.csv" -NoTypeInformation

#Check if HealthService and Dual Homed files exist

$dhexists = Test-Path -Path $filedir"\dh_file_raw.csv"
$hsexists = Test-Path -Path $filedir"\hs_file_raw.csv"

#Load Dual Home CSV file into Memory

if($dhexists -eq $true){

$lookupdhdb = Get-ChildItem -Path $filedir -Filter dh_File_Raw.csv -Recurse
$dhfiledblocation = $lookupdhdb.FullName
$dhfile = Import-Csv $dhfiledblocation
}

#Load HealthService CSV file into Memory

if($hsexists -eq $true){

$lookuphsdb = Get-ChildItem -Path $filedir -Filter hs_File_Raw.csv -Recurse
$hsfiledblocation = $lookuphsdb.FullName
$hsfile = Import-Csv $hsfiledblocation
}

#Join all Files into Migration Database

function AddItemProperties($item, $properties, $output)
{
    if($item -ne $null)
    {
        foreach($property in $properties)
        {
            $propertyHash =$property -as [hashtable]
            if($propertyHash -ne $null)
            {
                $hashName=$propertyHash[“name”] -as [string]
                if($hashName -eq $null)
                {
                    throw “there should be a string Name”  
                }
         
                $expression=$propertyHash[“expression”] -as [scriptblock]
                if($expression -eq $null)
                {
                    throw “there should be a ScriptBlock Expression”  
                }
         
                $_=$item
                $expressionValue=& $expression
         
                $output | add-member -MemberType “NoteProperty” -Name $hashName -Value $expressionValue
            }
            else
            {
                # .psobject.Properties allows you to list the properties of any object, also known as “reflection”
                foreach($itemProperty in $item.psobject.Properties)
                {
                    if ($itemProperty.Name -like $property)
                    {
                        $output | add-member -MemberType “NoteProperty” -Name $itemProperty.Name -Value $itemProperty.Value
                    }
                }
            }
        }
    }
}

    
function WriteJoinObjectOutput($leftItem, $rightItem, $leftProperties, $rightProperties, $Type)
{
    $output = new-object psobject

    if($Type -eq “AllInRight”)
    {
        # This mix of rightItem with LeftProperties and vice versa is due to
        # the switch of Left and Right arguments for AllInRight
        AddItemProperties $rightItem $leftProperties $output
        AddItemProperties $leftItem $rightProperties $output
    }
    else
    {
        AddItemProperties $leftItem $leftProperties $output
        AddItemProperties $rightItem $rightProperties $output
    }
    $output
}

#Join HSFile and DHFile as a reference database for the migration scripts

<#
.Synopsis
   Joins two lists of objects
.DESCRIPTION
   Joins two lists of objects
.EXAMPLE
   Join-Object $a $b “Id” (“Name”,”Salary”)
#>
function Join-Object
{
    [CmdletBinding()]
    [OutputType([int])]
    Param
    (
        # List to join with $Right
        [Parameter(Mandatory=$true,
                   Position=0)]
        [object[]]
        $Left,

        # List to join with $Left
        [Parameter(Mandatory=$true,
                   Position=1)]
        [object[]]
        $Right,

        # Condition in which an item in the left matches an item in the right
        # typically something like: {$args[0].Id -eq $args[1].Id}
        [Parameter(Mandatory=$true,
                   Position=2)]
        [scriptblock]
        $Where,

        # Properties from $Left we want in the output.
        # Each property can:
        # – Be a plain property name like “Name”
        # – Contain wildcards like “*”
        # – Be a hashtable like @{Name=”Product Name”;Expression={$_.Name}}. Name is the output property name
        #   and Expression is the property value. The same syntax is available in select-object and it is 
        #   important for join-object because joined lists could have a property with the same name
        [Parameter(Mandatory=$true,
                   Position=3)]
        [object[]]
        $LeftProperties,

        # Properties from $Right we want in the output.
        # Like LeftProperties, each can be a plain name, wildcard or hashtable. See the LeftProperties comments.
        [Parameter(Mandatory=$true,
                   Position=4)]
        [object[]]
        $RightProperties,

        # Type of join. 
        #   AllInLeft will have all elements from Left at least once in the output, and might appear more than once
        # if the where clause is true for more than one element in right, Left elements with matches in Right are 
        # preceded by elements with no matches. This is equivalent to an outer left join (or simply left join) 
        # SQL statement.
        #  AllInRight is similar to AllInLeft.
        #  OnlyIfInBoth will cause all elements from Left to be placed in the output, only if there is at least one
        # match in Right. This is equivalent to a SQL inner join (or simply join) statement.
        #  AllInBoth will have all entries in right and left in the output. Specifically, it will have all entries
        # in right with at least one match in left, followed by all entries in Right with no matches in left, 
        # followed by all entries in Left with no matches in Right.This is equivallent to a SQL full join.
        [Parameter(Mandatory=$false,
                   Position=5)]
        [ValidateSet(“AllInLeft”,”OnlyIfInBoth”,”AllInBoth”, “AllInRight”)]
        [string]
        $Type=”OnlyIfInBoth”
    )

    Begin
    {
        # a list of the matches in right for each object in left
        $leftMatchesInRight = new-object System.Collections.ArrayList

        # the count for all matches  
        $rightMatchesCount = New-Object “object[]” $Right.Count

        for($i=0;$i -lt $Right.Count;$i++)
        {
            $rightMatchesCount[$i]=0
        }
    }

    Process
    {
        if($Type -eq “AllInRight”)
        {
            # for AllInRight we just switch Left and Right
            $aux = $Left
            $Left = $Right
            $Right = $aux
        }

        # go over items in $Left and produce the list of matches
        foreach($leftItem in $Left)
        {
            $leftItemMatchesInRight = new-object System.Collections.ArrayList
            $null = $leftMatchesInRight.Add($leftItemMatchesInRight)

            for($i=0; $i -lt $right.Count;$i++)
            {
                $rightItem=$right[$i]

                if($Type -eq “AllInRight”)
                {
                    # For AllInRight, we want $args[0] to refer to the left and $args[1] to refer to right,
                    # but since we switched left and right, we have to switch the where arguments
                    $whereLeft = $rightItem
                    $whereRight = $leftItem
                }
                else
                {
                    $whereLeft = $leftItem
                    $whereRight = $rightItem
                }

                if(Invoke-Command -ScriptBlock $where -ArgumentList $whereLeft,$whereRight)
                {
                    $null = $leftItemMatchesInRight.Add($rightItem)
                    $rightMatchesCount[$i]++
                }
            
            }
        }

        # go over the list of matches and produce output
        for($i=0; $i -lt $left.Count;$i++)
        {
            $leftItemMatchesInRight=$leftMatchesInRight[$i]
            $leftItem=$left[$i]
                               
            if($leftItemMatchesInRight.Count -eq 0)
            {
                if($Type -ne “OnlyIfInBoth”)
                {
                    WriteJoinObjectOutput $leftItem  $null  $LeftProperties  $RightProperties $Type
                }

                continue
            }

            foreach($leftItemMatchInRight in $leftItemMatchesInRight)
            {
                WriteJoinObjectOutput $leftItem $leftItemMatchInRight  $LeftProperties  $RightProperties $Type
            }
        }
    }

    End
    {
        #produce final output for members of right with no matches for the AllInBoth option
        if($Type -eq “AllInBoth”)
        {
            for($i=0; $i -lt $right.Count;$i++)
            {
                $rightMatchCount=$rightMatchesCount[$i]
                if($rightMatchCount -eq 0)
                {
                    $rightItem=$Right[$i]
                    WriteJoinObjectOutput $null $rightItem $LeftProperties $RightProperties $Type
                }
            }
        }
    }
}

#Combine DualHome and HealthState

$HSDHDatabase = Join-Object -Left $hsfile -Right $dhfile -Where {$args[0].DisplayName -eq $args[1].DisplayName } –LeftProperties * –RightProperties "MGList" -Type OnlyIfInBoth 

$HSDHExport = $HSDHDatabase | Export-CSV -Path $filedir"\hsdh_file_raw.csv" -NoTypeInformation

#Load HSDH CSV file into Memory

$lookuphsdhdb = Get-ChildItem -Path $filedir -Filter hsdh_File_Raw.csv -Recurse
$hsdhfiledblocation = $lookuphsdhdb.FullName
$hsdhdbfile = Import-Csv $hsdhfiledblocation

#Combine DualHome and HealthState and MRI to make Migration Database Source

#Check if MRI DB file exists

$mriexists = Test-Path -Path $filedir"\MRI_File.csv"

#Replace Headings

if($mriexists -eq $true){

$mrifileraw = Get-ChildItem -Path $filedir -Filter MRI_File.csv -Recurse
$filedblocationraw = $mrifileraw.FullName
$fileconvert = Get-Content -path $filedblocationraw
$fileconvert[0] = $fileconvert[0].replace($fileconvert[0], "ServerName,DatePurchased,Country,Location,BillingStatus,CostCentre,ARNNumber,ARNDescriptionServiceName,SDCName,WorkloadType,WorkloadFunction,Status,Platform,HWManufacturer,HWModel,Classification,CPUNo,CPUSpeed,CPUType,Memory,HDNo,HDSize,RPERF,OperatingSystemType,OSVersion,OSRevision,SerialNo,AssetNo,Comments")
Set-Content -Path $filedir"\mri_file_raw.csv" -Value $fileconvert

#Load MRI CSV file into Memory and populate HTML file

$lookupdb = Get-ChildItem -Path $filedir -Filter MRI_File_Raw.csv -Recurse
$filedblocation = $lookupdb.FullName
$mrifile = Import-Csv $filedblocation

$MIGDatabase = Join-Object -Left $hsdhdbfile -Right $mrifile -Where {$args[0].NetBIOSName -eq $args[1].ServerName } –LeftProperties * –RightProperties * -Type OnlyIfInBoth 

$MIGExport = $MIGDatabase | Export-CSV -Path $filedir"\MIG_file_raw.csv" -NoTypeInformation

#Load MIG CSV file into Memory

$lookupMIGdb = Get-ChildItem -Path $filedir -Filter MIG_File_Raw.csv -Recurse
$MIGfiledblocation = $lookupMIGdb.FullName
$MIGdbfile = Import-Csv $MIGfiledblocation

}

#************************FILE PREPARATION ENDS FROM HERE**************************

#************************AGENT INFORMATION STARTS FROM HERE***********************

if ($SCOM2012Version)
{
#Get All Grey Agents
$greylinktomri = $HSObjects | Where-Object {($_.IsAvailable -eq $false) -and (!($_.HealthState -eq "Uninitialized")) -and ($_.InMaintenanceMode -eq $False)}
$TotalAgentsinGreyStateCount = ($HSObjects | Where-Object {($_.IsAvailable -eq $false) -and (!($_.HealthState -eq "Uninitialized")) -and ($_.InMaintenanceMode -eq $False)} ).Count
}
Elseif ($SCOM2007Version)
{
#Get All Grey Agents
$greylinktomri = $HSObjects | Where-Object {($_.IsAvailable -eq $false) -and (!($_.HealthState -eq "Uninitialized")) -and ($_.InMaintenanceMode -eq $False)}
$TotalAgentsinGreyStateCount = ($HSObjects | Where-Object {($_.IsAvailable -eq $false) -and (!($_.HealthState -eq "Uninitialized")) -and ($_.InMaintenanceMode -eq $False)} ).Count
}

#Output dependent on MRI DB file being available

if ($mriexists -eq $true){

#Link Output to MRI File and populate line for HTML File

$AgentTable = New-Object System.Data.DataTable "$AvailableTable"
$AgentTable.Columns.Add((New-Object System.Data.DataColumn ServerName,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn PatchList,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn ProxyingEnabled,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn AgentVersion,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn MGList,([string])))
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

foreach($gagent in $greylinktomri){
    $gagtdata = $gagent.displayname.split('.')[0]
    $mridata = $migdbfile | ? {$_.ServerName -match $gagtdata}

#Create HTML Output

        $NewRow = $AgentTable.NewRow()
        $NewRow.ServerName=($gagtdata)
        $NewRow.PatchList=($mridata.PatchList).ToString()
        $NewRow.ProxyingEnabled=($mridata.ProxyingEnabled).ToString()
        $NewRow.AgentVersion=($mridata.AgentVersion).ToString()
        $NewRow.MGList=($mridata.MGList).ToString()
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
	$ReportOutput += $AgentTable | Sort-Object ServerName | Select ServerName,PatchList,ProxyingEnabled,AgentVersion,MGList,DatePurchased,Country,Location,BillingStatus,CostCentre,ARNNumber,ARNDescriptionServiceName,SDCName,WorkloadType,WorkloadFunction,Status,Platform,HWManufacturer,HWModel,Classification,CPUNo,CPUSpeed,CPUType,Memory,HDNo,HDSize,RPERF,OperatingSystemType,OSVersion,OSRevision,SerialNo,AssetNo,Comments | ConvertTo-HTML -fragment

	}

if ($mriexists -eq $false){

#Link Output to MRI File and populate line for HTML File

$AgentTable = New-Object System.Data.DataTable "$AvailableTable"
$AgentTable.Columns.Add((New-Object System.Data.DataColumn DisplayName,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn PatchList,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn ProxyingEnabled,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn AgentVersion,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn MGList,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn HealthState,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn AvailabilityLastModified,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn StateLastModified,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn InMaintenanceMode,([string])))

foreach($gagent in $greylinktomri){
    $gagtdata = $gagent.displayname
    $hsdhdata = $hsdhdbfile | ? {$_.DisplayName -match $gagtdata}

#Create HTML Output

        $NewRow = $AgentTable.NewRow()
        $NewRow.DisplayName=($hsdhdata.DisplayName).ToString()
        $NewRow.PatchList=($hsdhdata.PatchList).ToString()
        $NewRow.ProxyingEnabled=($hsdhdata.ProxyingEnabled).ToString()
        $NewRow.AgentVersion=($hsdhdata.AgentVersion).ToString()
        $NewRow.MGList=($hsdhdata.MGList).ToString()
        $NewRow.HealthState=($hsdhdata.HealthState).ToString()
        $NewRow.AvailabilityLastModified=($hsdhdata.AvailabilityLastModified).ToString()
        $NewRow.StateLastModified=($hsdhdata.StateLastModified).ToString()
        $NewRow.InMaintenanceMode=($hsdhdata.InMaintenanceMode).ToString()
        $AgentTable.Rows.Add($NewRow)
	}

#Write to Report 

	$ReportOutput +=  "<p><H2>Grey Agent Information:</H2></p>" 
	$ReportOutput +=  "<p><H3>Grey Agent Count: $TotalAgentsinGreyStateCount</H3></p>"
	$ReportOutput += $AgentTable | Sort-Object ServerName | Select DisplayName,PatchList,ProxyingEnabled,AgentVersion,MGList,HealthState,AvailabilityLastModified,StateLastModified,InMaintenanceMode | ConvertTo-HTML -fragment

	}

#*************************AGENT SECTION ENDS HERE**********************************

#*************************AGENT PATCH COMPLIANCE STARTS HERE***********************

if ($SCOM2012Version)
{
#Get All Agents that are not SCOM 2012 R2 UR9
$patchlinktomri = $HSObjects | Where-Object {($_.'[Microsoft.SystemCenter.HealthService].PatchList'.Value -notmatch ".*UR(9|\d{2,3}).*")-and ($_.InMaintenanceMode -eq $False)}
$TotalAgentsMissingPatch = ($HSObjects | Where-Object {($_.'[Microsoft.SystemCenter.HealthService].PatchList'.Value -notmatch ".*UR(9|\d{2,3}).*")-and ($_.InMaintenanceMode -eq $False)} ).Count
}
Elseif ($SCOM2007Version)
{
#Get All Agents that are not SCOM 2012 R2 UR9
$patchlinktomri = $HSObjects | Where-Object {($_.'[Microsoft.SystemCenter.HealthService].PatchList' -notmatch ".*UR(9|\d{2,3}).*")-and ($_.InMaintenanceMode -eq $False)}
$TotalAgentsMissingPatch = ($HSObjects | Where-Object {($_.'[Microsoft.SystemCenter.HealthService].PatchList' -notmatch ".*UR(9|\d{2,3}).*")-and ($_.InMaintenanceMode -eq $False)} ).Count

}

#Output dependent on MRI DB file being available

if ($mriexists -eq $true){

#Link Output to MRI File and populate line for HTML File

$AgentTable = New-Object System.Data.DataTable "$AvailableTable"
$AgentTable.Columns.Add((New-Object System.Data.DataColumn ServerName,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn PatchList,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn ProxyingEnabled,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn AgentVersion,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn MGList,([string])))
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

foreach($pagent in $patchlinktomri){
    $pagtdata = $pagent.displayname.split('.')[0]
    $mridata = $migdbfile | ? {$_.ServerName -match $pagtdata}

#Create HTML Output

        $NewRow = $AgentTable.NewRow()
        $NewRow.ServerName=($pagtdata)
        $NewRow.PatchList=($mridata.PatchList).ToString()
        $NewRow.ProxyingEnabled=($mridata.ProxyingEnabled).ToString()
        $NewRow.AgentVersion=($mridata.AgentVersion).ToString()
        $NewRow.MGList=($mridata.MGList).ToString()
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
	$ReportOutput += $AgentTable | Sort-Object ServerName | Select ServerName,PatchList,ProxyingEnabled,AgentVersion,MGList,DatePurchased,Country,Location,BillingStatus,CostCentre,ARNNumber,ARNDescriptionServiceName,SDCName,WorkloadType,WorkloadFunction,Status,Platform,HWManufacturer,HWModel,Classification,CPUNo,CPUSpeed,CPUType,Memory,HDNo,HDSize,RPERF,OperatingSystemType,OSVersion,OSRevision,SerialNo,AssetNo,Comments | ConvertTo-HTML -fragment

	}

if ($mriexists -eq $false){

#Link Output to MRI File and populate line for HTML File

$AgentTable = New-Object System.Data.DataTable "$AvailableTable"
$AgentTable.Columns.Add((New-Object System.Data.DataColumn DisplayName,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn PatchList,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn ProxyingEnabled,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn AgentVersion,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn MGList,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn HealthState,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn AvailabilityLastModified,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn StateLastModified,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn InMaintenanceMode,([string])))

foreach($pagent in patchlinktomri){
    $pagtdata = $pagent.displayname
    $hsdhdata = $hsdhdbfile | ? {$_.DisplayName -match $pagtdata}

#Create HTML Output

        $NewRow = $AgentTable.NewRow()
        $NewRow.DisplayName=($hsdhdata.DisplayName).ToString()
        $NewRow.PatchList=($hsdhdata.PatchList).ToString()
        $NewRow.ProxyingEnabled=($hsdhdata.ProxyingEnabled).ToString()
        $NewRow.AgentVersion=($hsdhdata.AgentVersion).ToString()
        $NewRow.MGList=($hsdhdata.MGList).ToString()
        $NewRow.HealthState=($hsdhdata.HealthState).ToString()
        $NewRow.AvailabilityLastModified=($hsdhdata.AvailabilityLastModified).ToString()
        $NewRow.StateLastModified=($hsdhdata.StateLastModified).ToString()
        $NewRow.InMaintenanceMode=($hsdhdata.InMaintenanceMode).ToString()
        $AgentTable.Rows.Add($NewRow)
	}

#Write to Report 

	$ReportOutput +=  "<p><H2>Compliance - Missing Approved Patch Level on Servers:</H2></p>"
	$ReportOutput +=  "<p><H3>Missing Approved Patch Level Count: $TotalAgentsMissingPatch</H3></p>"
	$ReportOutput += $AgentTable | Sort-Object ServerName | Select DisplayName,PatchList,ProxyingEnabled,AgentVersion,MGList,HealthState,AvailabilityLastModified,StateLastModified,InMaintenanceMode | ConvertTo-HTML -fragment

	}

#*************************AGENT PATCH COMPLIANCE ENDS HERE*************************

#*************************AGENT VERSION CHECK STARTS HERE**************************

if ($SCOM2012Version)
{
#Get All Versions that are not SCOM 2012 R2 UR9 Agents
$versionlinktomri = $HSObjects | Where-Object {($_.'[Microsoft.SystemCenter.HealthService].Version'.Value -lt "7.1")-and ($_.InMaintenanceMode -eq $False)}
$TotalAgentsVersionCheck = ($HSObjects| Where-Object {($_.'[Microsoft.SystemCenter.HealthService].Version'.Value -lt "7.1")-and ($_.InMaintenanceMode -eq $False)} ).Count
}
Elseif ($SCOM2007Version)
{
#Get All Versions that are not SCOM 2012 R2 UR9 Agents
$versionlinktomri = $HSObjects | Where-Object {($_.'[Microsoft.SystemCenter.HealthService].Version' -lt "7.1")-and ($_.InMaintenanceMode -eq $False)}
$TotalAgentsVersionCheck = ($HSObjects | Where-Object {($_.'[Microsoft.SystemCenter.HealthService].Version' -lt "7.1")-and ($_.InMaintenanceMode -eq $False)} ).Count

}

#Output dependent on MRI DB file being available

if ($mriexists -eq $true){

#Link Output to MRI File and populate line for HTML File

$AgentTable = New-Object System.Data.DataTable "$AvailableTable"
$AgentTable.Columns.Add((New-Object System.Data.DataColumn ServerName,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn PatchList,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn ProxyingEnabled,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn AgentVersion,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn MGList,([string])))
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

foreach($vagent in $versionlinktomri){
    $vagtdata = $vagent.displayname.split('.')[0]
    $mridata = $migdbfile | ? {$_.ServerName -match $vagtdata}

#Create HTML Output

        $NewRow = $AgentTable.NewRow()
        $NewRow.ServerName=($vagtdata)
        $NewRow.PatchList=($mridata.PatchList).ToString()
        $NewRow.ProxyingEnabled=($mridata.ProxyingEnabled).ToString()
        $NewRow.AgentVersion=($mridata.AgentVersion).ToString()
        $NewRow.MGList=($mridata.MGList).ToString()
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
	$ReportOutput += $AgentTable | Sort-Object ServerName | Select ServerName,PatchList,ProxyingEnabled,AgentVersion,MGList,DatePurchased,Country,Location,BillingStatus,CostCentre,ARNNumber,ARNDescriptionServiceName,SDCName,WorkloadType,WorkloadFunction,Status,Platform,HWManufacturer,HWModel,Classification,CPUNo,CPUSpeed,CPUType,Memory,HDNo,HDSize,RPERF,OperatingSystemType,OSVersion,OSRevision,SerialNo,AssetNo,Comments | ConvertTo-HTML -fragment

	}

if ($mriexists -eq $false){

#Link Output to MRI File and populate line for HTML File

$AgentTable = New-Object System.Data.DataTable "$AvailableTable"
$AgentTable.Columns.Add((New-Object System.Data.DataColumn DisplayName,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn PatchList,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn ProxyingEnabled,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn AgentVersion,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn MGList,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn HealthState,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn AvailabilityLastModified,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn StateLastModified,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn InMaintenanceMode,([string])))

foreach($vagent in $versionlinktomri){
    $vagtdata = $vagent.displayname
    $hsdhdata = $hsdhdbfile | ? {$_.DisplayName -match $vagtdata}

#Create HTML Output

        $NewRow = $AgentTable.NewRow()
        $NewRow.DisplayName=($hsdhdata.DisplayName).ToString()
        $NewRow.PatchList=($hsdhdata.PatchList).ToString()
        $NewRow.ProxyingEnabled=($hsdhdata.ProxyingEnabled).ToString()
        $NewRow.AgentVersion=($hsdhdata.AgentVersion).ToString()
        $NewRow.MGList=($hsdhdata.MGList).ToString()
        $NewRow.HealthState=($hsdhdata.HealthState).ToString()
        $NewRow.AvailabilityLastModified=($hsdhdata.AvailabilityLastModified).ToString()
        $NewRow.StateLastModified=($hsdhdata.StateLastModified).ToString()
        $NewRow.InMaintenanceMode=($hsdhdata.InMaintenanceMode).ToString()
        $AgentTable.Rows.Add($NewRow)
	}

#Write to Report 

	$ReportOutput +=  "<p><H2>Agents Requiring Upgrade:</H2></p>"
	$ReportOutput +=  "<p><H3>Agents Requiring Upgrade Count: $TotalAgentsVersionCheck</H3></p>"
	$ReportOutput += $AgentTable | Sort-Object ServerName | Select DisplayName,PatchList,ProxyingEnabled,AgentVersion,MGList,HealthState,AvailabilityLastModified,StateLastModified,InMaintenanceMode | ConvertTo-HTML -fragment
	}

#*************************AGENT VERSION CHECK ENDS HERE****************************

#*************************DUAL PATH AGENTS INFORMATION STARTS HERE*****************

#Get Legacy or New Management Group


if ($SCOM2012Version)
{
#Get All Non Dual Pathed Agents
#Get Dual Homing Agent Information
$DHMGName = Read-Host "Dual Homing - Please enter the Legacy SCOM 2007 Management Group Name"
$SearchPattern = '(' + $DHMGName + '\,)|(\,' + $DHMGName + '$)' 

#Get the agent class and the each object that is dual pathed
$NonDHAgents = $DHObjects | Where-Object {(($_.InMaintenanceMode -eq $False) -and ($_.'[Management.Group.Information.Class].MGList'.value -notmatch $SearchPattern))}
$TotalAgentsMissingDH = ($NonDHAgents | Where-Object {(($_.InMaintenanceMode -eq $False) -and ($_.'[Management.Group.Information.Class].MGList'.value -notmatch $SearchPattern))}).Count

#Get Agent Information
$duallinktomri = $NonDHAgents

}
Elseif ($SCOM2007Version)
{
#Get All Non Dual Pathed Agents
#Get Dual Homing Agent Information
$DHMGName = Read-Host "Dual Homing - Please enter the Legacy SCOM 2007 Management Group Name"
$SearchPattern = '(' + $DHMGName + '\,)|(\,' + $DHMGName + '$)' 

#Get the Agent Class and each object detail
$NonDHAgents = $DHObjects | Where-Object {(($_.InMaintenanceMode -eq $False) -and ($_.'[Management.Group.Information.Class].MGList' -notmatch $SearchPattern))}
$TotalAgentsMissingDH =  ($NonDHAgents | Where-Object {(($_.InMaintenanceMode -eq $False) -and ($_.'[Management.Group.Information.Class].MGList' -notmatch $SearchPattern))}).Count

#Get Agent Information
$duallinktomri = $NonDHAgents
}

#Output dependent on MRI DB file being available

if ($mriexists -eq $true){

#Link Output to MRI File and populate line for HTML File

$AgentTable = New-Object System.Data.DataTable "$AvailableTable"
$AgentTable.Columns.Add((New-Object System.Data.DataColumn ServerName,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn PatchList,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn ProxyingEnabled,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn AgentVersion,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn MGList,([string])))
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

foreach($dagent in $duallinktomri){
    $dagtdata = $dagent.displayname.split('.')[0]
    $mridata = $migdbfile | ? {$_.ServerName -match $dagtdata}

#Create HTML Output

        $NewRow = $AgentTable.NewRow()
        $NewRow.ServerName=($dagtdata)
        $NewRow.PatchList=($mridata.PatchList).ToString()
        $NewRow.ProxyingEnabled=($mridata.ProxyingEnabled).ToString()
        $NewRow.AgentVersion=($mridata.AgentVersion).ToString()
        $NewRow.MGList=($mridata.MGList).ToString()
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

	$ReportOutput +=  "<p><H2>Dual Pathing - Missing Management Groups on Server:</H2></p>"
	$ReportOutput +=  "<p><H3>Dual Pathing Not Applied Count: $TotalAgentsMissingDH</H3></p>"
	$ReportOutput += $AgentTable | Sort-Object ServerName | Select ServerName,PatchList,ProxyingEnabled,AgentVersion,MGList,DatePurchased,Country,Location,BillingStatus,CostCentre,ARNNumber,ARNDescriptionServiceName,SDCName,WorkloadType,WorkloadFunction,Status,Platform,HWManufacturer,HWModel,Classification,CPUNo,CPUSpeed,CPUType,Memory,HDNo,HDSize,RPERF,OperatingSystemType,OSVersion,OSRevision,SerialNo,AssetNo,Comments | ConvertTo-HTML -fragment

	}

if ($mriexists -eq $false){

#Link Output to MRI File and populate line for HTML File

$AgentTable = New-Object System.Data.DataTable "$AvailableTable"
$AgentTable.Columns.Add((New-Object System.Data.DataColumn DisplayName,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn PatchList,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn ProxyingEnabled,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn AgentVersion,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn MGList,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn HealthState,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn AvailabilityLastModified,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn StateLastModified,([string])))
$AgentTable.Columns.Add((New-Object System.Data.DataColumn InMaintenanceMode,([string])))

foreach($dagent in $duallinktomri){
    $dagtdata = $dagent.displayname
    $hsdhdata = $hsdhdbfile | ? {$_.DisplayName -match $dagtdata}

#Create HTML Output

        $NewRow = $AgentTable.NewRow()
        $NewRow.DisplayName=($hsdhdata.DisplayName).ToString()
        $NewRow.PatchList=($hsdhdata.PatchList).ToString()
        $NewRow.ProxyingEnabled=($hsdhdata.ProxyingEnabled).ToString()
        $NewRow.AgentVersion=($hsdhdata.AgentVersion).ToString()
        $NewRow.MGList=($hsdhdata.MGList).ToString()
        $NewRow.HealthState=($hsdhdata.HealthState).ToString()
        $NewRow.AvailabilityLastModified=($hsdhdata.AvailabilityLastModified).ToString()
        $NewRow.StateLastModified=($hsdhdata.StateLastModified).ToString()
        $NewRow.InMaintenanceMode=($hsdhdata.InMaintenanceMode).ToString()
        $AgentTable.Rows.Add($NewRow)
	}

#Write to Report 

	$ReportOutput +=  "<p><H2>Dual Pathing - Missing Management Groups on Server:</H2></p>"
	$ReportOutput +=  "<p><H3>Dual Pathing Not Applied Count: $TotalAgentsMissingDH</H3></p>"
	$ReportOutput += $AgentTable | Sort-Object ServerName | Select DisplayName,PatchList,ProxyingEnabled,AgentVersion,MGList,HealthState,AvailabilityLastModified,StateLastModified,InMaintenanceMode | ConvertTo-HTML -fragment
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
$ReportOutput += $Alerts | Sort -desc RepeatCount | select-object -first 10 Name, RepeatCount, MonitoringObjectPath, Description | ConvertTo-HTML -fragment
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
$ReportOutput += $Alerts | Sort -desc RepeatCount | select-object -first 10 Name, RepeatCount, MonitoringObjectPath, Description | ConvertTo-HTML -fragment
}

#*************************ALERT ANALYSIS OVER LAST 24 HRS ENDS FROM HERE***********

#*************************OUTPUT THE ENTIRE REPORT INFORMATION STARTS FROM HERE****

# Take all $ReportOutput and combine it with $Body to create completed HTML output
$Body = ConvertTo-HTML -head $Head -body "$ReportOutput"
$time = (Get-Date).ToString("yyyyMMddhh")
$Body | Out-File $filedir\$time.html

#*************************OUTPUT THE ENTIRE REPORT INFORMATION ENDS FROM HERE******


