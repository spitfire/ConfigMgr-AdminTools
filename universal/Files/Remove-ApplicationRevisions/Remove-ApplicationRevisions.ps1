[CmdletBinding()]
Param(
    [Parameter(Mandatory = $True, Position = 1)]
    [string] $ApplicationName
)
Try {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" -ErrorAction "Stop"
}
Catch {
    Write-host -Message 'Importing SCCM PSH module - Failed!'
}
#  Get the CMSITE SiteCode and change connection context
Try {
    $SiteCode = (Get-PSDrive -PSProvider CMSITE).Name |Select-Object -First 1
}
Catch {
    Write-host -Message 'Get PS drive - Failed!'
}
#  Change the connection context
Try {
    Set-Location "$($SiteCode):\"
}
Catch {
    Write-host -Message 'Set location to Site Drive - Failed!'
}

#runing from site server
write-host $MyInvocation.MyCommand.Name
write-host "Removing old revisions from:"$ApplicationName
$flag = $true
$cmApp = Get-CMApplication -name $ApplicationName
$cmAppRevision = $cmApp | Get-CMApplicationRevisionHistory
for ($i = 0; $i -lt $cmAppRevision.Count - 1; $i++) {
    write-host "Removing revision: "$cmAppRevision[$i].civersion
    Remove-CMApplicationRevisionHistory -Id $cmAppRevision[$i].ci_id -Revision $cmAppRevision[$i].civersion -force -Verbose
    $flag = $false
}
if ($flag) {write-host "No old revisions to remove!"}
Write-host "Finished!"
Read-Host -Prompt "Press ENTER to exit"