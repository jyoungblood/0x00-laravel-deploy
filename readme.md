





# Overview

These are installation instructions and scripts for deploying a Laravel application on a WHM-based VPS. This is the "bare bones" minimal deployment required to run an app on this stack (nothing included for ZDD, rollbacks, post-receive hooks, etc)

This solution assumes a standard WHM/cPanel setup (using Apache, PHP managed by EA/MultiPHP, etc), and is specifically intended for MY servers. These concepts _could_ be adapted for general use by other stacks, but YMMV if you're not me.

The plan: symlink docroots of primary and staging domains to the respective directories of the codebases for each. After initial setup, you should be able to run the deploy script locally (`./deploy.sh`), answer prompts and sit back and observe as your site is automatically deployed to the correct enfironment. 

The instructions assume a domain of `example.com` and a subdomain of `staging.example.com`, so replace any references to those with your domain and you should be good to go.

This solution has two primary components: 
- [deploy.sh](https://github.com/hxgf/0x00-laravel-deploy/blob/master/deploy.sh) - local script that goes in the root of your project (and should be added to `.gitignore`). This prompts for a couple pieces of information (git commit message, deployment environment), builds FE assets, commits current changes to Git, and triggers the remote deployment script via SSH.
- [deploy-remote.sh](https://github.com/hxgf/0x00-laravel-deploy/blob/master/deploy-remote.sh) - remote script that goes on server in a 'laravel' directory, relative to the codebase directories. This pulls changes from Git, updates Composer packages, runs database migrations, and clears caches for routes, views, and config. It also takes the current site offline during the process.

On the server, the _(relevant parts of the)_ directory structure will look like this:
```
/home/example/
├─ laravel/
│  ├─ staging/
│  ├─ production/
│  ├─ deploy-remote.sh
├─ staging.example.com/
├─ public_html/
```










# Server prep / prerequisites

Before installing, make sure you have set up the following with cPanel:

- [ ] cPanel user with SSH access (for the whole cpanel account, site owner or whatever)
  - [ ] (optional) SSH keys - I personally like to have an SSH key saved locally so I'm not prompted for a password
  - [ ] Git access set up for SSH user - I like to share with other accounts
    - Do this as root to copy from another site:
    - ```mv /home/example/.ssh /home/example/.ssh_bk```
    - ```cp /home/othersite/.gitconfig /home/example```
    - ```cp -R /home/othersite/.ssh /home/example```
    - ```chown -R example:example /home/example/.ssh```

- [ ] Root domain (`example.com`) and relevant subdomains (`staging.example.com`, `dev.example.com`, etc)
  - Docroots are expected to be the cPanel defaults: `public_html`, `staging.example.com`, etc
  - ?? maybe let AutoSSL run idk (after it's run once you should be fine)
  - You _could_ choose to "Force HTTPS Redirect" on the cPanel Domains screen, but we'll be adding a .htaccess rule to do the same thing
  - PHP default version should be >= 8.3. If not, change this on the MultiPHP screen, but only AFTER the .htaccess

- [ ] Update any PHP defaults in the MultiPHP INI editor. I usually do something like this:
  - allow_url_fopen: enabled
  - file_uploads: enabled
  - post_max_size: 100M
  - upload_max_filesize: 80M
  - zlib.output_compression: enabled
  - etc...

- [ ] MySQL database and web user
  - Set the appropriate permissions for the web user and assign user to db
    - _(fixit what are the recommended permissions?)_ 
    - Note credentials to be added to .env file during installation
  - Make sure you're developing with the same version of MySQL as the server uses (5.7, 8, etc)
  - Dump & import your dev db (I do this all with TablePlus)

- [ ] Required PHP & Composer installation
  - PHP version should be 8.3 or higher (upgrade if needed)
  - Laravel requires the `fileinfo` extension for PHP
    - Installed as root with EasyApache
    - I have to do this for every version of PHP `¯\_(ツ)_/¯`
  - Composer needs to be installed and usable be for site users (I've had issues in the past with Composer only being usable by root, but it's fine these days)

















# Installation

### Local machine:

In the root of your Laravel application, add the local deploy script (and add to .gitignore):
```
curl https://raw.githubusercontent.com/hxgf/0x00-laravel-deploy/master/deploy.sh -o deploy.sh && echo "/deploy.sh" >> .gitignore
```

Edit `deploy.sh` to add your SSH login info, deployment targets, and working Git branch. After editing, make sure the script is executable:
```
chmod +x deploy.sh
```

Add a rule to your .htaccess file to follow symlinks:
```
printf "Options +FollowSymLinks\n\n" >> public/.htaccess
```

Optionally, you can add a rule to force HTTPS (which I usually do). In the same `public/.htaccess` file, after "RewriteEngine On" add:

```
RewriteCond %{HTTPS} off
RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]
```

NOTE: If cPanel has added rules for MultiPHP or .well-known to the initial versions of .htaccess (in the current docroots), you can copy them to this file now.

This deployment method also depends on the built "public" files being shipped to the server in the repo, so comment out the default rules in `.gitignore` like so:
```
# /public/build
# /public/hot
```


Finally, do one last push to the working branch before cloning on the server: 
```
$ git add --all
$ git commit -am "update .htaccess, add 'public' build files, ready to set up deployment"
$ git push origin main
```




### On the server:

Next, we'll add the codebases to the server, install necessary composer packages

Log in to your server (via SSH, as the cPanel user mentioned earlier), and in your site home directory (`/home/example/`) run the following commands:
```
$ mkdir laravel && cd laravel
$ git clone git@bitbucket.org:$user/$repo.git production && cd production
$ /opt/cpanel/composer/bin/composer install --no-interaction --prefer-dist --optimize-autoloader --no-dev
$ ln -s /home/example/laravel/production/storage/app/public /home/example/laravel/production/public/storage
$ chmod -R 755 /home/example/laravel/production/storage
$ chmod -R 755 /home/example/laravel/production/bootstrap/cache
$ curl https://raw.githubusercontent.com/hxgf/0x00-laravel-deploy/master/.env -o production/.env
$ nano production/.env
  // see .env notes below
$ mv /home/example/public_html /home/example/public_html_bk
$ ln -s /home/example/laravel/production/public /home/example/public_html
$ cp -R /home/example/public_html_bk/.well-known /home/example/laravel/production/public
```

Repeat the process for staging and any additional environments:
```
$ cd /home/example/laravel
$ git clone git@bitbucket.org:$user/$repo.git staging && cd staging
$ /opt/cpanel/composer/bin/composer install --no-interaction --prefer-dist --optimize-autoloader --no-dev
$ ln -s /home/example/laravel/staging/storage/app/public /home/example/laravel/staging/public/storage
$ chmod -R 755 /home/example/laravel/staging/storage
$ chmod -R 755 /home/example/laravel/staging/bootstrap/cache
$ touch staging/.env
$ nano staging/.env
$ curl https://raw.githubusercontent.com/hxgf/0x00-laravel-deploy/master/.env -o staging/.env
$ nano staging/.env
  // see .env notes below
$ mv /home/example/staging.example.com /home/example/staging.example.com_bk
$ ln -s /home/example/laravel/staging/public /home/example/staging.example.com
$ cp -R /home/example/staging.example.com_bk/.well-known /home/example/laravel/staging/public
```


Finally, add the deployment script to the `laravel/` directory:
```
$ cd home/example/laravel
$ curl https://raw.githubusercontent.com/hxgf/0x00-laravel-deploy/master/deploy-remote.sh -o deploy-remote.sh && chmod +x deploy-remote.sh
```

You could edit the branch and PHP/Composer binary path variables at the beginning of this file, but (assuming you're using "main") it should be good to go as-is.


At this point, the site should be online at `https://example.com` and `https://staging.example.com` 🤞🤞

If it's not, it's because you've done something wrong and god is mad at you. If it all worked, then that's great! 
Either way, it's time for a smoke break 🚬

#### NOTES:
- I haven't annotated what every command does, maybe I will at some point? Who cares?
- The storage symlink is the same thing that `php artisan storage:link` creates, you could do that if you'd rather.
- We're using the full path for the Composer binary. It will likely be the same on most systems, but you might want to run `which composer` first to verify.
- You could also run Laravel migrations and seeders at this point, but it's not necessary if you're starting with a dump of your local database (like I usually do)
- Permissions issues? Composer errors?_(fixit note what to do in case of problems)_


#### .env NOTES:
- Important variables to note, different from dev version:
  - APP_ENV=production
  - APP_DEBUG=false
  - LOG_LEVEL=error
- Change any variables with "XXXX" values (APP_NAME, APP_URL, DB credentials, etc)
- You _could_ generate a new application key here (using `php artisan key:generate`), but it's also ok to use the same key as your local dev .env
- It's ok to put a copy in the `laravel/` directory if you're going to need multiple copies of this






















# CI/CD workflow

If everything has been set up correctly, you should be able to run the deployment script locally and watch as the process unfolds:
```
./deploy.sh
```

Modify as needed, talk with your team, strategize, synergize, meditate, pray about it, but hopefully this is all you'll need to do to get a working deployment running on your WHM-based VPS.

We've sure come a long way from just FTP'ing files to a public directory, huh?






















# Future improvements

- [ ] deploy-remote: read site url from .env file and show link to site at the end of the process - https://askubuntu.com/questions/1389904/read-from-env-file-and-set-as-bash-variables

- [ ] deploy-remote: misc optimizations (more research needed)
    - ?? does `php artisan migrate` need `--force` ??
    - ?? storage link need to be run on every deploy?
    - ?? need to set permissions for storage/cache differently? 
      - ?? o+w instead of 755 (prob no)
        - chmod -R o+w storage
        - chmod -R o+w bootstrap/cache
    - ?? need to do anything about user-generated storage?
      - the "right" way to do this is still a mystery to me
      - is it supposed to go in the regular storage directory? don't want to overwrite anything on deploy, obv


- [ ] zero-downtime & versioned deployment concept - https://www.reddit.com/r/laravel/comments/zsnk0h/comment/j1cma8g/
	- [ ] symlink & swap, plan for rolling back versions if needed
	- [ ] build each deployment in its own custom directory (each one gets a custom id string)
	- "production" directory is a symlink to build dir
    - ex: `ln -s /home/hxgf/tx.hxgf.io/production /home/hxgf/tx.hxgf.io/build-123123123`
    - update the symlink on build finish
  - [ ] build offline, make a zip w/ everything pre-configured & replace production copy - https://www.reddit.com/r/laravel/comments/br684t/comment/eoaf399/
  - ?? how to handle rollbacks for migrations?

- [ ] possible easier workflow w/ envoy?
	- https://laravel.com/docs/10.x/envoy
	- https://blog.oussama-mater.tech/laravel-envoy/

- [ ] set up post-receive deployment - https://adevait.com/laravel/deploying-laravel-applications-virtual-private-servers









# Additional resources
- [Laravel - Deployment](https://laravel.com/docs/10.x/deployment)
- _(fixit add more, I've got a ton I'm sure)_





