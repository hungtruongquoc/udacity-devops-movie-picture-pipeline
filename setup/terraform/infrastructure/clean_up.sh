#!/bin/bash

ENVIRONMENT_NAME="movie-pipeline"
REGION="us-east-1"

# Destroy infrastructure first
echo "Destroying infrastructure..."
terraform destroy -auto-approve

echo "Cleanup complete!"