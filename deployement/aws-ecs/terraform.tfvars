####################
#### Simple config for Carbone ECS deployement
####################

##### AWS Config
region              = "eu-west-3"

##### Carbone license
# Full ARN of the secret created at step 1 of the README
license_secret_arn  = "arn:aws:secretsmanager:<region>:<account-id>:secret:carbone-ee/license-XXXXXX"

##### HTTPS
# ACM certificate for your domain. Leave commented to serve plain HTTP (not for production).
# certificate_arn   = "arn:aws:acm:<region>:<account-id>:certificate/<id>"

##### Carbone persistency
# Template storage is needed if you don't use volatile template.
template_storage    = true
# Render storage is needed if you run multiple Carbone pods and if you don't use single Call API (?download=true option)
# If you don't know, it's better to use ?download=true and set render-storage to false
render_storage      = true
template_management = true

###### Persistence place
# Efs or S3, it's up to you
efs_storage         = false
s3_storage          = true

# Enables ECS Exec (shell into running containers). Only for troubleshooting.
debug               = false