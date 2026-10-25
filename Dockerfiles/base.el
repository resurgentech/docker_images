ARG BASE_IMAGE
FROM ${BASE_IMAGE}

# Update basic system packages (EL9 and later)
RUN dnf clean all && \
    dnf update -y && \
    dnf install -y epel-release && \
    dnf install -y dnf-plugins-core && \
    dnf config-manager --set-enabled crb && \
    dnf install -y git && \
    dnf install -y ansible-core && \
    rpm --import https://www.elrepo.org/RPM-GPG-KEY-v2-elrepo.org && \
    el=$(rpm -E %rhel) && \
    dnf install -y https://www.elrepo.org/elrepo-release-${el}.el${el}.elrepo.noarch.rpm && \
    dnf clean all && \
    rm -rf /var/cache/yum

ARG ORG IMAGE BASE_IMAGE CREATED GIT_URL GIT_SHA
RUN --mount=type=bind,source=scripts/image-history.sh,target=/tmp/image-history.sh \
    sh /tmp/image-history.sh
