package main

import (
	"encoding/binary"
	"fmt"
	"io"
	"net"
	"os"
	"os/exec"
	"strconv"

	"github.com/google/gopacket"
	"github.com/google/gopacket/layers"
	"github.com/pkg/errors"
	"github.com/sakai135/wsl-vpnkit/pkg/transport"
	log "github.com/sirupsen/logrus"
	"github.com/songgao/packets/ethernet"
	"github.com/songgao/water"
	"github.com/vishvananda/netlink"
	"gvisor.dev/gvisor/pkg/tcpip/header"
)

func main() {
	f, err := parseVMFlags()
	if err != nil {
		log.Fatal(err)
	}

	if err := run(f); err != nil {
		log.Fatal(err)
		if err == io.EOF {
			os.Exit(1)
		}
	}
}

func parseProxyOptions(f *VMFlags) []string {
	options := []string{
		"-subnet", f.Subnet,
		"-gateway-ip", f.GatewayIP,
		"-host-ip", f.HostIP,
		"-vm-ip", f.VMIP,
		"-mtu", strconv.Itoa(f.ProxyMTU),
	}
	if f.Debug {
		options = append(options, "-debug")
	}
	return options
}

func run(f *VMFlags) error {
	conn, err := transport.Dial(f.Endpoint, parseProxyOptions(f)[:]...)
	if err != nil {
		return errors.Wrap(err, "cannot connect to host")
	}
	defer conn.Close()

	tap, err := water.New(water.Config{
		DeviceType: water.TAP,
		PlatformSpecificParams: water.PlatformSpecificParams{
			Name: f.Iface,
		},
	})
	if err != nil {
		return errors.Wrap(err, "cannot create tap device")
	}
	defer tap.Close()

	if err := linkUp(f.Iface, f.MAC); err != nil {
		return errors.Wrap(err, "cannot set mac address")
	}

	errCh := make(chan error, 1)
	go tx(conn, tap, errCh, f.MTU, f.Debug)
	go rx(conn, tap, errCh, f.MTU, f.Debug)
	go func() {
		if err := dhcp(f.Iface); err != nil {
			errCh <- errors.Wrap(err, "dhcp error")
		}
	}()
	return <-errCh
}

func linkUp(iface string, mac string) error {
	link, err := netlink.LinkByName(iface)
	if err != nil {
		return err
	}
	if mac == "" {
		return netlink.LinkSetUp(link)
	}
	hw, err := net.ParseMAC(mac)
	if err != nil {
		return err
	}
	if err := netlink.LinkSetHardwareAddr(link, hw); err != nil {
		return err
	}
	return netlink.LinkSetUp(link)
}

func dhcp(iface string) error {
	if _, err := exec.LookPath("udhcpc"); err == nil { // busybox dhcp client
		cmd := exec.Command("udhcpc", "-f", "-q", "-i", iface, "-v")
		cmd.Stderr = os.Stderr
		cmd.Stdout = os.Stderr
		return cmd.Run()
	}
	cmd := exec.Command("dhclient", "-4", "-d", "-v", iface)
	cmd.Stderr = os.Stderr
	cmd.Stdout = os.Stderr
	return cmd.Run()
}

func rx(conn net.Conn, tap *water.Interface, errCh chan error, mtu int, debug bool) {
	log.Info("waiting for packets...")
	var frame ethernet.Frame
	for {
		frame.Resize(mtu)
		n, err := tap.Read([]byte(frame))
		if err != nil {
			errCh <- errors.Wrap(err, "cannot read packet from tap")
			return
		}
		frame = frame[:n]

		if debug {
			packet := gopacket.NewPacket(frame, layers.LayerTypeEthernet, gopacket.Default)
			log.Info(packet.String())
		}

		size := make([]byte, 2)
		binary.LittleEndian.PutUint16(size, uint16(n))

		if _, err := conn.Write(size); err != nil {
			errCh <- errors.Wrap(err, "cannot write size to socket")
			return
		}
		if _, err := conn.Write(frame); err != nil {
			errCh <- errors.Wrap(err, "cannot write packet to socket")
			return
		}
	}
}

func tx(conn net.Conn, tap *water.Interface, errCh chan error, mtu int, debug bool) {
	sizeBuf := make([]byte, 2)
	buf := make([]byte, mtu+header.EthernetMinimumSize)

	for {
		n, err := io.ReadFull(conn, sizeBuf)
		if err != nil {
			errCh <- errors.Wrap(err, "cannot read size from socket")
			return
		}
		if n != 2 {
			errCh <- fmt.Errorf("unexpected size %d", n)
			return
		}
		size := int(binary.LittleEndian.Uint16(sizeBuf[0:2]))

		n, err = io.ReadFull(conn, buf[:size])
		if err != nil {
			errCh <- errors.Wrap(err, "cannot read payload from socket")
			return
		}
		if n == 0 || n != size {
			errCh <- fmt.Errorf("unexpected size %d != %d", n, size)
			return
		}

		if debug {
			packet := gopacket.NewPacket(buf[:size], layers.LayerTypeEthernet, gopacket.Default)
			log.Info(packet.String())
		}

		if _, err := tap.Write(buf[:size]); err != nil {
			errCh <- errors.Wrap(err, "cannot write packet to tap")
			return
		}
	}
}
