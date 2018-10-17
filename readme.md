# Shop - Microservices Demo App

> Application is remotely available on [http://shop.edonis.xyz/shopfront](http://shop.edonis.xyz/shopfront); this is the version built with TRAVIS on GCP

## Building & running locally

Clone the following 4 projects, hierarchically _next_ to this (shop-parent) project:

* https://github.com/cbonami/shop-gateway
* https://github.com/cbonami/shopfront
* https://github.com/cbonami/productcatalogue
* https://github.com/cbonami/stockmanager

Add the following to your /etc/hosts file (on Windows this file can be found in §\WINDOWS\system32\drivers\etc):

```
127.0.0.1       shop-gateway
127.0.0.1       shopfront
127.0.0.1       stockmanager
127.0.0.1       productcatalogue
```

In all of the 4 (sub-)projects, run the following:

```
mvn spring-boot:run
```

Point your browser to [http://localhost:8080/shopfront](http://localhost:8080/shopfront)

## Building with Travis & running on GCP

Documented [here](./TRAVIS.md).

## Building with GitLab AutoDevops & running on GCP

Documented [here](./GITLAB-GCP.md).
