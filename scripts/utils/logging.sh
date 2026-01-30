#!/bin/bash
# Logging utilities for setup scripts

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Log levels
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3

# Current log level (set by VERBOSE_SETUP env var)
CURRENT_LOG_LEVEL=${LOG_LEVEL_INFO}
if [ "${VERBOSE_SETUP}" = "true" ]; then
    CURRENT_LOG_LEVEL=${LOG_LEVEL_DEBUG}
fi

# Get timestamp
timestamp() {
    date +"%Y-%m-%d %H:%M:%S"
}

# Log functions
log_debug() {
    if [ ${CURRENT_LOG_LEVEL} -le ${LOG_LEVEL_DEBUG} ]; then
        echo -e "${CYAN}[$(timestamp)] [DEBUG]${NC} $*" >&2
    fi
}

log_info() {
    if [ ${CURRENT_LOG_LEVEL} -le ${LOG_LEVEL_INFO} ]; then
        echo -e "${GREEN}[$(timestamp)] [INFO]${NC} $*" >&2
    fi
}

log_warn() {
    if [ ${CURRENT_LOG_LEVEL} -le ${LOG_LEVEL_WARN} ]; then
        echo -e "${YELLOW}[$(timestamp)] [WARN]${NC} $*" >&2
    fi
}

log_error() {
    if [ ${CURRENT_LOG_LEVEL} -le ${LOG_LEVEL_ERROR} ]; then
        echo -e "${RED}[$(timestamp)] [ERROR]${NC} $*" >&2
    fi
}

log_success() {
    echo -e "${GREEN}[$(timestamp)] [SUCCESS]${NC} $*" >&2
}

log_step() {
    echo -e "${MAGENTA}[$(timestamp)] [STEP]${NC} $*" >&2
}

log_section() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $*${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Progress indicator
show_progress() {
    local current=$1
    local total=$2
    local message=$3
    local percent=$((current * 100 / total))
    echo -ne "${CYAN}[$(timestamp)] [PROGRESS]${NC} ${message} [${current}/${total}] ${percent}%\r" >&2
    if [ ${current} -eq ${total} ]; then
        echo "" >&2
    fi
}

# Spinner for long-running tasks
spinner() {
    local pid=$1
    local message=$2
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) %10 ))
        printf "\r${CYAN}[$(timestamp)]${NC} ${message} ${spin:$i:1}" >&2
        sleep .1
    done
    printf "\r${GREEN}[$(timestamp)]${NC} ${message} ✓\n" >&2
}

# Error handler
handle_error() {
    local line_number=$1
    local error_code=$2
    log_error "Error on line ${line_number}: Exit code ${error_code}"
    exit ${error_code}
}

# Trap errors
trap 'handle_error ${LINENO} $?' ERR
