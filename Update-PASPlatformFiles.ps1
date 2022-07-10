#requires -modules PoShPACLI

function Update-PASPlatformFiles {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]
        $PlatformId,

        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [string]
        $Path
    )

    begin {
        Open-PVSafe -safe PasswordManagerShared
    }

    process {

        if ($null -eq $PlatformId -or $PlatformId -eq "") {
            $PlatformId = (Get-Item $Path).Name
        }

        # Throw an error if the platform does not already exist in the Vault as adding the files effectively do nothing.
        if ($null -eq (Find-PVFile -safe PasswordManagerShared -folder root\Policies -filePattern "Policy-PlatformId.ini")) {
            throw "Platform $PlatformId not found in Vault. Aborting."
        }

        $CPMPolicyFile = Join-Path -Path $Path -ChildPath "Policy-$PlatformId.ini"
        $PVWASettingsFile = Join-Path -Path $Path -ChildPath "Policy-$PlatformId.xml"

        if (Test-Path -Path $CPMPolicyFile) {
            $CPMPolicyFile = Get-Item $CPMPolicyFile
            Add-PVFile -safe PasswordManagerShared -folder root\Policies -file $CPMPolicyFile.Name -localFolder $CPMPolicyFile.DirectoryName -localFile $CPMPolicyFile.Name
        }
        else {
            throw "CPM policy file not found: Policy-$PlatformId.ini"
        }

        if (Test-Path -Path $PVWASettingsFile) {
            $PVWASettingsFile = Get-Item $PVWASettingsFile
            Update-PoliciesXml -PVWASettingsFile $PVWASettingsFile.FullName -PlatformId $PlatformId
        }
        else {
            throw "PVWA settings file not found: Policy-$PlatformId.xml"
        }

        $PlatformWasImported = Get-PVFolder -safe PasswordManagerShared | Where-Object { $_.Folder -eq "Root\ImportedPlatforms\Policy-$PlatformId" }
        if ($PlatformWasImported) {
            foreach ($File in (Get-ChildItem -Path $Path)) {
                if ($File.Name -ne "Policy-$PlatformId.ini" -or $File.Name -ne "Policy-$PlatformId.xml") {
                    Add-PVFile -safe PasswordManagerShared -folder root\ImportedPlatforms\Policy-$PlatformId -file $File.Name -localFolder $File.DirectoryName -localFile $File.Name
                }
                else {
                    Write-Debug "Skipping file $($File.Name) as it was already added."
                }
            }
        }
        else {
            Write-Warning "Platform $PlatformId does not have a folder under Root\ImportedPlatforms. Skipping optional files."
        }

        Clear-Variable -Name PlatformId # TODO: I don't think this should be necessary
    }
    end {
        Close-PVSafe -safe PasswordManagerShared
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
    if ($null -ne $ExistingPolicyElement) {
        # Import the Policy element from the PVWASettingsFile to the PoliciesXml document.
        $NewPolicyElement = $PoliciesXml.ImportNode($PVWASettingsXml.SelectSingleNode("//*[@ID='$PlatformId']"), $true)

        # Add the new policy element we imported, replace the old one.
        # Can this be done better with .ReplaceChild()?
        $ExistingPolicyElement.ParentNode.AppendChild($NewPolicyElement)
        $ExistingPolicyElement.ParentNode.RemoveChild($ExistingPolicyElement)

        $PoliciesXml.Save($TemporaryFile.FullName)

        Add-PVFile -safe PVWAConfig -folder root -file 'Policies.xml' -localFolder $TemporaryFile.DirectoryName -localFile $TemporaryFile.Name
    } else {
        throw "Platform $PlatformId not found in Policies.xml"
    }
    Close-PVSafe -safe PVWAConfig

    return $PoliciesXml
}