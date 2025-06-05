# Encode protocol fee setting op. Usage: just encode-set-protocol-fee 0xdeadbeef '0.5e18'
encode-set-protocol-fee pool fee:
    forge script script/GenerateL2Calldata.s.sol -s 'setProtocolFee(address,uint256)' {{pool}} {{fee}}
encode-set-protocol-fee-gyro-portion pool fee:
    forge script script/GenerateL2Calldata.s.sol -s 'setProtocolFeeGyroPortion(address,uint256)' {{pool}} {{fee}}

# generate permissions for setting PROTOCOL_SWAP_FEE_PERC for a given pool. In json for Safe.
mk-protocol-fee-permissions-json pool:
    #!/usr/bin/env fish
    set pool_bytes32 (cast abi-encode 'foo(address)' {{pool}})
    set key_bytes32 (cast format-bytes32-string "PROTOCOL_SWAP_FEE_PERC")
    echo "target: GyroConfigManager, see docs/deployed-contracts.md"
    echo "selector: 0x60b2cf71"  # see `forge selectors list GyroConfigManager`
    echo "parameters:" "[[0, \"$pool_bytes32\"], [1, \"$key_bytes32\"]]"

