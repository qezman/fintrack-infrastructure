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

