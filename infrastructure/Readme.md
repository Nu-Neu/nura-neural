# 1. Copy and configure variables
cp infrastructure/terraform.tfvars.example infrastructure/terraform.tfvars
# Edit terraform.tfvars with your values

# 2. Plan deployment
cd infrastructure
./deploy.ps1 -Plan

# 3. Apply infrastructure
./deploy.ps1 -Apply

# 4. Create search indexes
./create-search-indexes.ps1

# 5. Apply database schema
psql -h <postgres_host> -U <user> -d nura -f database/schema.sql