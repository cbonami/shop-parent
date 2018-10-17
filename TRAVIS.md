# Shop Microservices Demo App

Set of a couple of sample microservices, and a frontend app (BE4FE), all wired together via [Spring Cloud Gateway](https://cloud.spring.io/spring-cloud-gateway/).

## Create a Kubernetes Cluster on GCP/GCE

Make a project on GCP. You can do this with the [GCP dashboard](https://console.cloud.google.com/home/dashboard).
Note down the generated id of the project (in my case 'refined-algebra-215620').

Create a Kubernetes cluster.

Travis CI (see later) will access and operate under the restrictions of a service account on the k8s cluster.
So we need to [make a service account on GCP](https://developers.google.com/identity/protocols/OAuth2ServiceAccount#creatinganaccount): 
* Google Cloud Dashboard > IAM > Service Accounts > Add
Service Account Name: travisci
Roles:
* Project > Edit (these rights are quiet elevated, but I guess this is okay for demo purposes)
* Storage Admin (not sure if this is really needed)
Make note of sa's email: travisci@...
Make sure you download the private/public key-pair as a json-file (see [gcloud.json](../shop-gateway/gcloud.json)).

Instead, you could also use commandline (I did not get this working yet):

```
gcloud projects add-iam-policy-binding shop -- member serviceAccount:travisci@refined-algebra-215620.iam.gserviceaccount.com -- role roles/storage.admin
```

## Reserve a domain name

I used namecheap.com to register a domain 'edonis.xyz'.

Make NS Records for 'host' named 'shop'. In my case, this means that the final application will be available on 'shop.edonis.xyz'.
[Google Cloud DNS](https://console.cloud.google.com/net-services/dns/zones) provided the values; they are typically:

* ns-cloud-d1.googledomains.com.
* ns-cloud-d1.googledomains.com.
* ns-cloud-d1.googledomains.com.
* ns-cloud-d1.googledomains.com.

## Deploy GCE Ingress

[Inspired by this post](https://cloud.google.com/community/tutorials/nginx-ingress-gke)

Deploy tiller with RBAC enabled:

```
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'  
helm init --service-account tiller --upgrade
```

Deploy NGINX Controller with RBAC enabled:

```
helm install --name nginx-ingress stable/nginx-ingress --set rbac.create=true
```

Check if ingress-controller has been deployed well:
 
```
$ kubectl describe service/nginx-ingress-controller
Name:                     nginx-ingress-controller
Namespace:                default
Labels:                   app=nginx-ingress
                          chart=nginx-ingress-0.28.2
                          component=controller
                          heritage=Tiller
                          release=nginx-ingress
Annotations:              <none>
Selector:                 app=nginx-ingress,component=controller,release=nginx-ingress
Type:                     LoadBalancer
IP:                       10.51.241.52
LoadBalancer Ingress:     35.233.125.101
Port:                     http  80/TCP
TargetPort:               http/TCP
NodePort:                 http  30924/TCP
Endpoints:                10.48.0.9:80
Port:                     https  443/TCP
TargetPort:               https/TCP
NodePort:                 https  31324/TCP
Endpoints:                10.48.0.9:443
Session Affinity:         None
External Traffic Policy:  Cluster
Events:                   <none>
```

The LoadBalancer Ingress basically gives you the IP on which the app, after it has been deployed, will be available on the internet. 
And then the ingress-controller will internally fetch the routing rules from the deployed [ingress-resource](../shop-gateway/k8s/shop-gateway.yml).

## Travis

[Inspired by this post](http://thylong.com/ci/2016/deploying-from-travis-to-gce/)

Set some env variables needed by the Travis build (see .travis.yml > env.global.secure):

```
travis login --pro
travis encrypt GKE_USERNAME=cbonami@gmail.com --add --com
```

... and/or set the env vars via 'Travis project settings': 

* GCLOUD_EMAIL: travisci@refined-algebra-215620.iam.gserviceaccount.com
* CLOUDSDK_CORE_PROJECT: your gcloud project id; eg: refined-algebra-215620
* CLOUDSDK_COMPUTE_ZONE: europe-west1-b	
* GKE_SERVER: the cluster IP: eg: 35.205.224.241
* MICROSERVICE_NAME: shop-gateway

Travis will
* build and test the app
* build a docker container and upload it to GCE Registry
* deploy the app in k8s - see [manifest file containing the service, replication controller and ingress resource](../shop-gateway/k8s/shop-gateway.yml)
 
After the deployment, wail till the ingress resource receives an address (ip):

```
vagrant@ubuntu-xenial:/vagrant/shop-gl/shop-gateway$ kubectl get ingress
NAME                            HOSTS     ADDRESS        PORTS     AGE
shop-gateway-ingress-resource   *         104.155.6.44   80        3m
```

Check if gateway-app is available by pointing your browser to [http://<loadbalancer-ip>/actuator/health](http://35.233.125.101/actuator/health).

## Create a NS Record

Create a NS Record for the subdomain 'shop' (or something else) in namecheap.com.

## Varia

Base64 encoding:
```
cat project-shop-gateway.json | base64 > base64
```

## Links

* [Spring Cloud Gateway - Baeldung](https://www.baeldung.com/spring-cloud-gateway)
* [Spring Cloud Gateway - Routing Example](https://stackoverflow.com/questions/48865174/spring-cloud-gateway-proxy-forward-the-entire-sub-part-of-url)
* [Deploying from Travis to GCE](http://thylong.com/ci/2016/deploying-from-travis-to-gce/)

https://stackoverflow.com/questions/29045140/env-bash-r-no-such-file-or-directory
```
git config --global core.autocrlf false
```

## Todo

* Fix base64-encoded gcloud.json
* TLS on nginx