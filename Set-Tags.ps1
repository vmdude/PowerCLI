<# 
.SYNOPSIS 
    This script will give you a way to handle customField by using a source VM model
.DESCRIPTION 
    The script will replicate annotation and custom field 
	from a source VM to a destination VM
	(by default it will not overwrite existing custom field)
.NOTES 
    Author     : Frederic Martin - www.vmdude.fr
.LINK 
    http://www.vmdude.fr
.EXAMPLE 
	C:\foo> .\Set-Tags.ps1 -vmSourceName VM01 -vmDestinationName VM02
	
	Description
	-----------
	Replicate custom field from VM01 to VM02 (without overwriting destination)
.EXAMPLE 
	C:\foo> .\Set-Tags.ps1 -vmSourceName VM01 -vmDestinationName VM02 -force
	
	Description
	-----------
	Replicate custom field from VM01 to VM02 (with overwriting destination)
.PARAMETER vmSourceName 
   Name of the VM used for source replication
.PARAMETER vmDestinationName 
   Name of the VM used for destination replication
.PARAMETER force 
   This switch allows you to overwrite destination custom field.
#> 

param (
	[Parameter(Mandatory=$True)]
	[string]$vmSourceName,
	[Parameter(Mandatory=$True)]
	[string]$vmDestinationName,
	[switch]$force
)

# Only handle single vCenter connection, mess it up if not
if (($global:DefaultVIServers | Measure-Object).Count -gt 1) {
	Write-Host -Foreground Red "[ERROR] Multiple vCenter connection detected."
	Break
}

# Building hash table for speeding late process
$htCustomFields = @{}
Get-View CustomFieldsManager-CustomFieldsManager | %{$_.field} | ?{$_.managedObjectType -match "VirtualMachine|^$"} | %{$htCustomFields.Add($_.Key,$_.Name)}

# Check for source VM
$vmSource = Get-View -ViewType VirtualMachine -Filter @{"Name"="^$vmSourceName$"} -Property Config.Annotation,Value
if (($vmSource | Measure-Object).Count -eq 0) {
	Write-Host -Foreground Red "[ERROR] Source VM $vmSourceName doesn't exist."
	Break
}

# Check for destination VM
$vmDestination = Get-View -ViewType VirtualMachine -Filter @{"Name"="^$vmDestinationName$"} -Property Config.Annotation,Value,Name
if (($vmDestination | Measure-Object).Count -eq 0) {
	Write-Host -Foreground Red "[ERROR] Destination VM $vmDestinationName doesn't exist."
	Break
}

# Annotation handler
if ($vmSource.Config.Annotation.length -gt 0 -And $vmSource.Config.Annotation -ne $vmDestination.Config.Annotation) {
	if ($vmDestination.Config.Annotation -And -Not $force) {
		Write-Host -Foreground Red "[ERROR] Annotation in destination VM"($vmDestination.Name)"is not empty. Use -force switch to overwrite."
	} else {
		try {
			$vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
			$vmConfigSpec.Annotation = $vmSource.Config.Annotation
			$vmDestination.ReconfigVM($vmConfigSpec)
			Write-Host -Foreground Green "[SUCCESS] Annotation in destination VM"($vmDestination.Name)"has been cloned."
		} catch [System.Exception] {
			Write-Host -Foreground Red "[ERROR] Annotation in destination VM"($vmDestination.Name)"cannot be cloned: "($_.Exception.ToString())
		}
	}
}

# Custom fields handler
foreach ($vmField in $vmSource.Value) {
	if ($vmField.Value.length -gt 0 -And $vmField.Value -ne ($vmDestination.Value | ?{$_.Key -eq $vmField.Key}).Value) {
		if (($vmDestination.Value | ?{$_.Key -eq $vmField.Key}).Value -And -Not $force) {
			Write-Host -Foreground Red "[ERROR] Custom Field"($htCustomFields[$vmField.Key])"in destination VM"($vmDestination.Name)"is not empty. Use -force switch to overwrite."
		} else {
			try {
				$vmDestination.setCustomValue($htCustomFields[$vmField.Key],$vmField.Value)
				Write-Host -Foreground Green "[SUCCESS] Custom Field"($htCustomFields[$vmField.Key])"in destination VM"($vmDestination.Name)"has been cloned."
			} catch [System.Exception] {
				Write-Host -Foreground Red "[ERROR] Custom Field"($htCustomFields[$vmField.Key])"in destination VM"($vmDestination.Name)"cannot be cloned:"($_.Exception.ToString())
			}
		}
	}
}