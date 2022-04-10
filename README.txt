MGT SAM Coupe
=============

Based on McLeod's SAM coupe core.  Added single disk drive reading from SDcard in either
FAT16 or FAT32 format in MGT format.  Also a PS2 mouse should be working - it works fine
on another board, but I don't have a splitter to test the ZXUNO yet.

Keys
----
- F12 - disk menu
- F5 - NMI button
- CTRL-ALT-DEL - reset SAM
- CTRL-ALT-Backspace - reset to BIOS.
- SCROLL-LOCK - switch from VGA to RGB and back.
- (numeric keypad [-]) - switch on/off scanlines

Known issues
------------
- Only 1 disk at the moment
- Only support for .MGT 80 track 10 sector, or CPM 80 track 9 sector format

Links to sites with disk images
-------------------------------
- https://velesoft.speccy.cz/download.htm
- http://ftp.nvg.ntnu.no/pub/sam-coupe/

Disk image support
------------------
Many emulators running on host systems with infinite resources accept disk formats in ZIP format.  This core
does not.  Whereas it might be interesting to allow that support, it would be at the expense of other functionality
so for the sake of extracting and converting disk formats, for the moment, only MGT and CPM format is supported.

There is no support for copy protected disks with odd formats at present, so sorry, Lemmings is out unless there's a
cracked version.  This may change, the ZIP format probably will not.

To convert disks use Simon Owen's excellent SAMdisk utility available here: https://simonowen.com/samdisk/

Feedback
--------
zx.micro.jack@gmail.com

ChangeLog
---------
release r1
  - Initial release

release r2
  - Joystick fix for all ZXUNOs
  - Brightness fix seen in POP wall textures
  - Blank first 40 sectors on create disk (effectively format properly - blank SAM disks are truly all zeros)
  
