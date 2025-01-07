# Destroy IAM resources last
echo "Destroying IAM resources..."
terraform destroy -auto-approve

echo "Cleanup complete!"