#!/bin/bash

. ./scripts/setup.sh
. "env.org1.sh"

SECONDS=0
TARGET=dev-0.1


duration=$SECONDS
printf "${GREEN}$(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed.\n\n${NC}"
