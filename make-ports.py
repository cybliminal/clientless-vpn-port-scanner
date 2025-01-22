import sys
from pprint import pprint

HEADER = """# nmap top 1000 TCP ports
# port, service, description
TOP_1000_PORTS = """

ports = []
for line in sys.stdin:
    # print(f"DEBUG: line={line}")
    service = []
    nmap_service = line.strip().split()
    # get the port number
    service.append(int(nmap_service[1].split("/")[0]))
    # get the service name
    service.append(nmap_service[0])
    # get the service description
    description = ""
    try:
        description = " ".join(nmap_service[4:])
    except IndexError as _:
        pass
    service.append(description)
    ports.append(service)

# print(HEADER)
print(HEADER, end="")
pprint(ports, indent=4)
