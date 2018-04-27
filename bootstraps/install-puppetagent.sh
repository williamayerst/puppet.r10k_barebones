#!/bin/bash
# set -e
# ^ commented out 14/11//2016 as Puppet always warns on install!
#===========================================================#
#
# Install Puppet Agent Script
#
#===========================================================#

## WARNING! UPDATE THE PUPPETMASTER and DOMAIN fields to match your required!
## grep 'TODO-'

#===========================================================#
# PARAMETERS
#===========================================================#

# Parameters below are used in the creation of the puppet.conf file

# Declare a product
PRODUCT=${1}

# Declare an Environment from a Parameter
#ENVIRONMENT=${2}
# With a default:
ENVIRONMENT=${2:-production}

# Obtain the Environment from Hostname:
#[[ ! $HOSTNAME =~ ^dev ]] && ENVIRONMENT=Development
#[[ ! $HOSTNAME =~ ^uat ]] && ENVIRONMENT=UAT
#[[ ! $HOSTNAME =~ ^ppd ]] && ENVIRONMENT=PreProd

# Obtain the Environment from a Parameter
[ "$ENVIRONMENT" == "dev" ] && ENVIRONMENT=development
[ "$ENVIRONMENT" == "uat" ] && ENVIRONMENT=development
[ "$ENVIRONMENT" == "ppd" ] && ENVIRONMENT=production
[ "$ENVIRONMENT" == "Production" ] && ENVIRONMENT=production
# Not splitting DR into it's own environment!
[ "$ENVIRONMENT" == "dr" ] && ENVIRONMENT=production
[ "$ENVIRONMENT" == "DR" ] && ENVIRONMENT=production

# Obtain the PuppetMaster
PUPPETMASTER=${3:-TODO-PUPPETMASTERFQDN}

# Declare a Domain (AD, DNS, etc.)
DOMAIN=${4:-TODO-DOMAIN} # Which DNS/AD Domain

# The variables below are static
LOG=/var/log/install-puppetagent.log
CONFIG=/etc/puppetlabs/puppet/puppet.conf
IP=$(ifconfig eth0 | grep "inet addr" | cut -d ':' -f 2 | cut -d ' ' -f 1)


# # If the command is being parameterised the below will return errors
 # GREEN=$(tput setaf 2); YELLOW=$(tput setaf 3); NORM=$(tput sgr0)
# if [ "$#" != 2 ] && [ "$#" != 3 ] && [ "$#" != 4 ]; then
	 # echo "${GREEN}Usage: install-puppetagent.sh ${GREEN}DOMAIN ${YELLOW}ENVIRONMENT ${YELLOW}PUPPETMASTER"
	 # echo "${GREEN}This script will auto install the puppet agent, dependencies and configuration${NORM}"
	 # echo "${NORM}       ${GREEN}DOMAIN - required, acceptable casds.co.uk, adcfs.capita.co.uk"
	 # echo "${NORM}       ${YELLOW}ENVIRONMENT - defaulted to Production, acceptable dev, Development, UAT, ppd, PreProd, Production"
	 # echo "${NORM}       ${YELLOW}PUPPETMASTER - defaulted to puppetsvr0.casds.co.uk"
	 # echo "${NORM}See product.puppet gitlab readme.mkd for more information: http://gitlab.casds.co.uk/"
	 # exit 2
# fi

# Remove SDLC from product name if present
if [[ $PRODUCT =~ ^dev ]] || [[ $PRODUCT =~ ^uat ]] || [[ $PRODUCT =~ ^ppd ]]; then
	PRODUCT=$(echo $PRODUCT | cut -c 4-)
fi

# Remove DR from product name if present
if [[ $PRODUCT =~ ^dr ]] || [[ $PRODUCT =~ ^DR ]] ; then
	PRODUCT=$(echo $PRODUCT | cut -c 3-)
fi


# Initial logging information #
touch $LOG
echo "#===========================================================#" >> $LOG
echo "# Install-PuppetAgent.sh Script" >> $LOG
echo "#===========================================================#" >> $LOG
echo "Run at: $(/bin/date)" >> $LOG
echo "- Enviroment parameter: $ENVIRONMENT" >> $LOG
echo "- Domain parameter: $DOMAIN" >> $LOG
echo "- Puppetmaster parameter: $PUPPETMASTER" >> $LOG

#===========================================================#
# HOUSEKEEPING
#===========================================================#

echo "#===========================================================#" >> $LOG
echo "# HOUSEKEEPING" >> $LOG
echo "#===========================================================#" >> $LOG

# Checking root priviledges
echo "Checking root priviledges" >> $LOG
GOTROOT=$(whoami)
if [ "$GOTROOT" != "root" ]; then
	echo "Error: Not running as root"
	echo "- Error: Not running as root" >> $LOG
	exit 1
fi
echo "- Success!" >> $LOG

# Add puppetlabs path to all users BASH profile
echo "Adding puppetlabs path to all users BASH profile" >> $LOG
if grep "puppetlabs" /etc/profile -q; then
	echo "- Warning: Skipping as puppetlabs already exists in user BASH profile" >> $LOG
else
	echo PATH='$PATH':/opt/puppetlabs/bin >> /etc/profile
fi

# Add puppetlabs path to root user BASH profile
echo "Adding puppetlabs path to all users BASH profile" >> $LOG
if grep "puppetlabs" ~/.bashrc -q; then
	echo "- Warning: Skipping as puppetlabs already exists in root BASH profile" >> $LOG
else
	echo PATH='$PATH':/opt/puppetlabs/bin >> /home/nomen.nescio/.bashrc
	ln -s /opt/puppetlabs/bin/puppet /usr/local/bin
fi

#===========================================================#
# SETTING UP CUSTOM FACTS
#===========================================================#
echo "#===========================================================#" >> $LOG
echo "# SETTING UP CUSTOM FACTS" >> $LOG
echo "#===========================================================#" >> $LOG
# Creating a fact list based on script parameters
# see: https://puppet.com/blog/hiera-hierarchies-and-custom-facts-everyone-needs
echo "Creating a fact list based on script parameters" >> $LOG
mkdir -p /etc/puppetlabs/facter/facts.d
FACTS=/etc/puppetlabs/facter/facts.d/facts.txt
rm -f $FACTS
touch $FACTS
echo "role=$PRODUCT" >> $FACTS
echo "domain=$DOMAIN" >> $FACTS

#===============11==========================================#
# INSTALL PUPPET AGENT
#===========================================================#

echo "#===========================================================#" >> $LOG
echo "# INSTALL PUPPET AGENT" >> $LOG
echo "#===========================================================#" >> $LOG
# Check if it's installed first

if ! hash puppet 2>/dev/null; then
	echo "Installing Puppet..." >> $LOG
	OSF=$(grep Ubuntu /etc/issue | awk '{print $1}')
	if [ "$OSF" == "Ubuntu" ]; then  #if Ubunutu use .deb - else use .rpm
		echo "...via APT" >> $LOG
		# enable the repository
		echo "... via APT - add deb to the local repository" >> $LOG
		URL='https://apt.puppetlabs.com/puppetlabs-release-pc1-xenial.deb'; FILE=`mktemp`; wget "$URL" -qO $FILE && sudo dpkg -i $FILE; rm $FILE
		# get list of new packages and update system
		echo "... via APT - get list of new packages and update system" >> $LOG
		/usr/bin/apt -y update
		# for i in {update,upgrade,autoremove,autoclean}; do /usr/bin/apt -y $i; done
		# install the agent
		echo "... via APT - install the agent" >> $LOG
		apt install -y puppet-agent
		echo " - Success!" >> $LOG
	else
		echo "... via YUM" >> $LOG
		# enable the repository
		echo "... via YUM - enable the repository" >> $LOG
		rpm -Uvh https://yum.puppetlabs.com/puppetlabs-release-pc1-el-7.noarch.rpm
		# get list of new packages and update system
		echo "... via YUM - get list of new packages and update system" >> $LOG
		/usr/bin/apt -y update
		# for i in {update,upgrade,autoremove,autoclean}; do /usr/bin/yum -y $i; done
		# install the agent
		echo "... via YUM - install the agent" >> $LOG
		yum install -y puppet-agent
		echo " - Success!" >> $LOG
	fi
else
	echo "Warning: Puppet Agent already installed" >> $LOG
fi

#===========================================================#
# SET UP CONFIG FILE
#===========================================================#

echo "#===========================================================#" >> $LOG
echo "# SET UP CONFIG FILE" >> $LOG
echo "#===========================================================#" >> $LOG
# Check if we've done this before
if grep "# Generated by Install-PuppetAgent.sh Script" $CONFIG -q -s; then
	echo "- Warning: We've done this before, piping puppet.conf"
	echo "- Warning: to log for reference, then removing it" >> $LOG
	cat $CONFIG >> $LOG
	rm -f $CONFIG
fi

# Check if there's a meaningful manual .conf file
if grep "$HOSTNAME" $CONFIG -q -s; then
	echo "- Warning: Original Puppet Config file backed up to $CONFIG.old" >> $LOG
	echo "- Warning: in the event that it needs to be rolled back" >> $LOG
	mv -f $CONFIG $CONFIG.old
fi

# Create a new blank config file
echo "Creating a blank puppet.conf file" >> $LOG
touch $CONFIG
echo "- Success!" >> $LOG

echo "Populating the blank puppet.conf file" >> $LOG
# Populate the config file
echo "# Generated by Install-PuppetAgent.sh Script" >> $CONFIG
echo "# Run at: $(/bin/date)" >> $CONFIG
echo "#- Product parameter: $PRODUCT" >> $CONFIG
echo "#- Environment parameter: $ENVIRONMENT" >> $CONFIG
echo "#- Domain parameter: $DOMAIN" >> $CONFIG
echo "#- Puppetmaster parameter: $PUPPETMASTER" >> $CONFIG
echo "#" >> $CONFIG
echo "[main]" >> $CONFIG
echo "certname = $HOSTNAME.$DOMAIN"  >> $CONFIG
echo "server = $PUPPETMASTER" >> $CONFIG
echo "environment = $ENVIRONMENT" >> $CONFIG
echo "runinterval = 1h" >> $CONFIG
echo "- Success!" >> $LOG



#===========================================================#
# RESTART AGENT, EXECUTE INITIAL RUN AND EXIT
#===========================================================#
echo "#===========================================================#" >> $LOG
echo "# RESTART AGENT" >> $LOG
echo "#===========================================================#" >> $LOG
# service puppet restart
echo "#===========================================================#" >> $LOG
echo "# INITIATE FIRST RUN AND EXIT" >> $LOG
echo "#===========================================================#" >> $LOG
# nohup /opt/puppetlabs/bin/puppet agent -t 2>&1
echo "- Success!" >> $LOG
echo "#===========================================================#" >> $LOG
echo "Script Completed at $(/bin/date)" >> $LOG


exit 0
