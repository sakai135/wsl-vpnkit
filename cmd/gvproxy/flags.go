package main

import (
	"flag"
	"net"

	"github.com/containers/gvisor-tap-vsock/pkg/types"
	"github.com/pkg/errors"
)

const (
	gatewayMacAddress = "5a:94:ef:e4:0c:dd"
	vmMacAddress      = "5a:94:ef:e4:0c:ee"
)

type proxyFlags struct {
	debug             bool
	mtu               int
	subnet            string
	gatewayIP         string
	hostIP            string
	vmIP              string
	gatewayMacAddress string
	vmMacAddress      string
}

func parseProxyFlags() (*types.Configuration, error) {
	f := &proxyFlags{}

	flag.BoolVar(&f.debug, "debug", false, "Print debug info")
	flag.IntVar(&f.mtu, "mtu", 1500, "Set the MTU")

	flag.StringVar(&f.subnet, "subnet", "192.168.127.0/24", "Set the subnet")
	flag.StringVar(&f.gatewayIP, "gateway-ip", "192.168.127.1", "Set the IP for the gateway")
	flag.StringVar(&f.hostIP, "host-ip", "192.168.127.254", "Set the IP for accessing the host from the WSL 2 VM")
	flag.StringVar(&f.vmIP, "vm-ip", "192.168.127.2", "Set the IP for the WSL 2 VM")

	flag.Parse()

	if net.ParseIP(f.gatewayIP) == nil {
		return nil, errors.New("invalid gateway-ip")
	}
	if net.ParseIP(f.hostIP) == nil {
		return nil, errors.New("invalid host-ip")
	}
	if net.ParseIP(f.vmIP) == nil {
		return nil, errors.New("invalid vm-ip")
	}
	if _, _, err := net.ParseCIDR(f.subnet); err != nil {
		return nil, errors.Wrap(err, "invalid subnet")
	}

	f.gatewayMacAddress = gatewayMacAddress
	f.vmMacAddress = vmMacAddress

	return configuration(f), nil
}

func configuration(c *proxyFlags) *types.Configuration {
	return &types.Configuration{
		Debug:             c.debug,
		CaptureFile:       "",
		MTU:               c.mtu,
		Subnet:            c.subnet,
		GatewayIP:         c.gatewayIP,
		GatewayMacAddress: gatewayMacAddress,
		DHCPStaticLeases: map[string]string{
			c.vmIP: c.vmMacAddress,
		},
		DNS: []types.Zone{
			{
				Name: "internal.",
				Records: []types.Record{
					{
						Name: "gateway",
						IP:   net.ParseIP(c.gatewayIP),
					},
					{
						Name: "host",
						IP:   net.ParseIP(c.hostIP),
					},
				},
			},
		},
		DNSSearchDomains: nil,
		Forwards:         map[string]string{},
		NAT: map[string]string{
			c.hostIP: "127.0.0.1",
		},
		GatewayVirtualIPs:      []string{c.hostIP},
		VpnKitUUIDMacAddresses: map[string]string{},
		Protocol:               types.HyperKitProtocol,
	}
}
