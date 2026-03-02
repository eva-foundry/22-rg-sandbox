# Dev2 Code Location - CORRECTED

**Date**: February 4, 2026  
**Critical Correction**: Dev2 and HCCLD2 are DIFFERENT environments, not the same deployment

---

## Key Discovery: Three Separate Environments

### 1. DEV2 Environment (infoasst-dev2)
**What you want to copy to sandbox**

- **Resource Group**: `infoasst-dev2`
- **Storage**: `infoasststoredev2` (109 containers, 18,944 blobs)
- **ACR**: `infoasstacrdev2.azurecr.io`
- **Container Image**: `webapp:20260203-185957`
- **Purpose**: Development environment for team testing

### 2. HCCLD2 Environment (infoasst-hccld2)
**Production environment - different from dev2**

- **Resource Group**: `infoasst-hccld2`
- **Storage**: `infoasststorehccld2`
- **ACR**: (likely `infoasstacrhccld2.azurecr.io` or similar)
- **Purpose**: Production deployment with private endpoints
- **Network**: Requires VPN or DevBox access

### 3. Your Local Repository (I:\EVA-JP-v1.2)
**Currently configured for dev2**

- **Active Config**: `app\backend\backend.env` points to **dev2** resources
- **Alternative Configs**: 
  - `backend.env.dev2` - Development (current)
  - `backend.env.hccld2` - Production
  - `backend.env.sandbox` - Personal sandbox
- **Current Services** (from backend.env):
  - Cosmos: `infoasst-cosmos-dev2`
  - Storage: `infoasststoredev2`
  - Search: `infoasst-search-dev2`
  - OpenAI: `infoasst-aoai-dev2`

---

## Repository Source Code Location

**Azure DevOps Repository**: `https://dev.azure.com/ESDC-AICoE/EVA%20-%20Portal/_git/EVA-Jurisprudence-SecMode-Info-Assistant-v1.2`

**Local Clone**: `I:\EVA-JP-v1.2`

**Key Insight**: This is a SINGLE repository with environment-specific configurations, NOT separate repositories for dev2 and hccld2.

**Environment Switching**:
```powershell
# Current config (dev2)
cat I:\EVA-JP-v1.2\app\backend\backend.env | Select-String "AZURE_BLOB_STORAGE_ACCOUNT"
# Output: AZURE_BLOB_STORAGE_ACCOUNT=infoasststoredev2

# Switch to hccld2
Copy-Item backend.env.hccld2 backend.env

# Switch back to dev2
Copy-Item backend.env.dev2 backend.env
```

---

## Dev2 Container Images

**Dev2 Azure Container Registry**: `infoasstacrdev2.azurecr.io`

**Current Deployment**:
- **Webapp**: `infoasstacrdev2.azurecr.io/webapp:20260203-185957`
- **Enrichment**: `infoasstacrdev2.azurecr.io/enrichment:20260203-185957` (likely)
- **Functions**: `infoasstacrdev2.azurecr.io/function:20260203-185957` (likely)

**Build Source**: Same repository (`I:\EVA-JP-v1.2`), built with dev2 configuration

**Build Process** (dev2-specific):
```bash
# 1. Configure for dev2
cd I:\EVA-JP-v1.2
cp app/backend/backend.env.dev2 app/backend/backend.env

# 2. Build application
make build

# 3. Build container (dev2)
cd container_images/webapp_container_image
docker build -t infoasstacrdev2.azurecr.io/webapp:$(date +%Y%m%d-%H%M%S) -f Dockerfile ../..

# 4. Push to dev2 ACR
docker login infoasstacrdev2.azurecr.io
docker push infoasstacrdev2.azurecr.io/webapp:20260203-185957

# 5. Deploy to dev2 App Service
az webapp config container set \
  --name infoasst-web-dev2 \
  --resource-group infoasst-dev2 \
  --docker-custom-image-name infoasstacrdev2.azurecr.io/webapp:20260203-185957
```

---

## Corrected Sandbox Deployment Strategy

### What You Actually Want

**Goal**: Deploy dev2 application code to sandbox with dev2 data

**Dev2 Components to Replicate**:
1. ✅ **Storage Data** (config container) - Already assessed
2. ⏳ **Application Code** (same as local repo)
3. ⏳ **Container Images** (from dev2 ACR or rebuild)
4. ⏳ **Configuration** (dev2 settings adapted for sandbox)

### Option A: Copy Dev2 Container Images (if ACR access available)

**Prerequisite**: Resolve ACR IP firewall issue (403 error)

```powershell
# 1. Create sandbox ACR
az acr create --name marcosandacr --resource-group EsDAICoE-Sandbox --sku Basic --location canadaeast

# 2. Import dev2 images
az acr import \
  --name marcosandacr \
  --source infoasstacrdev2.azurecr.io/webapp:20260203-185957 \
  --image webapp:20260203-185957

# 3. Deploy to sandbox
az webapp config container set \
  --name marco-sandbox-backend \
  --resource-group EsDAICoE-Sandbox \
  --docker-custom-image-name marcosandacr.azurecr.io/webapp:20260203-185957
```

**Current Blocker**: ACR IP firewall denies access to `infoasstacrdev2.azurecr.io`

### Option B: Rebuild from Source (Recommended)

**Advantage**: No dependency on dev2 ACR access

```powershell
# 1. Use your local repo (already configured for dev2)
cd I:\EVA-JP-v1.2

# 2. Verify current config points to dev2
Get-Content app\backend\backend.env | Select-String "infoasststoredev2"
# Should show: AZURE_BLOB_STORAGE_ACCOUNT=infoasststoredev2

# 3. Build application code
make build

# 4. Create sandbox ACR (if not exists)
az acr create --name marcosandacr --resource-group EsDAICoE-Sandbox --sku Basic --location canadaeast

# 5. Build container for sandbox
cd container_images\webapp_container_image
docker build -t marcosandacr.azurecr.io/webapp:dev2-clone -f Dockerfile ../..

# 6. Push to sandbox ACR
az acr login --name marcosandacr
docker push marcosandacr.azurecr.io/webapp:dev2-clone

# 7. Deploy to sandbox web app
az webapp config container set \
  --name marco-sandbox-backend \
  --resource-group EsDAICoE-Sandbox \
  --docker-custom-image-name marcosandacr.azurecr.io/webapp:dev2-clone

# 8. Create sandbox-specific backend.env
cd I:\EVA-JP-v1.2\app\backend

# Copy dev2 config as template
cp backend.env.dev2 backend.env.sandbox-with-dev2-code

# Edit backend.env.sandbox-with-dev2-code:
# - COSMOSDB_URL=https://marco-sandbox-cosmos.documents.azure.com:443/
# - AZURE_BLOB_STORAGE_ACCOUNT=marcosand20260203
# - AZURE_SEARCH_SERVICE=marco-sandbox-search
# - AZURE_OPENAI_SERVICE=infoasst-aoai-dev2 (shared OK)

# 9. Update App Service app settings
az webapp config appsettings set \
  --name marco-sandbox-backend \
  --resource-group EsDAICoE-Sandbox \
  --settings @backend.env.sandbox-with-dev2-code

# 10. Restart web app
az webapp restart --name marco-sandbox-backend --resource-group EsDAICoE-Sandbox
```

---

## Key Differences: Dev2 vs HCCLD2

| Aspect | DEV2 | HCCLD2 |
|--------|------|--------|
| **Resource Group** | infoasst-dev2 | infoasst-hccld2 |
| **Storage** | infoasststoredev2 | infoasststorehccld2 |
| **ACR** | infoasstacrdev2 | (separate ACR) |
| **Network** | Mixed (some private endpoints) | Full private endpoints |
| **OpenAI Model** | gpt-4o | gpt-4.1-mini |
| **Embedding Model** | text-embedding-3-small (3072) | text-embedding-3-small (3072) |
| **Access** | Team development | Production only |
| **Purpose** | Testing and development | Live production workloads |

---

## Why This Matters for Sandbox Copy

**Original Plan Assumption**: Copy from "dev2" deployment

**Reality**:
- Your local repo `I:\EVA-JP-v1.2` has **dev2 configuration** (current)
- Same repo can build for **dev2**, **hccld2**, or **sandbox**
- The **source code is identical**, only **configuration differs**
- Dev2 ACR (`infoasstacrdev2.azurecr.io`) has dev2-specific builds

**Correct Strategy**:
1. ✅ Copy dev2 **data** (config container from infoasststoredev2)
2. ✅ Build dev2 **code** from local repo (I:\EVA-JP-v1.2)
3. ✅ Create sandbox **configuration** (blend of dev2 settings + sandbox resources)
4. ✅ Deploy to sandbox with sandbox-specific environment variables

---

## Next Steps (Corrected)

1. **Copy Dev2 Config Container** (unchanged):
```powershell
az storage blob copy start-batch \
  --source-account-name infoasststoredev2 \
  --source-container config \
  --destination-account-name marcosand20260203 \
  --destination-container config
```

2. **Build Application from Dev2-Configured Repo**:
```powershell
cd I:\EVA-JP-v1.2
make build
```

3. **Create Sandbox-Specific Container**:
```powershell
cd container_images\webapp_container_image
docker build -t marcosandacr.azurecr.io/webapp:dev2-clone -f Dockerfile ../..
az acr login --name marcosandacr
docker push marcosandacr.azurecr.io/webapp:dev2-clone
```

4. **Deploy to Sandbox with Hybrid Configuration**:
- Use dev2 code (just built)
- Point to sandbox resources (Cosmos, Search)
- Share dev2 resources where appropriate (OpenAI, AI Services)

5. **Test Sandbox**:
```powershell
curl https://marco-sandbox-backend.azurewebsites.net/health
az webapp log tail --name marco-sandbox-backend --resource-group EsDAICoE-Sandbox
```

---

## Evidence

**Local Repo Currently Configured for Dev2**:
```powershell
PS I:\EVA-JP-v1.2> Get-Content app\backend\backend.env | Select-String "COSMOSDB_URL"
# Output: COSMOSDB_URL=https://infoasst-cosmos-dev2.documents.azure.com:443/
```

**Environment Files Available**:
```
backend.env             # Active (dev2)
backend.env.dev2        # Dev2 template
backend.env.hccld2      # HCCLD2 template
backend.env.sandbox     # Sandbox template
```

**Dev2 Container Image in Use**:
```json
{
  "name": "infoasst-web-dev2",
  "containerSettings": "DOCKER|infoasstacrdev2.azurecr.io/webapp:20260203-185957"
}
```

---

**Document Status**: CORRECTED - Dev2 and HCCLD2 are separate environments  
**Author**: AI Agent (GitHub Copilot)  
**Last Updated**: February 4, 2026 17:35 EST
