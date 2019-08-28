#!/bin/sh
set -x
echo $@

# This script assumes the following container directory structure:
# /scan/results for all final output
# /scan/docker-bench-security
# /scan/jsondiff
# /scan/openscap

docker version

if [ $(which kubectl) ]; then
  kubectl version
fi

# Options for running various scans:
# -d : run docker-bench-security
# -m : compare /scan/results/docker with /scan/results/host (assumed to be there) for differences.
# -n : generate csv files from the docker scan
# -a : generate .csv files for the docker results
# -k : run k8s openscap scan
# -u : run ubuntu openscap scan
# -x : generate json from k8s xccdf files
while getopts ":dmbnopkxl:" opt; do
  case "${opt}" in
    d)
      DockerBench=1
      oindex=$((OPTIND-1))
      ;;
    m)
      DockerCompare=1
      oindex=$((OPTIND-1))
      ;;
    b)
      KubeCompare=1
      oindex=$((OPTIND-1))
      ;;
    n)
      DockerCSV=1
      oindex=$((OPTIND-1))
      ;;
    k)
      K8SSCAN=1
      oindex=$((OPTIND-1))
      ;;
    x)
      K8S2JSON=1
      oindex=$((OPTIND-1))
      ;;
    o)
      K8SCSV=1
      oindex=$((OPTIND-1))
      ;;
    p)
      PrevCompare=1
      oindex=$((OPTIND-1))
      ;;
    l)
      logfile=${OPTARG}
      ;;
    :)
      echo "Option $opt and -$OPTARG requires an argument." >&2
      exit 1
      ;;
    \?)
      #echo "Invalid option $opt and $OPTARG"
      ;;
  esac
done
if [ ! -z ${oindex+x} ]; then
    shift $oindex
fi

DBSArgs=$@
if [ -z ${logfile+x} ]; then
  logfile=/scan/results/docker/$HOSTNAME.log
  DBSArgs="-l $logfile $DBSArgs"
fi


if [ ! -z ${DockerBench+x} ]; then
  mkdir /scan/results/docker
  cd /scan/docker-bench-security
# ./run-cis-scan.sh -l /scan/results/docker/${HOSTNAME}.log
#    -c host_configuration,docker_daemon_configuration,docker_daemon_files,container_images,container_runtime,docker_security_operations
  ./run-cis-scan.sh $DBSArgs
fi

if [ ! -z ${DockerCompare+x} ]; then
  cd /scan/jsondiff
  ./run-docker-diff.sh $logfile /scan/results/host | tee /scan/results/diff-${HOSTNAME}-docker.json
fi

if [ ! -z ${DockerCSV+x} ]; then
  cd /scan/json2csv
  ./docker-csv-reports.sh $logfile
fi

if [ ! -z ${K8SSCAN+x} ]; then
  cd /scan/openscap
  ./run-k8s-scan.sh $(dirname $(dirname $logfile))/k8s
fi

if [ ! -z ${K8S2JSON+x} ]; then
  cd /scan/xmlutils.py
  ./xccdf2json.sh $(dirname $(dirname $logfile))/k8s
fi

if [ ! -z ${K8SCSV+x} ]; then
  cd /scan/json2csv
  ./k8s-csv-reports.sh $logfile
fi

#TODO: Turn these into hooks and put paths in a common source file
if [ ! -z ${KubeCompare+x} ]; then
  # first convert host output to json
  cd /scan/xmlutils.py
  ./xccdf2json.sh /scan/results/host/k8s

  # Perform diff
  cd /scan/jsondiff
  ./run-docker-diff.sh $logfile /scan/results/host/k8s | tee /scan/results/diff-${HOSTNAME}-k8s.json
fi

if [ ! -z ${PrevCompare+x} ]; then
  cd /scan/jsondiff
  ./diff-all-json.sh /scan/results /scan/prev_results
fi

chown -R ${TESTUID}:${TESTGID} /scan/results
