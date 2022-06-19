
function Update-PASPlatformFiles {
    param (
        $PacliClientPath,
        $VaultAddress,
        $VaultCredential,
        $PlatformId,
        $CPMPolicyFile,
        $PVWASettingsFile,
        $Path
    )

    begin {
        Set-PVConfiguration -ClientPath $PacliClientPath
        Start-PVPacli
        New-PVVaultDefinition -vault $VaultAddress -address $VaultAddress -ErrorAction SilentlyContinue
        Connect-PVVault -user $($VaultCredential.UserName) -password $($VaultCredential.Password)
        Open-PVSafe -safe PasswordManagerShared
    }

    process {
        $Files = Get-ChildItem -Path $Path

        foreach ($File in $Files) {
            if ($File.Name -eq (Get-ChildItem $CPMPolicyFile).Name) {
                Add-PVFile -safe PasswordManagerShared -folder root\Policies -file $File.Name -localFolder $File.DirectoryName -localFile $File.Name
            } elseif ($File.Name -eq (Get-ChildItem $PVWASettingsFile).Name) {
               # Do something some day? Download Policies.xml, replace what is in Policies.xml with what is in PVWASettingsFile, then upload?
            } else {
                Add-PVFile -safe PasswordManagerShared -folder root\ImportedPlatforms\Policy-$PlatformId -file $File.Name -localFolder $File.DirectoryName -localFile $File.Name
            }
        }
    }

    end {
        Close-PVSafe -safe PasswordManagerShared
        Disconnect-PVVault
        Stop-PVPacli
    }
}