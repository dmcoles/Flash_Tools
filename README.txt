==================================================================                  
                  Master SD device Misc Tools 
==================================================================

Here are some small tools i have built while hacking around with the Master SD
device. (http://ramtop-retro.uk/mastersd.html)

The device contains a SST39SF010 128k flash chip which is used to store the
mmfs rom that is used by the device.

The version of mmfs that is provided is modified specifically for this device
and is an older version of mmfs.

I wanted to see if I could use the latest versions of MMFS and MMFS2 on my device
and no upgrades were available so i set about figuring out how the hardware worked.

You can find forks of MMFS and ADFS 1.57 which i have updated for this device on github

https://github.com/dmcoles/MMFS
https://github.com/dmcoles/ADFS

It is possible to flash multiple roms onto the 16k banks of the flash chip on this
device and switch between them. However only the first 13.5k of rom can be
used in each bank as the device maps 2.5k of ram into the upper area (b600-bfff).

This means that the latest MMFS and MMFS2 can be flashed and do work without any
issues. The ADFS image can only be loaded into sideways RAM since it does not
fit in 13.5k.

All of the tools in this repository have been developed using information that was
reverse engineered and is not officially available so use these tools at your own
risk. You may well brick your device if you do something wrong (or even if you
do everything correctly as there are no guarantees).