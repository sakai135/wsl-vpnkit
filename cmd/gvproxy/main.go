package main

import (
	"context"
	"flag"
	"os"
	"os/signal"
	"syscall"

	"github.com/containers/gvisor-tap-vsock/pkg/types"
	"github.com/containers/gvisor-tap-vsock/pkg/virtualnetwork"
	"github.com/pkg/errors"
	"github.com/sakai135/wsl-vpnkit/pkg/transport"
	log "github.com/sirupsen/logrus"
	"golang.org/x/sync/errgroup"
)

var (
	debug bool
	mtu   int

	exitCode int

	subnet    string
	gatewayIP string
	hostIP    string
	vmIP      string
)

const (
	gatewayMacAddress = "5a:94:ef:e4:0c:dd"
	vmMacAddress      = "5a:94:ef:e4:0c:ee"
)

func main() {
	log.SetOutput(os.Stderr)

	flag.BoolVar(&debug, "debug", false, "Print debug info")
	flag.IntVar(&mtu, "mtu", 1500, "Set the MTU")

	flag.StringVar(&subnet, "subnet", "192.168.127.0/24", "Set the subnet")
	flag.StringVar(&gatewayIP, "gateway-ip", "192.168.127.1", "Set the IP for the gateway")
	flag.StringVar(&hostIP, "host-ip", "192.168.127.254", "Set the IP for accessing the host from the WSL 2 VM")
	flag.StringVar(&vmIP, "vm-ip", "192.168.127.2", "Set the IP for the WSL 2 VM")

	flag.Parse()
	ctx, cancel := context.WithCancel(context.Background())
	// Make this the last defer statement in the stack
	defer os.Exit(exitCode)

	groupErrs, ctx := errgroup.WithContext(ctx)
	// Setup signal channel for catching user signals
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM, syscall.SIGINT)

	if debug {
		log.SetLevel(log.DebugLevel)
	}

	config := types.Configuration{
		Debug:             debug,
		CaptureFile:       "",
		MTU:               mtu,
		Subnet:            subnet,
		GatewayIP:         gatewayIP,
		GatewayMacAddress: gatewayMacAddress,
		DHCPStaticLeases: map[string]string{
			vmIP: vmMacAddress,
		},
		DNS:              []types.Zone{},
		DNSSearchDomains: nil,
		Forwards:         map[string]string{},
		NAT: map[string]string{
			hostIP: "127.0.0.1",
		},
		GatewayVirtualIPs: []string{hostIP},
		VpnKitUUIDMacAddresses: map[string]string{
			"c3d68012-0208-11ea-9fd7-f2189899ab08": vmMacAddress,
		},
		Protocol: types.HyperKitProtocol,
	}

	groupErrs.Go(func() error {
		return run(ctx, groupErrs, &config)
	})

	// Wait for something to happen
	groupErrs.Go(func() error {
		select {
		// Catch signals so exits are graceful and defers can run
		case <-sigChan:
			cancel()
			return errors.New("signal caught")
		case <-ctx.Done():
			return nil
		}
	})
	// Wait for all of the go funcs to finish up
	if err := groupErrs.Wait(); err != nil {
		log.Error(err)
		exitCode = 1
	}
}

func run(ctx context.Context, g *errgroup.Group, configuration *types.Configuration) error {
	vn, err := virtualnetwork.New(configuration)
	if err != nil {
		return err
	}

	conn := transport.GetStdioConn()
	err = vn.AcceptQemu(ctx, conn)
	if err != nil {
		return err
	}

	return nil
}
