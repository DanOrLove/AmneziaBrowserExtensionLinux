package main

import (
	"bytes"
	"os"
	"path/filepath"
	"strconv"
	"syscall"
)

func detachedProcessAttributes() *syscall.SysProcAttr {
	return &syscall.SysProcAttr{Setsid: true}
}

func processAlive(pid int) bool {
	if pid < 2 {
		return false
	}
	process, err := os.FindProcess(pid)
	if err != nil || process.Signal(syscall.Signal(0)) != nil {
		return false
	}

	commandLine, err := os.ReadFile(filepath.Join("/proc", strconv.Itoa(pid), "cmdline"))
	if err != nil {
		return false
	}
	arguments := bytes.Split(bytes.TrimRight(commandLine, "\x00"), []byte{0})
	if len(arguments) != 3 || !bytes.Equal(arguments[1], []byte("proxy")) {
		return false
	}
	executable, err := os.Executable()
	if err != nil {
		return false
	}
	executable, err = filepath.EvalSymlinks(executable)
	if err != nil {
		return false
	}
	processExecutable, err := filepath.EvalSymlinks(string(arguments[0]))
	if err != nil || filepath.Clean(processExecutable) != filepath.Clean(executable) {
		return false
	}
	dataDir, err := dataDirectory()
	if err != nil {
		return false
	}
	return bytes.Equal(arguments[2], []byte(filepath.Join(dataDir, "active.conf")))
}
