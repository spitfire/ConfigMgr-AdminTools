<#
.SYNOPSIS
	This script is a template that allows you to extend the toolkit with your own custom functions.
    # LICENSE #
    PowerShell App Deployment Toolkit - Provides a set of functions to perform common application deployment tasks on Windows. 
    Copyright (C) 2017 - Sean Lillis, Dan Cunningham, Muhammad Mashwani, Aman Motazedian.
    This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details. 
    You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.
.DESCRIPTION
	The script is automatically dot-sourced by the AppDeployToolkitMain.ps1 script.
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
)

##*===============================================
##* VARIABLE DECLARATION
##*===============================================

# Variables: Script
[string]$appDeployToolkitExtName = 'PSAppDeployToolkitExt'
[string]$appDeployExtScriptFriendlyName = 'App Deploy Toolkit Extensions'
[version]$appDeployExtScriptVersion = [version]'1.5.0'
[string]$appDeployExtScriptDate = '02/12/2017'
[hashtable]$appDeployExtScriptParameters = $PSBoundParameters

##*===============================================
##* FUNCTION LISTINGS
##*===============================================

# <Your custom functions go here>

<#
Authors: Mieszko Ślusarczyk, Sławomir Kulczycki
Version: 1.3.0
Date: 19.07.2018
#>

Function Wait-Time
{
	Param
	(
		[int32]$Seconds = 60
	)
	Write-Log -Message "Info: Waiting $Seconds Seconds" -Source Wait-Time
	Start-Sleep -Seconds $Seconds
} # Wait-Time

Function Set-ScheduledTask
{
<#
.SYNOPSIS
Creates or removes a scheduled task on local computer or remote computer
.DESCRIPTION
Creates a scheduled task on local computer or remote computer using COM object and XML text.
Returns $True or $False

Simply create a task in "Task Scheduler" and export it to XML.
Then use that XML from inside a Here-String [@" "@] or from the xml file

CAVEAT: Only handles task folders ONE level deep
.PARAMETER TaskXmlContent
Contents of a Task XML file as [String], [XmlDocument] or [xml].
.PARAMETER TaskNamePath
Name of the task to be created/removed and/or TaskFolder to be created/removed
Can also contain a TaskFolder. TaskFolder is auto-created if needed.
[TODO SomeDay: Optional *if* TaskXmlContent Description's Last line is @@@MyTaskFolder\MyTaskName]
.PARAMETER TaskUser
Default: $null
TaskUser can be $null if task is running as SYSTEM or a group (e.g. BUILT-IN\USERS)
.PARAMETER TaskPwd
Default: $null
TaskPwd can be $null if task is running as SYSTEM or a group (e.g. BUILT-IN\USERS)
.PARAMETER ComputerName
Name of Computer where to create the task. Default: localhost
.PARAMETER Remove
Remove the task specified by TaskNamePath [and ComputerName]
.PARAMETER RemoveTaskFolderIfEmpty
Works with -Remove parameter. Delete folder holding the targeted task.
.PARAMETER ContinueOnError
Continue if an error is encountered. Default: $false.
.EXAMPLE
[XML]$NewTaskXmlFileContent = Get-Content "C:\stuff\ExportedTask.xml"
Set-ScheduledTask -TaskNamePath $NewTaskName -TaskXmlContent $NewTaskXmlFileContent -ComputerName $Computer
Creates task in Root Task folder (\) from "C:\stuff\ExportedTask.xml"
.EXAMPLE
Set-ScheduledTask -TaskNamePath $NewTaskName -Remove -ComputerName $Computer
Removes task from Root Task folder (\)
.EXAMPLE
[xml]$NewTaskXmlContent = @" �<xml stuff>� "@
Set-ScheduledTask -TaskNamePath "MyTaskFolder\MyTaskName" -TaskXmlContent $NewTaskXmlContent
Creates task in MyTaskFolder Task folder (\MyTaskFolder) from [xml]$NewTaskXmlContent
CAVEAT: Cannot create more than ONE level deep.
.EXAMPLE
Set-ScheduledTask -TaskNamePath "MyTaskFolder\MyTaskName" -Remove
Set-ScheduledTask -TaskNamePath "\MyTaskFolder\MyTaskName" -Remove
Removes task from MyTaskFolder Task folder (\MyTaskFolder)
CAVEAT: Cannot delete from more than ONE level deep.
.EXAMPLE
Set-ScheduledTask -TaskNamePath "MyTaskFolder\MyTaskName" -Remove -RemoveTaskFolderIfEmpty
Removes task from MyTaskFolder Task folder (\MyTaskFolder)
Removes MyTaskFolder Task folder if it then becomes empty
CAVEAT: Cannot delete from more than ONE level deep.
.EXAMPLE
Set-ScheduledTask -TaskNamePath "\MyTaskFolder\*" -Remove -RemoveTaskFolderIfEmpty
Removes MyTaskFolder Task folder and its Tasks. (BE CAREFUL!!)
CAVEAT: Cannot delete more than ONE level deep.
.NOTES
Version 1.0 (22-APR-2015)
Denis St-Pierre (Ottawa, Canada)
LIMITATION: cannot handle more than one task folder deep
Based on http://psappdeploytoolkit.codeplex.com
For syntax use: Get-Help Set-ScheduledTask
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $True)]
		[ValidateNotNullorEmpty()]
		[string]$TaskNamePath = "",
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		$TaskXmlContent,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[Switch]$Remove,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[string]$ComputerName = "localhost",
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[string]$TaskUser = $null,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[string]$TaskPwd = $null,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[switch]$RemoveTaskFolderIfEmpty,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[bool]$ContinueOnError = $true
	)
	Begin
	{
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
		Remove-Variable TaskFolderPath -ErrorAction SilentlyContinue #Needed for debug to make sense
		
		Try
		{
			[System.__ComObject]$ScheduleObj = New-Object -ComObject ("Schedule.Service") #Need Admin do to this!
			$ScheduleObj.connect($ComputerName)
			[System.__ComObject]$TaskRootFolderObj = $ScheduleObj.GetFolder("\")
		}
		Catch
		{
			[string]$exceptionMessage = "$($_.Exception.Message) ($($_.ScriptStackTrace))"
			[String]$message = "ERROR: Cannot connect to [Schedule.Service]. Are we running elevated? $exceptionMessage"
			If ($ContinueOnError)
			{
				Write-Log $message -Source ${CmdletName}
				return $false #exit function
			}
			Else
			{
				Throw $message
			}
		}
		#TODO SomeDay: Retrieve TaskNamePath from TaskXmlContent Description's Last line is @@@MyTaskFolder\MyTaskName
		Write-Log "TaskNamePath is [$TaskNamePath]" -Source ${CmdletName}

		If ($TaskNamePath -match '\\')
		{
			#Get $TaskName and $TaskFolderPath from TaskNamePath
			[string]$TaskName = [System.IO.Path]::GetFileName($TaskNamePath)
			[string]$TaskFolderPath = [System.IO.Path]::GetDirectoryName($TaskNamePath)
		}
		Else
		{
			[string]$TaskName = $TaskNamePath
			#	[string]$TaskFolderPath = "\"	#RootTaskFolder
		}
	}
	Process
	{
		#Remove ALL Tasks in ONE Task Folder (Except ROOT Task Folder)
		If (($Remove) -and ($TaskName -eq "*"))
		{
			If ($TaskRootFolderObj.Path -eq $TaskFolderObj.Path)
			{
				[String]$message = "Will NOT delete all tasks in [ROOT Task Folder]. Allowing this would break too many things!"
				If ($ContinueOnError)
				{
					Write-log $Message -Source ${CmdletName}
					return $false #exit function
				}
				Else
				{
					Throw "ERROR: $Message"
				}
			}
			
			Try
			{
				[System.__ComObject]$TaskFolderObj = $ScheduleObj.GetFolder($TaskFolderPath)
			}
			Catch
			{
				[string]$exceptionMessage = "$($_.Exception.Message)] ($($_.ScriptStackTrace))"
				[String]$message = "Task folder [$TaskFolderPath] does not exist. `nNothing to Delete. $exceptionMessage"
				If ($ContinueOnError)
				{
					Write-log $message -Source ${CmdletName}
					return $True #exit function
				}
				Else
				{
					Throw "ERROR: $message"
				}
			}
			
			Write-Log "Deleting Task folder [$($TaskFolderObj.Path)] regardless of the number of tasks in the folder" -Source ${CmdletName}
			Try
			{
				[System.__ComObject]$AllTasks = $TaskFolderObj.GetTasks(1) #1= include hidden tasks too
			}
			Catch
			{
				[string]$exceptionMessage = "$($_.Exception.Message)] ($($_.ScriptStackTrace))"
				[String]$message = "Unable to get Tasks in Task folder [$TaskFolderPath] $exceptionMessage"
				If ($ContinueOnError)
				{
					Write-log $message -Source ${CmdletName}
					return $false #exit function
				}
				Else
				{
					Throw "ERROR: $message"
				}
			}
			[Int32]$TotalNumTasks = $AllTasks.count
			Write-log "[$TaskFolderPath] has $TotalNumTasks task(s)" -Source ${CmdletName}
			If ($TotalNumTasks -gt 0)
			{
				ForEach ($Task in $AllTasks)
				{
					Try
					{
						$Task.Stop(0) #Just in case, should test if running first
						Start-Sleep -Seconds 1
						$TaskFolderObj.DeleteTask($Task.Name, 0)
						Write-Log ("Task [$($Task.Name)] was deleted") -Source ${CmdletName}
					}
					Catch
					{
						[String]$message = "Cannot delete task [$($Task.Name)]. Might not exist or stopped"
						If ($ContinueOnError)
						{
							Write-log $message -Source ${CmdletName}
						}
						Else
						{
							Throw "ERROR: $message"
						}
					}
				}
				
				#Are they all gone?
				[System.__ComObject]$AllTasks = $TaskFolderObj.GetTasks(1) #1= include hidden tasks too
				If ($($AllTasks.Count) -ne 0)
				{
					[string]$ErrMess = "ERROR: Not all tasks have been deleted from the task folder."
					ForEach ($Task in $AllTasks)
					{
						$ErrMess = $ErrMess + "`nTask [$($Task.Name)]"
					}
					If ($ContinueOnError)
					{
						Write-log $ErrMess -Source ${CmdletName}
						return $false #exit function
					}
					Else
					{
						Throw "ERROR: $ErrMess"
					}
				}
				Else
				{
					#Write-log "INFO:No Tasks to delete in task folder[$SubFolderPath]." -Source ${CmdletName}
				}
			}
			Else
			{
				Write-Log "INFO: No tasks to delete in task folder [$SubFolderPath]." -Source ${CmdletName}
			}
			
			#Delete the Task Folder
			If ($RemoveTaskFolderIfEmpty)
			{
				#CAVEAT : you must use .DeleteFolder method with the PARENT of the task folder you want to delete
				#CAVEAT2: I didn't bother to add code for subfolders b/c I didn't need it.
				$SubFolderName = Split-Path -Path $TaskFolderObj.Path -Leaf
				$ParentFolderPath = Split-Path -Path $TaskFolderObj.Path -Parent
				Try
				{
					[System.__ComObject]$ParentFolderObj = $ScheduleObj.GetFolder($ParentFolderPath)
				}
				Catch
				{
					[string]$exceptionMessage = "$($_.Exception.Message) ($($_.ScriptStackTrace))"
					Throw "Task folder [${ParentFolderPath}] does not exist. `nNothing to Delete. $exceptionMessage"
					Return $true #exit Function
				}
				#No need to check for left-over tasks. We did this already above
				
				Try
				{
					$ParentFolderObj.DeleteFolder($SubFolderName, $null)
					Write-Log "Task folder [$SubFolderName] was deleted" -Source ${CmdletName}
					return $true #exit Function
				}
				Catch
				{
					$exceptionMessage = "$($_.Exception.Message) ($($_.ScriptStackTrace))"
					[String]$message = "Unable to delete Task folder [$SubFolderName] $exceptionMessage"
					If ($ContinueOnError)
					{
						Write-log $message -Source ${CmdletName}
						return $false #exit Function
					}
					Else
					{
						Throw "ERROR: $message"
					}
				}
			}
			Else
			{
				#Write-log "Not attempting to delete Task Folder [$($TaskFolderObj.Path)]" -Source ${CmdletName}
				return $true #exit Function
			}
			
		}
		
		#Remove ONE Task
		If (($Remove) -and ($TaskName -ne ""))
		{
			Try
			{
				[System.__ComObject]$TaskFolderObj = $ScheduleObj.GetFolder($TaskFolderPath)
			}
			Catch
			{
				[String]$message = "Task folder [${TaskFolderPath}] does not exist. `nNothing to Delete."
				If ($ContinueOnError)
				{
					Write-log $message -Source ${CmdletName}
					return $true #exit Function
				}
				else { Throw "ERROR: $message" }
			}
			
			Write-Log ("Task [$TaskName] will be removed") -Source ${CmdletName}
			Try
			{
				[System.__ComObject]$task = $TaskFolderObj.gettask($TaskName)
				$Task.Stop(0) #Stop the task, Just in case
				Start-Sleep -Seconds 1
				$TaskFolderObj.DeleteTask($TaskName, 0)
				Write-Log ("Task [$TaskName] was deleted") -Source ${CmdletName}
			}
			Catch
			{
				[String]$message = "INFO:Cannot delete task [$TaskName]. It might not exist."
				Write-log $message -Source ${CmdletName}
				return $True #exit Function
			}
			
			#TODO: Check if the Task is still in $TaskFolderObj or not ( use gettasks() ?)
			
			If ($RemoveTaskFolderIfEmpty)
			{
				If ($TaskRootFolderObj.Path -eq $TaskFolderObj.Path)
				{
					[String]$message = "INFO: Cannot delete [ROOT task] folder."
					If ($ContinueOnError)
					{
						Write-log $message -Source ${CmdletName}
					}
					Else
					{
						Throw "ERROR: $message"
					}
				}
				Else
				{
					Try
					{
						#CAVEAT : you must use .DeleteFolder method with the PARENT of the task folder you want to delete
						#CAVEAT2: I didn't bother to add code for subfolders b/c I didn't need it.
						$SubFolderName = Split-Path -Path $TaskFolderObj.Path -Leaf
						$ParentFolderPath = Split-Path -Path $TaskFolderObj.Path -Parent
						
						Try
						{
							[System.__ComObject]$ParentFolderObj = $ScheduleObj.GetFolder($ParentFolderPath)
						}
						Catch
						{
							[string]$exceptionMessage = "$($_.Exception.Message) ($($_.ScriptStackTrace))"
							Throw "Cannot Get Task folder [${ParentFolderPath}] in order to delete $SubFolderName. $exceptionMessage"
							Return $false #exit Function
						}
						#Is $TaskFolder empty?
						[System.__ComObject]$AllTasks = $TaskFolderObj.GetTasks(1) #1= include hidden tasks too
						If ($($AllTasks.Count) -eq 0)
						{
							$ParentFolderObj.DeleteFolder($SubFolderName, $null)
							Write-Log "Task folder [$SubFolderName] was deleted" -Source ${CmdletName}
						}
						Else
						{
							Write-Log "INFO: Cannot delete Task folder [$SubFolderName]. It still contains $($AllTasks.Count) task(s)." -Source ${CmdletName}
						}
						return $True #exit Function
					}
					Catch
					{
						$exceptionMessage = "$($_.Exception.Message) ($($_.ScriptStackTrace))"
						[String]$message = "Unable to delete Task folder [$SubFolderName] $exceptionMessage"
						If ($ContinueOnError)
						{
							Write-log $message -Source ${CmdletName}
							return $false #exit Function
						}
						Else
						{
							Throw "ERROR: $message"
						}
					}
				} #Else
			}
			Else
			{
				#Write-log "Not attempting to delete Task Folder [$($TaskFolderObj.Path)]" -Source ${CmdletName}
				return $true #exit Function
			}
		}
		
		#Create Task
		If ($TaskName -eq "*")
		{
			[String]$message = "Cannot create task named $TaskName"
			If ($ContinueOnError)
			{
				Write-log $message -Source ${CmdletName}
				return $false #exit Function
			}
			Else
			{
				Throw "ERROR: $message"
			}
		}
		
		If (-not ($TaskXmlContent))
		{
			[String]$message = "Cannot create task without -TaskXmlContent parameter"
			If ($ContinueOnError)
			{
				Write-log $message -Source ${CmdletName}
				Return $false #exit Function
			}
			Else
			{
				Throw "ERROR: $message"
			}
		}
		
		If ($TaskFolderPath)
		{
			#Create TaskFolder if needed
			Write-Log "Creating Task folder [${TaskFolderPath}] If needed." -Source ${CmdletName}
			Try
			{
				$TaskRootFolderObj.CreateFolder($TaskFolderPath)
			}
			Catch { } #ignore already exists error
			Try
			{
				[System.__ComObject]$TaskFolderObj = $ScheduleObj.GetFolder($TaskFolderPath)
			}
			Catch
			{
				[String]$message = "Task folder [${TaskFolderPath}] does not exist. Cannot create task in non-existing task folder."
				If ($ContinueOnError)
				{
					Write-Log $message -Source ${CmdletName}
					Return $false
				}
				Else
				{
					Throw "ERROR: $message"
				}
			}
		}
		Else
		{
			#Task will be created in the "Root" Task Folder
			[System.__ComObject]$TaskFolderObj = $TaskRootFolderObj
		}

		#Creating task (In sub folder if needed)
		[System.__ComObject]$NewTask = $ScheduleObj.NewTask($null) #Create blank task
		If ($($TaskXmlContent.gettype().name) -eq "XmlDocument")
		{
			$NewTask.XmlText = $TaskXmlContent.OuterXml -as [string] #load XmlText property
		}
		ElseIf ($($TaskXmlContent.gettype().name) -eq "String")
		{
			$NewTask.XmlText = $TaskXmlContent #load XmlText property
		}
		Else
		{
			[String]$message = " -TaskXmlContent as [$($TaskXmlContent.gettype().name)] is not supported. Please cast as [XmlDocument] or [string]."
			If ($ContinueOnError)
			{
				Write-log $message -Source ${CmdletName}
				return $false #exit Function
			}
			Else
			{
				Throw "ERROR: $message"
			}
		}

		#It can overwrite an existing task just fine provided that the task folder exists already
		# but just in case�
		Try
		{
			Write-Log "Creating Task [$TaskName]�" -Source ${CmdletName}
			$RegistrationResult = $TaskFolderObj.RegisterTaskDefinition($TaskName, $NewTask, 6, $TaskUser, $TaskPwd, 1, $null)
			#Write-log "DEV: $RegistrationResult" -Source ${CmdletName}
		}
		Catch
		{
			[string]$exceptionMessage = "$($_.Exception.Message) ($($_.ScriptStackTrace))"
			[String]$message = "Unable to import task [$TaskName] $exceptionMessage"
			If ($ContinueOnError)
			{
				Write-log $message -Source ${CmdletName}
				return $false
			}
			Else
			{
				throw "ERROR: $message"
			}
		}
		#$RegistrationResult is a Massive block of text but not as [string]
		#[String]$RegistrationResultString = Out-String -InputObject $RegistrationResult
		#return $RegistrationResultString
		Return $true
	}
	End
	{
		Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
	}
} # Set-ScheduledTask

Function Check-PendingReboot
{
	Param
	(
		[int32]$CountdownSeconds = "3600",
		[int32]$CountdownNoHideSeconds = "3600",
		[int32]$ExitCode = "70010"
	)
	If ((Get-PendingReboot).IsSystemRebootPending)
	{
		If ($CountdownSeconds -lt $CountdownNoHideSeconds){ $CountdownNoHideSeconds = $CountdownSeconds }
		Write-Log -Message "Warning: The machine needs to be restarted before attempting installation" -Severity 2 -Source Check-PendingReboot
		Try
		{
			Write-Log -Message "Info: Setting scheduled tasks to request & evaluate policies/application deployment" -Source Check-PendingReboot
			
			$action = New-ScheduledTaskAction -Execute 'Wmic.exe' -Argument "/namespace:\\root\ccm path sms_client CALL TriggerSchedule `"{00000000-0000-0000-0000-000000000021}`" /NOINTERACTIVE"
			$trigger =  New-ScheduledTaskTrigger -Once -AtStartup
			Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "ConfigMgr Client: Request  Machine Assignments" -Description "Request ConfigMgr Machine Policy"

			$action = New-ScheduledTaskAction -Execute 'Wmic.exe' -Argument "/namespace:\\root\ccm path sms_client CALL TriggerSchedule `"{00000000-0000-0000-0000-000000000022}`" /NOINTERACTIVE"
			$trigger =  New-ScheduledTaskTrigger -Once -AtStartup -RandomDelay '120'
			Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "ConfigMgr Client: Evaluate Machine Policies" -Description "Evaluate ConfigMgr Machine Policy"

			$action = New-ScheduledTaskAction -Execute 'Wmic.exe' -Argument "/namespace:\\root\ccm path sms_client CALL TriggerSchedule `"{00000000-0000-0000-0000-000000000123}`" /NOINTERACTIVE"
			$trigger =  New-ScheduledTaskTrigger -Once -AtLogon -RandomDelay '120'
			Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "ConfigMgr Client: Application manager global evaluation action" -Description "Evaluate ConfigMgr Application deployments"
		}
		Catch
		{
			Write-Log -Message "Warning: Failed to set up scheduled tasks" -Severity 2 -Source Check-PendingReboot
		}
		
		Show-InstallationRestartPrompt -CountdownSeconds $CountdownSeconds -CountdownNoHideSeconds $CountdownNoHideSeconds
		Exit-Script -ExitCode $ExitCode
	}
} # Check-PendingReboot

##*===============================================
##* END FUNCTION LISTINGS
##*===============================================

##*===============================================
##* SCRIPT BODY
##*===============================================

If ($scriptParentPath) {
	Write-Log -Message "Script [$($MyInvocation.MyCommand.Definition)] dot-source invoked by [$(((Get-Variable -Name MyInvocation).Value).ScriptName)]" -Source $appDeployToolkitExtName
}
Else {
	Write-Log -Message "Script [$($MyInvocation.MyCommand.Definition)] invoked directly" -Source $appDeployToolkitExtName
}

##*===============================================
##* END SCRIPT BODY
##*===============================================