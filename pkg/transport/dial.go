package transport

import (
	"fmt"
	"net"
	"os"
	"os/exec"
)

func Dial(endpoint string, args ...string) (net.Conn, error) {
	cmd := exec.Command(endpoint, args[:]...)
	cmd.Stderr = os.Stderr

	stdin, err := cmd.StdinPipe()
	if err != nil {
		return nil, err
	}

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return nil, err
	}

	err = cmd.Start()
	if err != nil {
		return nil, err
	}

	local := IoAddr{path: fmt.Sprint(os.Getpid())}
	remote := IoAddr{path: fmt.Sprint(cmd.Process.Pid)}
	conn := IoConn{
		reader: stdout,
		writer: stdin,
		local:  local,
		remote: remote,
		close:  cmd.Process.Kill,
	}
	return conn, nil
}

func GetStdioConn() net.Conn {
	local := IoAddr{path: fmt.Sprint(os.Getpid())}
	remote := IoAddr{path: "remote"}
	conn := IoConn{
		writer: os.Stdout,
		reader: os.Stdin,
		local:  local,
		remote: remote,
	}
	return conn
}
