package dns

import (
	"net"

	"github.com/containers/gvisor-tap-vsock/pkg/types"
	"github.com/miekg/dns"
)

func ServeListener(ln net.Listener, zones []types.Zone) error {
	mux := dns.NewServeMux()
	handler := &dnsHandler{zones: zones}
	mux.HandleFunc(".", handler.handle)
	srv := &dns.Server{
		Listener: ln,
		Handler:  mux,
	}
	return srv.ActivateAndServe()
}
