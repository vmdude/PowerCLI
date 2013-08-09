$report = @()
Foreach ($esxhost in Get-View -ViewType HostSystem -Property summary,name) {
	$line = "" | Select Name, vCenter, OverallCpuUsage, OverallMemoryUsage, MaxCpu, MaxMemory
	$line.Name = $esxhost.Name
	$line.vCenter = $esxhost.client.serviceurl.replace("https://","").replace("/sdk","")
	$line.OverallCpuUsage = $esxhost.summary.quickstats.OverallCpuUsage
	$line.OverallMemoryUsage = $esxhost.summary.quickstats.OverallMemoryUsage
	$line.MaxCpu = ($esxhost.summary.hardware.NumCpuCores * $esxhost.summary.hardware.CpuMhz)
	$line.MaxMemory = [Math]::Round(($esxhost.summary.hardware.MemorySize/1024/1024),0)
	$report += $line
}
$report | Export-csv -NoTypeInformation -Path C:\quickstats.csv -Delimiter ";"