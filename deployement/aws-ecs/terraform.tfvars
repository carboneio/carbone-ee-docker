####################
#### Simple config for Carbone ECS deployement
####################

##### AWS Config
region              = "eu-west-3"

##### Carbone persistency
# Template storage is needed if you don't use volatile template.
template_storage    = true
# Render storage is needed if you run multiple Carbone pods and if you don't use single Call API (?download=true option)
# If you don't know, it's better to use ?download=true and set render-storage to false
render_storage      = false

###### Persistence place
# Efs or S3, it's up to you
efs_storage         = true
s3_storage          = false