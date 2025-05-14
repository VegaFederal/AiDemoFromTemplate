#!/bin/bash

# Text colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Prevent AWS CLI from opening editors
export EDITOR=:
export AWS_PAGER=""

echo -e "${YELLOW}Starting S3 bucket cleanup...${NC}"

# Ask for bucket filter pattern
read -p "Enter bucket filter pattern (e.g. '*' for all, 'website*' for buckets starting with 'website'): " filter_pattern
# Default to all buckets if no pattern provided
filter_pattern=${filter_pattern:-"*"}

# Convert wildcard pattern to regex
regex_pattern=$(echo "$filter_pattern" | sed 's/\*/.*/g')
echo -e "${YELLOW}Using filter pattern: ${filter_pattern}${NC}"

# Get list of all buckets
all_buckets=$(aws s3api list-buckets --query 'Buckets[].Name' --output text)

if [ -z "$all_buckets" ]; then
    echo -e "${GREEN}No buckets found. Nothing to delete.${NC}"
    exit 0
fi

# Filter buckets based on pattern
buckets=""
for bucket in $all_buckets; do
    if [[ $bucket =~ $regex_pattern ]]; then
        buckets="$buckets $bucket"
    fi
done

# Trim leading space
buckets=$(echo "$buckets" | sed 's/^ *//')

if [ -z "$buckets" ]; then
    echo -e "${GREEN}No buckets match the filter pattern. Nothing to delete.${NC}"
    exit 0
fi

# Show buckets that will be deleted and ask for confirmation
echo -e "${YELLOW}The following buckets will be deleted:${NC}"
for bucket in $buckets; do
    echo "- $bucket"
done

read -p "Are you sure you want to delete these buckets? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}Operation cancelled.${NC}"
    exit 0
fi

# Counter for progress
total_buckets=$(echo "$buckets" | wc -w)
current=0

for bucket in $buckets; do
    ((current++))
    echo -e "\n${YELLOW}Processing bucket ${current}/${total_buckets}: ${bucket}${NC}"
    
    # First, remove bucket versioning to handle versioned objects
    echo "Suspending versioning..."
    aws s3api put-bucket-versioning \
        --bucket "$bucket" \
        --versioning-configuration Status=Suspended >/dev/null 2>&1

    # Delete all versions and delete markers
    echo "Removing all object versions..."
    
    # Get versions with pagination to avoid large responses
    next_token=""
    while true; do
        if [ -z "$next_token" ]; then
            version_output=$(aws s3api list-object-versions \
                --bucket "$bucket" \
                --max-items 1000 \
                --output json 2>/dev/null)
        else
            version_output=$(aws s3api list-object-versions \
                --bucket "$bucket" \
                --max-items 1000 \
                --starting-token "$next_token" \
                --output json 2>/dev/null)
        fi
        
        # Process versions if any
        if echo "$version_output" | jq -e '.Versions' >/dev/null 2>&1; then
            echo "$version_output" | jq -r '.Versions[]? | "\(.Key) \(.VersionId)"' 2>/dev/null | \
            while IFS=' ' read -r key version_id; do
                [ -n "$key" ] && [ -n "$version_id" ] && \
                aws s3api delete-object \
                    --bucket "$bucket" \
                    --key "$key" \
                    --version-id "$version_id" >/dev/null 2>&1
            done
        fi
        
        # Process delete markers if any
        if echo "$version_output" | jq -e '.DeleteMarkers' >/dev/null 2>&1; then
            echo "$version_output" | jq -r '.DeleteMarkers[]? | "\(.Key) \(.VersionId)"' 2>/dev/null | \
            while IFS=' ' read -r key version_id; do
                [ -n "$key" ] && [ -n "$version_id" ] && \
                aws s3api delete-object \
                    --bucket "$bucket" \
                    --key "$key" \
                    --version-id "$version_id" >/dev/null 2>&1
            done
        fi
        
        # Check if there are more items
        next_token=$(echo "$version_output" | jq -r '.NextToken // empty')
        [ -z "$next_token" ] && break
    done

    # Delete remaining objects
    echo "Removing remaining objects..."
    aws s3 rm "s3://${bucket}" --recursive >/dev/null 2>&1

    # Finally delete the bucket
    echo "Deleting bucket..."
    if aws s3api delete-bucket --bucket "$bucket" >/dev/null 2>&1; then
        echo -e "${GREEN}Successfully deleted bucket: ${bucket}${NC}"
    else
        echo -e "${RED}Failed to delete bucket: ${bucket}${NC}"
    fi
done

echo -e "\n${GREEN}Bucket cleanup completed!${NC}"