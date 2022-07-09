BeforeAll {
    . $PSScriptRoot\..\Update-PASPlatformFiles.ps1

    Mock -CommandName Test-Path -MockWith { return $true }
    Mock -CommandName Set-PVConfiguration
    Mock -CommandName Start-PVPacli
    Mock -CommandName New-PVVaultDefinition
    Mock -CommandName Connect-PVVault
    Mock -CommandName Open-PVSafe
    Mock -CommandName Add-PVFile
    Mock -CommandName Close-PVSafe
    Mock -CommandName Disconnect-PVVault
    Mock -CommandName Stop-PVPacli

    Mock -CommandName Get-PVFile

    $VaultCredential = New-Object System.Management.Automation.PSCredential ('username', (ConvertTo-SecureString -String 'password' -AsPlainText -Force))
}

Describe 'Update-PASPlatformFiles' {
    BeforeAll {
        # Create a dummy platform and structure for the test
        $PlatformId = 'SamplePlatform'
        $PlatformDirectory = New-Item -Path (Join-Path -Path $TestDrive -ChildPath $PlatformId) -ItemType Directory
        # Create the required parts of a platform
        $PlatformCPMPolicyFile = Join-Path -Path $PlatformDirectory -ChildPath "Policy-$PlatformId.ini"
        Out-File -FilePath $PlatformCPMPolicyFile -Force
        $PlatformPVWASettingsFile = Join-Path -Path $PlatformDirectory -ChildPath "Policy-$PlatformId.xml"
        Out-File -FilePath $PlatformPVWASettingsFile -Force
        # Optional files
        Out-File -FilePath (Join-Path -Path $PlatformDirectory -ChildPath "$($PlatformId)Process.ini") -Force
        Out-File -FilePath (Join-Path -Path $PlatformDirectory -ChildPath "$($PlatformId)Prompts.ini") -Force

    }
    It 'assumes the PlatformID based on the directory name' -Skip {

    }
    Context 'when updating existing platforms' {

        It 'must add the CPM policy file to the Vault' {
            Mock -CommandName Update-PoliciesXml

            Update-PASPlatformFiles `
                -PacliClientPath C:\PACLI\Pacli.exe `
                -VaultAddress 192.168.0.50 `
                -VaultCredential $VaultCredential `
                -PlatformId $PlatformId `
                -CPMPolicyFile $PlatformCPMPolicyFile `
                -PVWASettingsFile $PlatformPVWASettingsFile `
                -Path $PlatformDirectory

            Should -Invoke -CommandName Add-PVFile -ParameterFilter {
                $safe -eq 'PasswordManagerShared' -and
                $folder -eq 'root\Policies' -and
                $file -eq "Policy-$PlatformId.ini" -and
                $localFolder -eq $PlatformDirectory -and
                $localFile -eq "Policy-$PlatformId.ini"
            }
        }
        It 'must merge the PVWA settings file into Policies.xml' {
            Mock -CommandName Update-PoliciesXml

            Update-PASPlatformFiles `
                -PacliClientPath C:\PACLI\Pacli.exe `
                -VaultAddress 192.168.0.50 `
                -VaultCredential $VaultCredential `
                -PlatformId $PlatformId `
                -CPMPolicyFile $PlatformCPMPolicyFile `
                -PVWASettingsFile $PlatformPVWASettingsFile `
                -Path $PlatformDirectory

            Should -Invoke -CommandName Update-PoliciesXml -ParameterFilter {
                $PVWASettingsFile -eq $PlatformPVWASettingsFile -and
                $PlatformId -eq $PlatformId }
        }
        It 'must add the new Policies.xml to the Vault' -Skip {
            Should -Invoke -CommandName  Add-PVFile -ParameterFilter {
                $safe -eq 'PVWAConfig'
                -and $folder -eq 'root'
                -and $file -eq 'Policies.xml'
            }
        }
    }
}