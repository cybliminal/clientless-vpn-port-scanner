from begin import formatters, start
from ports import TOP_1000_PORTS

from ipaddress import IPv4Network
import http.client
import ssl


FORMATTER = formatters.compose(formatters.RawDescription, formatters.RawArguments)
SSL_CONTEXT = ssl._create_unverified_context()


def scan_target(host, headers, ip, ports):
    """
    Scans a target host and checks if specified ports are open or responding.

    This function attempts to connect to a given host and port combination
    using HTTP. If a connection does not return any response data it assumes
    the port is not open or not responding.

    Args:
        host (str): The target host domain or IP.
        headers (dict): HTTP headers to include in the request.
        ip (str): The target IP address to scan.
        ports (list[int]): A list of ports to scan on the target IP.
    """
    for port in ports:
        conn = http.client.HTTPSConnection(host, 443, timeout=5, context=SSL_CONTEXT)
        try:
            conn.request("GET", f"/http-{port}/{ip}", headers=headers)
            _ = conn.getresponse()
            print(f"{ip}:{port}")
        except TimeoutError as _:
            # not open or responding
            pass
        except http.client.RemoteDisconnected as _:
            # not open or responding
            pass
        except http.client.BadStatusLine as _:
            # some kind of non-HTTP response was received
            print(f"{ip}:{port}")
        finally:
            conn.close()


@start(formatter_class=FORMATTER)  # pyright: ignore [reportCallIssue]
def clientless_vpn_port_scan(host, cookie, target, top_ports=10, port=None):
    """
    Conducts a TCP port scan via a Palo Alto Networks Global Protect clientless
    VPN gateway against a given target.

    This function scans specified ports or a subset of the top 1000 nmap ports
    on a target IP address, FQDN, or IP range. It uses HTTPS to attempt connections
    via the clientless VPN gateway identifies open ports. The function supports
    scanning multiple IPs derived from a CIDR range.

    Args:
        host (str): The target host domain or IP.
        cookie (str): The session cookie to include in HTTP requests.
        target (str): The target IP address or CIDR range.
        top_ports (int, optional): The number of top ports to scan (default: 10).
        port (str, optional): A comma-separated string of specific ports to scan.
                              Overrides `top_ports` if provided.

    Returns:
        None: Results are printed directly to stdout.

    Example:
        Scan a single target with the top 10 ports:
            clientless-vpn-port-scan.py vpn.example.com session_cookie 192.168.0.1

        Scan a range of IPs with specified ports:
            clientless-vpn-port-scan.py --port 80,443,8080 vpn.example.com session_cookie 192.168.0.0/24
    """
    if port:
        ports = [int(p) for p in port.split(",")]
    else:
        ports = TOP_1000_PORTS[: int(top_ports)]

    targets = []
    # check if we've been given an IP address prefix and convert it to a list of IPs
    if target.count("/") > 0:
        targets.extend([str(ip) for ip in IPv4Network(target)])
    else:
        targets.append(target)

    headers = dict(Cookie=f"GP_SESSION_CK={cookie}")
    for ip in targets:
        scan_target(host, headers, ip, ports)
