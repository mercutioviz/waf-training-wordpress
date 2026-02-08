#!/bin/bash

# Docker Cleanup and Troubleshooting Script
# Use this if you encounter layer corruption or other Docker issues

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "=========================================="
echo "Docker Cleanup & Troubleshooting"
echo "=========================================="
echo ""

# Check if running as root/sudo
if [ "$EUID" -ne 0 ]; then 
    print_error "Please run with sudo"
    exit 1
fi

# Stop any running containers for this project
print_info "Stopping WordPress WAF containers..."
docker compose down 2>/dev/null || true
print_success "Containers stopped"

# Option 1: Light cleanup (recommended first)
echo ""
print_warning "Choose cleanup level:"
echo "1) Light cleanup - Remove only stopped containers and dangling images"
echo "2) Full cleanup - Remove all unused Docker resources (WARNING: affects all projects)"
echo "3) Nuclear option - Complete Docker reset (WARNING: removes EVERYTHING)"
echo ""
read -p "Enter choice [1-3]: " choice

case $choice in
    1)
        print_info "Performing light cleanup..."
        docker container prune -f
        docker image prune -f
        print_success "Light cleanup complete"
        ;;
    2)
        print_warning "This will remove all unused containers, networks, images, and volumes"
        read -p "Are you sure? (yes/no): " confirm
        if [ "$confirm" = "yes" ]; then
            print_info "Performing full cleanup..."
            docker system prune -a --volumes -f
            print_success "Full cleanup complete"
        else
            print_info "Cancelled"
            exit 0
        fi
        ;;
    3)
        print_error "NUCLEAR OPTION: This will remove ALL Docker data"
        print_error "This includes images, containers, volumes, and networks for ALL projects"
        read -p "Type 'DELETE EVERYTHING' to confirm: " confirm
        if [ "$confirm" = "DELETE EVERYTHING" ]; then
            print_info "Stopping all Docker containers..."
            docker stop $(docker ps -aq) 2>/dev/null || true
            
            print_info "Removing all containers..."
            docker rm $(docker ps -aq) 2>/dev/null || true
            
            print_info "Removing all images..."
            docker rmi $(docker images -q) -f 2>/dev/null || true
            
            print_info "Removing all volumes..."
            docker volume rm $(docker volume ls -q) 2>/dev/null || true
            
            print_info "Removing all networks..."
            docker network rm $(docker network ls -q) 2>/dev/null || true
            
            print_info "Pruning system..."
            docker system prune -a --volumes -f
            
            print_success "Nuclear cleanup complete"
        else
            print_info "Cancelled"
            exit 0
        fi
        ;;
    *)
        print_error "Invalid choice"
        exit 1
        ;;
esac

# Check Docker daemon status
echo ""
print_info "Checking Docker daemon status..."
if systemctl is-active --quiet docker; then
    print_success "Docker daemon is running"
else
    print_warning "Docker daemon is not running, attempting to start..."
    systemctl start docker
    sleep 3
    if systemctl is-active --quiet docker; then
        print_success "Docker daemon started"
    else
        print_error "Failed to start Docker daemon"
        exit 1
    fi
fi

# Verify Docker is working
echo ""
print_info "Verifying Docker installation..."
if docker run --rm hello-world > /dev/null 2>&1; then
    print_success "Docker is working correctly"
else
    print_error "Docker verification failed"
    print_info "Try restarting Docker: sudo systemctl restart docker"
    exit 1
fi

echo ""
print_success "Cleanup complete! You can now try:"
echo "  cd $(dirname $0)"
echo "  sudo docker compose up -d"
echo ""
