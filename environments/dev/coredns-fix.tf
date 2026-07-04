resource "null_resource" "coredns_fix" {
  provisioner "local-exec" {
    command     = "kubectl get configmap coredns -n kube-system -o yaml | sed 's|forward . /etc/resolv.conf|forward . 8.8.8.8 8.8.4.4|g' | kubectl apply -f - && kubectl rollout restart deployment coredns -n kube-system"
    interpreter = ["/bin/bash", "-c"]
  }
}

