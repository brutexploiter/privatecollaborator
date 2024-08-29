# Burp Suite - Private collaborator server

A script for installing private Burp Collaborator with Let's Encrypt SSL-certificate. Requires an Ubuntu virtual machine and public IP-address.

Works for example with Ubuntu 18.04/20.04/22.10 virtual machine and with following platforms:
- Amazon AWS EC2 VM (with or without Elastic IP).
- DigitalOcean VM (with or without Floating IP).

Please see the below blog post for usage instructions:

[https://teamrot.fi/self-hosted-burp-collaborator-with-custom-domain/](https://teamrot.fi/self-hosted-burp-collaborator-with-custom-domain/)

## TL;DR:

1. Clone this repository.
2. Install Burp to /usr/local/BurpSuitePro.
3. Run `sudo ./install.sh yourdomain.fi your@email.fi` (the email is for Let's Encrypt expiry notifications).
4. You should now have Let's encrypt certificate for the domain and a private burp collaborator properly set up.
5. Start the collaborator with `sudo service burpcollaborator start`.
6. Configure your Burp Suite Professional to use it.
7. ????
8. Profit.

### Important note:

As stated in [the blog post](https://teamrot.fi/self-hosted-burp-collaborator-with-custom-domain/), be sure to firewall the ports 9443 and 9090 properly to allow connections only from your own Burp Suite computer IP address. Otherwise everyone in the internet can use your collaborator server!

#### Step 1: Create AWS Instance and Elastic IP

TL;DR: Create Ubuntu Server 18.04 instance and assign Elastic IP to it. Allow inbound SMTP(S), HTTP(S) and DNS from everywhere and ports 9090 & 9443 from your own IP.
First we’ll need to create a virtual machine for the Collaborator. Log in to your AWS-account and follow the steps:

1. First, lets create the virtual machine.
2. Navigate to Instance wizard and select Ubuntu Server 18.04 LTS (HVM), SSD Volume Type.
3. Select t2.micro or t3.micro depending on which has the free tier eligible tag on your AWS region. Then click Next: Configure Instance Details.
4. Uncheck T2/T3 Unlimited as it might cause some expenses and then click Next: Add Storage.
5. Go with default size and click Review and Launch.
6. Click Launch.
7. Create a new keypair and download it and click Launch instances.
8. Next, lets create free-tier eligible Elastic IP. This allows us to always have a static IP which can be linked to AWS virtual machines. Its not required but it makes things easier if you need to re-create your virtual machine.
9. Navigate to Allocate new address and click Allocate.
10. Go back to the Elastic IP List, right click your Elastic IP, and Associate Address to the virtual machine created in the previous steps.
11. Next, go to Instances and click your instance. On bottom of the page, click the Security Group and it should open.
12. Create Inbound rules like in the image below. Use your own PC IP for the port 9443 and 9090 as you don’t want anyone else using your collaborator.

![image](https://github.com/user-attachments/assets/5630d98a-d179-4187-83da-2d527ec060ed)

#### Step 2: Configure the collaborator domain

1. Next we’ll have to configure the domain to have the Elastic IP as nameserver. Most providers require two unique nameservers so we will use one.one.one.one as the second one. If your domain is registered on GoDaddy, see here for GoDaddy-specific instructions, otherwise follow the steps below.

2. First, find out hostname for your Elastic IP. You can for example use MxToolbox and it should give you something like ec2-00-00-00-00.eu-north-1.compute.amazonaws.com.
Next, add nameservers for your collaborator domain in domain registrar settings. Use hostname from the previous step as first nameserver and one.one.one.one as second nameserver:

![image](https://github.com/user-attachments/assets/bf2eec4c-7685-432d-84cb-58db7a57beb9)


3. Done! All DNS-queries towards your private collaborator domain should now end up in the Elastic IP.

##### Instructions for domains registered in GoDaddy:
1. Go to My Domains on GoDaddy.
2. Click the three black dots next to your collaborator domain and then click Manage DNS.
3. In Advanced Features section click the Host names.
4. Add ns-host with your Elastic IP:

![image](https://github.com/user-attachments/assets/99366ebc-25f9-478f-a16a-fd13e3d95e1c)

5. Next, modify the domain nameservers on the DNS Management page. Select Custom and set ns.YOUR_COLLABORATOR_DOMAIN as first one and one.one.one.one as second one:

![image](https://github.com/user-attachments/assets/c706dc3b-b7e7-4a36-9774-a7993169fbe3)

Done! All DNS-queries towards your private collaborator domain should now end up in the Elastic IP.

#### Step 3: Configure the virtual machine
Next you’ll need to fetch Let’s encrypt certificate and configure the virtual machine and do some other stuff. There’s a script for it so let’s use that. The script also implements automatic certificate renewal so you don’t have to manually renew the Let’s Encrypt every 90 days.

1. First, use the keypair you downloaded to log in to the virtual machine:

```
chmod 0600 newpair.pem
```
```
ssh -i newpair.pem ubuntu@YOUR_ELASTIC_IP
```

2. Clone the scripts:

```
git clone https://github.com/putsi/privatecollaborator && cd privatecollaborator
```
3. Copy your Burp Suite Professional JAR-file to the `privatecollaborator-directory`.

```
scp -i newpair.pem /your/own/pc/burp.jar ubuntu@YOUR_ELASTIC_IP:~/privatecollaborator/
```

4. Run the installer script and place your domain as a command line parameter. The email is for Let’s Encrypt expiry notifications and can either be a valid one or a non-existing one:

```
sudo ./install.sh collab.fi your@email.fi
```

5. Accept any package installations that the script suggests and also enter your email address for Lets Encrypt notifications.
6. Let’s Encrypt should now succeed creating a certificate for you. If it fails, you can try to run the install-script again couple of times. If it still fails, your domain DNS configuration from earlier steps most likely hasn’t refreshed yet. If that’s not the case, check your domain DNS configuration for typos and also check the security group inbound rules for port 53.
7. You can now start the Burp collaborator service.

```
sudo service burpcollaborator start
```

#### Step 4: Configure Burp Suite
If you didn’t do it already on previous step, start the private collaborator by running: sudo service burpcollaborator start. Then check logs with sudo systemctl status burpcollaborator. It should tell you about listening on various ports and should not show any errors.
Next start up your Burp Suite and open Project Options -> Misc. Set up the private collaborator config according to the below image, but using your own domain instead of collab.fi

![image](https://github.com/user-attachments/assets/e35f8fd9-0c18-4229-bd51-eea3dc3611e5)

Then click Run health check and wait for results. It should succeed on everything else than inbound SMTP (this is due to AWS policies):

![image](https://github.com/user-attachments/assets/bfb5bad9-a8b1-480a-bec2-efa89e8b0610)

If everything was OK, you should now be able to use the private collaborator instance normally on Burp Suite:

![image](https://github.com/user-attachments/assets/f0187f86-4c6b-4144-9791-96f84f68c7ad)


### Burpcollaborator Management
```
sudo service burpcollaborator start
```
```
sudo service burpcollaborator stop
```
```
sudo systemctl status burpcollaborator
```
```
sudo journalctl -u burpcollaborator --no-pager | grep "Received"
```
