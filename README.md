## PI Frame

Gaol: make a USB device for a digital picture frame that syncs with some images stored online.

Requirements:
    - Digital Picture Frame
    - Syncing USB Drive
    - Accessible Online Image Store

### Digital Picture Frame

The most important thing for our digital picture frame (aside from working at all),
is that it needs to be able to recognize when new images are there without us needing to manually power cycle the frame
or unplug/replug the USB.

I was originally gifted this frame:
Aluratek ADPF08SF: https://aluratek.com/eight-inch-digital-photo-frame
This frame seemed broken and could not load any images from any storage devices (USD or SD).

This one I later purchased seems to work pretty well, I am really happy with it:
https://www.amazon.com/gp/product/B07TZ43YJQ

The more types/sizes of images the frame supports, the better.
But, this is not very important.

### Syncing USB Drive

This is the crux of the entire project.
I decided to do this using a Raspberry PI Zero.
All we really need is an SBC with wifi and USB.
We can draw power from the frame itself using the same USB for data.

With wifi, we can periodically check for new images.
We will have to configure the Wifi for wherever the frame will stay.
With infinite money, it would be really interesting to use a pay-as-you-go data plan and 4G.

The masquerade the PI as a USB, we can just use the `g_mass_storag` kernel module:
    - https://linux-sunxi.org/USB_Gadget/Mass_storage
    - https://magpi.raspberrypi.org/articles/pi-zero-w-smart-usb-flash-drive

This let's us dd up a file that we can pretend it a USB device:
```
dd bs=1M if=/dev/zero of=/media/usb-data/data.bin count=16384
sync
sudo mkdosfs /media/usb-data/data.bin -F 32 -I
```

We can also mount this file.
This will let us copy images to it from the PI and let the picture frame see them as well.
The mount requires no special options, and here is an fstab entry:
```
# /etc/fstab

/media/usb-data/data.bin /media/frame vfat users,umask=000 0 2
```

To masquerade as a USB mass storage device, we just have to load the `g_mass_storage` module:
```
sudo modprobe g_mass_storage file=/media/usb-data/data.bin stall=0
```

To stop being a USB, just unload the module:
sudo rmmod g_mass_storage
```

To automatically load up the module, I found it easiest to use a systemd unit.
I first tried to load using `modules-load.d`, but kept running into all sorts of issues.
I think there was a timing issue on when the modules where loaded, since this requires the file on disk to be there.
Whatever the problem was, making a unit was easy:
```
# /etc/systemd/system/g_mass_storage.service

[Unit]
Description=Enable mass storage through USB.

[Service]
Type=simple
ExecStart=/sbin/modprobe g_mass_storage file=/media/usb-data/data.bin stall=0

[Install]
WantedBy=multi-user.target
`

Then just remember to enable to unit:
```
sudo systemctl enable g_mass_storage.service
```

Now once we download new images, we can just reload the module and pretend that the USB drive was unplugged and plugged back in.
This should work on a wide variety of frames.
```
sudo rmmod g_mass_storage
sudo systemctl restart g_mass_storage.service
```

I put the above commands in the sudoers file so I don't need a passowrd for them:
```
eriq ALL=(ALL) NOPASSWD: /sbin/rmmod g_mass_storage , /bin/systemctl restart g_mass_storage.service
```

### Accessible Online Image Store

My first candidate was Google Photos, since you can just use a shared album.
But it was a huge pain.
The API interfaces are actually pretty janky, and I could not find a permissions workflow that I was satisfied with.

Instead, I just went with a Wasabi (S3) bucket.
Ideally, I would want something even easier like a single web/file server.
But, then we would have to host it ourselves.
I also wanted something where I had to pay a little
(I know that may seem weird, but I didn't want to deal with ads or other privacy issues).
I was already paying for a Wasabi account, so I just went with that:
https://console.wasabisys.com/#/file_manager/piframe?region=us-west-1

To interface with is, we can use the standard AWS CLI interface (you can get it from the `awscli` package via pip).
You have to first configure it with:
```
aws configure --profile piframe
```

Then you can sync with:
```
aws s3 sync s3://piframe /media/frame  --endpoint-url=https://s3.us-west-1.wasabisys.com --profile piframe
```

The `sync.sh` script should handle fetching the images, converting them, and copying them over.
