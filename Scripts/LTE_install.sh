#!/bin/bash

# Script: setup_LTE.sh
# Description: Install and run LTE Cell Scanner
# Author: Khoa Tran
# Date: 01/05/2026

set -e 

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'

log() {
	echo -e "${GREEN}[INFO] $1"
}

log_warn() {
	echo -e "${YELLO}[INFO] $2"
}

log_error() {
	echo -e "${RED}[INFO] $3"
}

is_package_installed() {
	dpkg -l "$1" 2>/dev/null | grep -q "^ii" && return 0 || return 1
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

install_packages() {
    local packages=("$@")
    local to_install=()
    
    log_info "Checking packages..."
    
    for pkg in "${packages[@]}"; do
        if is_package_installed "$pkg"; then
            log_info "✓ $pkg is already installed"
        else
            log_warn "✗ $pkg needs to be installed"
            to_install+=("$pkg")
        fi
    done
    
    if [ ${#to_install[@]} -gt 0 ]; then
        log_info "Installing ${#to_install[@]} packages..."
        sudo apt-get update
        sudo apt-get install -y "${to_install[@]}"
        log_info "Package installation completed"
    else
        log_info "All packages are already installed"
    fi
}

is_scanner_built() {
    if [ -f "./build/src/CellSearch" ] || [ -f "/usr/local/bin/CellSearch" ]; then
        return 0
    else
        return 1
    fi
}

# Function to check if source directory exists
is_source_downloaded() {
    [ -d "LTE-Cell-Scanner" ] && return 0 || return 1
}

download_source() {
    local archive="LTE-Cell-Scanner_rpi.tar.gz"
    local url="http://rfhead.net/sats/LTE-Cell-Scanner_rpi.tar.gz"
    
    if is_source_downloaded; then
        log_info "Source code already exists in LTE-Cell-Scanner/"
        return 0
    fi
    
    log_info "Downloading LTE-Cell-Scanner source..."
    
    if [ -f "$archive" ]; then
        log_info "Archive $archive already exists"
    else
        wget "$url" || {
            log_error "Failed to download $url"
            return 1
        }
    fi
    
    log_info "Extracting $archive..."
    tar -xzf "$archive" || {
        log_error "Failed to extract $archive"
        return 1
    }
   
    if is_source_downloaded; then
        log_info "Source code extracted successfully"
        return 0
    else
        log_error "Extraction failed or directory not found"
        return 1
    fi
}

build_scanner() {
    local build_dir="LTE-Cell-Scanner/build"
    
    if is_scanner_built; then
        log_info "LTE-Cell-Scanner is already built"
        return 0
    fi
    
    log_info "Building LTE-Cell-Scanner..."
    
    if [ ! -d "LTE-Cell-Scanner" ]; then
        log_error "Source directory not found"
        return 1
    fi
    
    cd "LTE-Cell-Scanner" || {
        log_error "Cannot enter LTE-Cell-Scanner directory"
        return 1
    }
    
    if [ ! -d "build" ]; then
        mkdir -p build
    fi
    
    cd build || {
        log_error "Cannot enter build directory"
        return 1
    }
    
    log_info "Running CMake..."
    cmake ../ -DINSTALL_UDEV_RULES=ON || {
        log_error "CMake configuration failed"
        return 1
    }
    
    log_info "Compiling..."
    make -j$(nproc) || {
        log_error "Compilation failed"
        return 1
    }
    
    log_info "Installing..."
    sudo make install || {
        log_error "Installation failed"
        return 1
    }
    
    cd ../..
    
    if command_exists "CellSearch"; then
        log_info "✓ LTE-Cell-Scanner successfully built and installed"
        return 0
    else
        log_warn "CellSearch command not found in PATH, but build completed"
        return 0
    fi
}

create_marker_file() {
    local marker="$HOME/.lte_scanner_installed"
    
    if [ ! -f "$marker" ]; then
        echo "LTE-Cell-Scanner installation completed on $(date)" > "$marker"
        echo "Script: $0" >> "$marker"
        log_info "Marker file created: $marker"
    fi
}

check_previous_installation() {
    local marker="$HOME/.lte_scanner_installed"
    
    if [ -f "$marker" ]; then
        log_info "Previous installation detected:"
        cat "$marker"
        echo ""
        read -p "Do you want to continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Exiting as installation was already completed."
            exit 0
        fi
    fi
}

main() {
    log_info "Starting LTE-Cell-Scanner setup script"
    log_info "======================================"
    
    check_previous_installation
    
    required_packages=(
        cmake
        libncurses5-dev
        liblapack-dev
        libblas-dev
        libboost-thread-dev
        libboost-system-dev
        libitpp-dev
        librtlsdr-dev
        libfftw3-dev
    )
    
    install_packages "${required_packages[@]}"
    
    download_source
    
    build_scanner
    
    create_marker_file
    
    log_info "======================================"
    log_info "Setup completed successfully!"
    log_info ""
    log_info "You can now run:"
    log_info "  CellSearch --help"
    log_info "or"
    log_info "  ./LTE-Cell-Scanner/build/src/CellSearch --help"
    log_info ""
    log_info "To remove the marker file and allow re-installation:"
    log_info "  rm ~/.lte_scanner_installed"
}

if main; then
    exit 0
else
    log_error "Setup failed. Please check the errors above."
    exit 1
fi
