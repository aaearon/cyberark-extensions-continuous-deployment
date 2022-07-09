
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
                Update-PoliciesXml -PVWASettingsFile $PVWASettingsFile -PlatformId $PlatformId
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

function Update-PoliciesXml {
    param (
        $PVWASettingsFile,
        $PlatformId
    )

    $TemporaryFile = New-TemporaryFile

    Open-PVSafe -safe PVWAConfig
    Get-PVFile -safe PVWAConfig -folder root -file Policies.xml -localFolder $TemporaryFile.DirectoryName -localFile $TemporaryFile.Name

    $PoliciesXml =  [xml](Get-Content $TemporaryFile)
    $PVWASettingsXml = [xml](Get-Content $PVWASettingsFile)

    # Search via PlatformId as it could be a Policy, Usage, whatever.
    $ExistingPolicyElement = $PoliciesXml.SelectSingleNode("//*[@ID='$PlatformId']")
    # Import the Policy element from the PVWASettingsFile to the PoliciesXml document.
    $NewPolicyElement = $PoliciesXml.ImportNode($PVWASettingsXml.SelectSingleNode("//*[@ID='$PlatformId']"), $true)

    # Add the new policy element we imported, replace the old one.
    # Can this be done better with .ReplaceChild()?
    $ExistingPolicyElement.ParentNode.AppendChild($NewPolicyElement)
    $ExistingPolicyElement.ParentNode.RemoveChild($ExistingPolicyElement)

    $PoliciesXml.Save($TemporaryFile.FullName)

    Add-PVFile -safe PVWAConfig -folder root -file 'Policies.xml' -localFolder $TemporaryFile.DirectoryName -localFile $TemporaryFile.Name
    Close-PVSafe -safe PVWAConfig
}