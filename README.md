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
- install JJB

```
pip3 install virtualenv
virtualenv JJB
source JJB/bin/activate
pip install jenkins-job-builder
```
* JJB Documentation: https://jenkins-job-builder.readthedocs.io/

## Maintainer

Dean

## License

See LICENSE file
