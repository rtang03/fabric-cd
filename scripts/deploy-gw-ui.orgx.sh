#!/bin/bash
# $1 = n1 or n2
# $2 = org1 or org2 or org3 .... etc

. ./setup.sh
. "env.$2.sh"

SECONDS=0

set -x
argo submit -n $1 ../workflow/aoa-sync-re-au-gw-ui.$1.yaml --watch --request-timeout 300s
res=$?
set +x
printMessage "gw-org redis auth-server ui-control sync" $res

duration=$SECONDS
printf "${GREEN}$(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed.\n\n${NC}"
