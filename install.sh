#!/bin/bash


source .env
gerrit_config_dir="/var/lib/docker/volumes/*gerrit_config/_data"
gitlab_config_dir="/var/lib/docker/volumes/*gitlab_config/_data"

function install_depandent() {
	yum install -y yum-utils
	yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
	yum install docker-ce docker-ce-cli containerd.io docker-compose python-pip -y
	systemctl enable docker;systemctl start docker
}


function start_docker_compose() {
	docker-compose -f docker-compose.yaml up -d
	sleep 30
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
        accountPattern = (&(objectClass=person)(uid=${username}))
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
	destroy)
	   destroy 
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
