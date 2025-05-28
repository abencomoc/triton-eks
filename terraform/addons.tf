module "data_addons" {
  source  = "aws-ia/eks-data-addons/aws"
  version = "1.33.0"

  oidc_provider_arn = module.eks.oidc_provider_arn

  #---------------------------------------------------------------
  # Kubecost Add-on
  #---------------------------------------------------------------
  # enable_kubecost = true
  # kubecost_helm_config = {
  #   timeout = "300"
  #   version = "2.6.0"
  #   repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  #   repository_password = data.aws_ecrpublic_authorization_token.token.password
  #   values  = [templatefile("${path.module}/helm-values/kubecost-values.yaml", {

  #     kubecostToken = "YmVuY2FzaWVAYW1hem9uLmNvbQ==xm343yadf98"
  #   })]
  # }

  # ---------------------------------------------------------------
  # JupyterHub Add-on
  # ---------------------------------------------------------------
  # enable_jupyterhub = true
  # jupyterhub_helm_config = {
  #   namespace        = kubernetes_namespace_v1.jupyterhub.id
  #   create_namespace = false
  #   version = "4.1.0" # Hub 5.2.1  https://hub.jupyter.org/helm-chart/
  #   values = [templatefile("${path.module}/helm-values/jupyterhub-values.yaml", {
  #     jupyter_single_user_sa_name = kubernetes_service_account_v1.jupyterhub_single_user_sa.metadata[0].name
  #   })]
  # }

  #---------------------------------------
  # Kuberay Operator
  #---------------------------------------
  # enable_kuberay_operator = true
  # kuberay_operator_helm_config = {
  #   version = "1.1.1"
  #   # Enabling Volcano as Batch scheduler for KubeRay Operator
  #   values = [
  #     <<-EOT
  #     batchScheduler:
  #       enabled: true
  #   EOT
  #   ]
  # }

  # enable_volcano = true

  #---------------------------------------
  # Nvidia Plugin
  #---------------------------------------
  # enable_nvidia_device_plugin = true
  # nvidia_device_plugin_helm_config = {
  #   version = "v0.17.1"
  #   name    = "nvidia-device-plugin"
  #   values = [
  #     <<-EOT
  #       mixedStrategy: "mixed"
  #       config:
  #         map:
  #           default: |-
  #             version: v1
  #             flags:
  #               migStrategy: none
  #             # sharing:
  #             #   timeSlicing:
  #             #     resources:
  #             #     - name: nvidia.com/gpu
  #             #       replicas: 4
  #           nvidia-a100g: |-
  #             version: v1
  #             flags:
  #               migStrategy: mixed
  #             sharing:
  #               timeSlicing:
  #                 resources:
  #                 - name: nvidia.com/gpu
  #                   replicas: 8
  #                 - name: nvidia.com/mig-1g.5gb
  #                   replicas: 2
  #                 - name: nvidia.com/mig-2g.10gb
  #                   replicas: 2
  #                 - name: nvidia.com/mig-3g.20gb
  #                   replicas: 3
  #                 - name: nvidia.com/mig-7g.40gb
  #                   replicas: 7
  #       gfd:
  #         enabled: true
  #       nfd:
  #         worker:
  #           tolerations:
  #             - key: nvidia.com/gpu
  #               operator: Exists
  #               effect: NoSchedule
  #             - operator: "Exists"
  #             - key: "hub.jupyter.org/dedicated"
  #               operator: "Equal"
  #               value: "user"
  #               effect: "NoSchedule"
  #       tolerations:
  #         - key: CriticalAddonsOnly
  #           operator: Exists
  #         - key: nvidia.com/gpu
  #           operator: Exists
  #           effect: NoSchedule
  #     EOT
  #   ]
  # }

  depends_on = [
    module.eks, kubectl_manifest.custom_nodepool
  ]
}

#---------------------------------------------------------------
# EKS Blueprints Addons
#---------------------------------------------------------------
module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.2"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  enable_metrics_server = false
  enable_argocd = false

  # Install KEDA Operator
  # helm_releases = {
  #   keda = {
  #     chart             = "keda"
  #     chart_version     = "2.16.1"
  #     repository        = "https://kedacore.github.io/charts"
  #     description       = "Keda helm Chart deployment"
  #     namespace         = "keda"
  #     create_namespace  = true
  #   }
  # }

  #---------------------------------------
  # Prommetheus and Grafana stack
  #---------------------------------------
  #---------------------------------------------------------------
  # Install Monitoring Stack with Prometheus and Grafana
  # 1- Grafana port-forward `kubectl port-forward svc/kube-prometheus-stack-grafana 8080:80 -n kube-prometheus-stack`
  # 2- Grafana Admin user: admin
  # 3- Get admin user password: `aws secretsmanager get-secret-value --secret-id <output.grafana_secret_name> --region $AWS_REGION --query "SecretString" --output text`
  #---------------------------------------------------------------
  enable_kube_prometheus_stack = true
  kube_prometheus_stack = {
    values = [templatefile("${path.module}/helm-values/kube-prometheus.yaml", {})
    ]
    chart_version = "69.7.3"
    set_sensitive = [
      {
        name  = "grafana.adminPassword"
        value = data.aws_secretsmanager_secret_version.admin_password_version.secret_string
      }
    ],
  }

  depends_on = [
    module.eks, kubectl_manifest.custom_nodepool
  ]

}


#---------------------------------------------------------------
# Grafana Admin credentials resources
#---------------------------------------------------------------
data "aws_secretsmanager_secret_version" "admin_password_version" {
  secret_id  = aws_secretsmanager_secret.grafana.id
  depends_on = [aws_secretsmanager_secret_version.grafana]
}

resource "random_password" "grafana" {
  length           = 16
  special          = true
  override_special = "@_"
}

resource "random_string" "grafana" {
  length  = 4
  special = false
  lower   = true
}

#tfsec:ignore:aws-ssm-secret-use-customer-key
resource "aws_secretsmanager_secret" "grafana" {
  name                    = "${local.name}-grafana-${random_string.grafana.result}"
  recovery_window_in_days = 0 # Set to zero for this example to force delete during Terraform destroy
}

resource "aws_secretsmanager_secret_version" "grafana" {
  secret_id     = aws_secretsmanager_secret.grafana.id
  secret_string = random_password.grafana.result
}