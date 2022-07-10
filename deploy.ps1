param (
    [string]$PACLIClientPath,
    [PSCredential]$VaultCredential,
    [string]$VaultAddress,
    [string]$BasePlatformFolder
)

Import-Module PoShPACLI

. .\Update-PASPlatformFiles

Set-PVConfiguration -ClientPath $PACLIClientPath
Start-PVPacli
New-PVVaultDefinition -vault $VaultAddress -address $VaultAddress -ErrorAction SilentlyContinue
Connect-PVVault -user $($VaultCredential.UserName) -password $($VaultCredential.Password)

(Get-ChildItem $BasePlatformFolder).FullName | Update-PASPlatformFiles

Disconnect-PVVault
Stop-PVPacli
