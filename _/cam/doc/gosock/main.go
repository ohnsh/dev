package main

import (
	"bufio"
	"context"
	"fmt"
	"log"
	"net"
	"os"
	"os/signal"
	"syscall"
)

const socketPath = "./monitor.sock"

func main() {
	// 1. Create a context that automatically cancels when SIGINT or SIGTERM is received
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	// 2. Clean up stale socket file if left over from a previous crash
	_ = os.Remove(socketPath)

	// 3. Listen on the Unix domain stream socket
	var lc net.ListenConfig
	listener, err := lc.Listen(ctx, "unix", socketPath)
	if err != nil {
		log.Fatalf("Failed to listen on Unix socket: %v", err)
	}
	// Defer cleanup: guaranteed to run when main() returns cleanly!
	defer func() {
		listener.Close()
		os.Remove(socketPath)
		log.Println("Cleanup complete. Exiting.")
	}()

	if err := os.Chmod(socketPath, 0777); err != nil {
		log.Fatalf("Failed to set socket permissions: %v", err)
	}

	log.Printf("Listening on Unix socket: %s", socketPath)

	// 4. Goroutine dedicated solely to closing the listener when Context cancels
	go func() {
		<-ctx.Done() // Blocks until Ctrl+C / SIGTERM arrives
		log.Println("\nShutdown signal received, closing listener...")
		listener.Close() // This unblocks listener.Accept() in main()
	}()

	// 5. Main Accept Loop
	for {
		conn, err := listener.Accept()
		if err != nil {
			// Check if the error happened BECAUSE we received a shutdown signal
			if ctx.Err() != nil {
				log.Println("Accept loop stopped cleanly for shutdown.")
				return // Gracefully return from main()! Triggering defers!
			}

			// Otherwise, it was a real unexpected network error
			log.Printf("Unexpected accept error: %v", err)
			continue
		}

		go handleConnection(conn)
	}
}

func handleConnection(conn net.Conn) {
	defer conn.Close()

	clientAddr := conn.RemoteAddr().String()
	log.Printf("[+] Connected: %s", clientAddr)

	scanner := bufio.NewScanner(conn)
	for scanner.Scan() {
		fmt.Printf("[%s] %s\n", clientAddr, scanner.Text())
	}

	log.Printf("[-] Disconnected: %s", clientAddr)
}
