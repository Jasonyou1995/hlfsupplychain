# Author:           Jason You
# Last modified:    March 6 2019
# Project:          Car Components Supply Chain
#
# SPDX-License-Identifier: Apache-2.0
#
# In this script we get enrollment certificate for organization 1 and 2


###########################################################
####################### Task 3.1 ##########################
###########################################################
###########################################################
###########################################################

# First make sure the docker-compose is up
# Second is install the app, then host the app on PORT 4000
#
# Star to requesting for enrollment
echo "POST request Enroll on Org1  ..."
echo
ORG1_TOKEN=$(curl -s -X POST \
	http://localhost:4000/users \
	-H "content-type: application/x-www-form-urlencoded" \
	-d 'username=Supplier.supplier1&orgName=Org1')
echo $ORG1_TOKEN
ORG1_TOKEN=$(echo $ORG1_TOKEN | jq ".token" | sed "s/\"//g")
echo
echo "ORG1 token is $ORG1_TOKEN"
echo
echo "POST request Enroll on Org2 ..."
echo
ORG2_TOKEN=$(curl -s -X POST \
	http://localhost:4000/users \
	-H "content-type: application/x-www-form-urlencoded" \
	-d 'username=Manufacture.manufacture1&orgName=Org2')
echo $ORG2_TOKEN
ORG2_TOKEN=$(echo $ORG2_TOKEN | jq ".token" | sed "s/\"//g")
echo
echo "ORG2 token is $ORG2_TOKEN"
echo
echo
echo "POST request Create channel  ..."
echo

###########################################################
####################### Task 3.2 ##########################
###########################################################
###########################################################
###########################################################
