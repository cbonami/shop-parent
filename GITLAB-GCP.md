# GitLab on GCP

## Install GitLab

### Prepare a domain

I partially followed [these deprecated instructions](https://about.gitlab.com/handbook/marketing/product-marketing/demo/gke-setup/), to set up a domain, get a fixed ip, and link the domain to the fixed ip using Google Cloud DNS.

Register a domain using [namecheap service](www.namecheap.com) or equivalent service.
Make NS Records for 3 'hosts' (gitlab, registry, minio).
Google Cloud DNS provided the values; in my case:
* ns-cloud-d1.googledomains.com.
* ns-cloud-d1.googledomains.com.
* ns-cloud-d1.googledomains.com.
* ns-cloud-d1.googledomains.com.

So make 4 * 3 = 12 NS Records.
Make sure email forwarding is also set up (admin@edonis.club forwards to my private email address cbonami@gmail.com)

### Stand up a GCE Kubernetes Cluster

https://gitlab.com/charts/gitlab/blob/master/doc/cloud/gke.md

```
PROJECT=refined-algebra-215620 REGION=europe-west1 ZONE=europe-west1-b ./scripts/gke_bootstrap_script.sh up
```

### Install GitLab on the k8s cluster

https://gitlab.com/charts/gitlab/blob/master/doc/installation/README.md

```
helm upgrade --install gitlab gitlab/gitlab \
  --timeout 600 \
  --set global.hosts.domain=edonis.club \
  --set global.hosts.externalIP=35.241.129.159 \
  --set certmanager-issuer.email=admin@edonis.club
```

Recover the generated root-password like this:

```
kubectl get secret gitlab-gitlab-initial-root-password -ojsonpath={.data.password} | base64 --decode ; echo
```

Then log in to the gitlab dashboard [https://gitlab.edonis.club](https://gitlab.edonis.club)

u: root
pw: <the password>

## Configure GitLab

git-push or import a repo (code) into GitLab. This is the code that you will build, test and deploy.

Based on [this tutorial about GitLab on EKS](https://gitlab.edonis.club/help/user/project/clusters/eks_and_gitlab/index.md)
we have to disable RBAC, as it is [not supported yet in combination with AutoDevops](https://gitlab.com/groups/gitlab-org/-/epics/136).

```
kubectl create clusterrolebinding permissive-binding \
  --clusterrole=cluster-admin \
  --user=admin \
  --user=kubelet \
  --group=system:serviceaccounts
```

Retrieve the address of the k8s cluster by peeking into ~/.kube/config

E.g.: https://35.187.23.37

A valid Kubernetes certificate and token are needed to authenticate to the EKS cluster. A pair is created by default, which can be used.
Retrieve the certificates and token like this:

* List the secrets with `kubectl get secrets`, and one should named similar to default-token-xxxxx. Copy that token name for use below.
* Get the certificate with `kubectl get secret <secret name> -o jsonpath="{['data']['ca\.crt']}" | base64 -d`
* Retrieve the token with `kubectl get secret <secret name> -o jsonpath="{['data']['token']}" | base64 -d`.

You now have all the information needed to connect the EKS cluster:

* Kubernetes cluster name: Provide a name for the cluster to identify it within GitLab.
* Environment scope: Leave this as * for now, since we are only connecting a single cluster.
* API URL: Paste in the API server endpoint retrieved above.
* CA Certificate: Paste the certificate data from the earlier step, as-is.
* Paste the token value. Note on some versions of Kubernetes a trailing % is output, do not include it.
* Project namespace: This can be left blank to accept the default namespace, based on the project name.

After you registered the Kubernetes cluster, you need to install the following services:

* Helm/Tiller
* Nginx
* GitLab Runner -- plz note that I had to disable (pause or delete) the gitlab-runner that came pre-installed, as it tries to pull images from localhost, instead of registry.edonis.club

Enable AutoDevops for your project. The CI/CD pipeline is automatically created and started.

GitLab AutoDevops ref documentation [here](https://docs.gitlab.com/ee/topics/autodevops/).

### Installing new gitlab-runner

https://docs.gitlab.com/ee/install/kubernetes/gitlab_runner_chart.html
https://gitlab.com/charts/gitlab-runner

Make sure you have right values in values.yaml: 

* gitlab; eg: https://gitlab.edonis.club/
* registration token; see CI/CD Runners settings; https://gitlab.edonis.club/root/stockmanager/settings/ci_cd#js-runners-settings
* privileged=true

### Varia

#### Delete Helm Release

The (spring boot) app is deployed as a chart via helm, in a namespace named after the app; if you want to remove it for some reason (eg: a crash-loop), you do this:

```
$ helm list --tiller-namespace stockmanager-1
NAME    REVISION        UPDATED                         STATUS          CHART                   APP VERSION     NAMESPACE
staging 7               Sat Sep 22 18:37:16 2018        DEPLOYED        auto-deploy-app-0.2.4                   stockmanager-1
$ helm delete staging --tiller-namespace stockmanager-1
```

### Issues

* [Issue with clair](https://gitlab.com/gitlab-org/gitlab-ee/issues/6636)
* using local docker cli

```
Error response from daemon: Get https://registry.edonis.club/v2/: x509: certificate is valid for ingress.local, not registry.edonis.club
```


## Links

https://github.com/boz/kail
https://medium.com/@wijnandtop/gitlabs-auto-devops-java-spring-boot-with-quality-control-to-production-in-minutes-using-7afdbc859b9a
https://sammye.rs/post/gitlab_ci_kubernetes/
https://github.com/SchweizerischeBundesbahnen/springboot-graceful-shutdown
https://about.gitlab.com/2016/10/25/gitlab-workflow-an-overview/
https://docs.gitlab.com/ee/integration/jira_development_panel.html
https://cloud.google.com/kubernetes-engine/docs/tutorials/hello-app



