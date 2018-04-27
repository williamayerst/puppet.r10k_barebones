
#===========================================================#
#
# Install Puppet Agent Script
#
#===========================================================#

## WARNING! UPDATE THE PUPPETMASTER and DOMAIN fields to match your required!
## grep 'TODO-'

# Expected usage, copy locally or run as Azure Extension, like so:
# .\install-puppetagent.ps1 cascorevm

# For more explicit parameters, one can run the following:
# .\install-puppetagent.ps1 cascorevm production TODO-PUPPETMASTER TODO-DOMAIN


#===========================================================#
# PARAMETERS
#===========================================================#
Param
(
# Declare a product
    [Parameter(Mandatory=$true, Position=0)]
        [string]
        $product, # Name of the Product
# Obtain the Environment from a Parameter
    [parameter(Position=1)]
        [string]
        [AllowNull()]
        $environment, # Environment being deployed (info from Octopus)
# Declare a Domain (AD, DNS, etc.)
    [parameter(Position=2)]
        [string]
        $domain = "TODO-DOMAIN", # Environment being deployed
# Obtain the PuppetMaster
    [parameter(Position=3)]
        [string]
        $puppetmaster = "TODO-PUPPETMASTER" # Environment being deployed
)

#===========================================================#
# VARIABLES
#===========================================================#

# The variables below are static
$timestamp = $(get-date -Format yyMMddhhmm)
$localdir = "c:\temp\"
$installlogfile = "puppet_" + $timestamp + ".log"
$agentlogfile = "puppetagent_" + $timestamp + ".log"
$agentpath = "https://downloads.puppetlabs.com/windows/" # url for puppet agent
$agentfile = "puppet-agent-x64-latest.msi" # msi filename from puppet
$path = @('HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*') # registry path for checking if the agent is installed
$facterpath = "C:\ProgramData\PuppetLabs\facter\facts.d\"
$facterfile = "facts.txt"

# The variables below are dynamic
$computerSystem = Get-CimInstance CIM_ComputerSystem # Get and log local system info for a sanity check
$computerBIOS = Get-CimInstance CIM_BIOSElement # Get and log local system info for a sanity check
$computerOS = Get-CimInstance CIM_OperatingSystem # Get and log local system info for a sanity check
$computerCPU = Get-CimInstance CIM_Processor # Get and log local system info for a sanity check
$computerHDD = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID = 'C:'" # Get and log local system info for a sanity check

# Set a proper domain suffix for the machine
if ($domain -eq "nondomain") {$certname = $($computerSystem.Name).tolower()}
else {$certname = $($($computerSystem.Name) + "." + $domain).tolower()}

# Ensure environment parameter is correct:
if ($environment -eq $null) {
    switch -regex ($env:COMPUTERNAME)
    { 
        "^ppd" {$environment = "production"}
        "^dr" {$environment = "production"}
        "^dev" {$environment = "development"}
        "^uat" {$environment = "development"}
        default {$environment = "production"}
    }
}
elseif ($environment -notmatch "^prod" -and $environment -notmatch "^dev" -and $environment -notmatch "^ppd" -and
    $environment -notmatch "^uat" -and $environment -notmatch "^dr" -and $environment -notmatch "^$") 
    {
        throw "Incorrect Environment"
    }
else {
        switch -regex ($environment)
            { 
                "^" {$environment = "production"} # Blank #nonprodflag from octopus = Production
                "^ppd" {$environment = "production"} # no need for separate environment for PreProd, since it must match Prod
                "^prod" {$environment = "production"} 
                "^dr" {$environment = "production"} # no need for separate environment for DR, since it must match Prod
                "^dev" {$environment = "development"}
                "^uat" {$environment = "development"} # no need for separate environment for UAT, since it should match Dev
                default {$environment = "development"}
            }
}

# Define the agent install parameters
$arguments ="/qn /norestart /l*v $($localdir + $agentlogfile) /i $($localdir + $agentfile) PUPPET_MASTER_SERVER=$puppetmaster PUPPET_AGENT_ENVIRONMENT=$environment PUPPET_AGENT_CERTNAME=$certname"

#===========================================================#
# LOGGING FUNCTION
#===========================================================#

# Setting log output file
if (!(test-path $localdir)) {new-item -path $localdir -itemtype directory -force}

function Out-Logfile($string, $color)
{
    $logline = "$(get-date -Format yyMMddhhmmss) - $string"
    if ($Color -eq $null) {$color = "white"}
    write-host $logline -foregroundcolor $color
    $logline | out-file -Filepath $localdir$installlogfile -append
}

Out-Logfile "#===========================================================#"
Out-Logfile "#                I'm ALIIIIVE!"
Out-Logfile "#===========================================================#"
Out-Logfile "Logging all activity to $($localdir + $installlogfile)" green


Out-Logfile "#===========================================================#"
Out-Logfile "#  System Information:"
Out-Logfile "#===========================================================#"
Out-Logfile "Computer Name: $($computerSystem.Name)" cyan
Out-Logfile "HDD Capacity: $($computerHDD.Size/1GB)" cyan
Out-Logfile "RAM: $($computerSystem.TotalPhysicalMemory/1GB)" cyan
Out-Logfile "Operating System: $($computerOS.caption), Service Pack: $($computerOS.ServicePackMajorVersion)" cyan
Out-Logfile "User logged In: $($computerSystem.UserName)" cyan
Out-Logfile "Last Reboot: $($computerOS.LastBootUpTime)" cyan


# Output Puppet Parameters for sanity check
Out-Logfile "#===========================================================#"
Out-Logfile "#  Puppet Details: "
Out-Logfile "#===========================================================#"
Out-Logfile "Product Name: $product" cyan
Out-Logfile "Environment: $environment" cyan
Out-Logfile "Domain: $domain" cyan
Out-Logfile "Remote Path: $($agentpath + $agentfile)" cyan
Out-Logfile "Local Path: $($localdir + $agentfile)" cyan
Out-Logfile "Executing Install with following arguments: $arguments" cyan

# _____________________
#
# __ Puppet Agent Install INSTALL ___
# _____________________
Out-Logfile "#===========================================================#"
Out-Logfile "#  Agent Check"
Out-Logfile "#===========================================================#"

Out-Logfile "Checking if agent is installed already..." yellow
try {
      Out-Logfile "Interrogating Registry" yellow
      if (Get-ItemProperty $path | .{process{ if ($_.DisplayName -and $_.UninstallString) { $_ } }} | Where-object displayname -like "*puppet*") {Out-Logfile "Puppet Agent already installed" green; exit 0}
      else { Out-Logfile "Nope!" green }
    }
catch {
      $ErrorMessage = $_.Exception.Message
      $FailedItem = $_.Exception.ItemName
      Out-Logfile "Unable to verify if agent is installed, will reinstall" red
      Out-Logfile $errormessage red
      Out-Logfile $faileditem red
      }



Out-Logfile "#===========================================================#"
Out-Logfile "#  Agent Download"
Out-Logfile "#===========================================================#"
Out-Logfile "Checking if agent is downloaded already..." yellow
if (!(test-path $($localdir + $agentfile))) {
  Out-Logfile "Nope!" red
    try {
      Out-Logfile "Downloading Latest Agent" yellow
    Invoke-WebRequest -Uri "$($agentpath + $agentfile)" -OutFile "$($localdir + $agentfile)"
    Out-Logfile "...Successfully downloaded" green
            }

    catch {
    $ErrorMessage = $_.Exception.Message
    $FailedItem = $_.Exception.ItemName
    Out-Logfile $errormessage red
    Out-Logfile $faileditem red
            }
}
else { Out-Logfile "Yes, will use that instead" green}

Out-Logfile "#===========================================================#"
Out-Logfile "#  Agent Install"
Out-Logfile "#===========================================================#"

try {
        Out-Logfile "Installing Latest Agent" yellow
        Start-Process `
          -file "msiexec"`
          -arg $arguments `
          -passthru | wait-process
        Out-Logfile "...Successfully installed" green
    }
catch {
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        Out-Logfile $errormessage red
        Out-Logfile $faileditem red
       }

Out-Logfile "#===========================================================#"
Out-Logfile "#  Facter Custom Fact Setup"
Out-Logfile "#===========================================================#"

try {
        Out-Logfile "Checking if facter custom fact directory exists already and creating if not..." yellow
        if (!(test-path $facterpath)) {
					new-item -path $facterpath -itemtype directory -force | out-null ; Out-Logfile "...Successfully created" green
				}
				else {
					Out-Logfile "...already exists" green
				}
    }
catch {
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        Out-Logfile $errormessage red
        Out-Logfile $faileditem red
       }
try {
        Out-Logfile "Checking if facter custom fact file exists already..." yellow
        if (test-path "$($facterpath + $facterfile)") {
					Out-Logfile "Yes! Backing up" green; move-item "$($facterpath + $facterfile)" "$($facterpath + $facterfile).bak" -force
				}
				else {
				 	Out-Logfile "Nope!" green
				}
    }
catch {
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        Out-Logfile $errormessage red
        Out-Logfile $faileditem red
       }
try {
        Out-Logfile "Creating new factor custom facts file..." yellow
        New-Item "$($facterpath + $facterfile)" -type file -force -value "role=$product`r`ndomain=$domain" | Out-Null
        Out-Logfile "...Successfully created" green
    }
catch {
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        Out-Logfile $errormessage red
        Out-Logfile $faileditem red
       }

Out-Logfile "#===========================================================#"
Out-Logfile "#  Wrap-Up and Service Restarts"
Out-Logfile "#===========================================================#"
			 try {
			         Out-Logfile "Restarting Puppet Agent for new facts to take effect..." yellow
			         Restart-Service -Name puppet
			         Out-Logfile "...Successfully restarted" green
			     }
			 catch {
			         $ErrorMessage = $_.Exception.Message
			         $FailedItem = $_.Exception.ItemName
			         Out-Logfile $errormessage red
			         Out-Logfile $faileditem red
			        }

Out-Logfile "#===========================================================#"
Out-Logfile "#  Complete!"
