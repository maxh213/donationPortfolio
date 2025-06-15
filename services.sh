#!/bin/bash

# Define help function
show_help() {
    echo "Usage: $0 [option]"
    echo "Options:"
    echo "  start    - Start the backend service"
    echo "  stop     - Stop the backend service"
    echo "  status   - Check the status of the service"
    echo "  restart  - Restart the backend service"
    echo "  logs     - Show the logs for the service (press Ctrl+C to exit)"
    echo "  test     - Run backend tests"
    echo "  build    - Build the backend project"
    echo "  help     - Show this help message"
}

# Create logs directory if it doesn't exist
ensure_logs_dir() {
    mkdir -p logs
}

# Start backend service
start_backend() {
    echo "Starting backend service..."
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
    cd "$SCRIPT_DIR/backend"
    
    # Build first to ensure everything is compiled
    gleam build
    if [ $? -ne 0 ]; then
        echo "⚠️ Backend build failed. Check for compilation errors."
        cd "$SCRIPT_DIR"
        return 1
    fi
    
    gleam run > "$SCRIPT_DIR/logs/backend.log" 2>&1 &
    PID=$!
    echo $PID > "$SCRIPT_DIR/logs/backend.pid"
    cd "$SCRIPT_DIR"
    
    # Give it a moment to start
    sleep 2
    
    # Check if process is still running
    if ps -p $PID > /dev/null; then
        echo "Backend service started successfully (PID: $PID)"
        echo "Backend API URL: http://localhost:8000"
        echo "Health check: http://localhost:8000/health"
    else
        echo "⚠️ Backend service failed to start. Check logs/backend.log for details."
    fi
}

# Check and kill processes using a specific port
kill_process_using_port() {
    local port=$1
    local service_name=$2
    
    # Find PID using the port
    local pid=$(lsof -t -i:$port 2>/dev/null)
    
    if [ -n "$pid" ]; then
        echo "Found process (PID: $pid) using port $port. Killing it..."
        kill -9 $pid 2>/dev/null
        echo "Process killed. Port $port is now available for $service_name."
        return 0
    fi
    return 1
}

# Stop backend service
stop_backend() {
    # Try to stop process using PID file first
    if [ -f "logs/backend.pid" ]; then
        echo "Stopping backend service..."
        kill $(cat logs/backend.pid) 2>/dev/null || true
        rm logs/backend.pid
        echo "Backend service stopped."
    else
        echo "No PID file found for backend service."
    fi
    
    # Also check and kill any process using port 8000 to ensure the port is free
    kill_process_using_port 8000 "backend" || echo "No process found using port 8000."
}

# Check service status
check_status() {
    # Check backend status
    if [ -f "logs/backend.pid" ]; then
        PID=$(cat logs/backend.pid)
        if ps -p $PID > /dev/null; then
            echo "✅ Backend service is running (PID: $PID)"
            echo "   Backend API URL: http://localhost:8000"
            echo "   Health check: http://localhost:8000/health"
            
            # Test health endpoint
            if command -v curl >/dev/null 2>&1; then
                echo ""
                echo "Testing health endpoint..."
                if curl -s http://localhost:8000/health >/dev/null; then
                    echo "✅ Health endpoint responding"
                else
                    echo "❌ Health endpoint not responding"
                fi
            fi
        else
            echo "❌ Backend service is not running (stale PID file)"
            rm logs/backend.pid
        fi
    else
        echo "❌ Backend service is not running"
    fi

    # Print log file location if service is running
    if [ -f "logs/backend.pid" ]; then
        echo ""
        echo "Log file: logs/backend.log"
        echo "To view logs in real-time: ./services.sh logs"
    fi
}

# Show logs
show_logs() {
    if [ -f "logs/backend.log" ]; then
        echo "Showing backend logs (press Ctrl+C to exit)..."
        echo ""
        tail -f logs/backend.log
    else
        echo "No log files found. Start the service first."
    fi
}

# Run tests
run_tests() {
    echo "Running backend tests..."
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
    cd "$SCRIPT_DIR/backend"
    gleam test
    cd "$SCRIPT_DIR"
}

# Build project
build_project() {
    echo "Building backend project..."
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
    cd "$SCRIPT_DIR/backend"
    gleam build
    if [ $? -eq 0 ]; then
        echo "✅ Backend build successful"
    else
        echo "❌ Backend build failed"
    fi
    cd "$SCRIPT_DIR"
}

# Main script logic
case "$1" in
    start)
        ensure_logs_dir
        stop_backend
        start_backend
        ;;
    stop)
        stop_backend
        echo "Backend service stopped."
        ;;
    status)
        check_status
        ;;
    restart)
        ensure_logs_dir
        stop_backend
        echo "Service stopped. Restarting..."
        start_backend
        ;;
    logs)
        show_logs
        ;;
    test)
        run_tests
        ;;
    build)
        build_project
        ;;
    help|*)
        show_help
        ;;
esac