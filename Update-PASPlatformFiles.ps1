﻿#requires -modules PoShPACLI

function Update-PASPlatformFiles {
    param (
        $PacliClientPath,
        $VaultAddress,
        $VaultCredential,
        $PlatformId,
        $CPMPolicyFile,
        $PVWASettingsFile,

        [Parameter(Mandatory = $true)]
        [string]
        $PlatformFolder
    )

    begin {
        Set-PVConfiguration -ClientPath $PacliClientPath
        Start-PVPacli
        New-PVVaultDefinition -vault $VaultAddress -address $VaultAddress -ErrorAction SilentlyContinue
        Connect-PVVault -user $($VaultCredential.UserName) -password $($VaultCredential.Password)
        Open-PVSafe -safe PasswordManagerShared
    }

    process {

        $CPMPolicyFile = Join-Path -Path $PlatformFolder -ChildPath "Policy-$PlatformId.ini"
        $PVWASettingsFile = Join-Path -Path $PlatformFolder -ChildPath "Policy-$PlatformId.xml"

        if (Test-Path -Path $CPMPolicyFile) {
            $CPMPolicyFile = Get-ChildItem $CPMPolicyFile
            Add-PVFile -safe PasswordManagerShared -folder root\Policies -file $CPMPolicyFile.Name -localFolder $CPMPolicyFile.DirectoryName -localFile $CPMPolicyFile.Name
        }
        else {
            throw "CPM policy file not found: Policy-$PlatformId.ini"
        }

        if (Test-Path -Path $PVWASettingsFile) {
            $PVWASettingsFile = Get-ChildItem $PVWASettingsFile
            Update-PoliciesXml -PVWASettingsFile $PVWASettingsFile.FullName -PlatformId $PlatformId
        }
        else {
            throw "PVWA settings file not found: Policy-$PlatformId.xml"
        }

        foreach ($File in (Get-ChildItem -Path $PlatformFolder)) {
            if ($File.Name -ne "Policy-$PlatformId.ini" -or $File.Name -ne "Policy-$PlatformId.xml") {
                Add-PVFile -safe PasswordManagerShared -folder root\ImportedPlatforms\Policy-$PlatformId -file $File.Name -localFolder $File.DirectoryName -localFile $File.Name
            }
            else {
                Write-Debug "Skipping file: $($File.Name)"
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

    $PoliciesXml = [xml](Get-Content $TemporaryFile)
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