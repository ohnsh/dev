```bash
cleanup() {
    rm -rf "$MY_TMP_DIR"
    trap - SIGINT  # Clears the trap to avoid infinite loops
    kill -INT "$$" # Sends SIGINT to itself so the parent shell knows it was interrupted
}
trap cleanup SIGINT
```

- `trap cleanup EXIT` triggers when script terminates for any reason
- `trap cleanup SIGINT SIGTERM` can trap multiple signals

Within trap, exit status is set to 128 + signal (shell convention)

- 130 → 130 - 128 = 2 → SIGINT (Ctrl+C)
- 143 → 143 - 128 = 15 → SIGTERM (Default kill command)
- 129 → 129 - 128 = 1 → SIGHUP (Terminal closed)

```bash
cleanup() {
    # 1. Capture the exit code immediately
    local exit_code=$?
    
    # 2. Perform your cleanup tasks
    echo "Cleaning up temporary files..."
    rm -rf "$MY_TMP_DIR"

    # 3. Check if the script exited due to a signal (exit code > 128)
    if [ "$exit_code" -gt 128 ]; then
        local sig=$(( exit_code - 128 ))
        echo "Script interrupted by signal $sig. Re-sending..."
        
        # 4. Clear the trap and kill the process with its original signal
        trap - EXIT # CRITICAL to avoid infinite loop
        kill -$sig $$
    else
        # Normal exit or controlled error exit
        exit "$exit_code"
    fi
}

# Register the EXIT trap
trap cleanup EXIT

MY_TMP_DIR=$(mktemp -d)
echo "Working... Press Ctrl+C to test."
sleep 10
```
