package transport

import (
	"net"
	"os"
	"os/exec"
	"strconv"
)

var execCommand = exec.Command

func Dial(endpoint string, arg ...string) (net.Conn, error) {
	cmd := execCommand(endpoint, arg[:]...)
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

	local := IoAddr{path: strconv.Itoa(os.Getpid())}
	remote := IoAddr{path: strconv.Itoa(cmd.Process.Pid)}
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
	local := IoAddr{path: strconv.Itoa(os.Getpid())}
	remote := IoAddr{path: "remote"}
	conn := IoConn{
		writer: os.Stdout,
		reader: os.Stdin,
		local:  local,
		remote: remote,
	}
	return conn
}
