FROM centos/s2i-base-centos7

# This image provides a Perl 5.24 environment you can use to run your Perl daemons.

# Image metadata
ENV PERL_VERSION=5.24 \
    PERL_SHORT_VER=524 \
    NAME=zcme-perl-daemon

ENV SUMMARY="Platform for building and running Perl $PERL_VERSION daemons" \
    DESCRIPTION="Perl $PERL_VERSION available as docker container is a base platform for \
building and running various Perl  daemons. \
Perl is a high-level programming language with roots in C, sed, awk and shell scripting. \
Perl is good at handling processes and files, and is especially good at handling text. \
Perl's hallmarks are practicality and efficiency. While it is used to do a lot of \
different things, Perl's most common applications are system administration utilities \
and web programming."

LABEL summary="$SUMMARY" \
      description="$DESCRIPTION" \
      io.k8s.description="$DESCRIPTION" \
      io.k8s.display-name="$NAME/$PERL_VERSION" \
      io.openshift.tags="builder,${NAME},${NAME}${PERL_SHORT_VER}" \
      io.openshift.s2i.scripts-url="image:///usr/libexec/s2i" \
      io.s2i.scripts-url="image:///usr/libexec/s2i" \
      name="zarfmouse/${NAME}" \
      version="$PERL_VERSION" \
      maintainer="Zach Ember <zach@ember.us>" \
      help="WRITE ME" \
      usage="s2i build <SOURCE-REPOSITORY> trac/${NAME}-${PERL_SHORT_VER}-centos7:latest <APP-NAME>"

RUN yum install -y centos-release-scl && \
    yum-config-manager --enable centos-sclo-rh-testing && \
    INSTALL_PKGS="rh-perl524 rh-perl524-perl-devel rh-perl524-perl-CPAN rh-perl524-perl-App-cpanminus" && \
    yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    yum clean all

# Copy the S2I scripts from the specific language image to $STI_SCRIPTS_PATH
COPY ./s2i/bin/ $STI_SCRIPTS_PATH

# Copy extra files to the image.
COPY ./root/ /

# In order to drop the root user, we have to make some directories world
# writeable as OpenShift default security model is to run the container under
# random UID.
RUN chown -R 1001:0 ${APP_ROOT} && chmod -R ug+rwx ${APP_ROOT} && \
    rpm-file-permissions

USER 1001

# Enable the SCL for all bash scripts.
ENV BASH_ENV=${APP_ROOT}/etc/scl_enable \
    ENV=${APP_ROOT}/etc/scl_enable \
    PROMPT_COMMAND=". ${APP_ROOT}/etc/scl_enable"

# Set the default CMD to print the usage of the language image
CMD $STI_SCRIPTS_PATH/usage