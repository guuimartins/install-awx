#!/bin/bash

if [ "$(id -u)" -eq 0 ]; then
    # Instalando k3s
    apt update -y
    curl -sfL https://get.k3s.io | sh -
    systemctl status k3s
    kubectl get nodes

    mkdir -p $HOME/.kube # Crie o diretório .kube se ainda não existir
    cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config # Copie o arquivo de configuração do kubeconfig
    chown $(id -u):$(id -g) $HOME/.kube/config # Altere a propriedade do arquivo para o seu usuário

    kubectl get nodes

    # Instalando o HELM
    curl -fsSL https://baltocdn.com/helm/signing.asc | gpg --dearmor | tee /usr/share/keyrings/helm.gpg > /dev/null
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list
    apt-get update
    apt-get install helm

    # Install the awx chart
    helm repo add awx-operator https://ansible.github.io/awx-operator/
    helm repo update
    helm install ansible-awx-operator awx-operator/awx-operator -n awx --create-namespace
    kubectl get pods -n awx

    # Create pvc
    cat <<EOF > pvc.yaml
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-13-ansible-awx-postgres-13-0
  namespace: awx
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
EOF

    chmod 644 pvc.yaml
    kubectl apply -f pvc.yaml
    kubectl get pvc -n awx

    # Deploy awx instance
    cat <<EOF > ansible-awx.yaml
---
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: ansible-awx
  namespace: awx
spec:
  service_type: nodeport
EOF

    chmod 644 ansible-awx.yaml
    kubectl apply -f ansible-awx.yaml
    kubectl get pods -n awx -w

    # Access awx web interface
    kubectl expose deployment ansible-awx-web --name ansible-awx-web-svc --type NodePort -n awx
    kubectl get secret ansible-awx-admin-password -o jsonpath="{.data.password}" -n awx | base64 --decode ; echo
else
    echo "Este script deve ser executado como root."
fi
