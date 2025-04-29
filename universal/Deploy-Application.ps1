<#
.SYNOPSIS
	This script performs the installation or uninstallation of an application(s).
	# LICENSE #
	PowerShell App Deployment Toolkit - Provides a set of functions to perform common application deployment tasks on Windows. 
	Copyright (C) 2017 - Sean Lillis, Dan Cunningham, Muhammad Mashwani, Aman Motazedian.
	This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details. 
	You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.
.DESCRIPTION
	The script is provided as a template to perform an install or uninstall of an application(s).
	The script either performs an "Install" deployment type or an "Uninstall" deployment type.
	The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.
	The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.
.PARAMETER DeploymentType
	The type of deployment to perform. Default is: Install.
.PARAMETER DeployMode
	Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.
.PARAMETER AllowRebootPassThru
	Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.
.PARAMETER TerminalServerMode
	Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Destkop Session Hosts/Citrix servers.
.PARAMETER DisableLogging
	Disables logging to file for the script. Default is: $false.
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"
.EXAMPLE
    Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"
.NOTES
	Toolkit Exit Code Ranges:
	60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
	69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
	70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1
.LINK 
	http://psappdeploytoolkit.com
#>
[CmdletBinding()]
Param (
	[Parameter(Mandatory=$false)]
	[ValidateSet('Install','Uninstall','Repair')]
	[string]$DeploymentType = 'Install',
	[Parameter(Mandatory=$false)]
	[ValidateSet('Interactive','Silent','NonInteractive')]
	[string]$DeployMode = 'Interactive',
	[Parameter(Mandatory=$false)]
	[switch]$AllowRebootPassThru = $false,
	[Parameter(Mandatory=$false)]
	[switch]$TerminalServerMode = $false,
	[Parameter(Mandatory=$false)]
	[switch]$DisableLogging = $false
)

Try {
	## Set the script execution policy for this process
	Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch {}
	
	##*===============================================
	##* VARIABLE DECLARATION
	##*===============================================
	## Variables: Application
	[string]$appVendor = 'spitfire'
	[string]$appName = 'Admin Tools'
	[string]$appVersion = '1.2.0'
	[string]$appArch = ''
	[string]$appLang = 'en-us'
	[string]$appRevision = '01'
	[string]$baseScriptVersion = '1.2.0'
	[string]$appScriptVersion = '1.0.0'
	[string]$appScriptDate = '2025-04-29'
	[string]$appScriptAuthor = 'Mieszko Ślusarczyk'
	[bool]$showPostinstallMessage = $false
	##*===============================================
	## Variables: Install Titles (Only set here to override defaults set by the toolkit)
	[string]$installName = ''
	[string]$installTitle = ''
	
	##* Do not modify section below
	#region DoNotModify
	
	## Variables: Exit Code
	[int32]$mainExitCode = 0
	
	## Variables: Script
	[string]$deployAppScriptFriendlyName = 'Deploy Application'
	[version]$deployAppScriptVersion = [version]'3.7.0'
	[string]$deployAppScriptDate = '02/13/2018'
	[hashtable]$deployAppScriptParameters = $psBoundParameters
	
	## Variables: Environment
	If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }
	[string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent
	
	## Dot source the required App Deploy Toolkit Functions
	Try {
		[string]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
		If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) { Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]." }
		If ($DisableLogging) { . $moduleAppDeployToolkitMain -DisableLogging } Else { . $moduleAppDeployToolkitMain }
	}
	Catch {
		If ($mainExitCode -eq 0){ [int32]$mainExitCode = 60008 }
		Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
		## Exit the script, returning the exit code to SCCM
		If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $mainExitCode; Exit } Else { Exit $mainExitCode }
	}

	#endregion
	##* Do not modify section above
	$ConfigMgrConsolePath = $ENV:SMS_ADMIN_UI_PATH.Replace("bin\i386","")
	Function Install-Remove_ApplicationRevisions
	{
		#https://sccm-zone.com/sccm-right-click-clean-old-application-revisions-309f7bb9a8db
		If (!(Test-Path "$ConfigMgrConsolePath\XmlStorage\Extensions\Actions\968164ab-af86-459c-b89e-d3a49c05d367\")){New-Folder "$ConfigMgrConsolePath\XmlStorage\Extensions\Actions\968164ab-af86-459c-b89e-d3a49c05d367\"}
		Copy-File "$dirFiles\Remove-ApplicationRevisions\_Remove-ApplicationRevisions.xml" "$ConfigMgrConsolePath\XmlStorage\Extensions\Actions\968164ab-af86-459c-b89e-d3a49c05d367\"
		Copy-File "$dirFiles\Remove-ApplicationRevisions\Remove-ApplicationRevisions.ps1" "$env:ProgramData\ConfigMgr\"
		Unblock-File "$env:ProgramData\ConfigMgr\Remove-ApplicationRevisions.ps1"
	}

	Function UnInstall-Remove_ApplicationRevisions
	{
		#https://sccm-zone.com/sccm-right-click-clean-old-application-revisions-309f7bb9a8db
		If ("$ConfigMgrConsolePath\XmlStorage\Extensions\Actions\968164ab-af86-459c-b89e-d3a49c05d367\_Remove-ApplicationRevisions.xml"){Remove-File -Path "$ConfigMgrConsolePath\XmlStorage\Extensions\Actions\968164ab-af86-459c-b89e-d3a49c05d367\_Remove-ApplicationRevisions.xml"}
		If ("$env:ProgramData\ConfigMgr\Remove-ApplicationRevisions.ps1") { Remove-File -Path "$env:ProgramData\ConfigMgr\Remove-ApplicationRevisions.ps1" }
	}

	Function Install-Retire_CMApplication
	{
		If (!(Test-Path "$ConfigMgrConsolePath\XmlStorage\Extensions\Actions\968164ab-af86-459c-b89e-d3a49c05d367\")){New-Folder "$ConfigMgrConsolePath\XmlStorage\Extensions\Actions\968164ab-af86-459c-b89e-d3a49c05d367\"}
		Copy-File "$dirFiles\Retire-CMApplication\_Retire-CMApplication.xml" "$ConfigMgrConsolePath\XmlStorage\Extensions\Actions\968164ab-af86-459c-b89e-d3a49c05d367\"
		Copy-File "$dirFiles\Retire-CMApplication\Retire-CMApplication.ps1" "$env:ProgramData\ConfigMgr\"
		Unblock-File "$env:ProgramData\ConfigMgr\Retire-CMApplication.ps1"
	}

	Function UnInstall-Retire_CMApplication
	{
		If ("$ConfigMgrConsolePath\XmlStorage\Extensions\Actions\968164ab-af86-459c-b89e-d3a49c05d367\_Retire-CMApplication.xml"){Remove-File -Path "$ConfigMgrConsolePath\XmlStorage\Extensions\Actions\968164ab-af86-459c-b89e-d3a49c05d367\_Retire-CMApplication.xml"}
		If ("$env:ProgramData\ConfigMgr\Retire-CMApplication.ps1") { Remove-File -Path "$env:ProgramData\ConfigMgr\Retire-CMApplication.ps1" }
	}

	Function Install-Redistribute_FailedPKGsOnContentStatus
	{
		#https://www.applepie.se/redistribute-failed-packages-in-configmgr
		If (!(Test-Path "$ConfigMgrConsolePath\XmlStorage\Extensions\Actions\14214306-59f0-46cf-b453-a649f2a249e1\")){New-Folder "$ConfigMgrConsolePath\XmlStorage\Extensions\Actions\14214306-59f0-46cf-b453-a649f2a249e1\"}
		Copy-File "$dirFiles\Redistribute-FailedPKGsOnContentStatus\_Redistribute-FailedPKGsOnContentStatus.xml" "$ConfigMgrConsolePath\XmlStorage\Extensions\Actions\14214306-59f0-46cf-b453-a649f2a249e1\"
		Copy-File "$dirFiles\Redistribute-FailedPKGsOnContentStatus\Redistribute-FailedPKGsOnContentStatus.ps1" "$env:ProgramData\ConfigMgr\"
		Unblock-File "$env:ProgramData\ConfigMgr\Redistribute-FailedPKGsOnContentStatus.ps1"
	}

	Function UnInstall-Redistribute_FailedPKGsOnContentStatus
	{
		#https://www.applepie.se/redistribute-failed-packages-in-configmgr
		If ("$ConfigMgrConsolePath\XmlStorage\Extensions\Actions\14214306-59f0-46cf-b453-a649f2a249e1\_Redistribute-FailedPKGsOnContentStatus.xml"){Remove-File -Path "$ConfigMgrConsolePath\XmlStorage\Extensions\Actions\14214306-59f0-46cf-b453-a649f2a249e1\_Redistribute-FailedPKGsOnContentStatus.xml"}
		If ("$env:ProgramData\ConfigMgr\Redistribute-FailedPKGsOnContentStatus.ps1") { Remove-File -Path "$env:ProgramData\ConfigMgr\Redistribute-FailedPKGsOnContentStatus.ps1" }		
	}

	Function Install-Redistribute_FailedPKGsOnDPConfStatus
	{
		#https://www.applepie.se/redistribute-failed-packages-in-configmgr
		If (!(Test-Path "$ConfigMgrConsolePath\XmlStorage\Extensions\Actions\d8718784-99d5-4449-bc28-a26631fafc07\")){New-Folder "$ConfigMgrConsolePath\XmlStorage\Extensions\Actions\d8718784-99d5-4449-bc28-a26631fafc07\"}
		Copy-File "$dirFiles\Redistribute-FailedPKGsOnDPConfStatus\_Redistribute-FailedPKGsOnDPConfStatus.xml" "$ConfigMgrConsolePath\XmlStorage\Extensions\Actions\d8718784-99d5-4449-bc28-a26631fafc07\"
		Copy-File "$dirFiles\Redistribute-FailedPKGsOnDPConfStatus\Redistribute-FailedPKGsOnDPConfStatus.ps1" "$env:ProgramData\ConfigMgr\"
		Unblock-File "$env:ProgramData\ConfigMgr\Redistribute-FailedPKGsOnDPConfStatus.ps1"
	}

	Function UnInstall-Redistribute_FailedPKGsOnDPConfStatus
	{
		#https://www.applepie.se/redistribute-failed-packages-in-configmgr
		If ("$ConfigMgrConsolePath\XmlStorage\Extensions\Actions\d8718784-99d5-4449-bc28-a26631fafc07\_Redistribute-FailedPKGsOnDPConfStatus.xml"){Remove-File -Path "$ConfigMgrConsolePath\XmlStorage\Extensions\Actions\d8718784-99d5-4449-bc28-a26631fafc07\_Redistribute-FailedPKGsOnDPConfStatus.xml"}
		If ("$env:ProgramData\ConfigMgr\Redistribute-FailedPKGsOnDPConfStatus.ps1") { Remove-File -Path "$env:ProgramData\ConfigMgr\Redistribute-FailedPKGsOnDPConfStatus.ps1" }		
	}

	Function Install-Validate_ContentOnDPs
	{
		#https://gregramsey.net/2013/04/19/how-to-initiate-the-validate-action-on-all-dps-for-a-package-in-configmgr-2012/
		If (!(Test-Path "$ConfigMgrConsolePath\XmlStorage\Extensions\Actions\14214306-59f0-46cf-b453-a649f2a249e1\")){New-Folder "$ConfigMgrConsolePath\XmlStorage\Extensions\Actions\14214306-59f0-46cf-b453-a649f2a249e1\"}
		Copy-File "$dirFiles\Validate-ContentOnDPs\_Validate-ContentOnDPs.xml" "$ConfigMgrConsolePath\XmlStorage\Extensions\Actions\14214306-59f0-46cf-b453-a649f2a249e1\"
		Copy-File "$dirFiles\Validate-ContentOnDPs\Validate-ContentOnDPs.ps1" "$env:ProgramData\ConfigMgr\"
		Unblock-File "$env:ProgramData\ConfigMgr\Validate-ContentOnDPs.ps1"
	}

	Function UnInstall-Validate_ContentOnDPs
	{
		#https://gregramsey.net/2013/04/19/how-to-initiate-the-validate-action-on-all-dps-for-a-package-in-configmgr-2012/
		If ("$ConfigMgrConsolePath\XmlStorage\Extensions\Actions\14214306-59f0-46cf-b453-a649f2a249e1\_Validate-ContentOnDPs.xml"){Remove-File -Path "$ConfigMgrConsolePath\XmlStorage\Extensions\Actions\14214306-59f0-46cf-b453-a649f2a249e1\_Validate-ContentOnDPs.xml"}
		If ("$env:ProgramData\ConfigMgr\Validate-ContentOnDPs.ps1") { Remove-File -Path "$env:ProgramData\ConfigMgr\Validate-ContentOnDPs.ps1" }		
	}

	Function Install-Extensions
	{
		If(!(Test-Path -Path "$env:ProgramData\ConfigMgr")){New-Folder "$env:ProgramData\ConfigMgr"}
		If ($Env:SMS_ADMIN_UI_PATH) #ConfigMgr admin console installed
		{
			Install-Redistribute_FailedPKGsOnContentStatus
			Install-Redistribute_FailedPKGsOnDPConfStatus
			Install-Remove_ApplicationRevisions
			Install-Retire_CMApplication
			Install-Validate_ContentOnDPs
		}
		
	}
	Function UnInstall-Extensions
	{
		If(!(Test-Path -Path "$env:ProgramData\ConfigMgr")){New-Folder "$env:ProgramData\ConfigMgr"}
		If ($Env:SMS_ADMIN_UI_PATH) #ConfigMgr admin console installed
		{
			UnInstall-Redistribute_FailedPKGsOnContentStatus
			UnInstall-Redistribute_FailedPKGsOnDPConfStatus
			UnInstall-Remove_ApplicationRevisions
			UnInstall-Retire_CMApplication
			UnInstall-Validate_ContentOnDPs
		}
		
	}

	#Set DeployMode to 'NonInteractive' if running a task sequence
	If ($runningTaskSequence){ $DeployMode = 'NonInteractive'}

	## Specify list of (comma separated) names of the processes that should be closed dutring installation, i.e. "iexplore,java"
	$processes = "Microsoft.ConfigurationManagement"
	##*===============================================
	##* END VARIABLE DECLARATION
	##*===============================================
		
	If ($deploymentType -ieq 'Install') {
		##*===============================================
		##* PRE-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Installation'

		## Show Welcome Message, close apps specified in $processes, allow up to 2 deferrals (only if any of beforementioned processes is running), verify there is enough disk space to complete the install, and persist the prompt
		If ($processes)
		{
			#Allow deferrals/show countdown only if DeployMode is 'Interactive'
			If ($DeployMode -eq 'Interactive')
			{
				Show-InstallationWelcome -CloseApps "$processes" -ForceCloseAppsCountdown 3600 -AllowDeferCloseApps -BlockExecution -AllowDefer -DeferTimes 2 -CheckDiskSpace -PersistPrompt
			}
			Else 
			{
				Show-InstallationWelcome -CloseApps "$processes" -ForceCloseAppsCountdown 60 -BlockExecution -CheckDiskSpace -PersistPrompt
			}
		}
		Else
		{
			Show-InstallationWelcome -CheckDiskSpace -PersistPrompt
		}
		
		## Show Progress Message (with the default message)
		Show-InstallationProgress
		
		## <Perform Pre-Installation tasks here>
		
		
		##*===============================================
		##* INSTALLATION 
		##*===============================================
		[string]$installPhase = 'Installation'
		
		## Handle Zero-Config MSI Installations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Install'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat; If ($defaultMspFiles) { $defaultMspFiles | ForEach-Object { Execute-MSI -Action 'Patch' -Path $_ } }
		}
		
		## <Perform Installation tasks here>
		Install-Extensions
		
		
		##*===============================================
		##* POST-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Installation'
		
		## <Perform Post-Installation tasks here>
		
		## Display a message at the end of the install
		If (-not $useDefaultMsi -and $showPostinstallMessage) { Show-InstallationPrompt -Message 'You can customize text to appear at the end of an install or remove it completely for unattended installations.' -ButtonRightText 'OK' -Icon Information -NoWait }
	}
	ElseIf ($deploymentType -ieq 'Uninstall')
	{
		##*===============================================
		##* PRE-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Uninstallation'
		
		## Show Welcome Message, close apps specified in $processes, allow up to 2 deferrals (only if any of beforementioned processes is running), verify there is enough disk space to complete the install, and persist the prompt
		If ($processes)
		{
			#Show countdown only if DeployMode is 'Interactive'
			If ($DeployMode -eq 'Interactive')
			{
				Show-InstallationWelcome -CloseApps "$processes" -BlockExecution -ForceCloseAppsCountdown 600
			}
			Else
			{
				Show-InstallationWelcome -CloseApps "$processes"  -BlockExecution -ForceCloseAppsCountdown 60
			}
		}
		Else
		{
			Show-InstallationWelcome
		}
		
		## Show Progress Message (with the default message)
		Show-InstallationProgress
		
		## <Perform Pre-Uninstallation tasks here>
		
		
		##*===============================================
		##* UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Uninstallation'
		
		## Handle Zero-Config MSI Uninstallations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Uninstall'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat
		}
		
		# <Perform Uninstallation tasks here>
		UnInstall-Extensions
		
		##*===============================================
		##* POST-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Uninstallation'
		
		## <Perform Post-Uninstallation tasks here>
		
		
	}
	ElseIf ($deploymentType -ieq 'Repair')
	{
		##*===============================================
		##* PRE-REPAIR
		##*===============================================
		[string]$installPhase = 'Pre-Repair'
		
		## Show Welcome Message, close apps specified in $processes, allow up to 2 deferrals (only if any of beforementioned processes is running), verify there is enough disk space to complete the install, and persist the prompt
		If ($processes)
		{
			#Show countdown only if DeployMode is 'Interactive'
			If ($DeployMode -eq 'Interactive')
			{
				Show-InstallationWelcome -CloseApps "$processes" -BlockExecution -ForceCloseAppsCountdown 600
			}
			Else
			{
				Show-InstallationWelcome -CloseApps "$processes"  -BlockExecution -ForceCloseAppsCountdown 60
			}
		}
		Else
		{
			Show-InstallationWelcome
		}
		
		## Show Progress Message (with the default message)
		Show-InstallationProgress
		
		## <Perform Pre-Repair tasks here>
		
		
		##*===============================================
		##* REPAIR
		##*===============================================
		[string]$installPhase = 'Repair'
		
		## Handle Zero-Config MSI Repairs
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Repair'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat
		}
		
		# <Perform Repair tasks here>
		UnInstall-Extensions
		Install-Extensions
		
		##*===============================================
		##* POST-REPAIR
		##*===============================================
		[string]$installPhase = 'Post-Repair'
		
		## <Perform Post-Repair tasks here>
		
		
	}
	
	##*===============================================
	##* END SCRIPT BODY
	##*===============================================
	
	## Call the Exit-Script function to perform final cleanup operations
	Exit-Script -ExitCode $mainExitCode
}
Catch {
	[int32]$mainExitCode = 60001
	[string]$mainErrorMessage = "$(Resolve-Error)"
	Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
	Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
	Exit-Script -ExitCode $mainExitCode
}