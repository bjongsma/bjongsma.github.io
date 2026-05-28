$appid = "9c51b065-a9cc-4c17-ae2a-87f3081278d2"

#1 Delete Keys in \SideCarPolicies\StatusServiceReports
$statusServiceReportKeys = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\SideCarPolicies\StatusServiceReports"
foreach ($statusServiceReportKey in $statusServiceReportKeys)
{
    $targetSubKey = ""
    $keyChildName = $statusServiceReportKey.PSChildName
    $targetSubKeys = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\SideCarPolicies\StatusServiceReports\$keyChildName" | Where-Object {$_.PSChildName -like "$appid*"}
    foreach ($targetSubKey in $targetSubKeys)
    {
    #write $targetSubKey.PSPath
    Remove-Item $targetSubKey.PSPath -Recurse -Force -WhatIf
    Remove-Item $targetSubKey.PSPath -Recurse -Force
    }
}

$win32AppKeys = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\Win32Apps" | Where-Object {($_.PSChildName -ne "OperationalState" -and $_.PSChildName -ne "Reporting")}
foreach ($win32AppKey in $win32AppKeys)
{
    $targetSubKey = ""
    #2 Delete Keys in Win32Apps
    $keyChildName = $win32AppKey.PSChildName
    $targetSubKeys = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\Win32Apps\$keyChildName" | Where-Object {$_.PSChildName -like "$appid*"}
    foreach ($targetSubKey in $targetSubKeys)
    {
    #write $targetSubKey.PSPath
    Remove-Item $targetSubKey.PSPath -Recurse -Force -WhatIf
    Remove-Item $targetSubKey.PSPath -Recurse -Force
    }

    #3 Delete Key in GRS
    $GRSkeys = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\Win32Apps\$keyChildName\GRS"
    foreach ($GRSKey in $GRSkeys)
    {
        $GRSKeyPath = $GRSKey.PSPath
        if((Get-ItemProperty $GRSKeyPath).PSObject.Properties.Name -contains $appid)
        {
            Remove-Item $GRSKeyPath -Force -WhatIf
            Remove-Item $GRSKeyPath -Force
        }
    }
}