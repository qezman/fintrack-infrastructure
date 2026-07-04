resource "helm_release" "kyverno" {
  name       = "kyverno"
  repository = "https://kyverno.github.io/kyverno"
  chart      = "kyverno"
  namespace  = kubernetes_namespace.kyverno.metadata[0].name
  version    = "3.2.6"

  set {
    name  = "replicaCount"
    value = "1"
  }

  set {
    name  = "resource.requests.memory"
    value = "128Mi"
  }

  set {
    name  = "resource.requests.memory"
    value = "50m"
  }

  set {
    name  = "cleanupController.enabled"
    value = "false"
  }

  set {
    name  = "reportsController.enabled"
    value = "false"
  }

  set {
    name  = "cleanupJobs.admissionReports.enabled"
    value = "false"
  }

  set {
    name  = "cleanupJobs.clusterAdmissionReports.enabled"
    value = "false"
  }

  set {
    name  = "cleanupJobs.clusterEphemeralReports.enabled"
    value = "false"
  }

  set {
    name  = "cleanupJobs.ephemeralReports.enabled"
    value = "false"
  }

  set {
    name  = "cleanupJobs.updateRequests.enabled"
    value = "false"
  }

  wait    = false
  timeout = 600

  depends_on = [kubernetes_namespace.kyverno]
}
