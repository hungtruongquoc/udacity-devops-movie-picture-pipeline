Sure! Here’s your answer in Markdown format, ready to be added to your README.md file. 🚀

# 🚀 AWS EKS Access & Permissions Guide

## 🔍 Why You Don’t Have Access to EKS Resources by Default

By **default**, an **IAM user or role does NOT automatically have access to Kubernetes resources** inside an Amazon EKS cluster—even if that user has full AWS permissions!

This happens because **AWS IAM and Kubernetes RBAC (Role-Based Access Control) are separate systems**.

---

## 🔹 How AWS Handles EKS Access

### **1️⃣ AWS IAM Controls EKS Cluster API Access**
- **IAM manages who can connect to the cluster** using AWS permissions (`eks:DescribeCluster`, `eks:GetToken`, etc.).
- If your IAM user or role doesn’t have **`eks:DescribeCluster`** permission, it **cannot connect to EKS**.

✅ **Fix:** Ensure your IAM user/role has these AWS permissions:

```json
{
  "Effect": "Allow",
  "Action": [
    "eks:DescribeCluster",
    "eks:GetToken",
    "sts:GetCallerIdentity"
  ],
  "Resource": "*"
}

2️⃣ Kubernetes RBAC Controls Access to Kubernetes Resources
	•	Even if an IAM user can authenticate with aws eks update-kubeconfig, it does not have permission to access Kubernetes resources (kubectl get pods, kubectl get nodes).
	•	Kubernetes does not automatically map AWS IAM users to cluster roles.
	•	Only the IAM principal who created the EKS cluster gets full access.

✅ Fix: Add your IAM user/role to the EKS cluster via the aws-auth ConfigMap:

mapUsers: |
  - userarn: arn:aws:iam::723567309652:user/movie-pipeline-github-actions
    username: movie-pipeline-github-actions
    groups:
      - system:masters

This grants your IAM user full admin access (system:masters group).

🔹 How to Check if You Have Access

If you’re unsure whether you have access, run:

kubectl auth can-i get pods --all-namespaces

	•	✅ If you have permission, it will return:

yes


	•	❌ If you don’t have permission, it will return:

no

🚀 Summary

🔴 By default, AWS IAM does NOT give access to Kubernetes resources inside an EKS cluster.
✅ Fix: Add the IAM user/role to the aws-auth ConfigMap to grant Kubernetes RBAC permissions.
✅ Verify with kubectl auth can-i get pods --all-namespaces

Now you should have full access to your cluster! 🚀🔥

---

This will work **perfectly** in your `README.md` and provide **clear documentation** for others! 🎉  

Let me know if you need any modifications! 🚀😊