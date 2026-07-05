resource "kubernetes_namespace" "argo_rollouts" {
  metadata {
    name = "argo-rollouts"
  }
}

resource "helm_release" "argo_rollouts" {
  name       = "argo-rollouts"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-rollouts"
  namespace  = kubernetes_namespace.argo_rollouts.metadata[0].name
  version    = "2.37.7"

  set {
    name  = "controller.replicas"
    value = "1"
  }

  set {
    name  = "dashboard.enabled"
    value = "true"
  }

  wait    = false
  timeout = 600

  depends_on = [kubernetes_namespace.argo_rollouts]
}
