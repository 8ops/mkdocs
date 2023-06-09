# oauth2

## 一、背景

- ingress-nginx
- ingress
- echoserver

[Reference](https://kubernetes.github.io/ingress-nginx/examples/auth/oauth-external-auth/)

[Source](https://oak-tree.tech/blog/k8s-nginx-oauth2-gitlab)

[Source](https://oauth2-proxy.github.io/oauth2-proxy/docs/configuration/oauth_provider#gitlab-auth-provider)


## 二、步骤

app echoserver alerady exists.



### 2.1 create gitlab application

`Admin --> Applications`

Get

- Application ID
- Secret
- Callback URL
- Scopes - group,openid,profile,email
- Trusted - yes
- Confidential - yes

### 2.2 create oauth2-proxy

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: oauth2-proxy
  name: oauth2-proxy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: oauth2-proxy
  template:
    metadata:
      labels:
        app: oauth2-proxy
    spec:
      containers:
      - name: oauth2-proxy
        image: hub.8ops.top/middleware/oauth2-proxy:v7.4.0-amd64
        imagePullPolicy: Always
        ports:
        - containerPort: 4180
          protocol: TCP
        args:
        - --provider=gitlab
        - --upstream=file:///dev/null
        - --http-address=0.0.0.0:4180
        - --cookie-secure=false
        - --redirect-url=https://echoserver.8ops.top/oauth2/callback
        - --skip-provider-button=false
        - --set-xauthrequest=true
        - --skip-auth-preflight=false
        - --skip-oidc-discovery
        - --oidc-issuer-url=https://git.8ops.top
        - --login-url=https://git.8ops.top/oauth/authorize
        - --redeem-url=https://git.8ops.top/oauth/token
        - --oidc-jwks-url=https://git.8ops.top/oauth/discovery/keys
        - --email-domain=*
        env:
        - name: OAUTH2_PROXY_CLIENT_ID
          value: xx
        - name: OAUTH2_PROXY_CLIENT_SECRET
          value: xx
        - name: OAUTH2_PROXY_COOKIE_SECRET
          value: 9Lva8VIF3xXJQRkmM7i5Iw==
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: oauth2-proxy
  name: oauth2-proxy
spec:
  ports:
  - name: http
    port: 4180
    protocol: TCP
    targetPort: 4180
  selector:
    app: oauth2-proxy
```

> 当需要指定某个群组时

```bash
# 在gitlab里面创建一个群组，成员可以访问
        - --gitlab-group="echoserver-group,abc-group"

# 在gitlab里面创建一个仓库，成员可以访问
        - --gitlab-project="oauth2/kibana-app-prod=10"

```

> args

```bash

        - args:
            - --provider=gitlab
            - --http-address=0.0.0.0:4180
            - --ssl-insecure-skip-verify=true
            - --ssl-upstream-insecure-skip-verify=true
            - --redirect-url=https://echoserver.8ops.top/oauth2/callback
            - --client-id=xxx
            - --client-secret=xx
            - --cookie-secret=xx
            - --oidc-issuer-url=https://git.8ops.top
            # - --gitlab-group="oauth2"
            - --gitlab-project="oauth2/echoserver=10"
            - --upstream=file:///dev/null
            - --email-domain=*
            - --cookie-secure=true
            - --reverse-proxy=true
            - --set-xauthrequest=true
            - --pass-host-header=true
            - --pass-user-headers=true
            # - --session-store-type=redis
            # - --redis-connection-url=redis://127.0.0.1:6379

```



### 2.3 create ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/auth-url: "https://$host/oauth2/auth"
    nginx.ingress.kubernetes.io/auth-signin: "https://$host/oauth2/start?rd=$escaped_request_uri"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "false"
    nginx.ingress.kubernetes.io/limit-rps: "100"
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
  labels:
    app: echoserver
    argocd.argoproj.io/instance: lab-ofc-toolkit
  name: echoserver
  namespace: default
spec:
  ingressClassName: external
  rules:
  - host: echoserver.8ops.top
    http:
      paths:
      - backend:
          service:
            name: echoserver
            port:
              number: 8080
        path: /
        pathType: Prefix
  tls:
  - hosts:
    - echoserver.8ops.top
    secretName: tls-8ops.top
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: oauth2-proxy
  namespace: default
spec:
  ingressClassName: external
  rules:
  - host: echoserver.8ops.top
    http:
      paths:
      - path: /oauth2
        pathType: Prefix
        backend:
          service:
            name: oauth2-proxy
            port:
              number: 4180
  tls:
  - hosts:
    - echoserver.8ops.top
    secretName: tls-8ops.top
```

