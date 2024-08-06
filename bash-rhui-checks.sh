#!/bin/bash

##################################################################################
#                                                                                #
# Copyright 2020 Google Inc. All rights reserved.                                #
#                                                                                #
# Licensed under the Apache License, Version 2.0 (the "License");                #
# you may not use this file except in compliance with the License.               #
# You may obtain a copy of the License at                                        #
#                                                                                #
#     http://www.apache.org/licenses/LICENSE-2.0                                 #
#                                                                                #
# Unless required by applicable law or agreed to in writing, software            #
# distributed under the License is distributed on an "AS IS" BASIS,              #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.       #
# See the License for the specific language governing permissions and            #
# limitations under the License.                                                 #
#                                                                                #
# Author: Vinay Gahlout                                                          #
#                                                                                #
# Name: RHUI basic checks tool                                                   #
#                                                                                #
# Description: This script will help with Basic checks related to RHUI setup.    #
#                                                                                #
##################################################################################

Metadata_URL="http://169.254.169.254"

platform_get() {
    if [ -n "$1" ]; then
        platform=`echo $1`
    else
        if /usr/sbin/dmidecode | grep -qi "Google"; then 
            platform="GCP"
        elif /usr/sbin/dmidecode | grep -qi "Amazon"; then
            platform="AWS"
        elif /usr/sbin/dmidecode | grep -qi "Microsoft"; then
            platform="Azure"
        else
            platform="Unknown"
        fi
    fi
    echo "Instance is identified to be running on $platform platform"
}
platform_get

check_os_version() {
    if cat /etc/redhat-release| grep -q "Red Hat" ; then
        os_version=$(awk -F'=' '$1 == "VERSION_ID" {print $2}' /etc/os-release)
        os_major_version=$(echo "${os_version%%.*}" | tr -d '"')
        echo "OS is identified as Red Hat Enterprise Linux $os_version"
    else
        another_os=$(awk -F'=' '$1 == "NAME" {print $2}' /etc/os-release)
        echo "This script is designed only for Red Hat Enterprise Linux.\
             Current OS is $another_os, Exiting now!!"
        exit 1
    fi

}
check_os_version

licnese_check(){

    case $1 in 
        "2862452038400965874" )
            license=rhel-6-byol
            ;;
        "601259152637613565" )
            license=rhel-8-server
            ;;

    esac

}

check_metadata_connectivity() {

    if [ "$1" == "GCP" ]; then
        if curl -s "$Metadata_URL/computeMetadata/v1/instance/" \
                    -H "Metadata-Flavor: Google" | grep -q zone; then 
            echo "GCE Metadata connectivity check successful"
        else
            echo "GCE Metadata connectivity check failed!,\
                     Please check your instance health" 
        fi
    elif [ "$1" == "AWS" ]; then
        if curl -s "$Metadata_URL/latest/dynamic/instance-identity/document" |\
                                     grep -q "region"; then
            echo "AWS Metadata connectivity check successful"
        else
            echo "AWS Metadata connectivity check failed!"
            echo "Please check your instance health" 
        fi
    elif [ "$1" == "Azure" ]; then
        if curl -s "$Metadata_URL/metadata/instance?api-version=2021-02-01" \
                                    -H Metadata:true | grep -q "compute"; then
            echo "Azure Metadata connectivity check successful"
        else
            echo "Azure Metadata connectivity check failed!,\
                     Please check your instance health" 
        fi
    else
        platform="Unknown"
    fi
}
check_metadata_connectivity $platform

check_license() {
    if [ "$1" == "GCP" ]; then
        rhel_payg_licenses=" 1176308840663243801 1000002 4646774207868449156 \
                1000006 601259152637613565 7883559014960410759 "
        rhel_sap_payg_licenses=" 8555687517154622919 5955710252559838163 \
                996690525257673675 1785892118823772022 5882583258875011738 \
                1270685562947480748 8291906032809750558 "
        licenses=$(curl -s \
                "$Metadata_URL/computeMetadata/v1/instance/licenses/?recursive=true"\
                                     -H "Metadata-Flavor: Google")
        for i in $(echo "$licenses" | grep -oP '"id":"\K[^"]+');
        do
            #licnese_check $i
            #echo "License $license detected "
            if [[ "$rhel_payg_licenses " =~ " $i " ]]; then
                echo "RHEL PAYG License found. RHUI setup should work as expected"
                break
            elif [[ " $rhel_sap_payg_licenses" =~ " $i " ]]; then
                echo "RHEL-SAP PAYG License found. RHUI setup should work as expected"
                break
            else
                echo "RHEL PAYG License not found, RHUI will not work on this instance,\
                                         unless you have your own RHEL Subscription"
            fi
        done

    elif [ "$1" == "AWS" ]; then
        pass
    elif [ "$1" == "Azure" ]; then
        pass
    else
        platform="Unknown"
    fi
}
check_license $platform

check_rhui_client() {
    rhui_client_rpm=$(rpm -qa google-rhui-client-rhel$os_major_version*)
    if [ -n "$rhui_client_rpm" ]; then
        rhui_client_rpm=${rhui_client_rpm%.noarch}
        if rpm -qa --changelog google-rhui-client-rhel$os_major_version*| grep -q RHUIv4; then
            echo "The RHUI client package $rhui_client_rpm"
        else
            echo -e "Your RHUI client package $rhui_client_rpm is obsolete and not compatible with latest Redhat Update Infrastructure v4"
            echo -e "Please plan to upgrade your google-rhui-client-rhel* package to latest one using command:"
            echo -e "   sudo yum update --repo google-compute-engine google-rhui-client-rhel$os_major_version*"
        fi
    else
        echo "RHUI Client package google-rhui-client-rhel* is missing from the instance."
        echo "Please install the latest RHUI client package based on your OS and licnese."
    fi

}
#check_rhui_client

check_rhui_v4_baseurls() {
    if cat /etc/yum.repos.d/rh-cloud.repo | grep -v "^#" | grep -q "cds.rhel.updates.googlecloud.com"; then
        echo "You are still using RHUIv3 repo endpoints(https://cds.rhel.updates.googlecloud.com), which are now deprecated."
        check_rhui_client
    elif cat /etc/yum.repos.d/rh-cloud.repo | grep -v "^#" | grep -q "rhui.googlecloud.com"; then
        echo "Your yum repos are configured with correct RHUI endpoints(https://rhui.googlecloud.com)"
    fi
}
check_rhui_v4_baseurls

rhui_v4_endpoint_connectivity_check() {
    if curl -s https://rhui.googlecloud.com | grep -q "Red Hat"; 
    then
        echo "Connectivity to RHUIv4 endpoints(https://rhui.googlecloud.com) is working fine."
    else
        echo "Connectivity to RHUIv4 endpoints(https://rhui.googlecloud.com) is failing. Please work with your Network team to allow communication to https://rhui.googlecloud.com"
    fi
}
rhui_v4_endpoint_connectivity_check

platform_related_repo_checks() {
    pass
}

http_error_checks() {
    yum repolist &> /tmp/rhui-temp 

    if cat /tmp/rhui-temp | egrep 'HTTPS Error|curl#'| awk -F "HTTPS Error|curl" '{print $NF}'| uniq| grep certificate;
    then
        echo "This can happen with an outdated google-rhui-client-rhelX or google-rhui-client-rhelX-sap* (X = RHEL version) package (containing outdated ssl certificates and keys required used to connect to rhui servers)."
    fi

    if cat /tmp/rhui-temp | egrep 'HTTPS Error|curl#'| awk -F "HTTPS Error|curl" '{print $NF}'| uniq| grep "404 - Not Found";
    then
        echo "The errors indicates a content mismatch between what you are asking for and what the RHUI contains."
        echo "Please retry package install or update at different intervals."
        echo "If issue still persists, Please reachout to GCP Support via a case/chat"

    fi

    if cat /tmp/rhui-temp | egrep 'HTTPS Error|curl#'| awk -F "HTTPS Error|curl" '{print $NF}'| uniq| grep "403 - Forbidden";
    then
        echo "This issue can happen if the installed google-rhui-client is outdated and can be resolved by updating the rhui client package using yum."
        echo -e "   sudo yum update --repo google-compute-engine google-rhui-client-rhel$os_major_version*"
        echo "If issue still persists after updating the google-rhui-client to latest, Please reachout to GCP Support via a case/chat"
    fi 
}
http_error_checks

check_yum_set_var() {
    # check for Version hardcoding
    releasever=$(grep -r releasever /etc/yum.conf /etc/yum/vars/| awk -F":" '{print$NF}')
    if [ -n "$releasever" ];
    then
        echo "yum releasever has been set to $releasever"
    fi
}
check_yum_set_var



echo $platform



