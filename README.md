# Global Protect Clientless VPN Port Scanner

The Palo Alto Networks Clientless VPN feature allows for the port to be
specified in int schema portion of the URL path

```
https://clientlessvpn.example.com/<schema>-<port>/domain/path
```

Supported schema are `http` and `https`.

The `clientless-port-scanner.py` uses this functionality to perform rudimentary
TCP port scanning.

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
python clientless-port-scanner.py [options] <vpn fqdn> <cookie> <target>
```

Scan the top 10 nmap ports on `target` via `clientlessvpn.example.com`:

```sh
python clientless-port-scanner.py clientlessvpn.example.com XYZ1234abcjsieZY/g target
```

Scan the top 50 nmap ports on IP range `172.16.0.0/24` via
`clientlessvpn.example.com`:

```sh
python clientless-port-scanner.py --top-ports 50 clientlessvpn.example.com XYZ1234abcjsieZY/g target
```

Scan ports 22 and 23 on IP range `172.16.0.0/24` via
`clientlessvpn.example.com`:

```sh
python clientless-port-scanner.py --port 22,23 clientlessvpn.example.com XYZ1234abcjsieZY/g 172.16.0.0/24
```

## Caveats

In testing the port scanning with a variety of services can return a false
negative if the service does not return any response then even if it was able to
connect to it then it will be deemed as closed.

For example RDP (TCP/3389) does not return a response when the clientless VPN
gateway connects to it so it will be treated as closed even though it may be
open.

## To Do

- Investigate using something other than http.client that may allow sending
  non-HTTP protocol data.
- Perform timing analysis to see if we use timing as a means to detect if a
  non-HTTP port is open or closed.
