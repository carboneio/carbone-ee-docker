# Single source of truth for component versions and image tags.
# Local build:   docker buildx bake                      (all published variants)
#                docker buildx bake full --load          (one variant, current platform only: add --set '*.platform=')
# Override:      CARBONE_VERSION=5.15.5 docker buildx bake --print
# Every artefact downloaded from bin.carbone.io must be signed (see BUILD.md).

variable "CARBONE_VERSION" {
  default = "5.15.4"
}

variable "LO_VERSION" {
  default = "26.2.6.3"
}

variable "OO_VERSION" {
  default = "9.0.4"
}

variable "CHROME_VERSION" {
  default = "156.0.8078.12"
}

variable "DOCKERHUB_ORG" {
  default = "carbone"
}

variable "PLATFORMS" {
  default = "linux/amd64,linux/arm64"
}

# Also move the floating tags (full, latest, full-<carbone>, ...) to this build
variable "UPDATE_LATEST" {
  type    = bool
  default = false
}

function "major" {
  params = [version, parts]
  result = join(".", slice(split(".", version), 0, parts))
}

function "tags" {
  params = [versioned, floating]
  result = [for t in concat(versioned, UPDATE_LATEST ? floating : []) : "${DOCKERHUB_ORG}/carbone-ee:${t}"]
}

LO     = "L${major(LO_VERSION, 2)}"
OO     = "O${major(OO_VERSION, 2)}"
CHROME = "C${major(CHROME_VERSION, 1)}"

group "default" {
  targets = ["slim", "full", "no-onlyoffice", "full-fonts"]
}

target "_common" {
  context    = "."
  dockerfile = "Dockerfile"
  platforms  = split(",", PLATFORMS)
  attest = [
    "type=provenance,mode=max",
    "type=sbom",
  ]
  args = {
    CARBONE_VERSION = CARBONE_VERSION
    LO_VERSION      = LO_VERSION
    OO_VERSION      = OO_VERSION
    CHROME_VERSION  = CHROME_VERSION
  }
}

target "slim" {
  inherits = ["_common"]
  target   = "slim"
  tags     = tags(["slim-${CARBONE_VERSION}"], [])
}

target "full" {
  inherits = ["_common"]
  target   = "full"
  tags = tags(
    ["full-${CARBONE_VERSION}-${LO}-${OO}-${CHROME}"],
    ["full-${CARBONE_VERSION}", "full", "latest"]
  )
}

target "no-onlyoffice" {
  inherits = ["_common"]
  target   = "no-onlyoffice"
  tags = tags(
    ["no-onlyoffice-${CARBONE_VERSION}-${LO}-${CHROME}"],
    ["no-onlyoffice-${CARBONE_VERSION}", "no-onlyoffice"]
  )
}

# Needs ./carbone-fonts (carboneio/carbone-fonts without the "custom" folder)
target "full-fonts" {
  inherits = ["_common"]
  target   = "full-fonts"
  tags = tags(
    ["full-${CARBONE_VERSION}-${LO}-${OO}-${CHROME}-fonts"],
    ["full-${CARBONE_VERSION}-fonts", "full-fonts", "latest-fonts"]
  )
}

# Not published, available for custom builds
target "no-libreoffice" {
  inherits = ["_common"]
  target   = "no-libreoffice"
  tags     = tags(["no-libreoffice-${CARBONE_VERSION}-${OO}-${CHROME}"], [])
}

target "no-chrome" {
  inherits = ["_common"]
  target   = "no-chrome"
  tags     = tags(["no-chrome-${CARBONE_VERSION}-${LO}-${OO}"], [])
}
