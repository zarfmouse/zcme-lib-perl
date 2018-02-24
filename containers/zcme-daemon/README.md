Building the zcme-perl-daemon Docker image
==========================================

```
make build
docker push zarfmouse/zcme-perl-daemon
```

For now, this image is hosted from the "zarfmouse" account on
docker.io.

Testing the Image Locally
=========================

macOS users must install the "coreutils" package in order to get
greadlink which is used by the `test/run` script.

```
make test
```

