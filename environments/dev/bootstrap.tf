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

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-ssl-cert"
    value = var.certificate_arn
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-backend-protocol"
    value = "http"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-ssl-ports"
    value = "https"
  }

  set {
    name  = "controller.service.targetPorts.https"
    value = "http"
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
  repository = "https://bitnami.github.io/sealed-secrets"
  chart      = "sealed-secrets"
  namespace  = kubernetes_namespace.sealed_secrets.metadata[0].name
  version    = "2.15.3"

  wait    = false
  timeout = 600

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

  values = [<<-YAML
    alertmanager:
      enabled: true
      config:
        global:
          smtp_smarthost: "smtp.gmail.com:587"
          smtp_from: "holaryinka5050@gmail.com"
          smtp_auth_username: "holaryinka5050@gmail.com"
          smtp_auth_password: "${var.gmail_app_password}"
          smtp_require_tls: true
        route:
          group_by: ["alertname", "namespace"]
          group_wait: 30s
          group_interval: 5m
          repeat_interval: 12h
          receiver: email
          routes:
            - matchers:
                - alertname = "Watchdog"
              receiver: "null"
            - matchers:
                - severity = "critical"
              receiver: discord
            - matchers:
                - severity = "warning"
              receiver: email-telegram
            - matchers:
                - severity = "info"
              receiver: slack
        receivers:
          - name: "null"
          - name: email
            email_configs:
              - to: "holaryinka5050@gmail.com"
                send_resolved: true
          - name: discord
            slack_configs:
              - api_url: "${var.discord_webhook_url}"
                send_resolved: true
                title: '{{ .GroupLabels.alertname }}'
                text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
          - name: email-telegram
            email_configs:
              - to: "holaryinka5050@gmail.com"
                send_resolved: true
            telegram_configs:
              - bot_token: "${var.telegram_bot_token}"
                chat_id: ${var.telegram_chat_id}
                send_resolved: true
          - name: slack
            slack_configs:
              - api_url: "${var.slack_webhook_url}"
                channel: "#fintrack-alerts"
                send_resolved: true
                title: '{{ .GroupLabels.alertname }}'
                text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
    prometheus:
      prometheusSpec:
        resources:
          requests:
            memory: "256Mi"
          limits:
            memory: "512Mi"
        podMonitorSelectorNilUsesHelmValues: false
        serviceMonitorSelectorNilUsesHelmValues: false
    grafana:
      adminPassword: "fintrack-grafana-2025"
      ingress:
        enabled: false
  YAML
  ]

  # grafana
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

resource "null_resource" "coredns_fix" {
  provisioner "local-exec" {
    command     = "kubectl get configmap coredns -n kube-system -o yaml | sed 's|forward . /etc/resolv.conf|forward . 8.8.8.8 8.8.4.4|g' | kubectl apply -f - && kubectl rollout restart deployment coredns -n kube-system"
    interpreter = ["/bin/bash", "-c"]
  }

  depends_on = [helm_release.cert_manager]
}
