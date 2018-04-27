# Puppet 5.5 install guide

## Prerequisites
Set up the machine, ensuring hostname and /etc/hosts are valid

##  Installation

### Puppet Platform:

```
wget https://apt.puppetlabs.com/puppet5-release-xenial.deb
sudo dpkg -i puppet5-release-xenial.deb
sudo apt update
```

### PuppetServer

run `apt-get install puppetserver`


Update `/etc/puppetlabs/puppet/puppet.conf` roughly as below:

```
[master]
dns_alt_names = PUPPETMASTER
...

[main]
server = PUPPETMASTERFQDN
environment = production

[agent]
runinterval = 1h
```

## Basic Testing

Update environment.conf in /etc/puppetlabs/code/environments/production to point to a default file (i.e. default.pp) and a modulepath of modules:config (not sure if required)

Update `/etc/puppetabs/code/environments/production/default.pp` with a basic class or resource (i.e. 'notify') and run a `puppet-agent -tvd` to validate.

If you have errors, remember to check:

* puppetserver service is running
* puppet service has been restarted after updating puppet.conf
* you are running the puppet-agent via the full path `/opt/puppetlabs/bin/puppet xxxxx`
* you are running the puppet-agent commands via `sudo`

## Hiera

Hiera comes preinstalled, the key steps are:

* update /etc/puppetlabs/puppet/hiera.yaml with a hierarchy, i.e.

   ```
   hierarchy:
    - name: Trusted Names
      path: nodes/%{::trusted.certname}.yaml
      data_hash: yaml_data
    - name: Default
      path: default.yaml
      data_hash: yaml_data
   ```
    
* ensure the datadir variable is set `datadir: /etc/puppetlabs/code/environments/%{::environment}/hieradata`
  
* update default.pp to simply `hiera_include('classes')`
* create a file called `default.yaml` (last row of hierarchy) with the following content:

    ```
    ---
    classes:
     - 'profiles::default_linux'
    ```

* create a file called default_linux.pp in `/etc/puppetlabs/code/environments/production/config/profiles/manifests/default_linux.pp` and put the class 'profiles::default_linux' as the class name with the same dummy resource from before (or something simple and small)
* restart the `puppetserver` service and run a `puppet agent -tvd`


## R10k

* create a file `etc/puppetlabs/code/environments/production/Puppetfile and include 'puppet/r10k' in the list (this is for later)
* create a file `/etc/puppetlabs/code/environments/production/hieradata/nodes/PUPPETMASTER.yaml` and point it to the class `profiles::r10k` with a variable for r10k::remote of the gitlab HTTPS repo address
* create a file `/etc/puppetlabs/code/environments/production/config/profiles/manifests/r10k.pp` with the content 'include ::r10k' 
* Run `sudo puppet module install puppet-r10k` 
* Ensure your `/etc/puppetlabs/code/environments/production` is reflected in the gitlab repo in a branch called `production`
* Run `sudo r10k deploy environment production -pv`
    
