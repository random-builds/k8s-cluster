name=gh-scaleset-controller
helm template --namespace $name \
  $name oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller > templates/$name.yaml