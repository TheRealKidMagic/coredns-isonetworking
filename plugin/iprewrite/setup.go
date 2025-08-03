// setup.go
package iprewrite

import (
	"net"
	"strings"

	"github.com/coredns/caddy"
	"github.com/coredns/coredns/core/dnsserver"
	"github.com/coredns/coredns/plugin"
)

// init registers this plugin.
func init() { plugin.Register("iprewrite", setup) }

// setup is the function that gets called by the coredns framework to set up the plugin.
func setup(c *caddy.Controller) error {
	i := IP{}

	for c.Next() {
		for c.NextBlock() {
			switch c.Val() {
			case "mesh_domains":
				if !c.NextArg() {
					return c.ArgErr()
				}
				domains := strings.Split(c.Val(), ",")
				for _, d := range domains {
					i.MeshDomains = append(i.MeshDomains, strings.TrimSpace(d))
				}
			case "mesh_network_range":
				if !c.NextArg() {
					return c.ArgErr()
				}
				_, meshNet, err := net.ParseCIDR(c.Val())
				if err != nil {
					return c.Errf("invalid mesh network range: %s", c.Val())
				}
				i.MeshNetworkRange=meshNet
			case "node_domains":
				if !c.NextArg() {
					return c.ArgErr()
				}
				domains := strings.Split(c.Val(), ",")
				for _, d := range domains {
					i.NodeDomains = append(i.NodeDomains, strings.TrimSpace(d))
				}
			default:
				return c.Errf("unknown property '%s'", c.Val())
			}
		}
	}

	// Add the plugin to the chain
	dnsserver.Get.AddPlugin(func(next plugin.Handler) plugin.Handler {
		i.Next = next
		return i
	})
	
	return nil
}
