#requires -Version 5.1
<#
.SYNOPSIS
    Pester tests for Get-PackageKeywords.

.DESCRIPTION
    Get-PackageKeywords extracts the keywords used by the Leftovers Scanner to
    decide which files / registry entries are candidate leftovers. Two failures
    must never happen:
      - "microsoft" appearing as a primary keyword (would trigger FP everywhere)
      - a version-only match producing a hit (would mark live installs as leftovers)
#>

BeforeAll {
    $env:PCREV_TEST_HARNESS = '1'
    . (Join-Path $PSScriptRoot '..' 'patchCleanerRevisited.ps1')
    Remove-Item env:PCREV_TEST_HARNESS -ErrorAction SilentlyContinue
}

Describe 'Get-PackageKeywords' {

    Context 'Primary keywords' {
        It 'extracts distinctive words from a .NET package' {
            $pkg = [PSCustomObject]@{
                Subject = 'Microsoft .NET Runtime - 8.0.1 (x64)'
                Title   = '.NET Runtime'
                Name    = 'Microsoft .NET Runtime'
                Author  = 'Microsoft'
            }
            $result = Get-PackageKeywords -Package $pkg
            $result.Primary | Should -Contain 'Runtime'
            $result.Primary | Should -Contain 'NET'
        }

        It 'excludes stop words (case-insensitive)' {
            $pkg = [PSCustomObject]@{
                Subject = 'Microsoft Update for Windows (KB5034441)'
                Title   = 'Cumulative Update'
                Name    = 'Cumulative Update for Windows'
                Author  = 'Microsoft Corporation'
            }
            $result = Get-PackageKeywords -Package $pkg
            $primaryLower = $result.Primary | ForEach-Object { $_.ToLower() }
            # Confirmed stop words: see $script:LeftoverStopWords in
            # patchCleanerRevisited.ps1. The keyword list is intentionally small
            # to avoid hiding distinctive names.
            $primaryLower | Should -Not -Contain 'the'
            $primaryLower | Should -Not -Contain 'for'
            $primaryLower | Should -Not -Contain 'and'
            $primaryLower | Should -Not -Contain 'microsoft'
            $primaryLower | Should -Not -Contain 'corporation'
            $primaryLower | Should -Not -Contain 'update'
            # 'windows' is NOT a stop word by design - it is sometimes the most
            # distinctive keyword available for Windows-only installers.
        }

        It 'returns unique primary keywords only' {
            $pkg = [PSCustomObject]@{
                Subject = 'My Tool My Tool My Tool'
                Title   = ''
                Name    = ''
                Author  = ''
            }
            $result = Get-PackageKeywords -Package $pkg
            ($result.Primary | Where-Object { $_ -eq 'Tool' }).Count | Should -Be 1
        }

        It 'drops tokens shorter than 3 characters' {
            $pkg = [PSCustomObject]@{
                Subject = 'x64 Go Go Go'
                Title   = ''
                Name    = ''
                Author  = ''
            }
            $result = Get-PackageKeywords -Package $pkg
            $result.Primary | Should -Not -Contain 'x64'
            $result.Primary | Should -Not -Contain 'Go'
        }
    }

    Context 'Version keywords' {
        It 'extracts two-component versions' {
            $pkg = [PSCustomObject]@{
                Subject = 'Microsoft .NET Runtime - 8.0.10 (x64)'
                Title   = ''
                Name    = ''
                Author  = ''
            }
            $result = Get-PackageKeywords -Package $pkg
            $result.Versions | Should -Contain '8.0.10'
        }

        It 'extracts three-component versions' {
            $pkg = [PSCustomObject]@{
                Subject = 'KB5034441 10.0.22631'
                Title   = ''
                Name    = ''
                Author  = ''
            }
            $result = Get-PackageKeywords -Package $pkg
            $result.Versions | Should -Contain '10.0.22631'
        }

        It 'returns unique version keywords only' {
            $pkg = [PSCustomObject]@{
                Subject = '8.0.1 8.0.1 8.0.1'
                Title   = ''
                Name    = ''
                Author  = ''
            }
            $result = Get-PackageKeywords -Package $pkg
            ($result.Versions | Where-Object { $_ -eq '8.0.1' }).Count | Should -Be 1
        }

        It 'returns empty version list when no version-like tokens are present' {
            $pkg = [PSCustomObject]@{
                Subject = 'Some Random Software'
                Title   = ''
                Name    = ''
                Author  = ''
            }
            $result = Get-PackageKeywords -Package $pkg
            $result.Versions | Should -BeNullOrEmpty
        }
    }

    Context 'Anti-FP guardrails' {
        It 'does not leak "microsoft" into primary keywords' {
            $pkg = [PSCustomObject]@{
                Subject = 'Microsoft Visual C++ Redistributable'
                Title   = ''
                Name    = ''
                Author  = 'Microsoft'
            }
            $result = Get-PackageKeywords -Package $pkg
            $primaryLower = $result.Primary | ForEach-Object { $_.ToLower() }
            $primaryLower | Should -Not -Contain 'microsoft'
        }

        It 'separates primary and version keywords (versions alone must not match)' {
            $pkg = [PSCustomObject]@{
                Subject = 'Microsoft .NET Runtime - 8.0.10 (x64)'
                Title   = ''
                Name    = ''
                Author  = ''
            }
            $result = Get-PackageKeywords -Package $pkg
            $result.Versions | Should -Contain '8.0.10'
            $result.Versions | Should -Not -BeIn $result.Primary
        }
    }
}