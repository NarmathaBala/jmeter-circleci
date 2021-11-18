#!/usr/bin/env bash
##
## This script creates the BofA prototype service environment infrastructure
## Usage: ./env_setup.sh <env>
## Example: ./env_setup.sh dev
##
## Resources include:
## - Resource group
## - VNET
## - PIP
## - Bastion host
## - Storage account / Container
## - VMSS
##
## DSC resources include:
## - init.ps1
## - IIConfig.ps1
##
## Dependencies:
## - BofA prototype service deployment zip

(
    # Configure environment variables
    if [ -f .env ]
    then
        set -o allexport; source .env; set +o allexport
    fi

    cd "$(dirname "$0")/.." || exit
    set -euo pipefail

    # Set service principal information
    echo "#### Exporting SP as environment variables ####"
    subscription_id="${AZURE_SUBSCRIPTION_ID}"
    tenant_id="${TENANT_ID}"
    service_principal_id="${SERVICE_PRINCIPAL_ID}"
    service_principal_secret="${SERVICE_PRINCIPAL_SECRET}"

    app_container_url="${APP_CONTAINER_URL}"
    app_zip_filename="${APP_ZIP_FILENAME}"
    sas_token="${SAS_TOKEN}"

    owner_email="${OWNER_EMAIL}"
    resource_name_prefix="${RESOURCE_NAME_PREFIX}"
    storage_name_prefix="${STORAGE_NAME_PREFIX}"
    scale_set="${SCALE_SET}"

    admin_user="${ADMIN_USER}"
    admin_password="${ADMIN_PASSWORD}"

    # Set resource variables
    resource_group="${RESOURCE_NAME_PREFIX}-$1-rg"
    storage_name="${STORAGE_NAME_PREFIX}$1stor"

    location="${LOCATION}"

    # Login to Azure via Service Principal
    echo "#### Attempting az login via service principal ####"
    az login \
        --service-principal \
        --username="$service_principal_id" \
        --password="$service_principal_secret" \
        --tenant="$tenant_id" >/dev/null

    az account set -s "$subscription_id"
    echo "#### az login done ####"

    # Create resource group
    echo "#### Creating resource resource group - ${resource_group} ####"
    az group create \
        --name "$resource_group" \
        --location "$location" \
        --tags "Owner=$owner_email"

    # Create VNET
    echo "#### Creating VNET ####"
    az network vnet create \
        --resource-group "$resource_group" \
        --name "${resource_name_prefix}-vnet" \
        --address-prefix 10.1.0.0/16 \
        --subnet-name FrontEnd \
        --subnet-prefix 10.1.0.0/24 \
        --location "$location"

    # Create bastion subnet
    echo "#### Creating VNET AzureBastionSubnet ####"
    az network vnet subnet create \
        --address-prefixes "10.1.1.0/26" \
        --name AzureBastionSubnet \
        --resource-group "$resource_group" \
        --vnet-name "${resource_name_prefix}-vnet"

    # Create public IP
    echo "#### Creating public IP ####"
    az network public-ip create \
        --resource-group "$resource_group" \
        --name "${resource_name_prefix}-pip" \
        --sku Standard \
        --location "$location"

    # Create Bastion host
    echo "#### Creating Bastion host ####"
    az network bastion create \
        --name "${resource_name_prefix}-bh" \
        --public-ip-address "${resource_name_prefix}-pip" \
        --resource-group "$resource_group" \
        --vnet-name "${resource_name_prefix}-vnet" \
        --location "$location" \
        # --scale-units "2"

    # Create storage account
    echo "#### Creating storage account ####"
    az storage account create \
        --name "$storage_name" \
        --resource-group "$resource_group" \
        --location "$location" \
        --sku Standard_LRS

    # Get storage account key
    account_key=$( \
        az storage account keys list \
            --resource-group "$resource_group" \
            --account-name "$storage_name" \
            --query "[?keyName=='key1'].value" \
            --output tsv)

    # Create dsc container
    echo "#### Creating dsc container ####"
    az storage container create \
        --account-name "$storage_name" \
        --account-key "$account_key" \
        --name dsc

    # Upload init.ps1 zip
    echo "#### Upload init.ps1 ####"
    az storage blob upload \
        --account-name "$storage_name" \
        --account-key "$account_key" \
        --container-name dsc \
        --file scripts/dsc/init.ps1 \
        --name init.ps1

    # Create IISConfig.ps1 zip
    zip -rj scripts/dsc/IISConfig.ps1.zip scripts/dsc/IISConfig.ps1

    # Upload IISConfig.ps1 zip
    echo "#### Upload IISConfig.ps1.zip ####"
    az storage blob upload \
        --account-name "$storage_name" \
        --account-key "$account_key" \
        --container-name dsc \
        --file scripts/dsc/IISConfig.ps1.zip \
        --name IISConfig.ps1.zip

    # Create sas token
    echo "#### Creating sas token ####"
    # expiry_date=$(date -v+1d +"%Y-%m-%d")
    expiry_date=2021-11-20
    dsc_sas_token=$( \
        az storage container generate-sas \
            --account-name "$storage_name" \
            --account-key "$account_key" \
            --name dsc \
            --https-only \
            --permissions r \
            --expiry "$expiry_date" \
            --output tsv)

    # Create VMSS
    echo "#### Creating VMSS ####"
    az vmss create \
        --resource-group "$resource_group" \
        --name "$scale_set" \
        --image MicrosoftWindowsServer:WindowsServer:2019-Datacenter:latest \
        --upgrade-policy-mode automatic \
        --admin-username "$admin_user" \
        --admin-password "$admin_password" \
        --generate-ssh-keys \
        --vnet-name "${resource_name_prefix}-vnet" \
        --subnet "FrontEnd" \
        --tags datadog=monitored

# Create CustomScriptExtension settings
customScriptExtensionSettings=$(cat <<EOF
{
    "fileUris": ["https://${storage_name}.blob.core.windows.net/dsc/init.ps1?${dsc_sas_token}"],
    "commandToExecute": "powershell -ExecutionPolicy Unrestricted -File init.ps1"
}
EOF
)

    # Set CustomScriptExtension on VMSS
    echo "#### Setting VMSS CustomScriptExtension ####"
    az vmss extension set \
        --publisher Microsoft.Compute \
        --version 1.10 \
        --name CustomScriptExtension \
        --resource-group "$resource_group" \
        --vmss-name "$scale_set" \
        --settings "$customScriptExtensionSettings"

# Configure DSC settings
dscSettings=$(cat <<EOF
{
    "configuration": {
        "url": "https://${storage_name}.blob.core.windows.net/dsc/IISConfig.ps1.zip",
        "script": "IISConfig.ps1",
        "function": "ConfigureWeb"
    }
}
EOF
)

# Configure DSC protected settings
dscProtectedSettings=$(cat <<EOF
{
    "configurationArguments": {
        "appContainerUrl": "$app_container_url",
        "appZipFileName": "$app_zip_filename",
        "sasToken": "$sas_token"
    },
    "configurationUrlSasToken": "?$dsc_sas_token"
}
EOF
)

    # Set DSC on VMSS
    echo "#### Setting VMSS DSC ####"
    az vmss extension set \
        --publisher Microsoft.Powershell \
        --version 2.9 \
        --name DSC \
        --resource-group "$resource_group" \
        --vmss-name "$scale_set" \
        --settings "$dscSettings" \
        --protected-settings "$dscProtectedSettings"

    # Allow traffic to app
    echo "#### Setting VMSS lb rule ####"
    az network lb rule create \
        --resource-group "$resource_group" \
        --name myLoadBalancerRuleWeb \
        --lb-name "${scale_set}LB" \
        --backend-pool-name "${scale_set}LBBEPool" \
        --backend-port 80 \
        --frontend-ip-name loadBalancerFrontEnd \
        --frontend-port 80 \
        --protocol tcp

    # Show public ip
    az network public-ip show \
        --resource-group "$resource_group" \
        --name "${scale_set}LBPublicIP" \
        --query '[ipAddress]' \
        --output tsv
)
