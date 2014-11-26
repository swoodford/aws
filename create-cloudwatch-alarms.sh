#!/bin/bash
# This script creates AWS CloudWatch alarms based on standard metrics and user input to setup alarms for each environment
# Requires AWS CLI Setup and you must setup your ALARMACTION

# ALARMACTION="arn:aws:sns:us-east-1:YOURACCOUNTNUMBER:YOURSNSALERTNAME"

# Verify AWS CLI Credentials are setup
# http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html
if ! [ -f ~/.aws/config ]; then
  if ! [ -f ~/.aws/credentials ]; then
    echo "Error: AWS config not found or CLI not installed."
    exit 1
  fi
fi

# Verify ALARMACTION is setup with some alert mechanism
if [[ -z $ALARMACTION ]]; then
  echo "Error: ALARMACTION not configured."
  exit 1
fi

echo "================================================================="
echo "       Create CloudWatch Alarms"
echo "================================================================="
echo

echo -n "Client Name? "
read CLIENT
if [[ -z $CLIENT ]]; then
  echo "Invalid Client Name!"
  exit 1
fi

echo -n "How Many Servers Total? "
read SERVERNUM
if [[ $SERVERNUM > 0 ]] && echo "$SERVERNUM" | egrep '^[0-9]+$' >/dev/null 2>&1; then
  read -r -p "Loadbalanced Environment? (y/n) " LOADBALANCED
  
  # If Loadbalanced Environment
  if [[ $LOADBALANCED =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo -n "Load Balancer ID? "
    read LBID
    if [[ -z $LBID ]]; then
      echo "Invalid Load Balancer ID!"
      exit 1
    fi

    # Load Balancer Unhealthy Host Check
    aws cloudwatch put-metric-alarm --alarm-name "$CLIENT Unhealthy Host Check" --alarm-description "$CLIENT Load Balancer Unhealthy Host Detected" --metric-name "UnHealthyHostCount" --namespace "AWS/ELB" --statistic "Sum" --period 60 --threshold 0 --comparison-operator "GreaterThanThreshold" --dimensions Name=LoadBalancerName,Value=$LBID --evaluation-periods 3 --alarm-actions "$ALARMACTION"
    echo "================================================================="
    echo " Load Balancer Unhealthy Host Alarm Set"
    echo "================================================================="
    # Load Balancer High Latency Check
    aws cloudwatch put-metric-alarm --alarm-name "$CLIENT LB High Latency" --alarm-description "$CLIENT Load Balancer High Latency" --metric-name "Latency" --namespace "AWS/ELB" --statistic "Average" --period 60 --threshold 15 --comparison-operator "GreaterThanThreshold" --dimensions Name=LoadBalancerName,Value=$LBID --evaluation-periods 2 --alarm-actions "$ALARMACTION"
    echo "================================================================="
    echo "  Load Balancer High Latency Alarm Set"
    echo "================================================================="
  fi

  # Begin loop to create server alarms
  START=1
  for (( COUNT=$START; COUNT<=$SERVERNUM; COUNT++ )) do
    echo "Server #"$COUNT
    echo -n "Server Environment? (Beta/Prod) "
    read ENVIRONMENT
    if [[ -z $ENVIRONMENT ]]; then
      echo "Invalid Server Environment!"
      exit 1
    fi
    # Avoid "Beta Beta" situation
    if [[ $ENVIRONMENT == "Beta" ]]; then
      SERVERNAME=""
      else
        echo -n "Server Name? (Web01, Web02) "
        read SERVERNAME
      fi
    echo -n "Instance ID? (i-xxxxxxxx) "
    read INSTANCEID
    if [[ $INSTANCEID =~ ^([i]-........)$ ]]; then

        # CPU Check
        aws cloudwatch put-metric-alarm --alarm-name "$CLIENT $ENVIRONMENT $SERVERNAME CPU Check" --alarm-description "$CLIENT $ENVIRONMENT $SERVERNAME CPU usage >90% for 5 minutes" --namespace "AWS/EC2" --dimensions Name=InstanceId,Value=$INSTANCEID --metric-name "CPUUtilization" --statistic "Average" --comparison-operator "GreaterThanThreshold" --unit "Percent" --period 60 --threshold 90 --evaluation-periods 5 --alarm-actions "$ALARMACTION"
        echo "================================================================="
        echo $CLIENT $ENVIRONMENT $SERVERNAME "CPU Check Alarm Set"
        echo "================================================================="

        # Status Check
        aws cloudwatch put-metric-alarm --alarm-name "$CLIENT $ENVIRONMENT $SERVERNAME Status Check" --alarm-description "$CLIENT $ENVIRONMENT $SERVERNAME Status Check Failed for 5 minutes" --namespace "AWS/EC2" --dimensions Name=InstanceId,Value=$INSTANCEID --metric-name "StatusCheckFailed" --statistic "Maximum" --comparison-operator "GreaterThanThreshold" --unit "Count" --period 60 --threshold 0 --evaluation-periods 5 --alarm-actions "$ALARMACTION"
        echo "================================================================="
        echo $CLIENT $ENVIRONMENT $SERVERNAME "Status Check Alarm Set"
        echo "================================================================="

      else
        echo "Invalid Instance ID!"
        exit 1
      fi
  done
else
  if [[ $SERVERNUM == 0 ]]; then
    echo "Skipping Server Alarms"
  else
    echo "Invalid Number of Servers!"
  fi
fi

read -r -p "Setup Database Alarms? (y/n) " SETUPDB
  # If Database Alarms
  if [[ $SETUPDB =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo -n "How Many Database Hosts Total? "
    read DBNUM
    if [[ $DBNUM > 0 ]] && echo "$DBNUM" | egrep '^[0-9]+$' >/dev/null 2>&1; then

    # Begin loop to create database alarms      
      START=1
      for (( COUNT=$START; COUNT<=$DBNUM; COUNT++ )) do
        echo "DB #"$COUNT
        echo -n "Database Environment? (Beta/Prod) "
        read ENVIRONMENT
        if [[ -z $ENVIRONMENT ]]; then
          echo "Invalid Database Environment!"
          exit 1
        fi
        # # Avoid "Beta Beta" situation
        # if [[ $ENVIRONMENT == "Beta" ]]; then
        #   SERVERNAME=""
        # else
        #   echo -n "DB Name? (Web01, Web02) "
        #   read SERVERNAME
        # fi
        echo -n "DB Instance ID? "
        read DBID
        if [[ -z $DBID ]]; then
          echo "Invalid Database Instance ID!"
          exit 1
        fi

        # Database CPU Check
        aws cloudwatch put-metric-alarm --alarm-name "$CLIENT $ENVIRONMENT DB CPU Check" --alarm-description "$CLIENT $ENVIRONMENT Database CPU usage >90% for 5 minutes" --metric-name "CPUUtilization" --namespace "AWS/RDS" --statistic "Average" --unit "Percent" --period 60 --threshold 90 --comparison-operator "GreaterThanThreshold" --dimensions Name=DBInstanceIdentifier,Value=$DBID --evaluation-periods 5 --alarm-actions "$ALARMACTION"
        echo "================================================================="
        echo $CLIENT $ENVIRONMENT "Database CPU Check Alarm Set"
        echo "================================================================="

        # Database Memory Usage Check
        aws cloudwatch put-metric-alarm --alarm-name "$CLIENT $ENVIRONMENT DB Mem Check" --alarm-description "$CLIENT $ENVIRONMENT Database Freeable Memory < 200 MB for 5 minutes" --metric-name "FreeableMemory" --namespace "AWS/RDS" --statistic "Average" --unit "Bytes" --period 60 --threshold "200000000" --comparison-operator "LessThanThreshold" --dimensions Name=DBInstanceIdentifier,Value=$DBID --evaluation-periods 5 --alarm-actions "$ALARMACTION"
        echo "================================================================="
        echo $CLIENT $ENVIRONMENT "Database Memory Usage Alarm Set"
        echo "================================================================="

        # Database Available Storage Space Check
        aws cloudwatch put-metric-alarm --alarm-name "$CLIENT $ENVIRONMENT DB Storage Check" --alarm-description "$CLIENT $ENVIRONMENT Database Available Storage Space < 200 MB" --metric-name "FreeStorageSpace" --namespace "AWS/RDS" --statistic "Average" --unit "Bytes" --period 60 --threshold "200000000" --comparison-operator "LessThanThreshold" --dimensions Name=DBInstanceIdentifier,Value=$DBID --evaluation-periods 1 --alarm-actions "$ALARMACTION"
        echo "================================================================="
        echo $CLIENT $ENVIRONMENT "Database Available Storage Space Alarm Set"
        echo "================================================================="
      done
    else
      if [[ $DBNUM == 0 ]]; then
        echo "Skipping Database Alarms"
      else
        echo "Invalid Number of Databases"
      fi
    fi
  else
    echo "Exiting"
  fi
echo "Done!"
