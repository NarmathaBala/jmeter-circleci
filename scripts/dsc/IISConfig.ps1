Configuration ConfigureWeb {
    Param(
        [parameter(Mandatory)]
        [string]
        $appContainerUrl,
        [parameter(Mandatory)]
        [string]
        $appZipFileName,
        [parameter(Mandatory)]
        [string]
        $sasToken
    )

    Import-DscResource -ModuleName xWebAdministration, xPSDesiredStateConfiguration, PSDesiredStateConfiguration

    node ("localhost")
    {
        WindowsFeature InstallWebServer 
        { 
            Ensure = "Present"
            Name   = "Web-Server" 
        }

        WindowsFeature WebManagementConsole {
            Name   = "Web-Mgmt-Console"
            Ensure = "Present"
        }

        WindowsFeature WebManagementService {
            Name   = "Web-Mgmt-Service"
            Ensure = "Present"
        }

        WindowsFeature ASPNet45 {
            Name   = "Web-Asp-Net45"
            Ensure = "Present"
        }

        xWebSite DefaultWebSite {
            Ensure          = "Present"
            Name            = "Default Web Site"
            SiteId          = 1
            State           = "Stopped"
            ServerAutoStart = $false
        }

        xRemoteFile DownloadArtifact
        {
            Uri             = "{0}/{1}?{2}" -f $appContainerUrl, $appZipFileName, $sasToken
            DestinationPath = "{0}\{1}" -f "C:\inetpub\wwwroot", $appZipFileName
        }

        Archive ExtractWebApp {
            Ensure      = "Present"
            Path        = "{0}\{1}" -f "C:\inetpub\wwwroot", $appZipFileName
            Destination = "C:\inetpub\wwwroot"
            Force       = $TRUE
            DependsOn   = "[xRemoteFile]DownloadArtifact"
        }

        xWebSite BofAProtoSvc {
            Ensure          = "Present"
            Name            = "BofA Proto Svc"
            SiteId          = 2
            State           = "Started"
            ServerAutoStart = $false
            PhysicalPath    = "C:\inetpub\wwwroot\bofaprotosvc"
            ApplicationPool = "DefaultAppPool"
            BindingInfo     = @(
                MSFT_xWebBindingInformation {
                    Protocol = "HTTP"
                    Port     = 80
                })
            DependsOn       = "[Archive]ExtractWebApp"
        }
    } 
}