//go:build old

package main

import (
	"bufio"
	"fmt"
	"log"
	"net"
	"os"
	"os/signal"
	"syscall"
)

const socketPath = "./monitor.sock"

func main() {
	// 1. Clean up stale socket file if it exists from a previous run
	if err := os.RemoveAll(socketPath); err != nil {
		log.Fatalf("Failed to remove existing socket: %v", err)
	}

	// 2. Listen on the Unix domain stream socket
	listener, err := net.Listen("unix", socketPath)
	if err != nil {
		log.Fatalf("Failed to listen on Unix socket: %v", err)
	}
	defer listener.Close()

	// 3. Set file permissions so Docker containers can write to it
	if err := os.Chmod(socketPath, 0777); err != nil {
		log.Fatalf("Failed to set socket permissions: %v", err)
	}

	log.Printf("Listening on Unix socket: %s", socketPath)

	// 4. Handle OS signals (Ctrl+C / SIGTERM) for clean shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
	go func() {
		<-sigChan
		close(sigChan)
		log.Println("\nShutting down server...")
		listener.Close()
		os.Remove(socketPath)
		os.Exit(0)
	}()

	// 5. Accept connections continuously
	for {
		conn, err := listener.Accept()
		if err != nil {
			// If listener was closed during shutdown, exit loop
			select {
			case <-sigChan:
				return
			default:
				log.Printf("Accept error: %v", err)
				continue
			}
		}

		// Spawn a goroutine to handle each container connection in parallel
		go handleConnection(conn)
	}
}

func handleConnection(conn net.Conn) {
	defer conn.Close()

	clientAddr := conn.RemoteAddr().String()
	log.Printf("[+] Connected: %s", clientAddr)

	// bufio.Scanner handles line-buffering and framing automatically!
	scanner := bufio.NewScanner(conn)

	for scanner.Scan() {
		message := scanner.Text()
		fmt.Printf("[%s] %s\n", clientAddr, message)
	}

	if err := scanner.Err(); err != nil {
		log.Printf("[!] Error reading from %s: %v", clientAddr, err)
	}

	log.Printf("[-] Disconnected: %s", clientAddr)
}
