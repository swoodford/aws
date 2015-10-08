#!/usr/bin/env bash
# This script sets the hostname on Elastic Beanstalk servers from within the instance with their EB environment name and public IP address
# It also will restart New Relic monitoring if present
# Requires "ec2:Describe*" IAM Policy


# Remove any previous scripts
function cleanup(){
	if [ -f /home/ec2-user/ebenvironmentname.py ]; then
		rm /home/ec2-user/ebenvironmentname.py
	fi
	if [ -f /home/ec2-user/sethostname.sh ]; then
		rm /home/ec2-user/sethostname.sh
	fi
}

cleanup

# Create the Python script to detect EB Environment
cat > /home/ec2-user/ebenvironmentname.py <<- EOF
	#!/usr/bin/env python

	import boto.utils
	import boto.ec2

	iid_doc = boto.utils.get_instance_identity()['document']
	region = iid_doc['region']
	instance_id = iid_doc['instanceId']

	ec2 = boto.ec2.connect_to_region(region)
	instance = ec2.get_only_instances(instance_ids=[instance_id])[0]
	env = instance.tags['elasticbeanstalk:environment-name']

	print(env)
EOF

chmod +x /home/ec2-user/ebenvironmentname.py

# Set Hostname
echo '#!/usr/bin/env bash' >> /home/ec2-user/sethostname.sh
echo ebenvironmentname=\$\(./ebenvironmentname.py\) >> /home/ec2-user/sethostname.sh
echo sudo hostname '"$ebenvironmentname"'-"$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)" >> /home/ec2-user/sethostname.sh
echo "chkconfig --list newrelic-sysmond &> /dev/null && sudo service newrelic-sysmond restart" >> /home/ec2-user/sethostname.sh
chmod +x /home/ec2-user/sethostname.sh

cd /home/ec2-user/ && ./sethostname.sh

cleanup
