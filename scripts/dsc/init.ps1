[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Function Confirm-DscModule {
    Param([string] $ModuleName)

    if (Get-Module -ListAvailable -Name $ModuleName) {
        Write-Warning "$ModuleName module is already installed."
    }
    else {
        Write-Output ""
        Write-Output "$ModuleName module does not exist, installing..."

        Find-Module -Name $ModuleName | Install-Module
        Find-DscResource -ModuleName $ModuleName
    }
}

# Nuget Package Provider is installed for installation of DSC modules
if (Get-PackageProvider | Where-Object Name -eq "nuget") {
    Write-Warning "Nuget package provider is already installed."
}
else {
    Write-Output "Nuget package provider was not found, installing..."
    Install-PackageProvider -Name "NuGet" -RequiredVersion "2.8.5.201" -Force
}

# Temporarily trust
Write-Output "Temporarily trusting powershell repository 'PSGallery'..."
Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted

# Ensure the required modules are installed
Confirm-DscModule -ModuleName xPSDesiredStateConfiguration
Confirm-DscModule -ModuleName xWebAdministration

Write-Output "Untrusting powershell repository 'PSGallery'..."
Set-PSRepository -Name "PSGallery" -InstallationPolicy Untrusted
