## Gyroscope L2 governance

This contract contains the logic to be able to execute governance changes on layer 2.
All changes must be triggered by the [Ethereum mainnet governance contract](https://etherscan.io/address/0x78EcF97572c3890eD02221A611014F30219f6219).

To generate calldata for this, you can use `script/GenerateCalldata.s.sol` (on Ethereum).

To deploy, use `scripts/*.s.sol`. We use create3 to get deterministic addresses. You need `PRIVATE_KEY` in your `.env`.

