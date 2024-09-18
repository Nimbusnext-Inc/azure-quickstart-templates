@description('Name of Azure Web App')
param siteName string = 'sonarqube-${uniqueString(resourceGroup().id)}'

@description('The version of the Sonarqube container image to use. Only recent versions of Sonarqube which uses the new variables prefix and can run, as development purposes, with Azure App Service Web App for Containers.')
@allowed([
  '10.5-community'
  '10.4-community'
  '10.3-community'
  '10.2-community'
  '10.1-community'
  '10.0-community'
  '9.9-community'
  '9.8-community'
  '9.7-community'
  '9.6-community'
  '8.9-community'
  'latest'
])
param sonarqubeImageVersion string = '10.5-community'

@description('App Service Plan Pricing Tier')
@allowed([
  'B1'
  'B2'
  'B3'
  'S1'
  'S2'
  'S3'
  'P1V2'
  'P2V2'
  'P2V3'
])
param servicePlanPricingTier string = 'S2'

@description('App Service Capacity')
@minValue(1)
@maxValue(3)
param servicePlanCapacity int = 1

@description('Azure SQL Server Administrator Username')
@minLength(1)
param sqlServerAdministratorUsername string

@description('Azure SQL Server Administrator Password')
@minLength(12)
@maxLength(128)
@secure()
param sqlServerAdministratorPassword string

@description('Azure SQL Database SKU Name')
@allowed([
  'GP_S_Gen5_1'
  'GP_S_Gen5_2'
  'GP_S_Gen5_4'
  'HS_Gen5_1'
  'HS_Gen5_2'
  'HS_Gen5_4'
])
param sqlDatabaseSkuName string = 'GP_S_Gen5_2'

@description('Azure SQL Database Storage Max Size in GB')
@minValue(1)
@maxValue(1024)
param sqlDatabaseSkuSizeGB int = 16

@description('Location for all the resources.')
@allowed(
  [
    'eastus2'
    'eastus'
  ]
)
param location string

var databaseName = 'sonarqube'
var sqlServerName = '${siteName}-sql'
var servicePlanName = '${siteName}-asp'
var servicePlanPricingTiers = {
  F1: {
    tier: 'Free'
  }
  B1: {
    tier: 'Basic'
  }
  B2: {
    tier: 'Basic'
  }
  B3: {
    tier: 'Basic'
  }
  S1: {
    tier: 'Standard'
  }
  S2: {
    tier: 'Standard'
  }
  S3: {
    tier: 'Standard'
  }
  P1V2: {
    tier: 'Standard'
  }
  P2V2: {
    tier: 'Standard'
  }
  P2V3: {
    tier: 'Standard'
  }
}

resource servicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: servicePlanName
  location: location
  properties: {
    reserved: true
  }
  sku: {
    name: servicePlanPricingTier
    tier: servicePlanPricingTiers[servicePlanPricingTier].tier
    capacity: servicePlanCapacity
  }
  kind: 'linux'
}

resource site 'Microsoft.Web/sites@2023-01-01' = {
  name: siteName
  location: location
  properties: {
    siteConfig: {
      linuxFxVersion: 'DOCKER|sonarqube:${sonarqubeImageVersion}'
    }
    serverFarmId: servicePlan.id
  }
}

resource siteAppSettings 'Microsoft.Web/sites/config@2023-01-01' = {
  parent: site
  name: 'appsettings'
  properties: {
    SONAR_ES_BOOTSTRAP_CHECKS_DISABLE: 'true'
    SONAR_JDBC_URL: 'jdbc:sqlserver://${sqlServer.properties.fullyQualifiedDomainName}:1433;databaseName=${databaseName};encrypt=true;trustServerCertificate=false;hostNameInCertificate=${replace(sqlServer.properties.fullyQualifiedDomainName, '${sqlServerName}.', '*.')};loginTimeout=30;'
    SONAR_JDBC_USERNAME: sqlServerAdministratorUsername
    SONAR_JDBC_PASSWORD: sqlServerAdministratorPassword
  }
}

resource sqlServer 'Microsoft.Sql/servers@2021-11-01' = {
  location: location
  name: sqlServerName
  properties: {
    administratorLogin: sqlServerAdministratorUsername
    administratorLoginPassword: sqlServerAdministratorPassword
    version: '12.0'
  }
}

resource sqlServerFirewall 'Microsoft.Sql/servers/firewallrules@2021-11-01' = {
  parent: sqlServer
  name: '${sqlServerName}firewall'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2021-11-01' = {
  parent: sqlServer
  name: databaseName
  location: location
  sku: {
    name: sqlDatabaseSkuName
    tier: 'GeneralPurpose'
    family: 'Gen5'
  }
  properties: {
    autoPauseDelay: 60 // Time in minutes to auto-pause the serverless database
    minCapacity: 1 // Minimum vCores for serverless
    maxCapacity: 4 // Maximum vCores for serverless
    collation: 'SQL_Latin1_General_CP1_CS_AS'
    catalogCollation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: (((sqlDatabaseSkuSizeGB * 1024) * 1024) * 1024)
  }
}
