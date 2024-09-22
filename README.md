# XMRig ⛏️🐳

[![Static Badge](https://img.shields.io/badge/GitHub-blue?style=flat&logo=github)](https://github.com/XternA/xmrig)
[![Docker Pulls](https://img.shields.io/docker/pulls/xterna/xmrig?logo=docker&label=Docker%20Pulls)](https://hub.docker.com/r/xterna/xmrig)
[![Docker Stars](https://img.shields.io/docker/stars/xterna/xmrig?logo=docker&label=Docker%20Stars)](https://hub.docker.com/r/xterna/xmrig)
[![Docker Image Version (tag)](https://img.shields.io/docker/v/xterna/xmrig?style=flat&logo=docker&label=Version)](https://hub.docker.com/r/xterna/xmrig/tags)
[![Docker Image Size](https://img.shields.io/docker/image-size/xterna/xmrig?logo=docker&label=Image%20Size&color=red)](https://hub.docker.com/r/xterna/xmrig/tags)
[![GitHub Repo stars](https://img.shields.io/github/stars/XternA/xmrig?style=flat&logo=github&label=Stars&color=orange)](https://github.com/XternA/xmrig)
[![Donate](https://img.shields.io/badge/Donate-PayPal-blue.svg?style=flat&logo=paypal)](https://www.paypal.com/donate/?hosted_button_id=32DCQ65QM5FNE)

This [**XMRig**](https://hub.docker.com/r/xterna/xmrig) image is regularly updated with the latest releases and is built on Alpine for optimal performance and minimal size.

This containerized XMRig will CPU mine very well on-par with bare-metal version, ensuring minimal setup nor requiring additional binaries on the host.

If you're new to Monero (XMR) mining and need a wallet/address, see [Exodus wallet](https://www.exodus.com/download/), supporting XMR and can swap to other currencies.

## Quick Start 🚀
The simplest execution to start mining:

```markdown
docker run --rm xterna/xmrig -k --tls -o <POOL:PORT> -u <USER> -p <PASSWORD>
```

**Example:**
```sh
docker run --rm xterna/xmrig -k --tls -o pool.supportxmr.com:443 -u mW9G4TzVdEU5RX3KZp7A8fYRoZ1xg9BJnYH2iUeLkQvMdFwz8i6X6zRp5lSUjc -p Node-1
```

## Getting Started
A top mining pool choice for XMR is [SupportXMR](https://supportxmr.com/). To mine with SupportXMR, simply use your Monero wallet address as your username. Set the password as your alias, e.g. your host name for easy identification if running multiple nodes.

### Run Recommendation

#### Without config file
```markdown
docker run -d --restart always --name xmrig xterna/xmrig -k --tls -o <POOL:PORT> -u <USER> -p <PASSWORD>
```

#### With config file
```markdown
docker run -d -v /host/path/to/file/config.json:/app/config.json --restart always --name xmrig xterna/xmrig
```
You must map the config to the exact path of the container to override the file, or it won't be used. Any changes to the `config.json` will require restarting the container.

```
docker restart xmrig
```

### Stop/Pause
To stop or pause the miner:
```sh
docker stop xmrig
docker pause xmrig
```

### For Help and Commands
```sh
docker run --rm xterna/xmrig --help
```
This will list the commands of the actual xmrig miner.

## Improve Performance (Linux)
By increasing the `HugePages` memory management feature in Linux, you can easily increase the performance gain by up to 30%.

Using the following command will set the `HugePages`:

```sh
# Get the script from the container
docker cp xterna/xmrig:/app/huge-page.sh .

# Run the script to adjust the HugePages
sh huge-page.sh
```

You may need to restart the container in order for the changes to take effect.