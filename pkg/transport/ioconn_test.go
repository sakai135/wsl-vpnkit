package transport

import (
	"bytes"
	"strings"
	"testing"
	"time"

	"github.com/google/go-cmp/cmp"
)

func TestRead(t *testing.T) {
	buf := make([]byte, 10)
	conn := &IoConn{reader: strings.NewReader("aaaaa")}
	i, err := conn.Read(buf)

	if 5 != i {
		t.Errorf("unexpected bytes read %d", i)
	}
	if err != nil {
		t.Error("unexpected error")
	}
	expected := make([]byte, 10)
	copy(expected, []byte("aaaaa"))
	if !cmp.Equal(expected, buf) {
		t.Error(cmp.Diff(expected, buf))
	}
}

func TestWrite(t *testing.T) {
	writer := &bytes.Buffer{}
	conn := &IoConn{writer: writer}
	i, err := conn.Write([]byte("aaaaa"))

	if err != nil {
		t.Error(err)
	}
	if i != 5 {
		t.Errorf("unexpected bytes written %d", i)
	}
	expected := []byte("aaaaa")
	if !cmp.Equal(expected, writer.Bytes()) {
		t.Error(cmp.Diff(expected, writer.Bytes()))
	}
}

func TestClose_Nil(t *testing.T) {
	conn := &IoConn{}
	err := conn.Close()

	if err != nil {
		t.Error(err)
	}
}

func TestClose_FuncSuccess(t *testing.T) {
	called := false
	conn := &IoConn{
		close: func() error {
			called = true
			return nil
		},
	}
	err := conn.Close()

	if err != nil {
		t.Error(err)
	}
	if !called {
		t.Error("called should be true")
	}
}

func TestLocalAddr(t *testing.T) {
	conn := &IoConn{local: &IoAddr{path: "local"}}

	if "local" != conn.LocalAddr().String() {
		t.Error("unexpected local")
	}
}

func TestRemoteAddr(t *testing.T) {
	conn := &IoConn{remote: &IoAddr{path: "remote"}}

	if "remote" != conn.RemoteAddr().String() {
		t.Error("unexpected local")
	}
}

func TestSetDeadline(t *testing.T) {
	conn := &IoConn{}
	err := conn.SetDeadline(time.Now())

	if err != nil {
		t.Error(err)
	}
}

func TestSetReadDeadline(t *testing.T) {
	conn := &IoConn{}
	err := conn.SetReadDeadline(time.Now())

	if err != nil {
		t.Error(err)
	}
}

func TestSetWriteDeadline(t *testing.T) {
	conn := &IoConn{}
	err := conn.SetWriteDeadline(time.Now())

	if err != nil {
		t.Error(err)
	}
}
