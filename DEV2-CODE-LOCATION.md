# Dev2 Repository Code Location & Deployment Guide

**Date**: February 4, 2026  
**Context**: Identifying where Dev2 application code exists and how to deploy to sandbox  
**Status**: COMPLETE - Repository located, deployment method documented

---

## Executive Summary

**Dev2 repository code is already in your workspace**: `I:\EVA-JP-v1.2`

**Azure DevOps Repository**: `https://dev.azure.com/ESDC-AICoE/EVA%20-%20Portal/_git/EVA-Jurisprudence-SecMode-Info-Assistant-v1.2`

**Deployment Method**: Docker containers built from source and pushed to Azure Container Registry (ACR)

**Current Dev2 Container**: `infoasstacrdev2.azurecr.io/webapp:20260203-185957`

---

## Repository Details

### Source Code Location

**Local Clone**: `I:\EVA-JP-v1.2`

**Remote Repository**:
- **Platform**: Azure DevOps
- **Organization**: ESDC-AICoE
- **Project**: EVA - Portal
- **Repository**: EVA-Jurisprudence-SecMode-Info-Assistant-v1.2
- **URL**: `https://dev.azure.com/ESDC-AICoE/EVA%20-%20Portal/_git/EVA-Jurisprudence-SecMode-Info-Assistant-v1.2`

**Branch Structure**:
- `main` - Production deployments
- `ESDC-Deployment` - Dev2/Dev3 deployments
- `vNext-Dev` - Next version development

### Key Components

**Application Code**:
- **Backend API**: `app/backend/` (Python/Quart async API with RAG approaches)
- **Frontend SPA**: `app/frontend/` (React/TypeScript/Vite)
- **Enrichment Service**: `app/enrichment/` (Flask API for embeddings)
- **Functions**: `functions/` (Azure Functions for document processing pipeline)

**Infrastructure as Code**:
- **Terraform**: `infra/` (Complete Azure infrastructure definitions)
- **Deployment Scripts**: `scripts/` (Bash scripts for build, deploy, infrastructure)

**Container Images**:
- **Webapp Dockerfile**: `container_images/webapp_container_image/Dockerfile`
- **Enrichment Dockerfile**: `container_images/enrichment_container_image/Dockerfile`

**CI/CD Pipelines**:
- **Azure DevOps Pipelines**: `pipelines/` (Multiple environment-specific pipelines)
- **Dev2 Pipeline**: `pipelines/esdc-dev.yml`

---

## Deployment Architecture

### How Dev2 Applications Run

**Deployment Pattern**: Containerized deployment from Azure Container Registry

**Dev2 Resources**:
1. **Azure Container Registry (ACR)**: `infoasstacrdev2.azurecr.io`
   - Stores Docker images built from source code
   - Image tagging: `{component}:YYYYMMDD-HHMMSS` (timestamp-based)

2. **Web Apps** (App Service):
   - `infoasst-web-dev2` → Container: `webapp:20260203-185957` (Backend + Frontend)
   - `infoasst-enrichmentweb-dev2` → Container: `enrichment:20260203-185957`
   - `infoasst-func-dev2` → Container: `function:20260203-185957`

3. **Storage Account**: `infoasststoredev2`
   - Config container: 3 files (Lexicon.xlsx, config.json, examplelist.json)
   - Content containers: Document storage, chunking results

### Build Process

**Source Code → Docker Image → ACR → App Service**

```bash
# 1. Build frontend and prepare shared code
cd app/frontend
npm ci
npm run build

# 2. Build backend Docker image
cd container_images/webapp_container_image
docker build -t infoasstacrdev2.azurecr.io/webapp:$(date +%Y%m%d-%H%M%S) .

# 3. Push to ACR
docker login infoasstacrdev2.azurecr.io -u {client_id} -p {client_secret}
docker push infoasstacrdev2.azurecr.io/webapp:20260203-185957

# 4. Deploy to App Service
az webapp config container set \
  --name infoasst-web-dev2 \
  --resource-group infoasst-dev2 \
  --docker-custom-image-name infoasstacrdev2.azurecr.io/webapp:20260203-185957
```

**Automated via Azure DevOps**: Pipeline `esdc-dev.yml` executes build → test → deploy

---

## Sandbox Deployment Options

### Option A: Copy Container Images from Dev2 ACR to Sandbox ACR

**Pros**: 
- Exact Dev2 version (known working)
- Fast deployment (no rebuild)
- Consistent with Dev2

**Cons**:
- Requires ACR access (currently blocked by IP firewall)
- No source code visibility
- Can't customize without rebuild

**Commands** (when ACR access available):
```powershell
# 1. Create sandbox ACR (if not exists)
az acr create --name marcosandacr --resource-group EsDAICoE-Sandbox --sku Basic --location canadaeast

# 2. Import Dev2 images to sandbox ACR
az acr import \
  --name marcosandacr \
  --source infoasstacrdev2.azurecr.io/webapp:20260203-185957 \
  --image webapp:20260203-185957 \
  --resource-group EsDAICoE-Sandbox

# Repeat for enrichment and function images
az acr import \
  --name marcosandacr \
  --source infoasstacrdev2.azurecr.io/enrichment:20260203-185957 \
  --image enrichment:20260203-185957 \
  --resource-group EsDAICoE-Sandbox

# 3. Configure sandbox web app to use sandbox ACR
az webapp config container set \
  --name marco-sandbox-backend \
  --resource-group EsDAICoE-Sandbox \
  --docker-custom-image-name marcosandacr.azurecr.io/webapp:20260203-185957 \
  --docker-registry-server-url https://marcosandacr.azurecr.io
```

**Prerequisites**:
- ACR access (VPN or DevBox)
- Sandbox ACR created
- RBAC: ACRPull role on sandbox ACR for web app managed identity

---

### Option B: Rebuild from Source (Recommended)

**Pros**: 
- Full control over customization
- Source code available for modifications
- No dependency on Dev2 ACR access
- Can use latest code from repository

**Cons**:
- Longer setup time (build + push)
- Requires Docker installed locally or pipeline
- May differ from Dev2 version if code updated

**Commands** (local build):
```powershell
# 1. Navigate to EVA-JP-v1.2 repository
cd I:\EVA-JP-v1.2

# 2. Build using Makefile (preferred)
make build

# 3. Build webapp container manually (alternative)
cd container_images\webapp_container_image
docker build -t marcosandacr.azurecr.io/webapp:latest -f Dockerfile ../..

# 4. Login to sandbox ACR
az acr login --name marcosandacr

# 5. Push to sandbox ACR
docker push marcosandacr.azurecr.io/webapp:latest

# 6. Deploy to sandbox web app
az webapp config container set \
  --name marco-sandbox-backend \
  --resource-group EsDAICoE-Sandbox \
  --docker-custom-image-name marcosandacr.azurecr.io/webapp:latest \
  --docker-registry-server-url https://marcosandacr.azurecr.io

# 7. Restart web app
az webapp restart --name marco-sandbox-backend --resource-group EsDAICoE-Sandbox
```

**Build via Terraform + Scripts** (production method):
```powershell
# 1. Configure environment for sandbox
cd I:\EVA-JP-v1.2\scripts\environments
# Create/edit sandbox.env with sandbox-specific variables

# 2. Deploy infrastructure + application
cd I:\EVA-JP-v1.2
make deploy
# This runs: build → infrastructure → deploy-search-indexes → deploy-functions → deploy-webapp
```

---

### Option C: Use Terraform to Deploy Complete Environment

**Pros**: 
- Complete infrastructure + application deployment
- Automated, repeatable
- Best practice for production

**Cons**:
- Longest setup time
- Requires Terraform state management
- May create duplicate resources

**Commands**:
```powershell
# 1. Navigate to repository
cd I:\EVA-JP-v1.2

# 2. Configure sandbox environment variables
cd scripts\environments
# Edit .env file with sandbox-specific values:
# - AZURE_RESOURCE_GROUP=EsDAICoE-Sandbox
# - AZURE_LOCATION=canadaeast
# - AZURE_STORAGE_ACCOUNT=marcosand20260203
# - etc.

# 3. Initialize Terraform
cd ..\..\infra
terraform init

# 4. Plan deployment
terraform plan -out=sandbox.tfplan

# 5. Apply deployment
terraform apply sandbox.tfplan

# 6. Extract infrastructure outputs
cd ..
make extract-env

# 7. Deploy application code
make build-deploy-webapp
make build-deploy-enrichments
make build-deploy-functions
```

---

## Current Blockers & Solutions

### Blocker 1: ACR IP Firewall

**Problem**: Cannot access `infoasstacrdev2.azurecr.io` to list/copy images
**Error**: `403 - client with IP '173.178.152.45' is not allowed access`

**Solutions**:
1. **Use Azure Portal** (bypasses firewall):
   - Navigate to: https://portal.azure.com
   - Search: "infoasstacrdev2"
   - Click: Repositories → webapp → View tags
   - Document available tags (20260203-185957, etc.)

2. **Connect to VPN**:
   - ESDC VPN provides access to private resources
   - ACR may allow VPN IP range

3. **Use Microsoft DevBox**:
   - DevBox already in HCCLD2 VNet
   - Has network access to ACR

4. **Request Temporary IP Whitelist**:
   - Add current IP (173.178.152.45) to ACR firewall
   - Requires Dev2 admin access

5. **Use ARM REST API** (may bypass firewall):
```powershell
az rest --method GET \
  --url "/subscriptions/d2d4e571-e0f2-4f6c-901a-f88f7669bcba/resourceGroups/infoasst-dev2/providers/Microsoft.ContainerRegistry/registries/infoasstacrdev2/repositories/webapp/tags?api-version=2023-01-01-preview"
```

**Recommended**: Use Option B (rebuild from source) to avoid ACR access dependency

---

## Recommended Sandbox Deployment Strategy

**Best Approach**: **Option B - Rebuild from Source**

**Why**:
- No dependency on Dev2 ACR access (current blocker)
- Full control over application code
- Can customize for sandbox environment
- Source code already in workspace (`I:\EVA-JP-v1.2`)
- Production-ready Makefile and scripts available

**Steps** (30-60 minutes):

1. **Copy Config Container** (5 min):
```powershell
az storage blob copy start-batch \
  --source-account-name infoasststoredev2 \
  --source-container config \
  --destination-account-name marcosand20260203 \
  --destination-container config \
  --pattern "*" --auth-mode login
```

2. **Build Application Code** (10 min):
```powershell
cd I:\EVA-JP-v1.2
make build
```

3. **Create Sandbox ACR** (if not exists) (5 min):
```powershell
az acr create \
  --name marcosandacr \
  --resource-group EsDAICoE-Sandbox \
  --sku Basic \
  --location canadaeast
```

4. **Build and Push Webapp Container** (10 min):
```powershell
cd container_images\webapp_container_image
docker build -t marcosandacr.azurecr.io/webapp:latest -f Dockerfile ../..
az acr login --name marcosandacr
docker push marcosandacr.azurecr.io/webapp:latest
```

5. **Deploy to Sandbox Web App** (5 min):
```powershell
az webapp config container set \
  --name marco-sandbox-backend \
  --resource-group EsDAICoE-Sandbox \
  --docker-custom-image-name marcosandacr.azurecr.io/webapp:latest \
  --docker-registry-server-url https://marcosandacr.azurecr.io

az webapp restart --name marco-sandbox-backend --resource-group EsDAICoE-Sandbox
```

6. **Update Config Files for Sandbox** (10 min):
```powershell
# Download config.json
az storage blob download \
  --container-name config \
  --name config.json \
  --file config.json \
  --account-name marcosand20260203 \
  --auth-mode login

# Edit config.json - replace:
# - "infoasststoredev2" → "marcosand20260203"
# - "infoasst-web-dev2" → "marco-sandbox-backend"
# - "infoasst-search-dev2" → "marco-sandbox-search"
# - etc.

# Re-upload
az storage blob upload \
  --container-name config \
  --file config.json \
  --name config.json \
  --account-name marcosand20260203 \
  --auth-mode login \
  --overwrite
```

7. **Test Sandbox Application** (10 min):
```powershell
# Check web app status
az webapp show --name marco-sandbox-backend --resource-group EsDAICoE-Sandbox --query "state"

# Test HTTP endpoint
$url = "https://marco-sandbox-backend.azurewebsites.net"
Invoke-WebRequest -Uri $url -Method GET

# Check logs
az webapp log tail --name marco-sandbox-backend --resource-group EsDAICoE-Sandbox
```

---

## Next Steps

**Immediate Actions**:
1. ✅ **COMPLETE** - Repository location identified (`I:\EVA-JP-v1.2`)
2. ✅ **COMPLETE** - Deployment method documented (Docker containers from source)
3. ⏳ **PENDING** - Copy config container to sandbox (Task 4 from continuation plan)
4. ⏳ **PENDING** - Build and deploy application code (Task 6 from continuation plan)
5. ⏳ **PENDING** - Update config files for sandbox environment (Task 5 from continuation plan)
6. ⏳ **PENDING** - Test sandbox application (Task 7 from continuation plan)

**Decision Required**: Approve Option B (rebuild from source) as deployment strategy?

---

## Evidence & References

**Repository Clone Verification**:
```
PS I:\eva-foundation\22-rg-sandbox> cd I:\EVA-JP-v1.2 ; git remote -v
origin  https://dev.azure.com/ESDC-AICoE/EVA%20-%20Portal/_git/EVA-Jurisprudence-SecMode-Info-Assistant-v1.2 (fetch)
origin  https://dev.azure.com/ESDC-AICoE/EVA%20-%20Portal/_git/EVA-Jurisprudence-SecMode-Info-Assistant-v1.2 (push)
```

**Dev2 Container Image Reference**:
```json
{
  "name": "infoasst-web-dev2",
  "state": "Running",
  "containerSettings": "DOCKER|infoasstacrdev2.azurecr.io/webapp:20260203-185957"
}
```

**ACR Access Error**:
```
Access to registry 'infoasstacrdev2.azurecr.io' was denied. Response code: 403.
client with IP '173.178.152.45' is not allowed access
```

**Related Documents**:
- `COPY-PLAN-ASSESSMENT.md` - Original copy plan (now superseded by code deployment strategy)
- `DEV2-FINDINGS-COPY-DECISION.md` - Dev2 data analysis (config container details)
- `I:\EVA-JP-v1.2\README.md` - Repository documentation
- `I:\EVA-JP-v1.2\Makefile` - Build and deployment commands
- `I:\EVA-JP-v1.2\pipelines\esdc-dev.yml` - Dev2 CI/CD pipeline

---

**Document Status**: COMPLETE - Ready for deployment decision and execution  
**Author**: AI Agent (GitHub Copilot)  
**Last Updated**: February 4, 2026 17:15 EST
