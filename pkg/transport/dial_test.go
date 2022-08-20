package transport

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"os/exec"
	"testing"
)

func helperCommand(name string, arg ...string) (cmd *exec.Cmd) {
	cs := []string{"-test.run=TestHelperProcess", "--"}
	cs = append(cs, name)
	cs = append(cs, arg...)
	cmd = exec.Command(os.Args[0], cs...)
	cmd.Env = append(os.Environ(), "GO_WANT_HELPER_PROCESS=1")
	return cmd
}

func TestHelperProcess(*testing.T) {
	if os.Getenv("GO_WANT_HELPER_PROCESS") != "1" {
		return
	}
	defer os.Exit(0)

	args := os.Args
	for len(args) > 0 {
		if args[0] == "--" {
			args = args[1:]
			break
		}
		args = args[1:]
	}

	iargs := []any{}
	for _, s := range args {
		iargs = append(iargs, s)
	}
	fmt.Println(iargs...)

	conn := GetStdioConn()
	buf := make([]byte, 512)
	for {
		i, err := conn.Read(buf)
		if err != nil {
			break
		}
		read := buf[:i]
		if string(read) == "error" {
			os.Exit(1)
		}
		_, _ = conn.Write(read)
	}
}

func TestDial(t *testing.T) {
	execCommand = helperCommand
	defer func() { execCommand = exec.Command }()

	conn, err := Dial("executable", "arg1", "arg2")
	if err != nil {
		t.Error(err)
	}

	reader := bufio.NewReader(conn)
	line, _, err := reader.ReadLine()
	if err != nil {
		t.Error(err)
	}
	str := string(line)
	if str != "executable arg1 arg2" {
		t.Errorf("unexpected string %s", str)
	}

	_, _ = conn.Write([]byte("hi there\n"))
	line, _, err = reader.ReadLine()
	if err != nil {
		t.Error(err)
	}
	str = string(line)
	if str != "hi there" {
		t.Errorf("unexpected string %s", str)
	}

	err = conn.Close()
	if err != nil {
		t.Error(err)
	}
}

func TestDial_Error(t *testing.T) {
	execCommand = helperCommand
	defer func() { execCommand = exec.Command }()

	conn, err := Dial("executable", "arg1", "arg2")
	if err != nil {
		t.Error(err)
	}

	reader := bufio.NewReader(conn)
	_, _, err = reader.ReadLine()
	if err != nil {
		t.Error(err)
	}

	_, _ = conn.Write([]byte("error"))
	_, _, err = reader.ReadLine()
	if err == nil {
		t.Error("expected error")
	}
	if err != io.EOF {
		t.Errorf("unexpected error %s", err)
	}
}

func TestGetStdioConn(t *testing.T) {
	conn := GetStdioConn()
	if conn.RemoteAddr().String() != "remote" {
		t.Errorf("unexpected remote address %s", conn.RemoteAddr().String())
	}
	err := conn.Close()
	if err != nil {
		t.Error(err)
	}
}
