#!/bin/bash

[ `dirname $0` == "./bin" ] || exit 1

export PATH="`pwd`/bin":$PATH
kubectl_old="kubectl --kubeconfig=lib/kubeconfig-10.101.11.240"
# ${kubectl_old} api-resources --verbs=list --namespaced -o name 

#-----------------------------------------------------------------------------#
# 11, secrets
function do_secrets(){
#${kubectl_old} label `${kubectl_old} get secrets -o name | awk '/tls-/' | paste -s -d ' '` 8ops.top=true

${kubectl_old} get secrets -o name -l 8ops.top=true -o yaml | \
    yq eval '
        del( 
            .items[].metadata.annotations, 
	    .items[].metadata.creationTimestamp, 
	    .items[].metadata.resourceVersion, 
	    .items[].metadata.selfLink, 
	    .items[].metadata.uid, 
	    .metadata
	)' - | \
    yq eval '
        .items[].metadata.labels["8ops.top"]="true" | 
        .items[].metadata.namespace="kube-app"
        ' - > 11-secrets.yaml
}

#-----------------------------------------------------------------------------#
# 12, services
function do_services(){
#${kubectl_old} get services -l k8s-app=userdoor -o yaml | \
${kubectl_old} get services -l k8s-app -o yaml | \
    yq eval '
        del( 
            .items[].metadata.annotations, 
	    .items[].metadata.creationTimestamp, 
	    .items[].metadata.resourceVersion, 
	    .items[].metadata.selfLink, 
	    .items[].metadata.uid, 
	    .items[].spec.clusterIP,
	    .items[].spec.externalTrafficPolicy,
	    .items[].spec.sessionAffinity,
	    .items[].spec.ports[].nodePort,
	    .items[].status, 
	    .metadata
	)' - | \
    yq eval '
        .items[].metadata.namespace="kube-app" |
        .items[].metadata.labels["8ops.top"]="true" |
        .items[].spec.type="ClusterIP"
        ' - > 12-services.yaml
}

#-----------------------------------------------------------------------------#
# 13, deployments
function do_deployments(){
#${kubectl_old} get deployments -l k8s-app=userdoor -o yaml | \
${kubectl_old} get deployments -l k8s-app -o yaml | \
    yq eval '
        del( 
	    .items[].metadata.annotations, 
	    .items[].metadata.creationTimestamp, 
	    .items[].metadata.generation, 
	    .items[].metadata.resourceVersion, 
	    .items[].metadata.selfLink, 
	    .items[].metadata.uid, 
	    .items[].status, 
	    .metadata 
	)' - | \
    yq eval '
       .items[].metadata.namespace="kube-app" | 
       .items[].metadata.labels["8ops.top"]="true" |
       .items[].spec.replicas=0 |
       .items[].apiVersion="apps/v1" 
       ' - > 13-deployments.yaml
}

#-----------------------------------------------------------------------------#
# 14, ingresses
function do_ingresses(){
#${kubectl_old} label ing `${kubectl_old} get ing | awk '$2~/services.dev.ofc/{printf("%s ",$1)}'` 8ops.top/ingress.class=internal
#${kubectl_old} label ing `${kubectl_old} get ing | awk '$2!~/services.dev.ofc/{printf("%s ",$1)}'` 8ops.top/ingress.class=external

#${kubectl_old} get ingress -l k8s-app=a.guanaitong,8ops.top/ingress.class=external -o yaml | \
${kubectl_old} get ingress -l k8s-app,8ops.top/ingress.class=external -o yaml | \
    yq eval '
        del( 
            .items[].metadata.annotations["kubernetes.io/ingress.class"],
            .items[].metadata.annotations["kubectl.kubernetes.io/last-applied-configuration"],
	    .items[].metadata.creationTimestamp, 
	    .items[].metadata.generation, 
	    .items[].metadata.resourceVersion, 
	    .items[].metadata.selfLink, 
	    .items[].metadata.uid, 
	    .items[].status, 
	    .metadata 
	)' - | \
    yq eval '
        .items[].apiVersion="networking.k8s.io/v1" |
        .items[].metadata.namespace="kube-app" |
        .items[].metadata.labels["8ops.top"]="true" |
    	.items[].spec.ingressClassName="external" 
	' - | \
    sed \
        -e '/path:/a \
                pathType: Prefix' \
        -e 's/serviceName: /service: \
                    name: /g' \
        -e 's/servicePort: /  port: \
                      number: /g' > 14-ingresses-external.yaml


${kubectl_old} get ingress -l k8s-app,8ops.top/ingress.class=internal -o yaml | \
    yq eval '
        del( 
	    .items[].metadata.annotations, 
	    .items[].metadata.creationTimestamp, 
	    .items[].metadata.generation, 
	    .items[].metadata.resourceVersion, 
	    .items[].metadata.selfLink, 
	    .items[].metadata.uid, 
	    .items[].status, 
	    .metadata 
	)' - | \
    yq eval '
        .items[].apiVersion="networking.k8s.io/v1" |
        .items[].metadata.namespace="kube-app" |
        .items[].metadata.labels["8ops.top"]="true" |
    	.items[].spec.ingressClassName="internal" 
	' - | \
    sed \
        -e '/path:/a \
                pathType: Prefix' \
        -e 's/serviceName: /service: \
                    name: /g' \
        -e 's/servicePort: /  port: \
                      number: /g' > 14-ingresses-internal.yaml
}

#-----------------------------------------------------------------------------#
# 15, endpoints
function do_endpoints(){
${kubectl_old} get endpoints -l k8s-ep=custom-ep -o yaml | \
    yq eval '
        del( 
	    .items[].metadata.annotations, 
	    .items[].metadata.creationTimestamp, 
	    .items[].metadata.generation, 
	    .items[].metadata.resourceVersion, 
	    .items[].metadata.selfLink, 
	    .items[].metadata.uid, 
	    .items[].metadata.labels["k8s-ep"], 
	    .items[].status, 
	    .metadata 
	)' - | \
    yq eval '
        .items[].metadata.labels["8ops.top"]="true" |
        .items[].metadata.labels["8ops.top/endpoints.custom"]="true" | 
        .items[].metadata.namespace="kube-app" 
       ' - | \
    sed \
	-e '' > 15-endpoints.yaml

}

#-----------------------------------------------------------------------------#

# dump
do_secrets
do_services
do_deployments
do_ingresses
do_endpoints

# apply
kubectl apply -f 11-secrets.yaml
kubectl apply -f 12-services.yaml 
kubectl apply -f 13-deployments.yaml
kubectl apply -f 14-ingresses-external.yaml
kubectl apply -f 14-ingresses-internal.yaml
kubectl apply -f 15-endpoints.yaml

kubectl -n kube-app get deploy -o name | \
awk 'NR>1{
    printf("/usr/bin/kubectl -n kube-app scale --replicas=1 %s;\n",$1);
    if(NR%3==0){printf("sleep 60;\n")}
}' | sh

exit 0
