﻿# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

. $PSScriptRoot\New-ActionPlan.ps1
. $PSScriptRoot\New-ErrorContext.ps1
Function Test-KnownMsiIssuesCheck {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [object]
        $SetupLogReviewer
    )
    process {
        Write-Verbose "Calling: $($MyInvocation.MyCommand)"
        $contextOfError = $SetupLogReviewer | GetFirstErrorWithContextToLine -1 2

        if ($null -eq $contextOfError) {
            Write-Verbose "KnownMsiIssuesCheck - no known issue"
            return
        }
        $errorFound = $true
        $productError = $contextOfError | Select-String -Pattern "Couldn't remove product with code (.+). The installation source for this product is not available"

        if ($null -ne $productError) {
            Write-Verbose "Found MSI issue"
            return
        }

        $installingProductError = $contextOfError | Select-String -Pattern "\[ERROR\] Installing product .+ failed\. The installation source for this product is not available"

        if ($null -ne $installingProductError) {
            Write-Verbose "Found MSI Issue - installing product"
            return
        }

        $installFatalError = $contextOfError | Select-String -Pattern "\[ERROR\] Installing product .+\.msi failed\. Fatal error during installation\. Error code is 1603\."

        if ($null -ne $installFatalError) {
            Write-Verbose "Found MSI Issue - Fatal Error"
            return
        }

        $installingNewProduct = $contextOfError | Select-String -Pattern "Installing a new product\. Package: .+\.msi\. Property values"

        if ($null -ne $installingNewProduct) {
            Write-Verbose "Found trying to install product"
            $objectReferenceNotSet = $contextOfError | Select-String -Pattern "\[ERROR\] Object reference not set to an instance of an object\."

            if ($null -ne $objectReferenceNotSet) {
                Write-Verbose "Found MSI Issue - Object Reference Not Set"
                return
            }
        }

        $errorFound = $false
        Write-Verbose "KnownMsiIssuesCheck - no known issue"
    }
    end {
        if ($errorFound) {
            $contextOfError |
                Select-Object -First 10 |
                New-ErrorContext

            New-ActionPlan "Run FixInstallerCache.ps1 against $($SetupLogReviewer.LocalBuildNumber)"
        }
    }
}
