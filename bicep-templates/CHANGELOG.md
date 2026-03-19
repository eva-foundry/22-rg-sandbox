# Changelog

All notable changes to the Marco EVA Sandbox Bicep templates will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-03-03

### Added
- **Initial release** of production-ready Bicep templates for Marco EVA Sandbox infrastructure
- Complete modular template structure with 15 resource modules:
  - `log-analytics.bicep` - Log Analytics Workspace
  - `application-insights.bicep` - Application Insights for APM
  - `storage-account.bicep` - Azure Storage (general + FinOps)
  - `container-registry.bicep` - Azure Container Registry
  - `key-vault.bicep` - Key Vault for secrets
  - `cosmos-db.bicep` - Cosmos DB NoSQL database
  - `ai-services.bicep` - AI Services (OpenAI, Foundry, Cognitive Services, Document Intelligence)
  - `azure-search.bicep` - Azure AI Search
  - `container-app-environment.bicep` - Container Apps Environment
  - `container-app.bicep` - Individual Container Apps
  - `app-service-plan.bicep` - App Service Plans
  - `app-service.bicep` - App Services
  - `function-app.bicep` - Azure Functions
  - `api-management.bicep` - API Management gateway
  - `data-factory.bicep` - Data Factory for ETL
  - `event-hub-namespace.bicep` - Event Hubs for streaming
- Main orchestration template (`main.bicep`) with:
  - 31 resource deployments
  - Proper dependency management
  - Parameterized configuration
  - Comprehensive outputs
- Environment-specific parameter files:
  - `parameters.dev.json` - Development environment (B1/Basic SKUs)
  - `parameters.prod.json` - Production environment (P1v2/Standard SKUs)
- Automated deployment script (`Deploy-Infrastructure.ps1`) with:
  - Prerequisites validation
  - What-if analysis support
  - Post-deployment RBAC configuration
  - Health checks
  - Error handling and rollback
- Comprehensive documentation:
  - `README.md` - 400+ line deployment guide
  - `QUICK-REFERENCE.md` - Command cheat sheet
  - Architecture diagrams
  - Cost estimates (dev: $341-391/mo, prod: $1,727-1,827/mo)
  - Troubleshooting decision trees
- Security best practices:
  - Managed identities for all compute resources
  - TLS 1.2 minimum enforcement
  - HTTPS-only for all web endpoints
  - Key Vault integration for secrets
  - RBAC-based access control
  - Soft delete enabled for Key Vault
- Bicep linting configuration (`.bicepconfig.json`) with 15 active rules

### Resource Coverage
- **4 Container Apps**: EVA Brain API, Data Model API, Faces, Roles API
- **2 Storage Accounts**: Main storage (LRS), FinOps Hub (LRS)
- **1 Cosmos DB Account**: Session consistency, canadacentral
- **1 Container Registry**: Basic SKU with admin user
- **1 Key Vault**: Standard tier, soft delete enabled
- **5 AI/ML Services**: Foundry, OpenAI (2), Cognitive Services, Document Intelligence
- **1 Azure AI Search**: Basic tier, 1 replica, 1 partition
- **3 App Service Plans**: Backend, Enrichment, Functions (B1 Linux)
- **3 App Services/Functions**: Backend app, Enrichment app, Function app
- **1 API Management**: Developer tier (staging: Standard)
- **1 Data Factory**: V2, system-assigned identity
- **1 Event Hubs Namespace**: Standard tier, zone redundant
- **2 Application Insights**: Workspace-based, 90-day retention
- **1 Log Analytics Workspace**: PerGB2018 tier, 90-day retention
- **1 Container App Environment**: Consumption profile

### Dependencies Implemented
- Log Analytics Workspace → Application Insights
- Log Analytics Workspace → Container App Environment
- Container App Environment → Container Apps (4)
- Container Registry → Container Apps (ACR Pull via managed identity)
- Storage Account → Function Apps (content storage)
- Cosmos DB → Container Apps (connection via environment variables)
- Key Vault → All compute resources (secrets access via RBAC)

### Known Limitations
- Private endpoints not configured (public access enabled for all resources)
- VNet integration not implemented (suitable for dev/sandbox only)
- No custom domains or SSL certificates (uses Azure-provided domains)
- Event Grid system topics not explicitly defined (auto-created)
- Foundry project not included (parent AIServices resource only)
- No backup automation scripts (manual Cosmos DB export required)

### Security Notes
- All secrets parameterized (no hardcoded values)
- Managed identities used throughout (no passwords or keys in code)
- TLS 1.0/1.1 disabled on APIM
- Minimum TLS 1.2 enforced on all services
- Soft delete enabled on Key Vault (90-day retention)
- RBAC recommended over access policies (Key Vault)

### Cost Optimization Opportunities
- Use Azure Hybrid Benefit for Windows VMs (if applicable)
- Enable Cosmos DB auto-pause for non-prod
- Implement blob lifecycle policies for storage
- Use reserved instances for Container Apps (60% savings)
- Monitor with FinOps Hub (storage account included)

## [Unreleased]

### Planned for 1.1.0
- [ ] Private endpoint modules for VNet integration
- [ ] Custom domain and SSL certificate support
- [ ] Azure Front Door integration for global load balancing
- [ ] Automated backup and DR scripts
- [ ] Terraform port for multi-cloud compatibility
- [ ] GitHub Actions workflow for CI/CD
- [ ] Azure Policy assignments for governance
- [ ] Cost anomaly detection alerts
- [ ] Automated scaling rules based on metrics
- [ ] Integration tests for post-deployment validation

### Planned for 1.2.0
- [ ] Multi-region deployment support
- [ ] Azure Private Link for all PaaS services
- [ ] Managed HSM for Key Vault (Premium)
- [ ] Azure Sentinel integration for security monitoring
- [ ] Compliance as Code (PCI-DSS, HIPAA, SOC 2)
- [ ] Infrastructure drift detection
- [ ] Blue-green deployment strategy
- [ ] Canary release automation

---

## Version Support Matrix

| Template Version | Azure CLI | Bicep | PowerShell | Supported Until |
|---|---|---|---|---|
| 1.0.0 | 2.50.0+ | 0.24.0+ | 7.3+ | 2027-03-03 |

## Breaking Changes

None yet (initial release).

## Migration Guide

This is the initial release. No migration required.

For migrating from the legacy EsDAICoE-Sandbox resource group:
1. Export existing resource configurations: `az group export --resource-group EsDAICoE-Sandbox`
2. Update parameter files with your specific values
3. Deploy to new resource group with different name
4. Migrate data (Cosmos DB, Storage, Key Vault secrets)
5. Update DNS/application configs to point to new resources
6. Decommission old resource group after validation

## Support

- **Issues**: Report bugs or request features at marco.presta@hrsdc-rhdcc.gc.ca
- **Documentation**: See README.md and QUICK-REFERENCE.md
- **Azure Support**: Open support ticket in Azure Portal for Azure-specific issues

---

**Template Repository**: C:\eva-foundry\22-rg-sandbox\bicep-templates\  
**Maintainer**: Marco Presta (marco.presta@hrsdc-rhdcc.gc.ca)  
**License**: Internal use only - Government of Canada  
**Last Updated**: March 3, 2026
