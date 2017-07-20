#!/bin/bash -e

###
### TODO: Now that initial Azure support is included, need to make a pass through and globalize
###       certain variables, Region has already been done, however I think there are others that 
###       could be done. Refactoring will also be necessary, there is a lot of duplication being
###       done in the file.
###

echo ' 
      ###    ########   #######  ########  
     ## ##   ##     ## ##     ## ##     ## 
    ##   ##  ##     ## ##     ## ##     ## 
   ##     ## ##     ## ##     ## ########  
   ######### ##     ## ##     ## ##        
   ##     ## ##     ## ##     ## ##        
   ##     ## ########   #######  ##        
'

usage(){
   cat <<END_USAGE

Usage:
        ./quickstart.sh 
	    -t local 
	    [-m <MACHINE_NAME>] 
	    [-u <INITIAL_ADMIN_USER>] 
	    [-p <INITIAL_ADMIN_PASSWORD>]

        ./quickstart.sh 
	    -t aws 
	    -m <MACHINE_NAME> 
	    -c <AWS_VPC_ID> 
	    -r <DEFAULT_REGION> 
	    [-z <AVAILABILITY_ZONE_LETTER>] 
	    [-a <AWS_ACCESS_KEY>] 
	    [-s <AWS_SECRET_ACCESS_KEY>] 
	    [-u <INITIAL_ADMIN_USER>] 
	    [-p <INITIAL_ADMIN_PASSWORD>]

        ./quickstart.sh 
	    -t azure 
	    -m <MACHINE_NAME> 
	    -r <DEFAULT_REGION> 
	    [-u <INITIAL_ADMIN_USER>] 
	    [-p <INITIAL_ADMIN_PASSWORD>]

END_USAGE
}

provision_local() {
    if [ -z ${MACHINE_NAME} ]; then
        MACHINE_NAME=adop
    fi

    # Allow script to continue if error returned by docker-machine command
    set +e

    # Create Docker machine if one doesn't already exist with the same name
    docker-machine ip ${MACHINE_NAME} > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "Docker machine '$MACHINE_NAME' already exists"
    else
	# To run adop stack locally atleast 6144 MB is required.
        docker-machine create --driver virtualbox --virtualbox-memory 6144 ${MACHINE_NAME}
    fi

    # Reenable errexit
    set -e

}
    
# Function to create AWS-specific environment variables file
source_aws() {  
  AWS_FILE='./conf/provider/env.provider.aws.sh'

  if [ -f ${AWS_FILE} ]; then  
    echo "Your AWS parameters file already exists, deleting it..."
    rm -f ${AWS_FILE}
  fi
    
  echo "Creating a new AWS variables file..."
  cp ./conf/provider/examples/env.provider.aws.sh.example ${AWS_FILE}

  # AWS-specific environment variables
  if [ -z ${AWS_VPC_ID} ]; then
    usage
    exit 1
  else    
    sed -i'' -e "s/###AWS_VPC_ID###/$AWS_VPC_ID/g" ${AWS_FILE}
  fi

  if [ -z ${AWS_KEYPAIR} ]; then
    sed -i'' -e "s/###AWS_KEYPAIR###/$MACHINE_NAME/g" ${AWS_FILE}
  else
    sed -i'' -e "s/###AWS_KEYPAIR###/$AWS_KEYPAIR/g" ${AWS_FILE}
  fi

  if [ -z ${AWS_INSTANCE_TYPE} ]; then
    sed -i'' -e "s/###AWS_INSTANCE_TYPE###/t2.large/g" ${AWS_FILE}
  else
    sed -i'' -e "s/###AWS_INSTANCE_TYPE###/$AWS_INSTANCE_TYPE/g" ${AWS_FILE}
  fi

  if [ -z ${AWS_SUBNET_ID} ]; then
    sed -i'' -e "s/###AWS_SUBNET_ID###/default/g" ${AWS_FILE}
  else
    sed -i'' -e "s/###AWS_SUBNET_ID###/$AWS_SUBNET_ID/g" ${AWS_FILE}
  fi
  
  sed -i'' -e "s/###DEFAULT_REGION###/$DEFAULT_REGION/g" ${AWS_FILE}

}

provision_aws() {
    if [ -z ${MACHINE_NAME} ] | \
       [ -z ${AWS_VPC_ID} ] | \
       [ -z ${DEFAULT_REGION} ]; then
        echo "ERROR: Mandatory parameters missing!"
        usage
        exit 1
    fi

    if [ -z ${VPC_AVAIL_ZONE} ]; then
        echo "No availability zone specified - using default [a]."
        export VPC_AVAIL_ZONE=a
    elif [[ ! ${VPC_AVAIL_ZONE} =~ ^[a-e]{1,1}$ ]]; then
            echo "Availability zone can only be a single lower case char, 'a' to 'e'. Exiting..."
            exit 1
    fi

    if [ -z ${AWS_ACCESS_KEY_ID} ];
    then
      echo "WARN: AWS_ACCESS_KEY_ID not set (externally or with -a), delegating to Docker Machine"
    fi

    if [ -z ${AWS_SECRET_ACCESS_KEY} ];
    then
      echo "WARN: AWS_SECRET_ACCESS_KEY not set (externally or with -s), delegating to Docker Machine"
    fi
    
    if [ -z ${AWS_DOCKER_MACHINE_SIZE} ]; then
    	export AWS_DOCKER_MACHINE_SIZE="m4.xlarge"
    fi

    # Create a file with AWS parameters
    source_aws

    # Allow script to continue if error returned by docker-machine command
    set +e

    # Create Docker machine if one doesn't already exist with the same name
    docker-machine ip ${MACHINE_NAME} > /dev/null 2>&1
    rc=$?
    
    # Reenable errexit
    set -e
    
    if [ ${rc} -eq 0 ]; then
        echo "Docker machine '$MACHINE_NAME' already exists"
    else
        MACHINE_CREATE_CMD="docker-machine create \
                    --driver amazonec2 \
                    --amazonec2-vpc-id ${AWS_VPC_ID} \
                    --amazonec2-zone $VPC_AVAIL_ZONE \
                    --amazonec2-instance-type ${AWS_DOCKER_MACHINE_SIZE} \
                    --amazonec2-root-size ${AWS_ROOT_SIZE:-32}"

        if [ -n "${AWS_ACCESS_KEY_ID}" ] && [ -n "${AWS_SECRET_ACCESS_KEY}" ] && [ -n "${DEFAULT_REGION}" ]; then
            MACHINE_CREATE_CMD="${MACHINE_CREATE_CMD} \
                        --amazonec2-access-key ${AWS_ACCESS_KEY_ID} \
                        --amazonec2-secret-key ${AWS_SECRET_ACCESS_KEY} \
                        --amazonec2-region ${DEFAULT_REGION}"
        fi

        MACHINE_CREATE_CMD="${MACHINE_CREATE_CMD} ${MACHINE_NAME}"
        ${MACHINE_CREATE_CMD}
    fi
}

# Function to create Azure-specific environment variables file
source_azure() {  
  # TODO: Update to Azure specific information
  # This currently isn't being used in anyway, need to determine if it's necessary
  AWS_FILE='./conf/provider/env.provider.azure.sh'

  if [ -f ${AZURE_FILE} ]; then  
    echo "Your AZURE parameters file already exists, deleting it..."
    rm -f ${AZURE_FILE}
  fi
    
  echo "Creating a new AZURE variables file..."
  cp ./conf/provider/examples/env.provider.AZURE.sh.example ${AZURE_FILE}

  # AZURE-specific environment variables
  if [ -z ${AZURE_VPC_ID} ]; then
    usage
    exit 1
  else    
    sed -i'' -e "s/###AZURE_VPC_ID###/$AZURE_VPC_ID/g" ${AZURE_FILE}
  fi

  if [ -z ${AZURE_KEYPAIR} ]; then
    sed -i'' -e "s/###AZURE_KEYPAIR###/$MACHINE_NAME/g" ${AZURE_FILE}
  else
    sed -i'' -e "s/###AZURE_KEYPAIR###/$AZURE_KEYPAIR/g" ${AZURE_FILE}
  fi

  if [ -z ${AZURE_INSTANCE_TYPE} ]; then
    sed -i'' -e "s/###AZURE_INSTANCE_TYPE###/t2.large/g" ${AZURE_FILE}
  else
    sed -i'' -e "s/###AZURE_INSTANCE_TYPE###/$AZURE_INSTANCE_TYPE/g" ${AZURE_FILE}
  fi

  if [ -z ${AZURE_SUBNET_ID} ]; then
    sed -i'' -e "s/###AZURE_SUBNET_ID###/default/g" ${AZURE_FILE}
  else
    sed -i'' -e "s/###AZURE_SUBNET_ID###/$AZURE_SUBNET_ID/g" ${AZURE_FILE}
  fi
  
  sed -i'' -e "s/###DEFAULT_REGION###/$DEFAULT_REGION/g" ${AZURE_FILE}

}

provision_azure() {
  # Very basic right now, no way to change certain values, unless variables are pre-exported
  # into the environment. Definite opportunities for updates and making things smarter.
    if [ -z ${MACHINE_NAME} ] | \
       [ -z ${AZURE_SUB_ID} ] | \
       [ -z ${DEFAULT_REGION} ]; then
        echo "ERROR: Mandatory parameters missing!"
        usage
        exit 1
    fi

    if [ -z ${AZURE_DOCKER_MACHINE_SIZE} ]; then
    	export AZURE_DOCKER_MACHINE_SIZE="Standard_D5_v2"
    fi

    if [ -z ${AZURE_IMAGE} ]; then
      export AZURE_IMAGE="canonical:UbuntuServer:16.04.0-LTS:latest"
    fi

    # Create a file with AZURE parameters
    # source_azure

    # Allow script to continue if error returned by docker-machine command
    set +e

    # Create Docker machine if one doesn't already exist with the same name
    docker-machine ip ${MACHINE_NAME} > /dev/null 2>&1
    rc=$?
    
    # Reenable errexit
    set -e
    
    if [ ${rc} -eq 0 ]; then
        echo "Docker machine '$MACHINE_NAME' already exists"
    else
        MACHINE_CREATE_CMD="docker-machine create \
                    --driver azure \
                    --azure-subscription-id ${AZURE_SUB_ID} \
                    --azure-image ${AZURE_IMAGE} \
                    --azure-location ${DEFAULT_REGION} \
                    --azure-size ${AZURE_DOCKER_MACHINE_SIZE} \
                    --azure-open-port 80 \
                    --azure-open-port 443 \
                    --engine-install-url=https://web.archive.org/web/20170623081500/https://get.docker.com"

        MACHINE_CREATE_CMD="${MACHINE_CREATE_CMD} ${MACHINE_NAME}"
        echo ${MACHINE_CREATE_CMD}
        ${MACHINE_CREATE_CMD}
    fi
}

while getopts "t:m:a:s:c:z:r:u:p:" opt; do
  case ${opt} in
    t)
      export MACHINE_TYPE=${OPTARG}
      ;;
    m)
      export MACHINE_NAME=${OPTARG}
      ;;
    a)
      export AWS_ACCESS_KEY_ID=${OPTARG}
      ;;
    s)
      export AWS_SECRET_ACCESS_KEY=${OPTARG}
      ;;
    c)
      export AWS_VPC_ID=${OPTARG}
      ;;
    z)
      export VPC_AVAIL_ZONE=${OPTARG}
      ;;
    r)
      export DEFAULT_REGION=${OPTARG}
      ;;
    u)
      export INITIAL_ADMIN_USER=${OPTARG}
      ;;
    p)
      export INITIAL_ADMIN_PASSWORD_PLAIN=${OPTARG}
      ;;      
    *)
      echo "Invalid parameter(s) or option(s)."
      usage
      exit 1
      ;;
  esac
done

if [ -z ${MACHINE_TYPE} ]; then
    echo "Please specify a machine type to create during quickstart"
    usage
    exit 1
fi

CLI_COMPOSE_OPTS=""

# Switch based on the machine type
case ${MACHINE_TYPE} in
    "local")
        provision_local
        ;;
    "aws")
        provision_aws
        CLI_COMPOSE_OPTS="-f etc/aws/default.yml"
        ;;
    "azure")
        provision_azure
        ;;
    *)
        echo "Invalid parameter(s) or option(s)."
        usage
        exit 1
        ;;
esac

# Use the ADOP CLI
eval $(docker-machine env ${MACHINE_NAME})

./adop compose -m "${MACHINE_NAME}" ${CLI_COMPOSE_OPTS} init

# Generate and export Self-Signed SSL certificate for Docker Registry, applicable only for AWS type
if [ ${MACHINE_TYPE} == "aws" ]; then
    ./adop certbot gen-export-certs "registry.$(docker-machine ip ${MACHINE_NAME}).nip.io" registry
fi
