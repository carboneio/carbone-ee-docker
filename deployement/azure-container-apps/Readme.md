# Carbone terraform deployement on Azure

To deploy : 

```bash
export CARBONE_EE_LICENSE=`cat ./your_license.carbone-license`

terraform apply --var carbone_license="$CARBONE_EE_LICENSE"
```

Enjoy 🎉