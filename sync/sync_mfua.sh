#!/bin/bash

# ============================================
# MFUA Git Repository Sync Script (Bash)
# ============================================

# ------------------- НАСТРОЙКИ -------------------
SOURCE_REPO="/opt/mfua/development/mfua-core-v2"
TARGET_REPO="/var/mfua/production/mfua-deploy-live"
DO_PUSH="true"
CHECK_PRIVATE="true"
# ============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_path() {
    if [ ! -d "$1" ]; then
        log_error "Путь не существует: $1"
        return 1
    fi
    if [ ! -d "$1/.git" ]; then
        log_error "Не Git-репозиторий: $1"
        return 1
    fi
    log_success "Репозиторий найден: $1"
    return 0
}

check_private() {
    cd "$1" || return 1
    local url=$(git config --get remote.origin.url 2>/dev/null)
    if [[ "$url" == *"private"* ]] || [[ "$url" == *"mfua-internal"* ]]; then
        log_warning "Приватный репозиторий: $url"
        read -p "Продолжить? (y/n): " answer
        [[ "$answer" =~ ^[Yy]$ ]] || return 1
    fi
    return 0
}

git_pull_repo() {
    cd "$1" || return 1
    log_info "Выполняется git pull в $(basename "$1")..."
    git fetch origin
    local local_hash=$(git rev-parse HEAD)
    local remote_hash=$(git rev-parse origin/$(git branch --show-current) 2>/dev/null)
    if [ "$local_hash" != "$remote_hash" ]; then
        git pull && log_success "Pull выполнен" || { log_error "Ошибка pull"; return 1; }
    else
        log_info "Нет изменений"
    fi
    return 0
}

copy_content() {
    log_info "Копирование из $1 в $2 (исключая .git)..."
    find "$2" -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} + 2>/dev/null
    cp -r "$1"/* "$2"/ 2>/dev/null
    shopt -s dotglob
    for item in "$1"/.*; do
        local name=$(basename "$item")
        if [ "$name" != "." ] && [ "$name" != ".." ] && [ "$name" != ".git" ]; then
            cp -r "$item" "$2"/
        fi
    done
    shopt -u dotglob
    log_success "Копирование завершено"
}

git_push_repo() {
    cd "$1" || return 1
    log_info "Выполняется git push в $(basename "$1")..."
    local branch=$(git branch --show-current)
    git push origin "$branch" && log_success "Push выполнен" || log_error "Ошибка push"
}

main() {
    echo "========================================="
    echo "   MFUA Git Sync Script (Bash)"
    echo "========================================="
    
    command -v git >/dev/null || { log_error "Git не установлен"; exit 1; }
    
    check_path "$SOURCE_REPO" || exit 1
    check_path "$TARGET_REPO" || exit 1
    
    [ "$CHECK_PRIVATE" = "true" ] && check_private "$SOURCE_REPO" || exit 1
    
    echo ""
    git_pull_repo "$SOURCE_REPO" || exit 1
    
    echo ""
    copy_content "$SOURCE_REPO" "$TARGET_REPO"
    
    if [ "$DO_PUSH" = "true" ]; then
        echo ""
        git_push_repo "$TARGET_REPO"
    fi
    
    echo ""
    log_success "Синхронизация MFUA завершена!"
}

main