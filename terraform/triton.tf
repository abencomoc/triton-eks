# Define the namespace and service account name for your Triton pods
locals {
  namespace            = "triton-ns"
  service_account_name = "triton-sa"
}

resource "kubernetes_namespace_v1" "triton" {
  metadata {
    name = local.namespace
  }
  depends_on = [
    module.eks, kubectl_manifest.custom_nodepool
  ]
}

resource "kubernetes_service_account" "triton" {
  metadata {
    name      = local.service_account_name
    namespace = kubernetes_namespace_v1.triton.id
    annotations = {
      "eks.amazonaws.com/role-arn" = module.triton_irsa_role.iam_role_arn
    }
  }
  automount_service_account_token = true
}

# Create a custom IAM policy for S3 access (adjust as needed)
resource "aws_iam_policy" "triton_s3_access" {
  name        = "${local.name}-triton-s3-access"
  description = "Allow Triton to access S3 bucket"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::model-repository-123",
          "arn:aws:s3:::model-repository-123/*"
        ]
      }
    ]
  })
}

# Create the IAM role for the service account using the module
module "triton_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39.0"

  role_name = "${local.name}-triton-irsa-role"

  role_policy_arns = {
    s3 = aws_iam_policy.triton_s3_access.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${local.namespace}:${local.service_account_name}"]
    }
  }
}



### NOTE: Triton container image 25.03 doesn't support EKS pod identities.
# module "triton_pod_identity" {
#   source = "terraform-aws-modules/eks-pod-identity/aws"

#   name = "triton-identity"

#   additional_policy_arns = {
#     AmazonS3ReadOnlyAccess = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
#   }

#   associations = {
#     triton = {
#       cluster_name    = module.eks.cluster_name
#       namespace       = kubernetes_namespace_v1.triton.id
#       service_account = kubernetes_service_account_v1.triton.metadata[0].name
#     }
#   }

#   tags = local.tags
# }