#requires -Version 5.1
<#
.SYNOPSIS
    Pester tests for Test-InstalledVersion.

.DESCRIPTION
    Test-InstalledVersion is the LAST line of defence against deleting a live
    .NET runtime. A failure here would let the Leftovers Scanner flag
    C:\Program Files\dotnet\shared\Microsoft.NETCore.App\8.0.10 as a leftover
    because a removed package extracted "8.0.1" as a keyword.
#>

BeforeAll {
    $env:PCREV_TEST_HARNESS = '1'
    . (Join-Path $PSScriptRoot '..' 'patchCleanerRevisited.ps1')
    Remove-Item env:PCREV_TEST_HARNESS -ErrorAction SilentlyContinue
}

Describe 'Test-InstalledVersion' {

    Context 'Empty / null inputs' {
        It 'returns $false when InstalledVersions is null' {
            Test-InstalledVersion -Version '8.0.10' -InstalledVersions $null | Should -BeFalse
        }

        It 'returns $false when InstalledVersions is empty' {
            Test-InstalledVersion -Version '8.0.10' -InstalledVersions @{} | Should -BeFalse
        }

        It 'returns $false when Version is empty' {
            $installed = @{ 'Microsoft.NETCore.App' = @('8.0.10') }
            Test-InstalledVersion -Version '' -InstalledVersions $installed | Should -BeFalse
        }
    }

    Context 'Positive matches' {
        It 'returns $true for an exact version match' {
            $installed = @{ 'Microsoft.NETCore.App' = @('8.0.10') }
            Test-InstalledVersion -Version '8.0.10' -InstalledVersions $installed | Should -BeTrue
        }

        It 'returns $true when the version is in any component' {
            $installed = @{
                'Microsoft.NETCore.App'        = @('8.0.10')
                'Microsoft.AspNetCore.App'     = @('9.0.0')
                'Microsoft.WindowsDesktop.App' = @('9.0.0')
            }
            Test-InstalledVersion -Version '9.0.0' -InstalledVersions $installed | Should -BeTrue
        }
    }

    Context 'Negative matches - the anti-FP guard' {
        It 'does NOT match a shorter prefix' {
            $installed = @{ 'Microsoft.NETCore.App' = @('8.0.10') }
            Test-InstalledVersion -Version '8.0.1' -InstalledVersions $installed | Should -BeFalse
        }

        It 'does NOT match a longer version that has not been installed' {
            $installed = @{ 'Microsoft.NETCore.App' = @('8.0.10') }
            Test-InstalledVersion -Version '8.0.100' -InstalledVersions $installed | Should -BeFalse
        }

        It 'treats SDK and Templates entries as installed versions too' {
            $installed = @{
                'Microsoft.NETCore.App' = @('8.0.10')
                '__SDK__'              = @('8.0.402')
                '__TEMPLATES__'        = @('8.0.10')
            }
            Test-InstalledVersion -Version '8.0.402' -InstalledVersions $installed | Should -BeTrue
        }
    }
}