#/usr/bin/env bash

# Get the region list
export REGIONS=$(aws ec2 describe-regions | jq -r ".Regions[].RegionName")

read -p "Do you want to delete the default VPC from all the AWS regions [Y/N]? "

if [[ $REPLY =~ ^[Yy]$ ]]
then
    for region in $REGIONS ; do
        echo "Deleting default VPC from the  $region"
        # list vpcs
        export IDs=$(aws --region=$region ec2 describe-vpcs | jq -r ".Vpcs[]|{is_default: .IsDefault, id: .VpcId} | select(.is_default) | .id")
        for id in "$IDs" ; do
            # check if id is not empty or default vpc exisits 
            if [ -z "$id" ] ; then
                continue
            fi

            # deleteing igws
            for igw in `aws --region=$region ec2 describe-internet-gateways | jq -r ".InternetGateways[] | {id: .InternetGatewayId, vpc: .Attachments[0].VpcId} | select(.vpc == \"$id\") | .id"` ; do
                echo "Deleting igw $region $id $igw"
                aws --region=$region ec2 detach-internet-gateway --internet-gateway-id=$igw --vpc-id=$id
                aws --region=$region ec2 delete-internet-gateway --internet-gateway-id=$igw
            done

            # Deleting subnets
            for sub in `aws --region=$region ec2 describe-subnets | jq -r ".Subnets[] | {id: .SubnetId, vpc: .VpcId} | select(.vpc == \"$id\") | .id"` ; do
                echo "Deleting subnet $region $id $sub"
                aws --region=$region ec2 delete-subnet --subnet-id=$sub
            done

            echo "Deleteing vpc $region $id"
            aws --region=$region ec2 delete-vpc --vpc-id=$id
        done
    done
fi