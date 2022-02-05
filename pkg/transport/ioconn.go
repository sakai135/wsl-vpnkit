package transport

import (
	"io"
	"net"
	"time"
)

type IoConn struct {
	writer io.Writer
	reader io.Reader
	local  net.Addr
	remote net.Addr
	close  func() error
}

func (c IoConn) Read(b []byte) (n int, err error) {
	return c.reader.Read(b)
}

func (c IoConn) Write(b []byte) (n int, err error) {
	return c.writer.Write(b)
}

func (c IoConn) Close() error {
	if c.close != nil {
		return c.close()
	}
	return nil
}

func (c IoConn) LocalAddr() net.Addr {
	return c.local
}

func (c IoConn) RemoteAddr() net.Addr {
	return c.remote
}

func (c IoConn) SetDeadline(t time.Time) error {
	return nil
}

func (c IoConn) SetReadDeadline(t time.Time) error {
	return nil
}

func (c IoConn) SetWriteDeadline(t time.Time) error {
	return nil
}
