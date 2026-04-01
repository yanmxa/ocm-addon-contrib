#!/bin/bash
# Dry-run: send all demo content to flower:0.0 as # comments (no execution)
# Run from any session to preview the full demo flow in the flower pane.

HUB="flower:0.0"
CTX_DIR="$HOME/flower-demo"
DEMO_DIR="/home/cloud-user/workspace/flower-addon-demo/flower-addon/hack/demo"
KUBECONFIG_HUB=~/.kube/hub
KUBECONFIG_C1=~/.kube/cluster1
KUBECONFIG_C2=~/.kube/cluster2

f()  { tmux send-keys -t "$HUB" "# $*" Enter; sleep 0.12; }
fl() { tmux send-keys -t "$HUB" ""      Enter; sleep 0.08; }  # blank line

banner() {
  fl
  f "================================================================================"
  f " $*"
  f "================================================================================"
  fl
}

note() {
  f "-- $*"
}

run() {
  f "  \$ $*"
}

# ─── Reset hub pane (mirrors run-demo pane setup) ────────────
tmux send-keys -t "$HUB" "export REPO=/home/cloud-user/workspace/ocm-addon-contrib DEMO_DIR=$DEMO_DIR" Enter; sleep 0.3
tmux send-keys -t "$HUB" "export KUBECONFIG_HUB=$KUBECONFIG_HUB KUBECONFIG_C1=$KUBECONFIG_C1 KUBECONFIG_C2=$KUBECONFIG_C2" Enter; sleep 0.3
tmux send-keys -t "$HUB" "zle_highlight=(default:none)" Enter; sleep 0.3
tmux send-keys -t "$HUB" "cd $CTX_DIR/hub && clear" Enter; sleep 0.3
tmux send-keys -t "$HUB" "export KUBECONFIG=$KUBECONFIG_HUB" Enter; sleep 0.5

# ─── Agenda ──────────────────────────────────────────────────
f "================================================================================"
f " Scaling Enterprise Federated AI with Flower and Open Cluster Management"
f "================================================================================"
f ""
f "   1. Open Cluster Management Setup"
f "      Bootstrap hub + cluster1 + cluster2, join and accept managed clusters"
f ""
f "   2. Define SuperNode with OCM Addon"
f "      ClusterManagementAddon, ManagedClusterAddon, AddonTemplate"
f ""
f "   3. Schedule SuperNode with OCM Placement"
f "      Dynamically install SuperNode on clusters based on GPU resource"
f ""
f "   4. Application Distribution via OCM Work API"
f "      Distribute ClientApp dynamically via ManifestWorkReplicaSet + Placement"
f ""
f "================================================================================"

# ─── Section 1 ───────────────────────────────────────────────
banner "Section 1/4  |  Open Cluster Management Setup"

note "Creating 3 clusters in parallel -- hub (top), cluster1 (bottom-left), cluster2 (bottom-right)"
run "kind create cluster --name cluster1   # cluster1 pane"
run "kind create cluster --name cluster2   # cluster2 pane"
run "kind create cluster --name hub --config $DEMO_DIR/hub-kind.yaml"
run "[Enter to continue after all 3 clusters are ready]"

run "clusteradm init --feature-gates=ManifestWorkReplicaSet=true --wait"
run "[Enter to continue]"

run "# JOIN_C1 / JOIN_C2 captured from: clusteradm get token"
run "# cluster1 pane: <join-cmd> --force-internal-endpoint-lookup --wait"
run "# cluster2 pane: <join-cmd> --force-internal-endpoint-lookup --wait"

run "clusteradm accept --clusters cluster1,cluster2 --wait"

run "kubectl get pods -n open-cluster-management"
run "kubectl get managedclusters"
run "# cluster1 pane: kubectl get klusterlet"
run "# cluster2 pane: kubectl get klusterlet"

# ─── Section 2 ───────────────────────────────────────────────
banner "Section 2/4  |  Define SuperNode with OCM Addon"

run 'echo "Hub IP: $HUB_IP"'

note "Generate TLS certificates for SuperLink and create Kubernetes Secrets"
run '$REPO/flower-addon/hack/generate-certs.sh --hub-ip $HUB_IP'

note "Install flower-addon helm chart -- deploys SuperLink on hub + registers addon"
run "helm install flower-addon \$REPO/flower-addon/charts/flower-addon \\"
run "  --set deploymentConfig.superlinkAddress=\$HUB_IP \\"
run "  --set tls.enabled=true \\"
run "  --set addon.installStrategy=Placements \\"
run "  --set placement.gpu.enabled=true \\"
run "  --set placement.gpu.clusterSet=global"

run "kubectl wait --for=condition=available deployment/superlink -n flower-system --timeout=90s"
run "kubectl get pods -n flower-system"

note "AddonTemplate -- defines how SuperNode is installed on each Managed Cluster"
run "kubectl get addontemplate flower-addon -oyaml | bat -l yaml --paging=never"

note "ClusterManagementAddon -- global Addon policy, installStrategy=Placements"
run "kubectl get clustermanagementaddon flower-addon -oyaml | bat -l yaml --paging=never"

# ─── Section 3 ───────────────────────────────────────────────
banner "Section 3/4  |  Schedule SuperNode with OCM Placement"

run "kubectl get placement flower-addon-gpu-placement -n open-cluster-management -oyaml | bat -l yaml --paging=never"
note "ClusterManagementAddon links to this Placement via installStrategy.placements"
run "kubectl get clustermanagementaddon flower-addon -ojsonpath='{.spec.installStrategy.placements}' | python3 -m json.tool"

note "No cluster has gpu=true yet -- PlacementDecision selects nobody"
run "kubectl get placementdecisions -n open-cluster-management"
run "# cluster1/cluster2 panes: watch kubectl get pods -n flower-addon"
run "kubectl label managedcluster cluster2 gpu=true"
run "kubectl get placementdecisions -n open-cluster-management"
note "cluster2 selected -- SuperNode installing... watch the bottom-right pane"
run "kubectl get managedclusteraddons -A"
note "Scale out: label cluster1 gpu=true -- SuperNode auto-installed there too"
run "kubectl label managedcluster cluster1 gpu=true"
run "kubectl get managedclusteraddons -A"
run "kubectl get managedclusteraddon flower-addon -n cluster1 -oyaml | bat -l yaml --paging=never"

# ─── Section 4 ───────────────────────────────────────────────
banner "Section 4/4  |  Application Distribution via OCM Work API"

note "Show Placement predicate + ManifestWorkReplicaSet in one file"
run "bat -l yaml --paging=never $DEMO_DIR/clientapp-with-data.yaml"
run "kubectl apply -f $DEMO_DIR/clientapp-with-data.yaml"
run "kubectl label managedcluster cluster1 data=cifar10"
run "kubectl get manifestworks -A"
note "Scale out: label cluster2 with data=cifar10 -- ClientApp auto-distributed"
run "kubectl label managedcluster cluster2 data=cifar10"
run "kubectl get manifestworks -A"

note "Switch cluster panes to ClientApp logs"
run "# cluster1 pane: kubectl logs -n flower-addon -l app.kubernetes.io/component=superexec-clientapp -f --tail=20"
run "# cluster2 pane: kubectl logs -n flower-addon -l app.kubernetes.io/component=superexec-clientapp -f --tail=20"
run "kubectl logs -n flower-system deployment/superlink -f --tail=30"

# ─── Done ────────────────────────────────────────────────────
banner "Demo Complete"
f "  SuperNode  -- infrastructure layer  : scheduled by GPU resource via Placement"
f "  ClientApp  -- application layer     : scheduled by addon=Available + data label"
f "  ManifestWorkReplicaSet drives automatic distribution as labels change"
