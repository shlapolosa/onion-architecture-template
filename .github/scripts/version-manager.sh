#!/bin/bash
set -e

# Semantic Versioning Manager for GitOps
# Generates semantic versions with commit SHA for container tagging

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Default values
MAJOR_VERSION=1
MINOR_VERSION=1
BASE_VERSION_FILE="$PROJECT_ROOT/.version"

# Read base version from file if it exists
if [ -f "$BASE_VERSION_FILE" ]; then
    BASE_VERSION=$(cat "$BASE_VERSION_FILE")
    MAJOR_VERSION=$(echo "$BASE_VERSION" | cut -d. -f1)
    MINOR_VERSION=$(echo "$BASE_VERSION" | cut -d. -f2)
fi

# Function to get commit count for patch version
get_patch_version() {
    git rev-list --count HEAD 2>/dev/null || echo "0"
}

# Function to get short commit SHA
get_commit_sha() {
    git rev-parse --short=7 HEAD 2>/dev/null || echo "unknown"
}

# Function to get branch name (sanitized for container tags)
get_branch_name() {
    local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    # Sanitize branch name for container registry
    echo "$branch" | sed 's/[^a-zA-Z0-9._-]/-/g' | tr '[:upper:]' '[:lower:]'
}

# Function to check if this is a release branch
is_release_branch() {
    local branch=$(get_branch_name)
    [[ "$branch" == "main" || "$branch" == "master" || "$branch" =~ ^release/.* ]]
}

# Function to check if this is a hotfix
is_hotfix() {
    local branch=$(get_branch_name)
    [[ "$branch" =~ ^hotfix/.* ]]
}

# Function to generate semantic version
generate_semantic_version() {
    local service_name="$1"
    local commit_sha=$(get_commit_sha)
    
    # Use major.minor.sha format for Docker compatibility
    local semver="$MAJOR_VERSION.$MINOR_VERSION.$commit_sha"
    
    echo "$semver"
}

# Function to generate container tags
generate_container_tags() {
    local service_name="$1"
    local registry="${2:-docker.io/socrates12345}"
    local commit_sha=$(get_commit_sha)
    local branch=$(get_branch_name)
    local semver=$(generate_semantic_version "$service_name")
    
    # Base image name
    local image_base="$registry/$service_name"
    
    # Generate multiple tags
    local tags=()
    
    # 1. Full semantic version tag
    tags+=("$image_base:$semver")
    
    # 2. Short SHA tag
    tags+=("$image_base:$commit_sha")
    
    # 3. Branch-specific tag
    tags+=("$image_base:$branch-$commit_sha")
    
    # 4. Latest tag for main/master branch
    if is_release_branch; then
        tags+=("$image_base:latest")
        tags+=("$image_base:$MAJOR_VERSION")
        tags+=("$image_base:$MAJOR_VERSION.$MINOR_VERSION")
    fi
    
    # 5. Development tag for feature branches
    if [[ "$branch" == "develop" ]]; then
        tags+=("$image_base:develop")
    fi
    
    # Return as comma-separated string
    IFS=','
    echo "${tags[*]}"
}

# Function to update version in single OAM application file
update_oam_version() {
    local service_name="$1"
    local new_image="$2"
    local commit_sha=$(get_commit_sha)
    local semver=$(generate_semantic_version "$service_name")
    
    echo "Updating OAM application for $service_name"
    echo "New image: $new_image"
    echo "Semantic version: $semver"
    
    # Single OAM application file approach
    local oam_file="$PROJECT_ROOT/oam/applications/application.yaml"
    
    if [ ! -f "$oam_file" ]; then
        echo "Error: OAM application file not found at $oam_file"
        return 1
    fi
    
    echo "Updating $oam_file"
    
    # Update image reference for the specific service
    # Match the service name in the components array and update its image
    sed -i.bak "/- name: $service_name/,/- name: /{
        s|image: [^[:space:]]*$service_name:.*|image: $new_image|g
    }" "$oam_file"
    
    # Update application-level version annotation
    if grep -q "app.version:" "$oam_file"; then
        sed -i.bak "s|app.version: .*|app.version: \"$semver\"|g" "$oam_file"
    else
        # Add version to annotations section
        sed -i.bak "/annotations:/a\\
    app.version: \"$semver\"" "$oam_file"
    fi
    
    # Update application-level commit SHA annotation
    if grep -q "app.commit-sha:" "$oam_file"; then
        sed -i.bak "s|app.commit-sha: .*|app.commit-sha: \"$commit_sha\"|g" "$oam_file"
    else
        sed -i.bak "/annotations:/a\\
    app.commit-sha: \"$commit_sha\"" "$oam_file"
    fi
    
    # Remove backup file
    rm -f "$oam_file.bak"
    
    echo "Successfully updated $service_name image in OAM application"
}

# Function to create version summary
create_version_summary() {
    local service_name="$1"
    local commit_sha=$(get_commit_sha)
    local branch=$(get_branch_name)
    local semver=$(generate_semantic_version "$service_name")
    local container_tags=$(generate_container_tags "$service_name")
    
    cat << EOF
## 🏷️ Version Information for $service_name

**Semantic Version:** \`$semver\`
**Commit SHA:** \`$commit_sha\`
**Branch:** \`$branch\`

### 📦 Container Tags
$(echo "$container_tags" | tr ',' '\n' | sed 's/^/- `/' | sed 's/$/`/')

### 📅 Build Information
- **Timestamp:** $(date -u +"%Y-%m-%dT%H:%M:%SZ")
- **Build Number:** $(get_patch_version)
- **Is Release:** $(is_release_branch && echo "Yes" || echo "No")
EOF
}

# Main function
main() {
    local command="$1"
    local service_name="$2"
    local registry="${3:-docker.io/socrates12345}"
    
    case "$command" in
        "version")
            generate_semantic_version "$service_name"
            ;;
        "tags")
            generate_container_tags "$service_name" "$registry"
            ;;
        "update-oam")
            local new_image="$registry/$service_name:$(get_commit_sha)"
            update_oam_version "$service_name" "$new_image"
            ;;
        "summary")
            create_version_summary "$service_name"
            ;;
        "increment-major")
            echo "$((MAJOR_VERSION + 1)).0" > "$BASE_VERSION_FILE"
            echo "Incremented major version to $((MAJOR_VERSION + 1)).0.0"
            ;;
        "increment-minor")
            echo "$MAJOR_VERSION.$((MINOR_VERSION + 1))" > "$BASE_VERSION_FILE"
            echo "Incremented minor version to $MAJOR_VERSION.$((MINOR_VERSION + 1)).0"
            ;;
        "help"|*)
            cat << EOF
Usage: $0 <command> [service_name] [registry]

Commands:
  version <service>           Generate semantic version
  tags <service> [registry]   Generate container tags
  update-oam <service>        Update OAM applications with new version
  summary <service>           Create version summary
  increment-major             Increment major version
  increment-minor             Increment minor version
  help                        Show this help

Examples:
  $0 version streamlit-frontend
  $0 tags orchestration-service
  $0 update-oam streamlit-frontend
  $0 summary streamlit-frontend
EOF
            ;;
    esac
}

# Run main function with all arguments
main "$@"