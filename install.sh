#!/bin/bash


source .env
gerrit_config_dir="/var/lib/docker/volumes/cicd_gerrit_config/_data"
gitlab_config_dir="/var/lib/docker/volumes/cicd_gitlab_config/_data"

function install_depandent() {
	yum install -y yum-utils
	yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        yum install -y https://packages.endpoint.com/rhel/7/os/x86_64/endpoint-repo-1.7-1.x86_64.rpm
        curl --silent --location https://rpm.nodesource.com/setup_14.x | sudo bash
	yum install docker-ce docker-ce-cli containerd.io docker-compose python-pip python3-pip java git gcc-c++ make nodejs -y
        cat > /etc/yum.repos.d/google-chrome.repo << __EOF__
[google-chrome]
name=google-chrome
baseurl=http://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
__EOF__
	yum install -y google-chrome-stable --nogpgcheck
	systemctl enable docker;systemctl start docker
}


function install_ssr(){
	sudo pip install https://github.com/shadowsocks/shadowsocks/archive/master.zip -U
	cat > /etc/shadowsocks.json << __EOF__
{
  "server": "c33s2.jamjams.net",
  "server_port": 12228,
  "password": "gQvGMkz6MpuLKKLu",
  "local_port": 1080,
  "method": "aes-256-gcm"
}
__EOF__
	sslocal -c /etc/shadowsocks.json -d start
	yum install -y privoxy
	sed -i 's/listen-address  .*/listen-address  0.0.0.0:1087/' /etc/privoxy/config
        sed -i '$aforward-socks5t / 127.0.0.1:1080 .' /etc/privoxy/config
        systemctl enable privoxy;systemctl restart privoxy
}


function start_docker_compose() {
	docker-compose -f docker-compose.yaml up -d
	sleep 60
	docker-compose -f docker-compose-zuul.yaml up -d
}


function wait_for() {
	while true
	do
		if [ -n `ps -a | grep gerritconfig | grep -i exit` ];then
			break
		fi
	done
}


function setup_ldap_for_gerrit() {
	sed -i 's/DEVELOPMENT_BECOME_ANY_ACCOUNT/LDAP/' $gerrit_config_dir/gerrit.config
	cat >> $gerrit_config_dir/gerrit.config << EOF
[ldap]
	server = ldap://$EXTERNAL_IPV4_ADDRESS
        username=cn=admin,dc=dean,dc=org
        accountBase = dc=dean,dc=org
        accountPattern = (&(objectClass=person)(uid=\${username}))
        accountFullName = displayName
        accountEmailAddress = mail
EOF
	cat >> $gerrit_config_dir/secure.config << EOF
[ldap]
        password = zaq1@WSX
[plugins]
        allowRemoteAdmin = true
EOF
	docker restart gerrit
}


function setup_ldap_for_gitlab() {
	cat >> $gitlab_config_dir/gitlab.rb << EOF
gitlab_rails['ldap_enabled'] = true
gitlab_rails['ldap_servers'] = YAML.load <<-'EOS'
  main: # 'main' is the GitLab 'provider ID' of this LDAP server
    label: 'LDAP'
    host: '$EXTERNAL_IPV4_ADDRESS'
    port: 389
    uid: 'uid'
    bind_dn: 'cn=admin,dc=dean,dc=org'
    password: 'zaq1@WSX'
    encryption: 'plain' # "start_tls" or "simple_tls" or "plain"
    verify_certificates: true
    smartcard_auth: false
    active_directory: true
    allow_username_or_email_login: true
    lowercase_usernames: false
    block_auto_created_users: false
    base: 'dc=dean,dc=org'
    user_filter: ''
    ## EE only
    group_base: ''
    admin_group: ''
    sync_ssh_keys: false
EOS
EOF
	docker restart gitlab
}


function setup_gerrit_replication() {
	cat > $gerrit_config_dir/replication.config << EOF
[gerrit]
        autoReload = true
        replicateOnStartup = true
[remote "gitlab"]
        url = http://gitlab.cicd.com/\${name}.git
        push = +refs/tags/*:refs/tags/*
        push = +refs/heads/*:refs/heads/*
        rescheduleDelay = 15
        createMissingRepositories = true
EOF
	cat >> $gerrit_config_dir/secure.config << EOF
[remote "gitlab"]
        username = root
        password = Dean123456
EOF
        docker restart gerrit
	ssh -p 29418 admin@$EXTERNAL_IPV4_ADDRESS gerrit plugin reload replication
	ssh -p 29418 admin@$EXTERNAL_IPV4_ADDRESS replication start
}


function destroy(){
	docker-compose -f docker-compose-zuul.yaml down
	docker-compose -f docker-compose.yaml down
	docker volume ls | awk '{print $2}' | xargs docker volume rm
}


function usage() {
   echo "Usage: "
   echo "  ./install [COMMAND] [ARGS...]"
   echo "  ./install --help"
   echo
   echo "Commands: "
   echo "  deploy    deploy CICD container"
   echo "  destroy   destroy CICD container and volume"
}


case $1 in
	deploy)
	   install_depandent
	   start_docker_compose
	   ;;
	ssr)
	   install_ssr
	   ;;
	destroy)
	   destroy 
	   ;;
	replication)
	   setup_gerrit_replication
	   ;;
	setldap)
	   setup_ldap_for_gerrit
	   setup_ldap_for_gitlab
	   ;;
	help)
	   usage
	   ;;
	--help)
	   usage
	   ;;
	*)
	   echo "不支持的参数，请使用 help 或 --help 参数获取帮助"
esac
