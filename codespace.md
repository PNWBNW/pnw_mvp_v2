This file is a reminder for what commands to use.

cd /workspaces/pnw_mvp_v2
git pull origin main

# 1. Leaf programs (no deps)
cd src/layer1/employer_license_registry.aleo && leo build
cd ../payroll_audit_log.aleo && leo build
cd ../paystub_receipts.aleo && leo build

# 2. Name registry (deps: stub + license_registry)
cd ../pnw_name_registry.aleo && leo build

# 3. Agreement (deps: name_registry + license_registry)
cd ../employer_agreement.aleo && leo build

# 4. Profiles (deps: name_registry [+ license_registry])
cd ../worker_profiles.aleo && leo build
cd ../employer_profiles.aleo && leo build

# 5. Payroll core (deps: stub + agreement + receipts + audit_log)
cd ../payroll_core.aleo && leo build

# 6. Router (deps: agreement + profiles + name_registry)
cd ../pnw_router.aleo && leo build

# 7. Layer 2
cd ../../layer2/credential_nft.aleo && leo build
cd ../audit_nft.aleo && leo build
cd ../payroll_nfts.aleo && leo build
