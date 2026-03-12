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


# Copy your .env.example → .env and fill in the addresses
cp .env.example .env
# Set at minimum:
# ALEO_ADDRESS=aleo1...          (your employer address)
# WORKER1_ADDRESS=aleo1...
# WORKER2_ADDRESS=aleo1...
# WORKER3_ADDRESS=aleo1...

source .env

# Substitute tokens into a temp file, then validate
ALEO_ADDRESS="$ALEO_ADDRESS" \
WORKER1_ADDRESS="$WORKER1_ADDRESS" \
WORKER2_ADDRESS="$WORKER2_ADDRESS" \
WORKER3_ADDRESS="$WORKER3_ADDRESS" \
  envsubst '${ALEO_ADDRESS} ${WORKER1_ADDRESS} ${WORKER2_ADDRESS} ${WORKER3_ADDRESS}' \
  < config/scenarios/testnet/batch_payroll_smoke.json \
  > /tmp/batch_resolved.json

python3 scripts/validate_phaseA_scenario.py /tmp/batch_resolved.json
