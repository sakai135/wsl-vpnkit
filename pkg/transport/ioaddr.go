package transport

type IoAddr struct {
	path string
}

func (a IoAddr) Network() string {
	return "stdio"
}
func (a IoAddr) String() string {
	return a.path
}
