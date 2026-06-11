# Namespaces
resource "kubernetes_namespace" "ingress_nginx" {
  metadata {
    name = "ingress-nginx"
  }
}

resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "cert-manager"
  }
}

resource "kubernetes_namespace" "sealed_secrets" {
  metadata {
    name = "sealed-secrets"
  }
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "kubernetes_namespace" "fintrack" {
  metadata {
    name = "fintrack"
    labels = {
      # tells cert-manager it can issue certificates
      # for services in this namespace
      "cert-manager.io/disable-validation" = "false"
    }
  }
}

# nginx-ingress
resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = kubernetes_namespace.ingress_nginx.metadata[0].name
  version    = "4.10.1"

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  # Don't wait for rollout
  wait    = false
  timeout = 600

  depends_on = [kubernetes_namespace.ingress_nginx]
}

# cert-manager
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = kubernetes_namespace.cert_manager.metadata[0].name
  version    = "v1.14.5"

  set {
    name  = "installCRDs"
    value = "true"
  }

  wait    = false
  timeout = 600

  depends_on = [kubernetes_namespace.cert_manager]
}

# Sealed Secrets
resource "helm_release" "sealed_secrets" {
  name       = "sealed-secrets"
  repository = "https://bitnami-labs.github.io/sealed-secrets"
  chart      = "sealed-secrets"
  namespace  = kubernetes_namespace.sealed_secrets.metadata[0].name
  version    = "2.15.3"

  wait    = false
  timeout = 300

  depends_on = [kubernetes_namespace.sealed_secrets]
}

# ArgoCD
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = "6.7.18"

  set {
    name  = "dex.enabled"
    value = "false"
  }

  set {
    name  = "notifications.enabled"
    value = "false"
  }

  wait    = false
  timeout = 600

  depends_on = [
    kubernetes_namespace.argocd,
    helm_release.ingress_nginx,
    helm_release.cert_manager
  ]
}

# Monitoring
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "58.2.2"

  set {
    name  = "prometheus.prometheusSpec.resources.requests.memory"
    value = "256Mi"
  }

  set {
    name  = "prometheus.prometheusSpec.resources.limits.memory"
    value = "512Mi"
  }

  set {
    name  = "alertmanager.enabled"
    value = "false"
  }

  set {
    name  = "grafana.adminPassword"
    value = "fintrack-grafana-2026"
  }

  set {
    name  = "grafana.ingress.enabled"
    value = false
  }

  # Enable ArgoCD metrics scraping
  set {
    name  = "prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues"
    value = "false"
  }

  set {
    name  = "prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues"
    value = "false"
  }
  wait    = false
  timeout = 600

  depends_on = [
    kubernetes_namespace.monitoring,
    helm_release.ingress_nginx
  ]
}
