param (
    [string]$PACLIClientPath,
    [PSCredential]$VaultCredential,
    [string]$VaultAddress,
    [string]$BasePlatformFolder
)

Import-Module PoShPACLI
Import-Module .\deploy-pasextensions\Deploy-PASExtensions\Deploy-PASExtensions.psd1

Set-PVConfiguration -ClientPath $PACLIClientPath
Start-PVPacli
New-PVVaultDefinition -vault $VaultAddress -address $VaultAddress -ErrorAction SilentlyContinue
Connect-PVVault -user $($VaultCredential.UserName) -password $($VaultCredential.Password)

(Get-ChildItem $BasePlatformFolder).FullName | Update-PASPlatformFiles

Disconnect-PVVault
Stop-PVPacli
