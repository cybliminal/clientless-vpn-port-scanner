# Global Protect Clientless VPN Port Scanner

The Palo Alto Networks Clientless VPN feature allows for the port to be
specified in the schema portion of the URL path:

```
https://clientlessvpn.example.com/<schema>-<port>/domain/path
```

Supported schema are `http` and `https`.

The `clientless_vpn_port_scanner.py` uses this functionality to perform
rudimentary TCP port scanning.

In order to run a scan you need:
- the clientless VPN gateway domain e.g. `clientlessvpn.example.com`
- the value of the `GP_SESSION_CK` session cookie from a user logged in to the
  VPN.
  You can get this from the browser developer tools, BurpSuite etc.
- the target IP range, IP address, or domain name.

## Installation

Clone this repo.

Install the required python modules:

```sh
pip install -r requirements.txt
```

## Usage


```sh
python clientless_vpn_port_scanner.py [options] <vpn fqdn> <cookie> <target>
```

Scan the top 10 nmap ports on `target` via `clientlessvpn.example.com`:

```sh
python clientless_vpn_port_scanner.py clientlessvpn.example.com XYZ1234abcjsieZY/g target
```

Scan the top 50 nmap ports on IP range `172.16.0.0/24` via
`clientlessvpn.example.com`:

```sh
python clientless-port-scanner.py --top-ports 50 clientlessvpn.example.com XYZ1234abcjsieZY/g target
```

Scan ports 22 and 23 on IP range `172.16.0.0/24` via
`clientlessvpn.example.com`:

```sh
python clientless_vpn_port_scanner.py --port 22,23 clientlessvpn.example.com XYZ1234abcjsieZY/g 172.16.0.0/24
```
Example output:

```sh
python clientless_vpn_port_scanner.py \
	clientlessvpn.example.com \
	tyCHJqwpQmCh/qB6G5LyTMm1iIXzjkJA \
	172.16.2.7
172.16.2.7:80 (http) [World Wide Web HTTP]
172.16.2.7:443 (https) [secure http (SSL)]
172.16.2.7:22 (ssh) [Secure Shell Login]
172.16.2.7:139 (netbios-ssn) [NETBIOS Session Service]
```

## Caveats

In testing the port scanning with a variety of services can return a false
negative if the service does not return any response then, even if it was able
to connect, it will be deemed as closed.

For example RDP (TCP/3389) does not return a response when the clientless VPN
gateway connects to it so it will be treated as closed even though it may be
open.

## To Do

- Investigate using something other than python's standard library `http.client`
  that may allow sending non-HTTP protocol data.
- Perform timing analysis to see if we can use timing differences as a means to
  detect if a non-HTTP port is open or closed.

## ports.py

The `ports.py` contains a list of the top 1000 TCP services according to nmap.

It is created by running the command:

```sh
sort -r -k3 /usr/share/nmap/nmap-services | grep '/tcp' | head -1000 | python make-ports.py > ports.py
```
