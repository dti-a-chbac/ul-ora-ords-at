# Installation de Oracle Rest Data Services sous Redhat Openshift

## Descriptions

   

## Transfert d'une applications sous Docker vers Redhat Openshift
### Transfert d'un image docker vers le registre d'openshift
#### Accès au systèmes Openshift
```bash
$ oc login api.ul-pca-pr-ul01.ulaval.ca:6443 -u dti-a-idul
$ oc project ul-ora-ords-at
```
#### Voir l'image
```bash
$ docker image ls ords

REPOSITORY   TAG       IMAGE ID       CREATED        SIZE
ords         latest    4954003ff068   17 hours ago   480MB
```

#### Préparé l'image pour le registre d'Openshift
```bash
$ docker tag $(docker image ls ords -q) registre.apps.ul-pca-pr-ul01.ulaval.ca:443/ul-ora-ords-at/ords
$ docker image ls | grep ords

ords                                                             latest        4954003ff068   17 hours ago    480MB
registre.apps.ul-pca-pr-ul01.ulaval.ca:443/ul-ora-ords-at/ords   latest        4954003ff068   17 hours ago    480MB

```
#### Se logger sur le registre d'Openshift et transférer l'image
```bash
$ docker login -p $(oc whoami -t) -u $(oc whoami) registre.apps.ul-pca-pr-ul01.ulaval.ca:443
$ docker push registre.apps.ul-pca-pr-ul01.ulaval.ca:443/ul-ora-ords-at/ords
Using default tag: latest
The push refers to repository [registre.apps.ul-pca-pr-ul01.ulaval.ca:443/ul-ora-ords-at/ords]
cd224ea90c68: Pushed
6535d1b7210c: Pushed
6607c57525cf: Pushed
0b1125224454: Pushed
5a7e7a880634: Pushed
3dccaa93bb0e: Pushed
5c384ea5f752: Pushed
293d5db30c9f: Pushed
03127cdb479b: Pushed
9c742cd6c7a5: Pushed
latest: digest: sha256:28d3f9072f6cc37f938c50b723bfb9c2cfdaaacdbb9c7678b24b6f9cb969ef45 size: 2420
```

#### Liste des images dans le projet UL-ORA-ORDS-AT
```bash
$ oc get imagestream

NAME             IMAGE REPOSITORY                                                       TAGS     UPDATED
ords             registre.apps.ul-pca-pr-ul01.ulaval.ca/ul-ora-ords-at/ords             latest   About a minute ago
ul-ora-ords-at   registre.apps.ul-pca-pr-ul01.ulaval.ca/ul-ora-ords-at/ul-ora-ords-at   latest   15 hours ago
```
#### Création d'une application à partir d'une image 
```
oc new-app ul-ora-ords-at/ords --name=ords
```

## Additional resources
* For more information about devfiles, see [Devfile.io](https://devfile.io/).
* Info : [Create devfiles](https://devfile.io/docs/2.2.2/create-devfiles)
* For more information about Dockerfiles, see [Dockerfile reference](https://docs.docker.com/engine/reference/builder/).
  
### Notes
Before you begin creating an application with this `devfile` code sample, it's helpful to understand the relationship between the `devfile` and `Dockerfile` and how they contribute to your build. You can find these files at the following URLs:

* [`devfile.yaml`](https://github.com/devfile-samples/devfile-sample-python-basic/blob/main/devfile.yaml)
* [`Dockerfile`](https://github.com/devfile-samples/devfile-sample-python-basic/blob/main/docker/Dockerfile)

1. The `devfile.yaml` file has an [`image-build` component](https://github.com/devfile-samples/devfile-sample-python-basic/blob/main/devfile.yaml#L24-L30) that points to your `Dockerfile`.
2. The [`docker/Dockerfile`](https://github.com/devfile-samples/devfile-sample-python-basic/blob/main/docker/Dockerfile) contains the instructions you need to build the code sample as a container image.
3. The `devfile.yaml` [`kubernetes-deploy` component](https://github.com/devfile-samples/devfile-sample-python-basic/blob/main/devfile.yaml#L31-L44) points to a `deploy.yaml` file that contains instructions for deploying the built container image.
4. The `devfile.yaml` [`deploy` command](https://github.com/devfile-samples/devfile-sample-python-basic/blob/main/devfile.yaml#L46-L59) completes the [outerloop](https://devfile.io/docs/2.2.0/innerloop-vs-outerloop) deployment phase by pointing to the `image-build` and `kubernetes-deploy` components to create your application.

