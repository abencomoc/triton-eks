# resource "kubernetes_namespace_v1" "jupyterhub" {
#   metadata {
#     name = "jupyterhub"
#   }
# }

# module "jupyterhub_pod_identity" {
#   source = "terraform-aws-modules/eks-pod-identity/aws"

#   name = "jupyterhub-single-user-identity"

#   additional_policy_arns = {
#     AmazonS3FullAccess = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
#   }

#   associations = {
#     jupyterhub-single-user = {
#       cluster_name    = module.eks.cluster_name
#       namespace       = kubernetes_namespace_v1.jupyterhub.id
#       service_account = kubernetes_service_account_v1.jupyterhub_single_user_sa.metadata[0].name
#     }
#   }

#   tags = local.tags
# }

# resource "kubernetes_service_account_v1" "jupyterhub_single_user_sa" {
#   metadata {
#     name        = "jupyterhub-sa"
#     namespace   = kubernetes_namespace_v1.jupyterhub.metadata[0].name
#   }

#   automount_service_account_token = true
# }
