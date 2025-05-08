#!/bin/bash

# Load configuration
CONFIG_FILE="config/project-config.json"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: Config file not found at $CONFIG_FILE"
  exit 1
fi

PROJECT_NAME=$(jq -r '.projectName' $CONFIG_FILE)
AWS_REGION=$(jq -r '.awsRegion' $CONFIG_FILE || echo "us-east-1")

echo "Starting cleanup for project: $PROJECT_NAME in region: $AWS_REGION"

# Function to wait for stack deletion
wait_for_stack_deletion() {
  local stack_name=$1
  echo "Waiting for stack $stack_name to be deleted..."
  
  while true; do
    stack_status=$(aws cloudformation describe-stacks --stack-name $stack_name --query "Stacks[0].StackStatus" --output text --region $AWS_REGION 2>/dev/null || echo "DELETE_COMPLETE")
    
    if [ "$stack_status" == "DELETE_COMPLETE" ]; then
      echo "Stack $stack_name has been deleted."
      break
    elif [[ "$stack_status" == *"FAILED"* ]]; then
      echo "Stack deletion failed with status: $stack_status"
      break
    else
      echo "Current status: $stack_status. Waiting..."
      sleep 10
    fi
  done
}

# Function to empty an S3 bucket
empty_s3_bucket() {
  local bucket_name=$1
  echo "Emptying S3 bucket: $bucket_name"
  
  # Check if bucket exists
  if aws s3api head-bucket --bucket $bucket_name --region $AWS_REGION 2>/dev/null; then
    # Empty the bucket
    aws s3 rm s3://$bucket_name --recursive --region $AWS_REGION
    echo "Bucket emptied: $bucket_name"
  else
    echo "Bucket does not exist: $bucket_name"
  fi
}

# Get the template bucket name from the main stack outputs
TEMPLATE_BUCKET=$(aws cloudformation describe-stacks --stack-name $PROJECT_NAME --query "Stacks[0].Parameters[?ParameterKey=='TemplateBucket'].ParameterValue" --output text --region $AWS_REGION 2>/dev/null || echo "")

# Get the website bucket name from the storage stack outputs
WEBSITE_BUCKET=$(aws cloudformation describe-stacks --stack-name $PROJECT_NAME --query "Stacks[0].Outputs[?OutputKey=='WebsiteBucketName'].OutputValue" --output text --region $AWS_REGION 2>/dev/null || echo "")

if [ -z "$WEBSITE_BUCKET" ]; then
  # Try to get it from the storage stack directly
  WEBSITE_BUCKET=$(aws cloudformation describe-stacks --stack-name $PROJECT_NAME-storage --query "Stacks[0].Outputs[?OutputKey=='WebsiteBucketName'].OutputValue" --output text --region $AWS_REGION 2>/dev/null || echo "")
fi

# Empty the S3 buckets before deleting the stacks
if [ ! -z "$WEBSITE_BUCKET" ]; then
  empty_s3_bucket $WEBSITE_BUCKET
fi

if [ ! -z "$TEMPLATE_BUCKET" ]; then
  empty_s3_bucket $TEMPLATE_BUCKET
fi

# Delete the main stack (this will trigger deletion of all nested stacks)
echo "Deleting main stack: $PROJECT_NAME"
aws cloudformation delete-stack --stack-name $PROJECT_NAME --region $AWS_REGION

# Wait for the main stack to be deleted
wait_for_stack_deletion $PROJECT_NAME

# Check if any nested stacks are still around (they should be deleted automatically)
NESTED_STACKS=(
  "$PROJECT_NAME-cdn"
  "$PROJECT_NAME-api"
  "$PROJECT_NAME-compute"
  "$PROJECT_NAME-storage"
)

for stack in "${NESTED_STACKS[@]}"; do
  # Check if stack exists
  if aws cloudformation describe-stacks --stack-name $stack --region $AWS_REGION 2>/dev/null; then
    echo "Nested stack $stack still exists. Attempting to delete..."
    aws cloudformation delete-stack --stack-name $stack --region $AWS_REGION
    wait_for_stack_deletion $stack
  fi
done

# Delete the template bucket if it still exists
if [ ! -z "$TEMPLATE_BUCKET" ]; then
  echo "Deleting template bucket: $TEMPLATE_BUCKET"
  aws s3 rb s3://$TEMPLATE_BUCKET --force --region $AWS_REGION
fi

echo "Cleanup completed for project: $PROJECT_NAME"
