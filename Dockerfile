FROM ubuntu:xenial

#LABEL docker-bench-security="docker-bench-security"
#LABEL org.label-schema.name="docker-bench-security" \
#      org.label-schema.url="https://github.com/konstruktoid/docker-bench-security" \
#      org.label-schema.vcs-url="https://github.com/konstruktoid/docker-bench-security.git"

RUN \
    apt-get update && \
    apt-get -y upgrade && \
    apt-get -y install auditd ca-certificates docker.io gawk iproute2 procps --no-install-recommends && \
   apt-get -y install jq && \
   apt-get install -y python && \
   apt-get install --yes libopenscap8 && \
    apt-get -y clean && \
    apt-get -y autoremove && \
    true

#   rm -rf /var/lib/apt/lists/* \
#     /usr/share/doc /usr/share/doc-base \
#     /usr/share/man /usr/share/locale /usr/share/zoneinfo
#   apt install --yes phython-pip && \

RUN apt-get install -y wget curl

# JIC: install kubectl via apt. Right now we can just copy the local kubectl binary
#RUN apt-get install -y apt-transport-https ca-certificates \
#  && curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -\
#  && echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list \
#  && apt-get update \
#  && apt-get -y install kubectl

# DEBUG
#RUN apt-get install -y vim less git telnet

RUN \
   curl "https://bootstrap.pypa.io/get-pip.py" -o "get-pip.py" && \
   python get-pip.py && \
   pip install lxml

RUN mkdir /scan
WORKDIR /scan

ARG DBSDIR
COPY container_utils/run-cis-scan.sh $DBSDIR docker-bench-security/

ARG JSONDIFF
COPY container_utils/run-docker-diff.sh container_utils/diff-all-json.sh $JSONDIFF jsondiff/

ARG JSON2CSV
COPY container_utils/docker-csv-reports.sh container_utils/k8s-csv-reports.sh $JSON2CSV json2csv/
COPY container_utils/csv_files/* json2csv/

ARG OPENSCAP
COPY container_utils/run-k8s-scan.sh $OPENSCAP/scap-content openscap/
#RUN mkdir -p openscap/results
COPY $OPENSCAP/scap-content/mirantis/cpe /usr/share/openscap/cpe

ARG XCCDF2JSON
COPY container_utils/xccdf2json.sh $XCCDF2JSON xmlutils.py/

COPY container_utils/run-scan.sh .

ENTRYPOINT ["/scan/run-scan.sh"]
CMD ["-dm"]
