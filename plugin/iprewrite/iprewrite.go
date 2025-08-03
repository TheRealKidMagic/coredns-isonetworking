// github.com/TheRealKidMagic/coredns-isonetworking/plugin/iprewrite/iprewrite.go

package iprewrite

import (
	"context"
	"fmt"
	"net"
	"strings"

	"github.com/coredns/coredns/plugin"
	"github.com/coredns/coredns/request"
	"github.com/miekg/dns"
)

// IP a holds the plugin configuration.
type IP struct {
	Next				plugin.Handler
	MeshDomains			[]string
	MeshNetworkRange	*net.IPNet
	NodeDomains			[]string
}

const dockerDNS = "127.0.0.11"

// ServeDNS implements the plugin.Handler interface.
func (i IP) ServeDNS(ctx context.Context, w dns.ResponseWriter, r *dns.Msg) (int, error) {
	state := request.Request{W: w, Req: r}
	qName := state.QName()
	clientIP := w.RemoteAddr().(*net.UDPAddr).IP

	// Dynamically get the list of CoreDNS IPs
	corednsIPs, err := getCorednsIPs()
	if err != nil {
		return dns.RcodeServerFailure, fmt.Errorf("failed to get CoreDNS IPs: %w", err)
	}

	// Perform the initial query to Docker DNS
	response, err := i.forwardTo(r, dockerDNS)
	if err != nil {
		return dns.RcodeServerFailure, err
	}

	// Get the IP of the requested site from the response
	var requestedIP net.IP
	if len(response.Answer) > 0 {
		if a, ok := response.Answer[0].(*dns.A); ok {
			requestedIP = a.A
		}
	}

	// Decision-making logic

	// 1) Is the IP of the requested site in the subnet with the requesting service?
	if requestedIP != nil && isSameSubnet(clientIP, requestedIP) {
		w.WriteMsg(response)
		return dns.RcodeSuccess, nil
	}

	// 2) Is the requested site in a subnet with coredns?
	for _, corednsIP := range corednsIPs {
		if isSameSubnet(requestedIP, corednsIP) {
			rewrittenIP := getIPInSubnet(clientIP, corednsIPs)
			if rewrittenIP != nil {
				m := new(dns.Msg)
				m.SetReply(r)
				m.Authoritative = true
				hdr := dns.RR_Header{Name: state.QName(), Rrtype: dns.TypeA, Class: dns.ClassINET, Ttl: 60}
				a := &dns.A{Hdr: hdr, A: rewrittenIP}
				m.Answer = append(m.Answer, a)
				w.WriteMsg(m)
				return dns.RcodeSuccess, nil
			}
		}
	}

	// 3) Is the requested site's domain in the mesh or a node domain? Is the requested site's IP address in the mesh?
	isMeshDomain := false
	for _, meshDomain := range i.MeshDomains {
		if strings.HasSuffix(qName, meshDomain) {
			isMeshDomain = true
			break
		}
	}

	isNodeDomain := false
	for _, nodeDomain := range i.NodeDomains {
		if strings.HasSuffix(qName, nodeDomain) && strings.Count(qName, ".") == strings.Count(nodeDomain, ".") + 1 {
			isNodeDomain = true
			break
		}
	}

	if isMeshDomain || isNodeDomain || (requestedIP != nil && i.MeshNetworkRange.Contains(requestedIP)) {
		rewrittenIP := getIPInSubnet(clientIP, corednsIPs)
		if rewrittenIP != nil {
			m := new(dns.Msg)
			m.SetReply(r)
			m.Authoritative = true
			hdr := dns.RR_Header{Name: state.QName(), Rrtype: dns.TypeA, Class: dns.ClassINET, Ttl: 60}
			a := &dns.A{Hdr: hdr, A: rewrittenIP}
			m.Answer = append(m.Answer, a)
			w.WriteMsg(m)
			return dns.RcodeSuccess, nil
		}
	}

	// 4) Logic for mesh and external domains is now handled by other plugins
	w.WriteMsg(response)
	return dns.RcodeSuccess, nil
}

// Name implements the plugin.Handler interface
func (i IP) Name() string { return "iprewrite" }

// getCorednsIPs dynamically discovers all IP address of the Coredns container.
func getCorednsIPs() ([]net.IP, error) {
	ifaces, err := net.Interfaces()
	if err != nil {
		return nil, err
	}
	var ips []net.IP
	for _, iface := range ifaces {
		if iface.Flags&net.FlagUp == 0 || iface.Flags&net.FlagLoopback != 0 {
			continue // Skip down interfaces and loopback
		}
		addrs, err := iface.Addrs()
		if err != nil {
			continue
		}
		for _, addr := range addrs {
			var ip net.IP
			switch v := addr.(type) {
			case *net.IPNet:
				ip = v.IP
			case *net.IPAddr:
				ip = v.IP
			}
			if ip == nil || ip.IsLoopback() || ip.To4() == nil {
				continue // Skip non-IPv4 or loopback IPs
			}
			ips = append(ips, ip)
		}
	}
	return ips, nil
}

// isSameSubnet checks if two IPs are in the same subnet
func isSameSubnet(ip1, ip2 net.IP) bool {
	// This is a placeholder for a more robust subnet comparison,
	// which would require knowing the subnet mask.  For this example,
	// we'll assume a /24 and compare the first three octets
	return ip1.To4()[0] == ip2.To4()[0] && ip1.To4()[1] == ip2.To4()[1] && ip1.To4()[2] == ip2.To4()[2]
}

// getIPInSubnet returns the CoreDNS IP that is in the same subnet as the client IP
func getIPInSubnet(clientIP net.IP, corednsIPs []net.IP) net.IP {
	for _, corednsIP := range corednsIPs {
		if isSameSubnet(clientIP, corednsIP) {
			return corednsIP
		}
	}
	return nil
}

// forwardTo forwards a DNS request to a specified upstream server.
func (i IP) forwardTo(r *dns.Msg, upstream string) (*dns.Msg, error) {
	c := new(dns.Client)
	resp, _, err := c.Exchange(r, net.JoinHostPort(upstream, "53"))
	if err != nil {
		return nil, fmt.Errorf("failed to forward DNS query: %w", err)
	}
	return resp, nil
}
