# Encode protocol fee setting op. Usage: just encode-set-protocol-fee 0xdeadbeef '0.5e18'
encode-set-protocol-fee pool fee:
    @# Last part strips the logs lol
    @forge script script/GenerateL2Calldata.s.sol -s 'setProtocolFee(address,uint256)' {{pool}} {{fee}} | awk 'BEGIN {output=0} /^== Logs ==/ {output=3} (output != 0) { output -= 1 } (output == 1) {print($1)}' 
encode-set-protocol-fee-gyro-portion pool fee:
    @forge script script/GenerateL2Calldata.s.sol -s 'setProtocolFeeGyroPortion(address,uint256)' {{pool}} {{fee}} | awk 'BEGIN {output=0} /^== Logs ==/ {output=3} (output != 0) { output -= 1 } (output == 1) {print($1)}'

# Encode calls to set both protocol fee and gyro portion, and output info to paste into safe. Usage: just mk-set-both-protocol-fees 0.5e18 1e18
mk-set-both-protocol-fees chain pool protocol_fee gyro_portion:
    #!/usr/bin/env fish
    echo "Contract: GovernanceRoleManager" (just get-contract {{chain}} GovernanceRoleManager)
    echo "Method: executeActions()"
    set gyro_config_manager (just get-contract {{chain}} GyroConfigManager)
    set cd_set_protocol_fee (just encode-set-protocol-fee {{pool}} {{protocol_fee}})
    set cd_set_gyro_portion (just encode-set-protocol-fee-gyro-portion {{pool}} {{gyro_portion}})
    echo "Actions:" "[[\"$gyro_config_manager\", \"$cd_set_protocol_fee\", 0], [\"$gyro_config_manager\", \"$cd_set_gyro_portion\", 0]]"

# generate permissions for setting PROTOCOL_SWAP_FEE_PERC for a given pool. In json for Safe.
mk-protocol-fee-permissions-json pool:
    #!/usr/bin/env fish
    set pool_bytes32 (cast abi-encode 'foo(address)' {{pool}})
    set key_bytes32 (cast format-bytes32-string "PROTOCOL_SWAP_FEE_PERC")
    echo "target: GyroConfigManager"
    echo "selector: 0x60b2cf71"  # setPoolConfigUint see `forge selectors list GyroConfigManager`
    echo "parameters:" "[[0, \"$pool_bytes32\"], [1, \"$key_bytes32\"]]"
    echo
    echo "target: GyroConfigManager"
    echo "selector: 0xec1bf875"  # unsetPoolConfig
    echo "parameters:" "[[0, \"$pool_bytes32\"], [1, \"$key_bytes32\"]]"

    

# get contract address on a specified chain
get-contract chain name:
    @json5 docs/deployed-contracts.json5 | jq -r '.{{chain}}.{{name}}'

# Output calls to make to the multisig to set up an UpdatableRateProviderBalV2
mk-bind-updatablerateprovider-balv2-eclp-calls chain updatable_rateprovider pool:
    #!/usr/bin/env fish
    echo "Call 1:"
    echo "======="
    echo
    echo "Contract: UpdatableRateProviderBalV2 {{updatable_rateprovider}}"
    echo "Method: setPool()"
    echo "pool: {{pool}}"
    echo "pool_type: 0"
    echo
    echo "Call 2:"
    echo "======="
    echo
    echo "Contract: GovernanceRoleManager" (just get-contract {{chain}} GovernanceRoleManager)
    echo "Method: addPermission()"
    echo "user: {{updatable_rateprovider}}"
    echo "target:" (just get-contract {{chain}} GyroConfigManager)
    echo "selector: 0x60b2cf71"  # setPoolConfigUint see `forge selectors list GyroConfigManager`
    set pool_bytes32 (cast abi-encode 'foo(address)' {{pool}})
    set key_bytes32 (cast format-bytes32-string "PROTOCOL_SWAP_FEE_PERC")
    echo "parameters:" "[[0, \"$pool_bytes32\"], [1, \"$key_bytes32\"]]"
    echo
    echo "Call 3 (optional depending on protocol fee use):"
    echo "======="
    echo
    echo "Contract: GovernanceRoleManager" (just get-contract {{chain}} GovernanceRoleManager)
    echo "Method: addPermission()"
    echo "user: {{updatable_rateprovider}}"
    echo "target:" (just get-contract {{chain}} GyroConfigManager)
    echo "selector: 0xec1bf875"  # unsetPoolConfig see `forge selectors list GyroConfigManager`
    set pool_bytes32 (cast abi-encode 'foo(address)' {{pool}})
    set key_bytes32 (cast format-bytes32-string "PROTOCOL_SWAP_FEE_PERC")
    echo "parameters:" "[[0, \"$pool_bytes32\"], [1, \"$key_bytes32\"]]"
    
# Copy contract ABI to clipboard
copy-abi name:
    jq .abi out/{{name}}.sol/{{name}}.json | pbcopy

