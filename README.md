# monad-validator-tool
All-in-one CLI tool for Monad validator operations (testnet/mainnet)

# ⬡ Monad Validator Management Tool

A comprehensive CLI tool for managing Monad validator/fullnode operations on both **testnet** and **mainnet**.

Built by [MegaNode](https://meganode.top/) — an independent Monad validator operator.

## Features

| # | Feature | Description |
|---|---------|-------------|
| 1 | **Quick Status** | Services health, block height, RAM, swap at a glance |
| 2 | **Sync Verification** | Compare local block vs network block with sync percentage |
| 3 | **Service Status** | Detailed systemd status for monad-bft, execution, rpc |
| 4 | **View Logs** | Browse recent logs or follow realtime; filter errors/warnings |
| 5 | **Resource Monitor** | CPU, RAM, disk, TrieDB usage, CPU isolation, time sync |
| 6 | **Wallet Balance** | Check MON balance of any address via local RPC |
| 7 | **Restart Services** | Restart individual or all Monad services safely |
| 8 | **Soft Reset** | Clear WAL/ledger, re-download forkpoint (TrieDB preserved) |
| 9 | **Hard Reset** | Full wipe: TrieDB + snapshot re-import from scratch |
| 10 | **Swap Management** | Clear swap, set swappiness, check monitoring cron |
| 11 | **Environment Check** | Verify .env, node.toml config, binary versions, system info |

## Requirements

- Ubuntu 22.04 / 24.04
- Monad node installed ([official docs](https://docs.monad.xyz/node-ops))
- `jq`, `curl` installed
- Root or sudo access

## Installation

```bash
# Clone the repo
git clone https://github.com/mega-node/monad-validator-tool.git
cd monad-validator-tool

# Make executable
chmod +x monad-tool.sh

# Run
sudo bash monad-tool.sh
```

Or one-liner:

```bash
curl -sSL https://raw.githubusercontent.com/mega-node/monad-validator-tool/main/monad-tool.sh -o monad-tool.sh && chmod +x monad-tool.sh && sudo bash monad-tool.sh
```

## Usage

1. Select network: **Testnet** or **Mainnet**

   
   <img width="527" height="232" alt="Screenshot 2026-05-25 162106" src="https://github.com/user-attachments/assets/d78092d6-0e3a-44e3-b95a-f0e1001f1e8a" />

2. Choose from the menu (1-11)
3. Follow on-screen instructions

```
╔══════════════════════════════════════════════════════╗
║  ⬡ MONAD VALIDATOR MANAGEMENT TOOL v1.0             ║
║  MegaNode                                  ║
╚══════════════════════════════════════════════════════╝

 Network: TESTNET | RPC: http://localhost:8080
──────────────────────────────────────────────────────
   1)  Quick Status Check
   2)  Sync Verification
   3)  Service Status (detailed)
   4)  View Logs
   5)  Resource Monitor
   6)  Wallet Balance
   7)  Restart Services
   8)  Soft Reset
   9)  Hard Reset
  10)  Swap Management
  11)  Environment Check
──────────────────────────────────────────────────────
   s)  Switch Network
   0)  Exit
```

## Network Configuration

| Setting | Testnet | Mainnet |
|---------|---------|---------|
| Chain | `monad_testnet` | `monad_mainnet` |
| Public RPC | `https://testnet-rpc.monad.xyz` | `https://rpc.monad.xyz` |
| Local RPC | Auto-detected (default: 8080) | Auto-detected (default: 8080) |
| Snapshot Bucket | `bucket.monadinfra.com` | `bucket.monadinfra.com` |

## Safety

- **Read-only by default** — status checks and monitoring don't modify anything
- **Confirmation required** — Soft Reset and Hard Reset require explicit confirmation
- **Hard Reset requires typing `YES`** — extra safety for destructive operations
- **No private keys stored or transmitted** — the tool only reads public blockchain data
- **Open source** — review the code before running

## Soft Reset vs Hard Reset

| | Soft Reset | Hard Reset |
|---|-----------|-----------|
| Stops services | ✅ | ✅ |
| Clears WAL & ledger | ✅ | ✅ |
| Wipes TrieDB | ❌ | ✅ |
| Re-imports snapshot | ❌ | ✅ |
| Downtime | Minutes | 30min - 2hrs |
| Use when | Minor sync issues | TrieDB corruption |

## Performance Tuning (Recommended)

For optimal validator performance, we recommend:

- **Swap**: Set `vm.swappiness=1` (use option 10)
- **CPU Governor**: Set to `performance` mode
- **CPU Isolation**: Dedicate CPUs to Monad services via systemd
- **Time Sync**: Install `chrony` for accurate NTP
- **Separate NVMe**: Use dedicated NVMe for TrieDB, OS, and other services

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/new-feature`)
3. Commit your changes (`git commit -m 'Add new feature'`)
4. Push to the branch (`git push origin feature/new-feature`)
5. Open a Pull Request

## License

MIT License — see [LICENSE](LICENSE) for details.

## Disclaimer

This tool is provided as-is for the Monad validator community. It is not officially affiliated with or endorsed by Monad Labs. Always review the code before running on production systems. Use at your own risk.

## Links

- [Monad Official Docs](https://docs.monad.xyz)
- [Monad Node Operations](https://docs.monad.xyz/node-ops)
- [Staking SDK CLI](https://github.com/monad-developers/staking-sdk-cli)
- [MegaNode](https://meganode.top/)
