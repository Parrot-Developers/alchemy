#===============================================================================
# Generate a file system image in 'cpio' format.
#===============================================================================

import os
import stat

#===============================================================================
#===============================================================================
class Cpio(object):
    def __init__(self, fout):
        self.writeLen = 0
        self.inode = 0
        self.fout = fout

    def align4(self):
        for _ in range(0, (4 - self.writeLen % 4) % 4):
            self.fout.write(b"\0")
            self.writeLen += 1

    def align512(self):
        for _ in range(0, (512 - self.writeLen % 512) % 512):
            self.fout.write(b"\0")
            self.writeLen += 1

    def write(self, buf):
        self.fout.write(buf)
        self.writeLen += len(buf)

    def writeHeader(self, entry):
        buf = ("%s%08x%08x%08x%08x%08x%08x%08x%08x%08x%08x%08x%08x%08x" % (
                "070701",
                self.inode,
                entry.st.st_mode,
                entry.st.st_uid,
                entry.st.st_gid,
                1,
                int(entry.st.st_mtime),
                entry.dataSize,
                0,
                0,
                os.major(entry.st.st_dev),
                os.minor(entry.st.st_dev),
                len(entry.filePath) + 1, 0))
        self.write(buf.encode("UTF-8"))
        self.write((entry.filePath + "\0").encode("UTF-8"))
        self.align4()
        self.inode += 1

    def writeTrailer(self):
        filePath = "TRAILER!!!"
        buf = ("%s%08x%08x%08x%08x%08x%08x%08x%08x%08x%08x%08x%08x%08x" % (
                "070701",
                self.inode,
                0,
                0,
                0,
                1,
                0,
                0,
                0,
                0,
                0,
                0,
                len(filePath) + 1, 0))
        self.write(buf.encode("UTF-8"))
        self.write((filePath + "\0").encode("UTF-8"))
        self.align512()
        self.inode += 1

#===============================================================================
#===============================================================================
def processTree(cpio, tree):
    for child in tree.children.values():
        if stat.S_IFMT(child.st.st_mode) == stat.S_IFDIR:
            # No data, only header, do recursion
            cpio.writeHeader(child)
            processTree(cpio, child)
        elif stat.S_IFMT(child.st.st_mode) == stat.S_IFREG:
            # Write file header and file content
            cpio.writeHeader(child)
            cpio.write(child.getData())
            cpio.align4()
        elif stat.S_IFMT(child.st.st_mode) == stat.S_IFLNK:
            # Data is link target
            cpio.writeHeader(child)
            cpio.write(child.getData())
            cpio.align4()
        elif stat.S_IFMT(child.st.st_mode) == stat.S_IFBLK:
            # No data, only header
            cpio.writeHeader(child)
        elif stat.S_IFMT(child.st.st_mode) == stat.S_IFCHR:
            # No data, only header
            cpio.writeHeader(child)

#===============================================================================
#===============================================================================
def genImage(image, root):
    cpio = Cpio(image.fout)
    processTree(cpio, root)
    cpio.writeTrailer()
