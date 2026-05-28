$targetVersion = "8.0.25"
$targetVersionSDK = "8.0.419"

Start-Transcript "C:\Windows\Temp\Update-DotNet8.0.25.log"
Write-Host "$(Get-date) - Script run started"

#Free drive space
$freeSpaceGB = (Get-Volume -DriveLetter "C").SizeRemaining / 1GB
if ($freeSpaceGB -lt 2)
{
    Write-Host "$(Get-date) - C:\ drive free space is less than 2GB. Terminating script"
    Exit
}

#$scriptRoot = Get-Location
$scriptRoot = Split-Path $PSCommandPath
$regPath = "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall" 
$apps = Get-ChildItem $regPath

$dotNetAppsArray = @()
$alreadyUpdatedCheckArray = @()
$alreadyUpdatedCheckArray += [PSCustomObject]@{ Type = "SDK" ; Bitness = "x64" ; Updated = "" }
$alreadyUpdatedCheckArray += [PSCustomObject]@{ Type = "SDK" ; Bitness = "x86" ; Updated = "" }
$alreadyUpdatedCheckArray += [PSCustomObject]@{ Type = "HostingBundle" ; Bitness = "" ; Updated = "" }
$alreadyUpdatedCheckArray += [PSCustomObject]@{ Type = "AspNetCore" ; Bitness = "x64" ; Updated = "" }
$alreadyUpdatedCheckArray += [PSCustomObject]@{ Type = "AspNetCore" ; Bitness = "x86" ; Updated = "" }
$alreadyUpdatedCheckArray += [PSCustomObject]@{ Type = "NetCore" ; Bitness = "x64" ; Updated = "" }
$alreadyUpdatedCheckArray += [PSCustomObject]@{ Type = "NetCore" ; Bitness = "x86" ; Updated = "" }
$alreadyUpdatedCheckArray += [PSCustomObject]@{ Type = "WindowsDesktop" ; Bitness = "x64" ; Updated = "" }
$alreadyUpdatedCheckArray += [PSCustomObject]@{ Type = "WindowsDesktop" ; Bitness = "x86" ; Updated = "" }

#Discover installed .NET apps and build work list array
foreach($app in $apps)
{
    $keys = Get-ItemProperty $app.PSPath
    foreach($key in $keys)
    {
        if($key.BundleCachePath -like "C:\ProgramData\Package Cache\*")
        {
            if(
                ($key.DisplayName -like "*.NET*SDK*") -or`
                ($key.DisplayName -like "Microsoft .NET*Windows Server Hosting*") -or`
                ($key.DisplayName -like "Microsoft ASP.NET*") -or`
                ($key.DisplayName -like "Microsoft .NET*Runtime*") -or`
                ($key.DisplayName -like "Microsoft Windows Desktop Runtime*")`
            )
            {
                if($key.DisplayName -like "*.NET*SDK*") {$keyAppType = "SDK"}
                elseif($key.DisplayName -like "Microsoft .NET*Windows Server Hosting*") {$keyAppType = "HostingBundle"}
                elseif($key.DisplayName -like "Microsoft ASP.NET*") {$keyAppType = "AspNetCore"}
                elseif($key.DisplayName -like "Microsoft .NET*Runtime*") {$keyAppType = "NetCore"}
                elseif($key.DisplayName -like "Microsoft Windows Desktop Runtime*") {$keyAppType = "WindowsDesktop"}
                if($key.UninstallString -like "*x64*"){$keyBitness = "x64"}
                elseif($key.UninstallString -like "*x86*"){$keyBitness = "x86"}
                else{$keyBitness = ""}
                $keyVersion = ($key.DisplayName | Select-String -Pattern "\d+(\.\d+)+").Matches.Value
                $keyUninstallString = $key.UninstallString
                $dotNetAppsArray += [PSCustomObject]@{ DisplayName = $key.DisplayName ; Version = $keyVersion ; Type = $keyAppType ; Bitness = $keyBitness ; UninstallCommand = $keyUninstallString ; FirstPassActioned = "" }
            }
        } 
    }
}

Write-Host "$(Get-date) - Work List:"
Write-Host ($dotNetAppsArray | Out-String)

#FIRST PASS - Detects all .NET apps. If there are more than one of the same .NET app type it will leave one app, basically cleaning up all apps of the same type that are older than the target version
foreach($dotNetAppOuterLoop in $dotNetAppsarray)
{
    $dotNetAppOuterLoopDisplayName = $dotNetAppOuterLoop.DisplayName
    $dotNetAppOuterLoopType = $dotNetAppOuterLoop.Type
    $dotNetAppOuterLoopVersion = $dotNetAppOuterLoop.Version
    if( (($dotNetAppOuterLoopType -eq "SDK") -and ([System.Version]$dotNetAppOuterLoopVersion -ge [System.Version]$targetVersionSDK)) -or (($dotNetAppOuterLoopType -ne "SDK") -and ([System.Version]$dotNetAppOuterLoopVersion -ge [System.Version]$targetVersion)) )
    {
        Write-Host "$(Get-date) - .NET app present: $dotNetAppOuterLoopDisplayName, which is equal to or newer than target version"
        $dotNetAppOuterLoop.FirstPassActioned = "yes"
        #Checking if same app type but older versions are present for uninstall
        foreach($dotNetAppInnerLoop in $dotNetAppsarray)
        {
            $dotNetAppInnerLoopDisplayName = $dotNetAppInnerLoop.DisplayName
            $dotNetAppInnerLoopBitness = $dotNetAppInnerLoop.Bitness
            $dotNetAppInnerLoopType = $dotNetAppInnerLoop.Type
            $dotNetAppInnerLoopVersion = $dotNetAppInnerLoop.Version
            if(($dotNetAppInnerLoopType -eq $dotNetAppOuterLoopType) -and ($dotNetAppInnerLoopVersion -ne $dotNetAppOuterLoopVersion) -and ($dotNetAppInnerLoop.Bitness -eq $dotNetAppOuterLoop.Bitness))
            {
                Write-Host "$(Get-date) - Same .NET app type detected. Inner loop app: $dotNetAppInnerLoopDisplayName. Outer loop app: $dotNetAppOuterLoopDisplayName"
                if( (($dotNetAppOuterLoopType -eq "SDK") -and ([System.Version]$dotNetAppOuterLoopVersion -lt [System.Version]$targetVersionSDK)) -or (($dotNetAppOuterLoopType -ne "SDK") -and ([System.Version]$dotNetAppOuterLoop.Version -lt [System.Version]$targetVersion)) )
                {
                    #Uninstalling older version
                    $arg = $dotNetAppInnerLoop.UninstallCommand
                    $process = $arg.Substring(0,$arg.IndexOf("/"))
                    $arg = $arg.Substring($process.Length)
                    $arg = $arg + " /quiet /norestart /log C:\Windows\Temp\dotNET_" + $dotNetAppInnerLoopType + "_" + $dotNetAppInnerLoopVersion + "_" + $dotNetAppInnerLoopBitness + "_uninstall.log"
                    $process = $process -replace '"',""
                    $process = Resolve-Path $process -ErrorAction SilentlyContinue
                    $process = $process.Path
                    Write-Host "$(Get-date) - Uninstalling $dotNetAppInnerLoopDisplayName"
                    if($dotNetAppDisplayName -like "*SDK*from Visual Studio*")
                    {
                        Write-Host "$(Get-date) - $dotNetAppDisplayname detected. Visual Studio needs to be updated to update .NET SDK"
                    }
                    else
                    {
                        Start-Process $process -ArgumentList $arg -Wait
                    }
                    $dotNetAppInnerLoop.FirstPassActioned = "yes"   #this flag will mean that item in the work list will be skipped on the second pass
                }
            }
        }
    }
}

#SECOND PASS - For remaining apps if they are older than the target version, install the target version and uninstall older version
foreach($dotNetApp in $dotNetAppsarray)
{
    Clear-Variable arg -ErrorAction SilentlyContinue
    Clear-Variable process -ErrorAction SilentlyContinue
    $dotNetAppDisplayName = $dotNetApp.DisplayName
    $dotNetAppType = $dotNetApp.Type
    $dotNetAppVersion = $dotNetApp.Version
    $dotNetAppBitness = $dotNetApp.Bitness
    if($dotNetApp.FirstPassActioned -ne "yes")
    {
        #Target version for this .NET app and type was not detected in first pass
        if( (($dotNetAppType -eq "SDK") -and ([System.Version]$dotNetAppVersion -lt [System.Version]$targetVersionSDK)) -or (($dotNetAppType -ne "SDK") -and ([System.Version]$dotNetApp.Version -lt [System.Version]$targetVersion)) )
        {
            Write-Host "$(Get-date) - $dotNetAppDisplayname is older than target version"

            if($dotNetAppDisplayName -like "*SDK*from Visual Studio*")
            {
                Write-Host "$(Get-date) - $dotNetAppDisplayname detected. Visual Studio needs to be updated to update .NET SDK"
            }
            else
            {   
                $alreadyUpdatedCheck = $alreadyUpdatedCheckArray | ? {($_.Type -eq $dotNetAppType) -and ($_.Bitness -eq $dotNetAppBitness) }
                if($alreadyUpdatedCheck.Updated -eq "Yes")
                {
                    Write-Host "$(Get-date) - Target version for this .NET App type has already been installed"
                }
                else
                {    
                        if($dotNetAppType -eq "SDK"){$installer = Get-ChildItem $scriptRoot | ? {$_.BaseName -like "dotnet-sdk*" -and $_.BaseName -like "*$dotNetAppBitness*"}}
                    elseif($dotNetAppType -eq "HostingBundle"){$installer = Get-ChildItem $scriptRoot | ? {$_.BaseName -like "dotnet-hosting*"}}
                    elseif($dotNetAppType -eq "AspNetCore"){$installer = Get-ChildItem $scriptRoot | ? {$_.BaseName -like "aspnetcore-runtime*" -and $_.BaseName -like "*$dotNetAppBitness*"}}
                    elseif($dotNetAppType -eq "NetCore"){$installer = Get-ChildItem $scriptRoot | ? {$_.BaseName -like "dotnet-runtime*" -and $_.BaseName -like "*$dotNetAppBitness*"}}
                    elseif($dotNetAppType -eq "WindowsDesktop"){$installer = Get-ChildItem $scriptRoot | ? {$_.BaseName -like "windowsdesktop-runtime*" -and $_.BaseName -like "*$dotNetAppBitness*"}}
                    if($dotNetAppType -eq "SDK")
                    {
                        $arg = "/install /quiet /norestart /log C:\Windows\Temp\dotNET_" + $dotNetAppType + "_" + $targetVersionSDK + "_" + $dotNetAppBitness + "_install.log"
                    }
                    else
                    {
                        $arg = "/install /quiet /norestart /log C:\Windows\Temp\dotNET_" + $dotNetAppType + "_" + $targetVersion + "_" + $dotNetAppBitness + "_install.log"
                    }
                    $process = Resolve-Path "$scriptRoot\$installer" -ErrorAction SilentlyContinue
                    $process = $process.Path
                    Write-Host "$(Get-date) - Installing $installer"
                    Start-Process $process -ArgumentList $arg -Wait
                    $alreadyUpdatedCheck.Updated = "Yes"   #this flag ensures the target version is ony installed once
                    Write-Host "$(Get-date) - Setting $dotnetAppType updated flag to yes"
                }

                Clear-Variable process -ErrorAction SilentlyContinue
                $dotNetAppUninstallCommand = $dotNetApp.UninstallCommand
                $process = $dotNetAppUninstallCommand.Substring(0,$dotNetAppUninstallCommand.IndexOf("/"))
                $arg = "/uninstall /quiet /norestart /log C:\Windows\Temp\dotNET_" + $dotNetAppType + "_" + $dotNetAppVersion + "_" + $dotNetAppBitness + "_uninstall.log"
                $process = $process -replace '"',""
                
                $error.clear()
                $process = Resolve-Path $process -ErrorAction SilentlyContinue
                $process = $process.Path
                #check to see if the uninstall path is still present. If the version difference between the old app and target version is minor then the app will update and no uninstall is required
                if(!($error))
                {
                    #Uninstalling older app
                    Write-Host "$(Get-date) - Uninstalling $dotNetAppDisplayName"
                    Start-Process $process -ArgumentList $arg -Wait
                }
                else
                {
                    #No need to uninstall older app because version was updated
                    Write-Host "$(Get-date) - No need to uninstall existing app because it was a minor version older and was updated by target version"
                }
            }
        }
    }
}
New-ItemProperty -Path "HKLM:\SYSTEM\SOE\Admin" -Name "Update-DotNet_8.0.25_Completed" -PropertyType dword -Value 1 -ErrorAction SilentlyContinue
Write-Host "$(Get-date) - Script run complete"
Stop-Transcript