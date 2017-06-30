#===============================================================================
# Generate a file system image in 'tar' format.
#===============================================================================

import os
import stat
import tarfile
import io

# Convert a stat type to a tarfile type
# Note: socket are not supported
_STAT_TO_TAR_TYPE = {
    stat.S_IFDIR: tarfile.DIRTYPE,
    stat.S_IFCHR: tarfile.CHRTYPE,
    stat.S_IFBLK: tarfile.BLKTYPE,
    stat.S_IFREG: tarfile.REGTYPE,
    stat.S_IFIFO: tarfile.FIFOTYPE,
    stat.S_IFLNK: tarfile.SYMTYPE,
    stat.S_IFSOCK: None
}

#===============================================================================
#===============================================================================
def processTree(tarfd, tree):
    for child in tree.children.values():
        # Create file info
        info = tarfile.TarInfo()
        info.name = child.filePath
        info.mode = stat.S_IMODE(child.st.st_mode)
        info.type = _STAT_TO_TAR_TYPE[stat.S_IFMT(child.st.st_mode)]
        info.mtime = child.st.st_mtime
        info.uid = child.st.st_uid
        info.gid = child.st.st_gid

        # Setup content and links
        content = None
        if stat.S_IFMT(child.st.st_mode) == stat.S_IFREG:
            info.size = child.dataSize
            content = io.BytesIO(child.getData())
        elif stat.S_IFMT(child.st.st_mode) == stat.S_IFLNK:
            info.linkname = child.getData().decode("UTF-8")
        elif stat.S_IFMT(child.st.st_mode) == stat.S_IFCHR or \
                stat.S_IFMT(child.st.st_mode) == stat.S_IFBLK:
            info.devmajor = os.major(child.st.st_dev)
            info.devminor = os.minor(child.st.st_dev)

        # Add file and itd content
        tarfd.addfile(info, content)

        # Recursion for directories
        if stat.S_IFMT(child.st.st_mode) == stat.S_IFDIR:
            processTree(tarfd, child)

#===============================================================================
#===============================================================================
def genImage(image, root):
    tarfd = tarfile.open(fileobj=image.fout, mode="w")
    processTree(tarfd, root)
    tarfd.close()
