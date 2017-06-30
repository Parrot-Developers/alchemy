
import os, logging
import stat
import tempfile
import subprocess
import shlex

#===============================================================================
#===============================================================================
class Ubi(object):
    def __init__(self):
        self.tmpRoot = tempfile.TemporaryDirectory()

#===============================================================================
#===============================================================================
def processTree(ubi, tree):
    for child in tree.children.values():
        fullPath = os.path.join(ubi.tmpRoot.name, child.filePath)
        if stat.S_IFMT(child.st.st_mode) == stat.S_IFDIR:
            os.mkdir(fullPath)
            processTree(ubi, child)
        elif stat.S_IFMT(child.st.st_mode) == stat.S_IFREG:
            with open(fullPath, "wb") as fout:
                fout.write(child.getData())
        elif stat.S_IFMT(child.st.st_mode) == stat.S_IFLNK:
            os.symlink(child.getData(), fullPath)
        elif stat.S_IFMT(child.st.st_mode) == stat.S_IFBLK:
            os.mknod(fullPath, child.st.st_mode)
        elif stat.S_IFMT(child.st.st_mode) == stat.S_IFCHR:
            os.mknod(fullPath, child.st.st_mode)

        # Update mode/owner, requires to be run under fakeroot to work properly
        try:
            if stat.S_IFMT(child.st.st_mode) != stat.S_IFLNK:
                os.chmod(fullPath, stat.S_IMODE(child.st.st_mode))
            os.chown(fullPath, child.st.st_uid, child.st.st_gid, follow_symlinks=False)
        except OSError:
            logging.error("Script must be run under fakeroot to work properly")
            raise

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

    # Re-create a root fs with contents and mode/owner set (requires fakeroot)
    ubi = Ubi()
    processTree(ubi, root)

    # Create file system image with mkfs.ubifs
    cmd = "%s %s -r %s %s" % (mkubifs, options.mkubifs, ubi.tmpRoot.name,
            image.filePath + ".ubifs")
    logging.info("In %s: %s", os.getcwd(), cmd)
    subprocess.check_call(shlex.split(cmd))

    # Create ubi image with ubinize
    cmd = "%s %s -o %s" % (ubinize, options.ubinize, image.filePath)
    logging.info("In %s: %s", options.ubinizeRoot, cmd)
    subprocess.check_call(shlex.split(cmd), cwd=options.ubinizeRoot)
