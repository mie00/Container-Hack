# Container Hacking

This script bruteforces ssh passwords inside containers (e.g. docker, lxc) running in physical machines on the same network.

The script succeeds only if:

1. The physical machine has no firewall and doesn't have proper rules for ip forward.
2. There is an ssh server running inside the container.
3. There is an easy password for the user inside the container.

## Dependencies

sshpass
nmap
openssh-client
iproute2

## Usage

```
Usage ./hack.sh [OPTION]

Options are:
  -n, --network=NETWORK        the nerwork that contains te physical machine (192.168.1.0/24)
  -i, --interface=INTERFACE    the interface connected to the network (eth0)
  -s, --scan=SCAN              the ranges to be scanned inside the physical machines (172.17.0.0/24,10.0.3.0/24)
  -u, --usernames=FILE         a file containing the list of usernames to be tried
  -p, --passwords=FILE         a file containing the list of passwords to be tried
  -h, --help                   print this help
```
