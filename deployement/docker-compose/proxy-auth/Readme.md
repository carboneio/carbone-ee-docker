# Carbone sample deployement with Oaut2-proxy and Google Identity provider

## Setup
You first need to create `.env` file with Google Oauth identifier. To get it, you need to create Oauth2 client from GCP console : https://console.cloud.google.com/auth/clients.

After creation of Web Application Client with correct redirect URL (http://localhost/oauth2/callback), you should get `Client ID` and `Client secret`. All you have to do now is generate the secret cookie: 

```bash
dd if=/dev/urandom bs=32 count=1 2>/dev/null | base64 | tr -d -- '\n' | tr -- '+/' '-_' ; echo
```

Then push these values in `.env` file :
```bash
OAUTH2_PROXY_CLIENT_ID=
OAUTH2_PROXY_CLIENT_SECRET=
OAUTH2_PROXY_COOKIE_SECRET=
```

## Deploy environement

Finally, just run : 

```bash
docker compose up -d
```

Enjoy 🎉