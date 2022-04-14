package transport

import "testing"

func TestNetwork(t *testing.T) {
	addr := &IoAddr{path: "path"}
	result := addr.Network()

	if "stdio" != result {
		t.Errorf("unexpected result %s", result)
	}
}

func TestString(t *testing.T) {
	addr := &IoAddr{path: "path"}
	result := addr.String()

	if "path" != result {
		t.Errorf("unexpected result %s", result)
	}
}
