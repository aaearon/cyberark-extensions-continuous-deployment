param(
    [Parameter(Mandatory=$true)]
    [string] $action,
	[Parameter(Mandatory=$true)]
    [string] $address,
	[Parameter(Mandatory=$true)]
	[string] $realvnctype,
	[Parameter(Mandatory=$true)]
    [string] $domain,
	[Parameter(Mandatory=$true)]
    [string] $extrapass3username, 
	[Parameter(Mandatory=$true)]
    [string] $path,
	[Parameter(Mandatory=$true)]
    [string] $ServiceRegistryPath	
)
$ErrorActionPreference = "stop"

Write-Host "Enter reconcile users password:"
$pmextrapass3 = [Console]::ReadLine()

switch ($realvnctype)
{
	Standard {break}
	AdminPassword {break}
	ViewOnlyPassword {break}
	InputOnlyPassword {break}
	GuestPassword {break}
	default {Write-Host "Invalid RealVNCType. Valid values are Standard, AdminPassword, ViewOnlyPassword, InputOnlyPassword, or GuestPassword." 
			 Exit}
}

$extrapass3username = $domain + "\" + $extrapass3username
$pmextrapass3 = ConvertTo-SecureString $pmextrapass3 -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential -ArgumentList $extrapass3username, $pmextrapass3

try
{
	$RemoteSession = New-PSSession -ComputerName $address -Credential $Credential
	Invoke-Command -Session $RemoteSession -ScriptBlock {cd $Using:path}
	
	switch($action)
	{
		verifypass
		{
			Write-Host "Enter current password:"
			$pmpass = [Console]::ReadLine()
			if ($realvnctype -eq "Standard"){$realvnctype = "password"}
			
			$passwordInRegistry = Invoke-Command -Session $RemoteSession -ScriptBlock {(Get-ItemProperty $Using:ServiceRegistryPath).$Using:realvnctype}			
			$printedPassword = Invoke-Command -Session $RemoteSession -ScriptBlock {$Using:pmpass | .\vncpasswd.exe -print} 
			$Password = $printedPassword.Substring(9)
			
			if ($passwordInRegistry -eq $Password){Write-Host "Passwords match"}else{Write-Host "Passwords do not match"}
		}
		reconcilepass
		{
			Write-Host "Enter new password:"
			$pmnewpass = [Console]::ReadLine()
			if ($realvnctype -eq "Standard"){$reconcilePassword =Invoke-Command -Session $RemoteSession -ScriptBlock {$Using:pmnewpass | .\vncpasswd.exe -Service}}
			else{$reconcilePassword = Invoke-Command -Session $RemoteSession -ScriptBlock {$Using:pmnewpass | .\vncpasswd.exe -Service -type $Using:realvnctype}}
			
			Write-Host $reconcilePassword
		}
	}
	Remove-PSSession -Session $RemoteSession
	Write-Host "PowerShell session is closed"
}	
catch
{
	Remove-PSSession -Session $RemoteSession
	Write-Host "PowerShell session is closed"
    Write-Host $_.Exception.Message
}