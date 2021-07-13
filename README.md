# CICD

Easy way to deploy your own CICD env.

Inclouding below sw:
- Gitlab
- Gerrit
- Zuul
- Jenkins
- OpenLDAP
- SonarQube

## Usage

*Requires Centos*

- Edit .env file to setup your external ip address
- Run install.sh
```
./install deploy
```

### Config Jenkins

- install JJB

```
pip3 install virtualenv
virtualenv JJB
source JJB/bin/activate
pip install jenkins-job-builder
```

- config jenkins authorization
```
mkdir -p ~/.config/jenkins_jobs/
cat ~/.config/jenkins_jobs/jenkins_jobs.ini < __EOF__
[jenkins]
user=root
password=zaq1@WSX
url=http://xx.xx.xx.xx:xx
query_plugins_info=False
__EOF__
```

* JJB Documentation: https://jenkins-job-builder.readthedocs.io/

## Maintainer

Dean

## License

See LICENSE file
