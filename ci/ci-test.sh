#!/usr/bin/env bash
# Copyright 2019 The OpenEBS Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

ZFS_CHART=deploy/helm/charts
SNAP_CLASS=deploy/sample/zfssnapclass.yaml
export OPENEBS_NAMESPACE="openebs"

TEST_DIR="tests"


# Prepare env for runnging BDD tests
# Minikube is already running
helm install openebs-zfslocalpv "$ZFS_CHART" -n "$OPENEBS_NAMESPACE" --create-namespace --dependency-update --set analytics.enabled=false
kubectl apply -f "$SNAP_CLASS"

dumpAgentLogs() {
  NR=$1
  AgentPOD=$(kubectl get pods -l app=openebs-zfs-node -o jsonpath='{.items[0].metadata.name}' -n "$OPENEBS_NAMESPACE")
  kubectl describe po "$AgentPOD" -n "$OPENEBS_NAMESPACE"
  printf "\n\n"
  kubectl logs --tail="${NR}" "$AgentPOD" -n "$OPENEBS_NAMESPACE" -c openebs-zfs-plugin
  printf "\n\n"
}

dumpControllerLogs() {
  NR=$1
  ControllerPOD=$(kubectl get pods -l app=openebs-zfs-controller -o jsonpath='{.items[0].metadata.name}' -n "$OPENEBS_NAMESPACE")
  kubectl describe po "$ControllerPOD" -n "$OPENEBS_NAMESPACE"
  printf "\n\n"
  kubectl logs --tail="${NR}" "$ControllerPOD" -n "$OPENEBS_NAMESPACE" -c openebs-zfs-plugin
  printf "\n\n"
}


isPodReady(){
  [ "$(kubectl get po "$1" -o 'jsonpath={.status.conditions[?(@.type=="Ready")].status}' -n $OPENEBS_NAMESPACE)" = 'True' ]
}


isDriverReady(){
  for pod in $zfsDriver;do
    isPodReady "$pod" || return 1
  done
}


waitForZFSDriver() {
  period=120
  interval=1
  
  i=0
  while [ "$i" -le "$period" ]; do
    zfsDriver="$(kubectl get pods -l role=openebs-zfs -o 'jsonpath={.items[*].metadata.name}' -n $OPENEBS_NAMESPACE)"
    if isDriverReady "$zfsDriver"; then
      return 0
    fi

    i=$(( i + interval ))
    echo "Waiting for zfs-driver to be ready..."
    sleep "$interval"
  done

  echo "Waited for $period seconds, but all pods are not ready yet."
  return 1
}

# wait for zfs-driver to be up
waitForZFSDriver

cd $TEST_DIR

kubectl get po -n "$OPENEBS_NAMESPACE"

set +e

echo "running ginkgo test case"

if ! ginkgo -v -coverprofile=bdd_coverage.txt -covermode=atomic; then

sudo zpool status

sudo zfs list -t all

sudo zfs get all

echo "******************** ZFS Controller logs***************************** "
dumpControllerLogs 1000

echo "********************* ZFS Agent logs *********************************"
dumpAgentLogs 1000

echo "get all the pods"
kubectl get pods -owide --all-namespaces

echo "get pvc and pv details"
kubectl get pvc,pv -oyaml --all-namespaces

echo "get snapshot details"
kubectl get volumesnapshot.snapshot -oyaml --all-namespaces

echo "get sc details"
kubectl get sc --all-namespaces -oyaml

echo "get zfs volume details"
kubectl get zfsvolumes.zfs.openebs.io -n "$OPENEBS_NAMESPACE" -oyaml

echo "get zfs snapshot details"
kubectl get zfssnapshots.zfs.openebs.io -n "$OPENEBS_NAMESPACE" -oyaml

exit 1
fi

printf "\n\n######### All test cases passed #########\n\n"
