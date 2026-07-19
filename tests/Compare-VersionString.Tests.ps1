#requires -Version 5.1
<#
.SYNOPSIS
    Pester tests for Compare-VersionString.

.DESCRIPTION
    Compare-VersionString does a component-wise version comparison. It must
    NEVER treat "8.0.1" and "8.0.10" as equal - that bug would flag the live
    .NET installation as a leftover.
#>

BeforeAll {
    $env:PCREV_TEST_HARNESS = '1'
    # `$PSScriptRoot` is not reliably populated inside Pester 5.x BeforeAll
    # blocks under Windows PowerShell 5.1, so we resolve the project root
    # through `$Pester.BuildRoot` first (set by Pester 5 at discovery time),
    # and fall back to the parent of the tests/ directory otherwise.
    $projectRoot = $null
    if ($Pester -and $Pester.BuildRoot) { $projectRoot = $Pester.BuildRoot }
    elseif ($PSScriptRoot)              { $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }
    if (-not $projectRoot)              { $projectRoot = (Resolve-Path '.').Path }
    . (Join-Path $projectRoot 'patchCleanerRevisited.ps1')
    Remove-Item env:PCREV_TEST_HARNESS -ErrorAction SilentlyContinue
}

Describe 'Compare-VersionString' {

    Context 'Equality' {
        It 'returns 0 for identical versions' {
            Compare-VersionString -A '8.0.29' -B '8.0.29' | Should -Be 0
        }

        It 'returns 0 for identical versions with different padding' {
            Compare-VersionString -A '8.0.29' -B '8.0.029' | Should -Be 0
        }

        It 'treats missing components as zero' {
            Compare-VersionString -A '8.0' -B '8.0.0' | Should -Be 0
            Compare-VersionString -A '8' -B '8.0.0' | Should -Be 0
        }
    }

    Context 'Inequality - the anti-FP guard' {
        # The whole point of Compare-VersionString. Prefix-matching -like "8.0.1*"
        # would have wrongly flagged the live installation as a leftover.
        It 'distinguishes 8.0.1 from 8.0.10' {
            Compare-VersionString -A '8.0.1'  -B '8.0.10' | Should -BeLessThan 0
            Compare-VersionString -A '8.0.10' -B '8.0.1'  | Should -BeGreaterThan 0
        }

        It 'distinguishes 9.0 from 9.0.18' {
            Compare-VersionString -A '9.0'    -B '9.0.18' | Should -BeLessThan 0
            Compare-VersionString -A '9.0.18' -B '9.0'    | Should -BeGreaterThan 0
        }

        It 'distinguishes 10.0.100 from 10.0.1000' {
            Compare-VersionString -A '10.0.100'  -B '10.0.1000' | Should -BeLessThan 0
            Compare-VersionString -A '10.0.1000' -B '10.0.100'  | Should -BeGreaterThan 0
        }
    }

    Context 'Major / minor differences' {
        It 'returns -1 when A is older on the major axis' {
            Compare-VersionString -A '7.0.0' -B '8.0.0' | Should -BeLessThan 0
        }

        It 'returns 1 when A is newer on the minor axis' {
            Compare-VersionString -A '8.1.0' -B '8.0.0' | Should -BeGreaterThan 0
        }

        It 'returns -1 when A is older on the patch axis' {
            Compare-VersionString -A '8.0.9' -B '8.0.10' | Should -BeLessThan 0
        }
    }
}