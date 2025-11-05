#!/bin/bash

#loading environment variables
if [ -f ".env" ]; then
    set -a  # Automatically export all variables
    source .env
    set +a  # Stop auto-exporting
fi


REPO_DIR="$DIR"
GIT_REPO="$REMOTE_REPO"
COMMIT_MESSAGE="Automated backup: $(date +'%Y-%m-%d %H:%M:%S')"
LOG_DIR="$LOG_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"

    echo "[$(date +'%Y-%m-%d %H:%M:%S')]$: $1" | sudo tee -a "$LOG_DIR/backup_script.log"  > /dev/null
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"

    echo "[$(date +'%Y-%m-%d %H:%M:%S')]: $1" | sudo tee -a "$LOG_DIR/backup_script.log" > /dev/null
}

notify() {
    echo "$1"
    notify-send -a"" "backup script" "$1"
}


#check if command is available
check_dependencies() {
    local deps=("git" "rsync")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            error "$dep is not installed. Please install it first"
            echo "run 'sudo apt install $dep' to install the package"
            exit 1
        fi
    done
}

#initalize repo if it doesnt exist
init_repo() {
    if [ ! -d "$REPO_DIR" ]; then

        if mkdir -p "$REPO_DIR"; then
            log "local repo created at $REPO_DIR"
            if cd "$REPO_DIR"; then
                if git clone "$GIT_REPO" .; then
                    log "remote repo cloned"
                else
                    error "could not clone into current directory. directory may not be empty"
                    notify "could not clone remote repo. failed"
                    exit 1
                fi
            else
                notify "could not access local dir. failed"
                error "could not access local dir. failed"
                exit 1
            fi
        else
            notify "could not create local dir. backup failed"
            error "could not create local repo at $REPO_DIR. failed"
            exit 1
        fi

    elif [ -d "$REPO_DIR" ] && [ ! -d "$REPO_DIR/.git" ]; then
        git config --global init.defaultBranch main
        if cd "$REPO_DIR"; then
            log "initializing git at $REPO_DIR"

            if git clone "$GIT_REPO" .; then
                log "remote repo cloned"
            else
                error "could not clone into current directory. directory may not be empty"
                notify "could not add origin. backup failed"
                exit 1
            fi
        else
            notify "could not access local dir. failed"
            error "could not access local dir. failed"
            exit 1
        fi 

    elif [ -d "$REPO_DIR" ] && [ -d "$REPO_DIR/.git" ]; then
        log "git already initialized at $REPO_DIR"
    fi
}


#create log file
create_log()  {
    if [ ! -d "$LOG_DIR" ]; then
        if sudo mkdir "$LOG_DIR"; then
            log "log folder created successfully"

            if sudo touch "$LOG_DIR/backup_script.log"; then
                log "log file created successfully"
            else
                notify "creating log file failed. please create it for logging of backup events"
                
                error "failed to create log directory and file"
            fi
        else
            notify "creating log folder failed. please create it for logging of backup events"

            error "failed to create log folder"
        fi
    elif [ -d "$LOG_DIR" ] && [ ! -f "$LOG_DIR/backup_script.log" ]; then

        if sudo touch "$LOG_DIR/backup_script.log"; then
            log "log file file created"

        else
            notify "creating log file failed. please create it for logging of backup events"

            error "failed to create log file"
        fi
    elif [ -d "$LOG_DIR" ] && [ -f "$LOG_DIR/backup_script.log" ]; then
        log "log folder and file exist"
    fi
}

#perform the backup
perform_backup() {
    log "starting backup"
    #log "local folder: $REPO_DIR"
    #log "remote repo: $GIT_REPO"

    #cd
    if cd "$REPO_DIR"; then
        log "accessed local folder at $REPO_DIR"

    else
        notify "could not access local repo. backup failed"
        error "failed to access local folder at $REPO_DIR"
        return 1
    fi

    

    #pull from remote repo

    # if git remote add origin "$GIT_REPO"; then
    #     log "remote url added"
    # else
    #     error "could not add remote repo"
    # fi
    

    if git remote set-url origin "$GIT_REPO"; then
        log "remote url set"
    else
        error "could not set remote repo"
    fi

    if git pull origin main 2> /dev/null || git pull origin master 2> /dev/null; then
        log "successfully pulled from remote repo"
        
    else
        error "could not pull from remote repo"
        notify "could not pull changes from remote repo. backup failed"
        exit 1
    fi

    #check for changes
    if git diff --quiet && git diff --staged --quiet && [ $(git rev-list --count origin/main..HEAD) -eq 0 ]; then
        log "no changes to commit or push"
        return 0
    fi

    #stage changes and commit
    if ! git diff --quiet; then
        if git add .; then
            log "changes staged"
            if git commit -m "$COMMIT_MESSAGE"; then
                log "staged changes committed successfully"
                if git push -u origin main 2> /dev/null || git origin -u origin master 2> /dev/null; then
                    log "committed changes pushed to remote repo successfully"
                    return 0
                else
                    error "failed to push changes to remote repo"
                    return 1
                fi
            else
                error "failed to commit changes"
                return 1
            fi
        else
            error "could not stage cchanges"
        fi

    elif ! git diff --staged --quiet; then
        if git commit -m "$COMMIT_MESSAGE"; then
            log "staged changes committed successfully"
            if git push -u origin main 2> /dev/null || git push -u origin master 2> /dev/null; then
                log "committed changes pushed to remote repo successfully"
                return 0
            else
                error "failed to push changes to remote repo"
                return 1
            fi
        else
            error "failed to commit changes"
            return 1
        fi

    elif ! [ $(git rev-list --count origin/main..HEAD) -eq 0 ]; then
        
        if git push -u origin main || git push -u origin master; then

                log "committed changes pushed to remote repo successfully"
                return 0
        else
            error "failed to push changes to remote repo1"
            #git remote -v
            return 1
        fi
    else
        error "failure to stage, commit and or push changes"
        
    fi
}

main() {
    log "starting automated backup..."

    check_dependencies
    init_repo
    create_log

    if perform_backup; then
        notify "backup completed successfully"
        log "backup completed successfully"
        exit 0
    else
        notify "backup failed"
        error "backup failed"
        exit 1
    fi
}

 main
