# Namespaces
resource "kubernetes_namespace" "ingress_nginx" {
  metadata {
    name = "ingress-nginx"
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
}

# Loki - log aggregation
resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "6.6.4"

  values = [<<-YAML
  deploymentMode: SingleBinary
  loki:
    commonConfig:
      replication_factor: 1
    auth_enabled: false
    storage:
      type: filesystem
    schemaConfig:
      configs:
        - from: "2024-01-01"
          store: tsdb
          object_store: filesystem
          schema: v13
          index:
            prefix: loki_index_
            period: 24h
  singleBinary:
    replicas: 1
    resources:
      requests:
        memory: "256Mi"
        cpu: "100m"
      limits:
        memory: "512Mi"
  read:
    replicas: 0
  write:
    replicas: 0
  backend:
    replicas: 0
  lokiCanary:
    enabled: false
  chunksCache:
    enabled: false
  resultsCache:
    enabled: false
  gateway:
    enabled: false
YAML
  ]

  set {
    name  = "test.enabled"
    value = "false"
  }

  wait    = false
  timeout = 600

  depends_on = [kubernetes_namespace.monitoring]
}

# Promtail - log shipper (DaemonSet, one per node)
resource "helm_release" "promtail" {
  name       = "promtail"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "promtail"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "6.16.6"

  values = [<<-YAML
    config:
      clients:
        - url: http://loki:3100/loki/api/v1/push
    resources:
      requests:
        memory: "64Mi"
        cpu: "50m"
      limits:
        memory: "128Mi"
  YAML
  ]

  wait    = false
  timeout = 600

  depends_on = [helm_release.loki]
}

# External Secrets Operator namespace
resource "kubernetes_namespace" "external_secrets" {
  metadata {
    name = "external-secrets"
  }
}

# External Secrets Operator
resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  namespace  = kubernetes_namespace.external_secrets.metadata[0].name
  version    = "0.9.20"

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.external_secrets.role_arn
  }

  wait    = false
  timeout = 600

  depends_on = [kubernetes_namespace.external_secrets]
}
