# coredns-isonetworking
A CoreDNS instance with a custom plugin provides a navigation path between services on isolated docker networks.

Usage:
- This container should be set up as a sidecar to a forwarder (like haproxy) that spans/is a member of multiple docker isolated networks.
- The forwarder is then set as the primary nameserver for all the services of the docker network
- This coredns instance, using the docker dns as its backend, will provide either:
  -  The requested service's IP address (if it is in the same network as the requestor service)
  -  The forwarder's IP address (that is in the same network as the requestor service, if the requested service is in a different isolated network)
  -  The forwarder's IP address (that is in the same network as the requestor service if the requested site is in a connected mesh network)
  -  The public IP address of the requested site (if it is not in the connected mesh network)
 
Docker compose example:

