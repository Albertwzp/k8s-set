#! /bin/bash

ETCDHOSTS=($@)
kubeadm init phase certs etcd-ca
for i in ${!ETCDHOSTS[@]}; do
HOST=${ETCDHOSTS[$i]}
echo "${HOST}"
NAME="infra${i}"
echo "${NAME}"
mkdir -p /tmp/${HOST}
cat << EOF > /tmp/${HOST}/kubeadmcfg.yaml
apiVersion: "kubeadm.k8s.io/v1beta2"
kind: ClusterConfiguration
etcd:
    local:
        serverCertSANs:
        - "${HOST}"
        peerCertSANs:
        - "${HOST}"
        extraArgs:
            initial-cluster: infra0=https://${ETCDHOSTS[0]}:2380,infra1=https://${ETCDHOSTS[1]}:2380,infra2=https://${ETCDHOSTS[2]}:2380
            initial-cluster-state: new
            name: ${NAME}
            listen-peer-urls: https://${HOST}:2380
            listen-client-urls: https://${HOST}:2379
            advertise-client-urls: https://${HOST}:2379
            initial-advertise-peer-urls: https://${HOST}:2380
EOF
kubeadm init phase certs etcd-server --config=/tmp/${HOST}/kubeadmcfg.yaml
kubeadm init phase certs etcd-peer --config=/tmp/${HOST}/kubeadmcfg.yaml
kubeadm init phase certs etcd-healthcheck-client --config=/tmp/${HOST}/kubeadmcfg.yaml
kubeadm init phase certs apiserver-etcd-client --config=/tmp/${HOST}/kubeadmcfg.yaml
cp -R /etc/kubernetes/pki /tmp/${HOST}/
find /etc/kubernetes/pki -not -name ca.crt -not -name ca.key -type f -delete
tar -zcf /tmp/${HOST}.tar.gz -C /tmp/${HOST} kubeadmcfg.yaml pki
done
