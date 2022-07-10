BeforeAll {
    . $PSScriptRoot\..\Update-PASPlatformFiles.ps1

    Mock -CommandName Open-PVSafe
    Mock -CommandName Add-PVFile
    Mock -CommandName Close-PVSafe

}

Describe 'Update-PASPlatformFiles' {
    BeforeAll {
        Mock -CommandName Update-PoliciesXml
        Mock -CommandName Get-PVFile

        Mock -CommandName Find-PVFile -MockWith { $true }
        Mock -CommandName Get-PVFolder -MockWith { return [PSCustomObject]@{
                Folder = "Root\ImportedPlatforms\Policy-$PlatformId"
            }
        }

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
    It 'assumes the PlatformID based on the directory name' {
        Update-PASPlatformFiles -Path $PlatformDirectory

        Should -Invoke -CommandName Add-PVFile -ParameterFilter {
            $safe -eq 'PasswordManagerShared' -and
            $folder -eq 'root\Policies' -and
            $file -eq "Policy-$PlatformId.ini" -and
            $localFolder -eq $PlatformDirectory -and
            $localFile -eq "Policy-$PlatformId.ini"
        }
    }

    It 'takes a list of platform folders and updates the files' {
        # Create a second dummy platform and structure for the test
        $PlatformId2 = 'SamplePlatform2'
        $PlatformDirectory2 = New-Item -Path (Join-Path -Path $TestDrive -ChildPath $PlatformId2) -ItemType Directory
        # Create the required parts of a platform
        $PlatformCPMPolicyFile2 = Join-Path -Path $PlatformDirectory2 -ChildPath "Policy-$PlatformId2.ini"
        Out-File -FilePath $PlatformCPMPolicyFile2 -Force
        $PlatformPVWASettingsFile2 = Join-Path -Path $PlatformDirectory2 -ChildPath "Policy-$PlatformId2.xml"
        Out-File -FilePath $PlatformPVWASettingsFile2 -Force

        (Get-ChildItem $TestDrive).FullName | Update-PASPlatformFiles

        Should -Invoke -CommandName Add-PVFile -ParameterFilter {
            $safe -eq 'PasswordManagerShared' -and
            $folder -eq 'root\Policies' -and
            $file -eq "Policy-$PlatformId.ini" -and
            $localFolder -eq $PlatformDirectory -and
            $localFile -eq "Policy-$PlatformId.ini"
        }

        Should -Invoke -CommandName Add-PVFile -ParameterFilter {
            $safe -eq 'PasswordManagerShared' -and
            $folder -eq 'root\Policies' -and
            $file -eq "Policy-$PlatformId2.ini" -and
            $localFolder -eq $PlatformDirectory2 -and
            $localFile -eq "Policy-$PlatformId2.ini"
        }
    }

    Context 'when updating existing platforms' {

        It 'must throw an exception if the platform is not found in the Vault' {
            Mock -CommandName Find-PVFile -MockWith { $null }

            { Update-PASPlatformFiles -PlatformId banana -Path $PlatformDirectory } | Should -throw "Platform banana not found in Vault. Aborting."
        }

        It 'must add the CPM policy file to the Vault' {
            Update-PASPlatformFiles -PlatformId $PlatformId -Path $PlatformDirectory

            Should -Invoke -CommandName Add-PVFile -ParameterFilter {
                $safe -eq 'PasswordManagerShared' -and
                $folder -eq 'root\Policies' -and
                $file -eq "Policy-$PlatformId.ini" -and
                $localFolder -eq $PlatformDirectory -and
                $localFile -eq "Policy-$PlatformId.ini"
            }
        }
        It 'must add any optional files to the Vault' {
            Update-PASPlatformFiles -PlatformId $PlatformId -Path $PlatformDirectory

            Should -Invoke -CommandName Add-PVFile -ParameterFilter {
                $safe -eq 'PasswordManagerShared' -and
                $folder -eq "root\ImportedPlatforms\Policy-$PlatformId" -and
                $file -eq "$($PlatformId)Process.ini" -and
                $localFolder -eq $PlatformDirectory -and
                $localFile -eq "$($PlatformId)Process.ini"
            }

            Should -Invoke -CommandName Add-PVFile -ParameterFilter {
                $safe -eq 'PasswordManagerShared' -and
                $folder -eq "root\ImportedPlatforms\Policy-$PlatformId" -and
                $file -eq "$($PlatformId)Prompts.ini" -and
                $localFolder -eq $PlatformDirectory -and
                $localFile -eq "$($PlatformId)Prompts.ini"
            }
        }

        It 'does not add optional files to the Vault if the platform was not imported' {
            Mock -CommandName Get-PVFolder -MockWith { $null }
            Mock -CommandName Write-Warning

            Update-PASPlatformFiles -PlatformId $PlatformId -Path $PlatformDirectory

            Should -Not -Invoke -CommandName Add-PVFile -ParameterFilter {
                $safe -eq 'PasswordManagerShared' -and
                $folder -eq "root\ImportedPlatforms\Policy-$PlatformId" -and
                $file -eq "$($PlatformId)Process.ini" -and
                $localFolder -eq $PlatformDirectory -and
                $localFile -eq "$($PlatformId)Process.ini"
            }

            Should -Not -Invoke -CommandName Add-PVFile -ParameterFilter {
                $safe -eq 'PasswordManagerShared' -and
                $folder -eq "root\ImportedPlatforms\Policy-$PlatformId" -and
                $file -eq "$($PlatformId)Prompts.ini" -and
                $localFolder -eq $PlatformDirectory -and
                $localFile -eq "$($PlatformId)Prompts.ini"
            }

            Should -Invoke -CommandName Write-Warning
        }

        It 'must merge the PVWA settings file into Policies.xml' {
            Update-PASPlatformFiles -PlatformId $PlatformId -Path $PlatformDirectory

            Should -Invoke -CommandName Update-PoliciesXml -ParameterFilter {
                $PVWASettingsFile -eq $PlatformPVWASettingsFile -and
                $PesterBoundParameters.PlatformId -eq $PlatformId
            }

        }
    }
}

Describe 'Update-PoliciesXml' {
    BeforeAll {
        Mock -CommandName Get-PVFile
        Mock -CommandName Get-Content -ParameterFilter {$Path -like '*.tmp' } -MockWith { return (Get-Content -Path 'Tests\Policies.xml') }

    }
    It 'validates that the platform exists in Policies.xml' {
        { Update-PoliciesXml -PVWASettingsFile 'Tests\Policy-RealVNCServiceMode.xml' -PlatformId 'RealVNCServiceMode' } | Should -Not -throw "Platform RealVNCServiceMode not found in Policies.xml"

        { Update-PoliciesXml -PVWASettingsFile 'Tests\Policy-RealVNCServiceMode.xml' -PlatformId 'RealVNCServiceModeNotExisting' } | Should -throw "Platform RealVNCServiceModeNotExisting not found in Policies.xml"
    }

    It 'replaces the platform content in Policies.xml with the content in the PVWA settings file' {
        $PoliciesXml = Update-PoliciesXml -PVWASettingsFile 'Tests\Policy-RealVNCServiceMode.xml' -PlatformId 'RealVNCServiceMode'
        (Select-Xml -Xml $PoliciesXml -XPath '//*[@ID="RealVNCServiceMode"]/Properties/Optional/Property[@Name="Banana"]')[0] | Should -Be $true
    }

    It 'adds the new Policies.xml to the Vault' {
        Update-PoliciesXml -PVWASettingsFile 'Tests\Policy-RealVNCServiceMode.xml' -PlatformId 'RealVNCServiceMode'

        Should -Invoke -CommandName Add-PVFile -ParameterFilter {
            $safe -eq 'PVWAConfig' -and
            $folder -eq 'root' -and
            $file -eq 'Policies.xml'
        }
    }
}