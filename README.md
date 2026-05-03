<h1 align="center">
XMRig
</h1>

<div align="center">

[![Static Badge](https://img.shields.io/badge/GitHub-blue?style=flat&logo=github)](https://github.com/XternA/xmrig)
[![Static Badge](https://img.shields.io/badge/License-purple?style=flat&logo=github)](https://github.com/XternA/xmrig?tab=License-1-ov-file)
[![GitHub Release Date](https://img.shields.io/github/release-date/XternA/xmrig?style=&label=Latest%20Release)](https://github.com/XternA/xmrig/releases)
[![GitHub Release](https://img.shields.io/github/v/release/XternA/xmrig?sort=date&display_name=release&style=flat&label=Version)](https://github.com/XternA/xmrig/releases/latest)
![GitHub package.json dynamic](https://img.shields.io/github/package-json/version/XternA/xmrig?style=flat&logo=opencontainersinitiative&label=Image%20Tag&color=red)
[![GitHub Repo stars](https://img.shields.io/github/stars/XternA/xmrig?style=flat&logo=github&label=Stars&color=orange)](https://github.com/XternA/xmrig)

If you like this project, don't forget to leave a star. ⭐

![Logo](./assets/banner.svg)

</div>

A lightweight, containerized, performance-optimised [XMRig](https://github.com/xmrig/xmrig) miner for mining Monero.
Provide your pool details and start mining — no setup, no dependencies, no fuss.

### Features

- 🔒 **Isolated and sandboxed** — runs as non-root, self-contained, host stays clean, removes without a trace
- 🏔️ **Lightweight Alpine image** — native builds for amd64 & arm64
- 🎯 **Ready to mine** — sensible defaults pre-configured, no setup required

## Quick Start 🚀

The quickest way to start mining, supply your pool details and run.

```markdown
docker run --rm -it ghcr.io/xterna/xmrig -o <pool_url> -u <wallet_address> -p <worker_name>
```

| Flag | Description |
|---|---|
| `-o` | Pool address and port |
| `-u` | Your XMR wallet address |
| `-p` | Worker name for identification on the pool |

Miner runs in interactive mode. Press `Ctrl+C` to stop and remove the miner.

## Usage

### Zero Configuration (Recommended)

Pass your pool details directly. The miner starts immediately with a pre-optimised config:

```markdown
docker run -d --name xmrig ghcr.io/xterna/xmrig -o <pool_url> -u <wallet_address> -p <worker_name>
```

As environment variables:
```sh
docker run -d --name xmrig ghcr.io/xterna/xmrig -o $POOL_URL -u $WALLET_ADDRESS -p $WORKER_NAME
```

The miner is now running as a daemon.

---

### Mounted Config File (Flexible Control)

For advanced configuration — custom thread counts, multiple pools, algorithm tuning. 

Generate a config using the [XMRig Wizard Helper](https://xmrig.com/wizard) and mount your config file:

```sh
docker run -d --name xmrig -v /config_path/config.json:/app/config.json ghcr.io/xterna/xmrig
```

Your custom config is now used instead.

> Ensure your config has `"autosave": false` and `"watch": false`. Auto-saving and file watching serve no purpose in a container. It will also inflate your config file, making it harder to maintain and remember your preferences.

> Changes to `config.json` require a container restart to take effect.

See [Config Wiki](https://xmrig.com/docs/miner/config) for all available options.

---

### Direct CLI Mode

Pass `--cli` to bypass the internal config entirely and send all arguments directly to XMRig. This gives you complete control over every XMRig flag:

```markdown
docker run -d --name xmrig ghcr.io/xterna/xmrig \
  --cli -o <pool_url> -u <wallet_address> -p <worker_name> -k --tls ...
```

> In CLI mode, the internal optimised config is not loaded. You control all settings via flags. Use `docker run --rm ghcr.io/xterna/xmrig --cli --help` for the full list of XMRig options.


## Container Management

```sh
docker restart xmrig    # restart the miner
docker stop xmrig       # stop the miner
docker logs -f xmrig    # follow live output
docker pause xmrig      # pause without stopping
```

For help and commands, see [XMRig documentation](https://xmrig.com/docs/miner/cli-options).

```sh
docker run --rm ghcr.io/xterna/xmrig --cli --help
```

## Donations

- Default donation 1% (1 minute in 100 minutes) can be increased via the `donate-level` option in the config file.
- XMR: `87LGyTzNrRCFGAAGVkKD6wL4a3xFpLAfh7JL3RbmbvhUgWW1BHbtrkT7M5wkMWEEvSQdz2VJemvfgYvVWnC49e7S6BRA9Xv`

## RandomX Optimisation

### Huge Pages

Enabling huge pages on supported systems reduces TLB pressure on the RandomX scratchpad, lowering memory management overhead and improving hashrate by **up to 30%**.

```sh
# Temporary (resets on reboot)
sudo sysctl -w vm.nr_hugepages=1280

# Permanent
sudo bash -c "echo vm.nr_hugepages=1280 >> /etc/sysctl.conf"

# Removing huge pages
sudo sed -i '/vm.nr_hugepages=1280/d' /etc/sysctl.conf
```

> Note: 1280 pages reserves 2560 MB exclusively for huge pages, unavailable for other use. The miner automatically uses the precise number it needs.

Restart the container after configuring.

---

### MSR (Model Specific Register)

MSR writes allow XMRig to tune CPU microarchitectural settings for RandomX, achieving optimal hashrates on supported hardware.

#### Supported CPUs:
- Intel (Nehalem, Westmere, Sandy Bridge, Ivy Bridge, Haswell, Broadwell and newer)
- Ryzen (All Zen based CPUs: Ryzen, Threadripper, EPYC)

Load the MSR module on the host:
```sh
sudo modprobe msr
```

Run the container with the `--privileged` flag:

```markdown
docker run --rm -it --privileged ghcr.io/xterna/xmrig -o <pool_url> -u <wallet_address> -p <worker_name>
```