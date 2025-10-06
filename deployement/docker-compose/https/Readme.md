# Carbone deployment sample : Docker compose with HTTPS

## Prerequisites

To activate a Carbone service with HTTPS, you must have:
- a DNS name for your service
- network configuration to ensure that the DNS resolution links to your server with accessible port 80 and 443
- a certificate and a private key. You can generate these with Let's Encrypt and Cerbot, for example.

## Enable HTTPS with your own certificat

Please follow your certificatio provider to get working one for you server.
Then set server_name in nginx.conf.
Copy server certificat in ./cert.pem and private key in privkey.pem

Finally run :
```bash
docker-compose up
```

## Enable HTTPS with Certbot

You can use letsencrypt to provide free certificat.

To create private key and certificate :
```bash
# Start containers
docker compose -f docker-compose-certbot.yml restart

# Dry-run certbot
docker compose -f docker-compose-certbot.yml run --rm  certbot certonly --webroot --webroot-path /var/www/certbot/ --dry-run -d **** YOUR HOSTNAME****

# If success
docker compose -f docker-compose-certbot.yml run --rm  certbot certonly --webroot --webroot-path /var/www/certbot/ -d **** YOUR HOSTNAME****
```

Then set **** YOUR HOSTNAME**** in nginx-certbot.conf.
And uncomment server 443 configuration in nginx-certbot.conf and run:
```bash
docker compose -f docker-compose-certbot.yml restart
```

To renew certificat :
```bash
docker compose -f docker-compose-certbot.yml run --rm certbot renew
```
