#!/usr/bin/env bash
set -euo pipefail

# This script only touches a disposable kind cluster and a temporary loop filesystem.
: "${RUNNER_TEMP:?Run this smoke check on a Linux CI runner}"
state_dir=$(mktemp -d "$RUNNER_TEMP/ayakaleaf-deployment.XXXXXX")
cluster=ayakaleaf-smoke
export KUBECONFIG="$state_dir/kubeconfig"

cleanup() {
  local status=$?
  set +e
  if [ "$status" -ne 0 ]; then
    kubectl -n overleaf get pods,pvc
    kubectl -n overleaf describe pods
    kubectl -n overleaf logs deployment/ayakaleaf-pro --all-containers --tail=100
    kubectl -n overleaf exec deployment/ayakaleaf-pro -c overleaf -- bash -c \
      "for file in /var/log/overleaf/*.log; do echo \"=== \$file ===\"; tail -n 60 \"\$file\"; done"
  fi
  kind delete cluster --name "$cluster"
  if mountpoint -q "$state_dir/data"; then
    sudo umount "$state_dir/data"
  fi
  sudo rm -rf "$state_dir"
  exit "$status"
}
trap cleanup EXIT

# Exercise overlay2 on the same filesystem type as Andromeda's chosen root disk.
mkdir "$state_dir/data"
truncate -s 64G "$state_dir/storage.img"
mkfs.btrfs --quiet "$state_dir/storage.img"
sudo mount -o loop "$state_dir/storage.img" "$state_dir/data"
cat > "$state_dir/kind.yaml" <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraMounts:
      - hostPath: $state_dir/data
        containerPath: /var/lib/ayakaleaf-pro
EOF
kind create cluster --name "$cluster" --config "$state_dir/kind.yaml" \
  --image kindest/node:v1.30.10@sha256:4de75d0e82481ea846c0ed1de86328d821c1e6a6a91ac37bf804e5313670e507 \
  --wait 120s
kubectl label node "$cluster-control-plane" kubernetes.io/hostname=andromeda --overwrite
kubectl create namespace overleaf

cp -R deploy/andromeda "$state_dir/manifests"
if [ -n "${IMAGE_REFERENCE:-}" ]; then
  (
    cd "$state_dir/manifests"
    kustomize edit set image "ghcr.io/honahec/ayakaleaf-pro=$IMAGE_REFERENCE"
  )
fi
kubectl apply -k "$state_dir/manifests"
kubectl -n overleaf rollout status deployment/ayakaleaf-pro --timeout=1200s

kubectl -n overleaf exec deployment/ayakaleaf-pro -c overleaf -- \
  curl --fail --silent --show-error --output /dev/null http://127.0.0.1/login
kubectl -n overleaf exec deployment/ayakaleaf-pro -c docker -- \
  docker info --format 'Docker storage driver: {{.Driver}}'

compile_document() {
  kubectl -n overleaf exec -i deployment/ayakaleaf-pro -c overleaf -- node --input-type=module <<'NODE'
import assert from 'node:assert/strict'
import { writeFile, unlink } from 'node:fs/promises'
import { execFileSync } from 'node:child_process'

const project = '0123456789abcdef01234567'
const response = await fetch(`http://127.0.0.1:3013/project/${project}/compile`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ compile: {
    options: { compiler: 'pdflatex', timeout: 60, imageName: process.env.TEX_LIVE_DOCKER_IMAGE },
    rootResourcePath: 'main.tex',
    resources: [{ path: 'main.tex', content: '\\documentclass{article}\n\\begin{document}\nGitOps sandbox smoke\n\\end{document}' }],
  } }),
  signal: AbortSignal.timeout(90000),
})
assert.equal(response.status, 200)
const result = await response.json()
assert.equal(result.compile.status, 'success', JSON.stringify(result))
const pdf = result.compile.outputFiles.find(file => file.type === 'pdf')
assert.ok(pdf, 'Compile response must include the PDF')
const url = new URL(pdf.url, 'http://127.0.0.1:8080')
url.hostname = '127.0.0.1'
url.port = '8080'
const download = await fetch(url, { signal: AbortSignal.timeout(10000) })
assert.equal(download.status, 200)
const path = '/tmp/gitops-smoke.pdf'
try {
  await writeFile(path, Buffer.from(await download.arrayBuffer()))
  const text = execFileSync('pdftotext', [path, '-'], { encoding: 'utf8' })
  assert.ok(text.includes('GitOps sandbox smoke'), 'Downloaded PDF must contain the submitted text')
} finally {
  await unlink(path).catch(error => { if (error.code !== 'ENOENT') throw error })
}
console.log('CLSI API compiled through DinD; output nginx served the correct PDF')
NODE
}
compile_document

secret_before=$(kubectl -n overleaf exec deployment/ayakaleaf-pro -c overleaf -- \
  sha256sum /var/lib/overleaf/deployment-secrets.env)
kubectl -n overleaf exec deployment/ayakaleaf-pro -c mongo -- mongosh --quiet --eval \
  'db.getSiblingDB("sharelatex").gitopsSmoke.insertOne({_id:"persistent-marker", value:"survives-restart"})'
kubectl -n overleaf rollout restart deployment/ayakaleaf-pro
kubectl -n overleaf rollout status deployment/ayakaleaf-pro --timeout=600s
secret_after=$(kubectl -n overleaf exec deployment/ayakaleaf-pro -c overleaf -- \
  sha256sum /var/lib/overleaf/deployment-secrets.env)
test "$secret_before" = "$secret_after"
kubectl -n overleaf exec deployment/ayakaleaf-pro -c mongo -- mongosh --quiet --eval \
  'const marker = db.getSiblingDB("sharelatex").gitopsSmoke.findOne({_id:"persistent-marker"}); if (marker?.value !== "survives-restart") { throw new Error("Mongo data did not persist"); }'
kubectl -n overleaf exec deployment/ayakaleaf-pro -c overleaf -- \
  curl --fail --silent --show-error --output /dev/null http://127.0.0.1/login
compile_document
printf '%s\n' 'Deployment startup, sandbox compilation, PDF download and restart persistence passed'
