# Shop Parent Project

## General

Reference app demonstrating microservices approach on OpenShift.

## Stand up a Minishift Cluster

```bash
$ minishift config set cpus 6
$ minishift config set memory 16g
$ minishift config set vm-driver virtualbox
$ minishift start
```

## Install GitLab

```bash
$ oc login -u system:admin
$ oc create -f  https://gitlab.com/gitlab-org/omnibus-gitlab/raw/master/docker/openshift-template.json -n openshift
$ oc new-app gitlab
```

Apply workaround [permissions problem](https://blog.openshift.com/getting-any-docker-image-running-in-your-own-openshift-cluster/)

```bash
$ oc project gitlab
$ oc adm policy add-scc-to-user anyuid -z gitlab-ce-user
```

Apply workaround [for this bug](https://gitlab.com/gitlab-org/omnibus-gitlab/issues/3087#note_66022563)

```bash
$ oc debug dc/gitlab-ce
...
# chown git /gitlab-data
```

In the OpenShift UI, create gitlab-app using the imported template 'gitlab-ce'. 
Name the app 'gitlab'.

Domain name: gitlab-ce-gitlab.192.168.99.100.nip.io
Of course, the IP-part needs to be adapted to the IP of VirtualBox on your host machine.

In the OpenShift UI, beef up the timeout settings on the health checks, so that OpenShift doesn't think the pod is unresponsive while it's still starting.
DeploymentConfig 'gitlab-ce' > Actions > Edit Health Checks
* Readiness Probe: 
    * Initial Delay : 28
    * Timeout: 2
* Liveness Probe:
    * Initial Delay : 240
    * Timeout: 2
    
Login using _root_ as username and providing the password you just set, and start using GitLab!

Optional: Make sure your local helm CLI works:

```bash
$ oc login ...
$ helm init
$ kubectl create clusterrolebinding add-on-cluster-admin --clusterrole=cluster-admin --serviceaccount=kube-system:default
$ helm ls
```

## Integrate GitLab with Minishift

Make a project and a serviceaccount that will be used by gitlab:

```bash
$ oc new-project gitlab-managed-apps
$ oc create serviceaccount gitlab-robot
$ oc policy add-role-to-user admin system:serviceaccount:gitlab-managed-apps:gitlab-robot
$ oc serviceaccounts get-token gitlab-robot
```

Use the token later in the GitLab UI while integrating with Kubernetes.

Avoid permission problems with images wanting elevated access:

```bash
$ oc adm policy add-scc-to-user anyuid -z default
$ oc adm policy add-scc-to-user anyuid -z deployer
$ oc adm policy add-scc-to-user anyuid -z builder
$ oc adm policy add-scc-to-user anyuid -z gitlab-robot
# this one is definitely needed to avoid: "Privileged containers are not allowed" when starting pipeline
$ oc adm policy add-scc-to-user privileged -z default
```

The above set of permissions is of course way to wild, so don't do this in prod :-)

Countermeasure [another permission issue](https://gitlab.com/gitlab-org/gitlab-ce/issues/46969):

```bash
$ kubectl create clusterrolebinding --user system:serviceaccount:gitlab-managed-apps:default default-gitlab-sa-admin --clusterrole cluster-admin
```

Get the CA certificate. Use the 2nd certificate displayed by the following command:

```bash
$ openssl s_client -connect 192.168.99.100:8443 -showcerts
```

Create a project (repo) in GitLab.
Git-push your project into GitLab repo.
Enable AutoDevops: 

Use GitLab UI to set up the kubernetes integration: Administrator > Operations > Kubernetes.
Install the following components:
- Helm Tiller
- GitLab Runner
 
Make sure you have some working docker hub credentials in the [environment variables of the project](https://docs.gitlab.com/ee/ci/variables/#variables) in the CI/CD pipeline.

* CI_REGISTRY_USER = cbonami
* CI_REGISTRY_PASSWORD = xxxxxxxxxx

Fyi, [this](https://github.com/gitlabhq/gitlabhq/blob/master/vendor/gitlab-ci-yml/Auto-DevOps.gitlab-ci.yml) is the gitlab-ci.yml that is run by AutoDevops




## 

https://forum.gitlab.com/t/auto-devops-in-kubernetes-invalid-reference-format/11387/2

    
## Links

* [Deploy from GitLab to an OpenShift container cluster](https://about.gitlab.com/2017/05/16/devops-containers-gitlab-openshift/)
* [How to install GitLab on OpenShift](https://docs.gitlab.com/ee/install/openshift_and_gitlab/index.html)
* [Integrating OpenSHift GitLab](https://www.okiok.com/integrating-openshift-gitlab/)
* [Service Accounts & SCCs](https://blog.openshift.com/understanding-service-accounts-sccs/)

https://gitlab.com/gitlab-org/gitlab-ce/issues/39760
https://github.com/gitlabhq/gitlabhq/blob/master/vendor/gitlab-ci-yml/Auto-DevOps.gitlab-ci.yml
https://about.gitlab.com/2018/09/03/how-gitlab-ci-compares-with-the-three-variants-of-jenkins/
https://docs.gitlab.com/ee/administration/container_registry.html#enable-the-container-registry


