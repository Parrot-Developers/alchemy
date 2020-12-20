
import os, logging
import subprocess
import shlex

#===============================================================================
#===============================================================================
def genImage(image, root, options, version=2, blocksize=1024):
    if blocksize < 1024 or (blocksize & (blocksize - 1)) != 0:
        raise ValueError("Bad value of blocksize: %d" % blocksize)

    if options.mke2fs is None:
        raise ValueError("Missing --mke2fs option")

    mke2fs = os.environ.get("MKE2FS", None)
    if mke2fs is None:
        raise ValueError("MKE2FS not found in environment")

    # Create file system image with mke2fs
    cmd = "%s -t ext%u -b %u %s -d %s %s %u" % (mke2fs, version, blocksize,
            options.mke2fs, root, image.filePath,
            image.size / 1024)
    logging.info("In %s: %s", os.getcwd(), cmd)
    subprocess.check_call(shlex.split(cmd))
