#!/bin/bash

#Run updates
sudo apt update
sudo apt upgrade -y

sudo apt-get install -y ca-certificates curl apt-transport-https lsb-release gnupg

curl -sL https://packages.microsoft.com/keys/microsoft.asc |
gpg --dearmor | ## unpacks the key
sudo tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null ## creates a file called microsoft.gpg in the folder where keys are stored

AZ_REPO=$(lsb_release -cs) ## outputs the codename for the linux distribution i.e. Ubuntu 18.04 = bionic
 echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | ## outputs the entire url with the codename appended.
     sudo tee /etc/apt/sources.list.d/azure-cli.list ## writes that URL to the package resource list

sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list


sudo apt-get update
sudo apt-get install -y azure-cli
sudo apt-get install -y kubectl

touch /tmp/configcreated.txt