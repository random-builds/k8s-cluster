#!/usr/bin/env bash

version="0.11.0"
controller_directory="gh-scale-set-controller"

helm pull oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller:${version}
tar --overwrite -xzf gha-runner-scale-set-controller-${version}.tgz
rm -rf ${controller_directory}
mv gha-runner-scale-set-controller ${controller_directory}
rm gha-runner-scale-set-controller-${version}.tgz




target_directory="gh-scale-set-primary"

helm pull oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set:${version}
tar --overwrite -xzf gha-runner-scale-set-${version}.tgz
rm -rf ${target_directory}
mv gha-runner-scale-set ${target_directory}
rm gha-runner-scale-set-${version}.tgz

sed -i 's|githubConfigUrl: ""|githubConfigUrl: "https://github.com/random-builds"|' ${target_directory}/values.yaml
sed -i "s/githubConfigSecret:/githubConfigSecret: ${target_directory}-vault-secret/" ${target_directory}/values.yaml
sed -i 's/  github_token: ""/#  github_token: ""/' ${target_directory}/values.yaml
cat <<EOF >> ${target_directory}/values.yaml
minRunners: 0
maxRunners: 3
controllerServiceAccount:
  namespace: ${controller_directory}
  name: ${controller_directory}-gha-rs-controller
EOF

cat <<EOF > ${target_directory}/templates/external-secrets.yaml
{{ if .Capabilities.APIVersions.Has "external-secrets.io/v1beta1" -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${target_directory}-vault-secret
---
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: ${target_directory}-vault-secret
spec:
  provider:
    vault:
      server: "http://vault-active.vault:8200"
      path: system/${target_directory}
      version: v2
      auth:
        kubernetes:
          mountPath: kubernetes
          role: ${target_directory}
          serviceAccountRef:
            name: ${target_directory}-vault-secret
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: ${target_directory}-vault-secret
spec:
  secretStoreRef:
    name: ${target_directory}-vault-secret
    kind: SecretStore
  target:
    name: ${target_directory}-vault-secret
  data:
    - remoteRef:
        key: application
        property:  github_app_id
      secretKey:  github_app_id
    - remoteRef:
        key: application
        property:  github_app_installation_id
      secretKey:  github_app_installation_id
    - remoteRef:
        key: application
        property:  github_app_private_key
      secretKey:  github_app_private_key
{{ end }}
EOF