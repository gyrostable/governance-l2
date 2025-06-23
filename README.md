## Gyroscope L2 governance

This contract contains the logic to be able to execute governance changes on layer 2.
All changes must be triggered by the [Ethereum mainnet governance contract](https://etherscan.io/address/0x78EcF97572c3890eD02221A611014F30219f6219).

To generate calldata for this, you can use `script/GenerateCalldata.s.sol` (on Ethereum).

To generate calldata to help using the GovernanceRoleManager use `script/GenerateL2Calldata.s.sol` and the commands in the justfile.

To deploy, use `scripts/*.s.sol`. We use create3 to get deterministic addresses. You need `PRIVATE_KEY` in your `.env`.

### Some helpful pointers

Bytes32-encoded form of "PROTOCOL_SWAP_FEE_PERC" = 0x50524f544f434f4c5f535741505f4645455f5045524300000000000000000000

### How to deploy GovernanceRoleManager and GyroConfigManager on a new chain

1. Add the GyroConfig address to `script/DeployGyroConfigManager.s.sol`.
2. Deploy GovernanceRoleManager using the script. Initial governor will be the deployer. To verify the contracts, you have to verify _both_ the implementation and the UUPS proxy. Use `forge verify-contract` and use the constructor args output by the script.
3. Deploy GyroConfigManager using the script. Owner will be the GovernanceRoleManager. This is not a proxy. To verify, use the constructor args output by the script.
4. Add these two new deployments to `docs/deployed-contracts.json5`.
5. Add permission to call any action on GyroConfigManager for the designated admin (currently a multisig) using the selector whildcard, `0x00000000`.
6. **!DANGER ZONE, don't mess this up!** Move governance of GyroConfig to GyroConfigManager
	1. From the old governor (likely a multisig), call `GyroConfig.changeGovernor(GyroConfigManager)`.
	2. From the new admin (perhaps a multisig), call `GovernanceRoleManager.executeActions([[GyroConfigManager, GyroConfig.acceptGovernance, 0]])`.
7. Move ownership of the GovernanceRoleManager to its target owner (currently often a multisig)

