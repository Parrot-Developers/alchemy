
import os, logging
import subprocess
import shlex

#===============================================================================
#===============================================================================
def genImage(image, root, options):
    if not options.mkubifs:
        raise ValueError("Missing --mkubifs option")
    if not options.ubinize:
        raise ValueError("Missing --ubinize option")
    if not options.ubinizeRoot:
        raise ValueError("Missing --ubinize-root option")

    mkubifs = os.environ.get("MKUBIFS", None)
    ubinize = os.environ.get("UBINIZE", None)

    if mkubifs is None:
        raise ValueError("MKUBIFS not found in environment")
    if ubinize is None:
        raise ValueError("UBINIZE not found in environment")
    if not mkubifs or not ubinize:
        raise ValueError("Missing mkfs.ubifs/ubinize tools")

    # Create file system image with mkfs.ubifs
    cmd = "%s %s -r %s %s" % (mkubifs, options.mkubifs, root,
            image.filePath + ".ubifs")
    logging.info("In %s: %s", os.getcwd(), cmd)
    subprocess.check_call(shlex.split(cmd))

    # Create ubi image with ubinize
    cmd = "%s %s -o %s" % (ubinize, options.ubinize, image.filePath)
    logging.info("In %s: %s", options.ubinizeRoot, cmd)
    subprocess.check_call(shlex.split(cmd), cwd=options.ubinizeRoot)
