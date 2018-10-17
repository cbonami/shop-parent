# GitLab on MiniKube

Based on [these instructions](https://gitlab.com/charts/gitlab/blob/master/doc/minikube/README.md).
I am running Windows 10.

## Minikube setup

Start minikube and make sure that nginx ingress controller is running. I have a 32GB-machine with 6 cores, so I reserved 16G of memory and 6 vCPUs, but 8GB and 3 vCpus should be fine.
```
minikube start --memory 16384 --cpus 6 --vm-driver="virtualbox"
minikube addons enable ingress
minikube addons enable kube-dns
```
(some [background on ingress addon](https://medium.com/@Oskarr3/setting-up-ingress-on-minikube-6ae825e98f82))

Initialize helm with RBAC enabled:
```
kubectl create -f https://gitlab.com/charts/gitlab/raw/master/doc/helm/examples/rbac-config.yaml
helm init --service-account tiller
#or, in case helm was already initialized before: helm init --upgrade --service-account tiller
```

## GitLab EE setup

Install GitLab EE on the cluster:
```
git clone https://gitlab.com/charts/gitlab
cd gitlab
cp examples/values-minikube.yaml ./
helm repo add gitlab https://charts.gitlab.io/
helm dep update
helm upgrade --install -f values-minikube.yaml gitlab .
```

This outputs:

```
... snip ...
NOTES:
WARNING: Automatic TLS certificate generation with cert-manager is disabled and
no TLS certificates were provided. Self-signed certificates were generated.

You may retrieve the CA root for these certificates from the `gitlab-wildcard-tls-ca` secret, via the following command. It can then be imported to a web browser or system store.

    kubectl get secret gitlab-wildcard-tls-ca -ojsonpath={.data.cfssl_ca} | base64 --decode > gitlab.192.168.99.100.nip.io.ca.pem
... snip ...
```

Execute the following:

```
kubectl get secret gitlab-wildcard-tls-ca -ojsonpath={.data.cfssl_ca} | base64 --decode > gitlab.192.168.99.100.nip.io.ca.pem
```

Wait for a long(?) time. 8 mins on my machine.
Check the status of your deployment with the following:

```
helm status gitlab
minikube dashboard
```

The dashboard was the easiest for me.

Sidenote: Apparently, there is an [issue on W10 with ingress controller attaching to eth0 instead of eth1](https://github.com/kubernetes/minikube/issues/2922), but it should not bother us too much.

## Restarting Minikube

https://github.com/kubernetes/minikube/issues/951

## Use GitLab

### Log in

[Install](https://www.bounca.org/tutorials/install_root_certificate.html) the generated self-signed root-certificate in your browser. Needed ??

Retrieve the generated root-password (to log in to the gitlab unicorn dashboard) like this:

```
vagrant@ubuntu-xenial:~$ kubectl get secret gitlab-gitlab-initial-root-password -o yaml
apiVersion: v1
data:
  password: RmpFOUtWYWxVakJJaWVPeWl6NDlXb1d1SXh6M0hzR0FsMXdZSThFd0p2Ujk4aVRVQldWNXZUZFNzdUlucDR3OA==
kind: Secret
metadata:
  creationTimestamp: 2018-09-11T17:31:33Z
... snip ...
```

Use [this site](https://www.base64decode.org/) to base64-decode the password (UTF-8).

Point Chrome to [https://gitlab.192.168.99.100.nip.io/](https://gitlab.192.168.99.100.nip.io/).
user: root
password: <base64 decoded value> - in my case: I3BqtwKyQKPUuYsAU4dVAs42T4McR75O7hYltQZvMY71R65hVwEdW5P46lAQ7cDG

I started the free 30-day trial. License:

```
eyJkYXRhIjoiYjQydXhtWDYrZFUydGpBSk13dFZzYklKRlFUTXlkc0RKSDJC WDFJTVpIelRPQTl3cFdrY2h0NU5PbE1KXG4xZUJueFN0cnY2K2ZyTjVVL2My NC9lUmw5UHptVXkrWHNLdDRFWmlieWtvY2N4SWUyUFBDcDZQa0ZLdE9cbnJh NVhmMlF1V0FWaElwcjUxbm4wTTNyNFRWMFNES3ZNYTNWNS9HNGVwcGJLWkhD dzdYUFN5bVZmRFBOcVxuamJmNWdZS1ZBZ2VkMVRsRFBNak1QUkdkVXZvakYr Q1UzaDEwS1V4djQzZU9Uc3JyaWh4WnA5cW8rWkFKXG5tcGRQUHBBdFJaZ2tQ ZDlMWXhuRmI3TEZ2cFhKUERHcG4wdEhJUUNDK25NSFR6MEJ5WGJTWVNUL3Fs cEJcbjdKSWZQWURqbm1oMHV2K2xYeXpDSUtLcVVuM2s4Vzk2Si9NUFgrQi80 cm9YSmFwZ2UvRHlmT1JZeDAwZlxuSHVZWS9MUjVSRURVN2xhS21Jdml4RmdW bE5iU1JyM2I4dzQyUUJDbUlTc1VoWXp6bEljZFlWVkhEK2JxXG5WMFQ2U1lz eE1RbHpXcStUQXdLbFY0MVVlUC9tNGloclNwdEhMVEltMlZUSGFRYUVNMytR dWh4OGhXUGNcbkhOV2tGOGtiK0hGQWUxL2piWVZuVDlvRWc0ZFBpZExROGVK NFk0OFpBSldNZGxHU2g2a2hiTWpLcnpKU1xuMGwzaWdtMnRNcENDSUNCS3Jj Y1ZXMkY1UDV1bms4WDBhYmpLXG4iLCJrZXkiOiJuQXh4OXVGZXhraU5Helgw YzloQzR1aXI0aHZ1TUx3TVB1bDU3MGdYZkNDZXgveGxjTWFaandpL1RndUNc bnZKZGIxeWNTZ2xGQWlUWWRFN1Vrb3QzbnFLbCtlY0w5Uk5PMkc2dU51dWd5 VFg3NWxrdWh1YVJyKzFkVFxuR2dEQitQRWwwbzhtTDR1eVNydTNLcy9XZkdT V1AveDZWSndkdTdUakErUXlxaGE2Yzk1V0d2OW51RE5NXG50aFdtN2pUWUpp OTI2eUUxTWlTcTduKzVrUDdmNHNlTGUrSi9mMU5ucUVJWDB3ejNvOVVsTmNq SVVmY1FcbjhuaHFqMHFYZ2o4Uno2UlJFV3BscW9qSkNsZGdTazVNQ2FOUXJ4 QWs0UmNkWCtBNDduR1prZ0lEMW55eFxuWVlqM1dtT1pERzBCYUVYUkJ0U0xx V25kZkRtQXl6eXRIQnVBeFp5dzN3PT1cbiIsIml2IjoiZnovdjVNSWNPelFK YjFwTGRKL3hYdz09XG4ifQ==
```

### Create new project

In order to push code to the newly created project, we need to deal with [git complaining about the self-signed certificate](https://confluence.atlassian.com/bitbucketserverkb/ssl-certificate-problem-unable-to-get-local-issuer-certificate-816521128.html).

```
git config --global http.sslVerify false
```

### Set up Kubernetes Integration

In dashboard: Administrator > Operations > Kubernetes.
Install the following components:
- Helm Tiller
- GitLab Runner

### Enable AutoDevops for the project

https://gitlab.192.168.99.100.nip.io/help/topics/autodevops/index.md

## Cleanup

```
helm delete gitlab --purge
```