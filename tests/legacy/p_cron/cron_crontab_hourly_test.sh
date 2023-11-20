#!/bin/sh
# Author: Athmane Madjoudj <athmanem@gmail.com>

t_Log "Running $0 - crontab will run hourly jobs."

# Add a test cron
cat > /etc/cron.hourly/test.sh<<EOF
#!/bin/sh
echo 'test'
EOF
chmod +x /etc/cron.hourly/test.sh

run-parts /etc/cron.hourly | grep -q "test" 


t_CheckExitStatus $?
