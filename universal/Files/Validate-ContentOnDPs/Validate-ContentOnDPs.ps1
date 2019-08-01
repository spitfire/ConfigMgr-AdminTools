#capturing arguments:
$SiteServer = $args[0]
$SiteNamespace = $args[1]
$SiteCode = ($args[1]).Substring(14)
$PackageID = $args[2]
 
"{0} {1} {2} {3}" -f $SiteServer, $SiteNamespace, $SiteCode, $PackageID
 
$myFilter = "PackageID='$PackageID'"
 
$dps = gwmi sms_distributionpoint -namespace $SiteNamespace -ComputerName $SiteServer -filter $myFilter
 
if (($dps | measure-object).Count -ge 1)
{
    $dps | % 
    {
        "Initiating 'Validate Content' on {0}..." -f $_.ServerNALPath
        if ($env:Computername -eq $SiteServer)
        {
            #if running directly on the site server, omit the -computername argument
            invoke-cimmethod -ClassName sms_distributionPoint -namespace $SiteNamespace -methodname "VerifyPackage" -arguments @{ PackageID=$_.PackageID; Nalpath=$_.ServerNALPath}
        }
        else
        {
            invoke-cimmethod -ClassName sms_distributionPoint -namespace $SiteNamespace -ComputerName $SiteServer -methodname "VerifyPackage" -arguments @{ PackageID=$_.PackageID; Nalpath=$_.ServerNALPath}
        }
    }
    "Validation initiated - Review Content Status for more information."
    Write-Host "Press any key to continue ..."
    $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
else
{
    "0 DPs found with this package. Content must be distributed in order to validate."
    Write-Host "Press any key to continue ..."
    $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}