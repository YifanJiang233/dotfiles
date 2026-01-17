#!/bin/bash

# --- Function to handle clean exit on Ctrl+C (SIGINT) ---
trap 'echo "Script interrupted by user. Exiting..."; exit 1' INT

# --- Input Validation and Simplification ---
if [[ -z "$1" ]]; then
    echo "Error: You must provide a package name."
    echo "Usage: $0 <package_name>"
    echo "Example: $0 times"
    exit 1
fi

# Automatically append '.sty' to the input for the search
STY_FILE="$1.sty"
PACKAGE_NAME_INPUT="$1"

# --- Main Script Loop with Retry Logic ---
RETRY_DELAY=45
MAX_RETRIES=3
retries=0

while [[ $retries -le $MAX_RETRIES ]]; do
    echo "Searching for the TeX Live package containing '$STY_FILE'..."
    # The --color=never is crucial for parsing
    PACKAGE_INFO=$(tlmgr search --global --file "/$STY_FILE" | grep -E "texmf-dist/tex/latex/[^/]+/$STY_FILE")
    SEARCH_SUCCESS=$?

    if [[ $SEARCH_SUCCESS -eq 0 && -n "$PACKAGE_INFO" ]]; then
        # Successfully found package, now extract name
        PACKAGE_NAME=$(echo "$PACKAGE_INFO" | grep -oP 'texmf-dist/tex/latex/\K[^/]+')

        if [[ -n "$PACKAGE_NAME" ]]; then
            echo "Found package: '$PACKAGE_NAME' for '$PACKAGE_NAME_INPUT'."
            break # Exit the loop, package name found.
        else
            echo "Error: Could not extract package name from search results."
            echo "Please inspect the output of 'tlmgr search --global --file \"/$STY_FILE\"'."
            tlmgr search --global --file "/$STY_FILE"
            exit 1 # Extraction failed, this is likely not a temporary issue.
        fi
    else
        echo "Error: No TeX Live package found containing '$STY_FILE'."
        if [[ $retries -lt $MAX_RETRIES ]]; then
            echo "Retrying in $RETRY_DELAY seconds... (Retry $((retries + 1)) of $MAX_RETRIES)"
            sleep "$RETRY_DELAY"
            retries=$((retries + 1))
        else
            echo "Max retries reached. Exiting."
            exit 1
        fi
    fi
done

# --- User Confirmation ---
read -p "Do you want to install '$PACKAGE_NAME'? (Y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "Installation aborted by user."
    exit 0
fi

# --- Installation Loop with Retry Logic ---
retries=0 # Reset retry counter for installation
while [[ $retries -le $MAX_RETRIES ]]; do
    echo "Attempting to install package '$PACKAGE_NAME'..."
    if sudo env PATH="$PATH" tlmgr install "$PACKAGE_NAME"; then
        echo "Package '$PACKAGE_NAME' installed successfully."

        echo "Running 'tlmgr path add' to update executables path (if any)..."
        if sudo env PATH="$PATH" tlmgr path add; then
            echo "tlmgr path add completed."
        else
            echo "Warning: 'tlmgr path add' failed. You might need to run it manually."
        fi

        echo "Installation process complete for '$PACKAGE_NAME_INPUT'."
        exit 0 # Success
    else
        echo "Error: Failed to install package '$PACKAGE_NAME'."
        if [[ $retries -lt $MAX_RETRIES ]]; then
            echo "Retrying in $RETRY_DELAY seconds... (Retry $((retries + 1)) of $MAX_RETRIES)"
            sleep "$RETRY_DELAY"
            retries=$((retries + 1))
        else
            echo "Max retries reached. Exiting."
            exit 1
        fi
    fi
done
