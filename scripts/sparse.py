#!/usr/bin/env python3

import sys, os, logging
import argparse
import struct
from io import StringIO

from mkextfs import ExtfsSuperBlock, EXTFS_SUPER_BLOCK_STRUCT_SIZE
from mkextfs import ExtfsGroupDescV2, EXTFS_GROUP_DESC_V2_STRUCT_SIZE
from mkextfs import EXTFS_SUPER_MAGIC

SPARSE_HEADER_MAGIC = 0xed26ff3a
SPARSE_MAJOR_VERSION = 1
SPARSE_MINOR_VERSION = 0

CHUNK_TYPE_RAW = 0xcac1
CHUNK_TYPE_FILL = 0xcac2
CHUNK_TYPE_SKIP = 0xcac3
CHUNK_TYPE_CRC32 = 0xcac4

_CHUNK_TYPE_TO_STR = {
    CHUNK_TYPE_RAW: "RAW",
    CHUNK_TYPE_FILL: "FILL",
    CHUNK_TYPE_SKIP: "SKIP",
    CHUNK_TYPE_CRC32: "CRC32",
}
def getChunkTypeStr(val):
    return _CHUNK_TYPE_TO_STR.get(val, "UNKNOWN(0x%04x)" % val)

SPARSE_HEADER_SIZE = 28
CHUNK_HEADER_SIZE = 12

#===============================================================================
# Wrapper just to avoid errors with pylint saying that methods
# from_buffer and from_address does not exist for class deriving from ctypes
# structures.
#===============================================================================
def _from_buffer_copy(cls, buf, off=0):
    return cls.from_buffer_copy(buf, off)

#===============================================================================
#===============================================================================
def alignUp(val, size):
    return (val + size - 1) & ~(size - 1)

#===============================================================================
#===============================================================================
class Extfs(object):
    def __init__(self, fin, sb):
        self.fin = fin
        self.sb = sb

        # Setup some internal variables
        self.blockSize = 1024 << self.sb.log_block_size
        self.blockCount = self.sb.blocks_count
        self.firstDataBlock = self.sb.first_data_block
        self.blocksPerGroup = self.sb.blocks_per_group
        assert self.blocksPerGroup > 0 and self.blocksPerGroup <= self.blockCount * 8
        self.groupDescStructSize = EXTFS_GROUP_DESC_V2_STRUCT_SIZE
        self.groupCount = (self.blockCount - self.firstDataBlock +
                self.blocksPerGroup - 1) // self.blocksPerGroup

        # Read group descriptors
        self.fin.seek((self.firstDataBlock + 1) * self.blockSize, os.SEEK_SET)
        self.groups = []
        for _ in range(0, self.groupCount):
            buf = fin.read(self.groupDescStructSize)
            group = _from_buffer_copy(ExtfsGroupDescV2, buf)
            self.groups.append(group)

        # Read block bitmaps
        self.bbmList = []
        for group in self.groups:
            bbmpos = group.block_bitmap
            self.fin.seek(bbmpos * self.blockSize, os.SEEK_SET)
            buf = fin.read(self.blockSize)
            self.bbmList.append(buf)

    def isBlockUsed(self, blockNum):
        if blockNum < self.firstDataBlock or blockNum >= self.blockCount:
            return True
        grp = (blockNum - self.firstDataBlock) // self.blocksPerGroup
        idx = (blockNum - self.firstDataBlock) % self.blocksPerGroup
        bbm = self.bbmList[grp]
        return (bbm[idx // 8] & 1 << (idx % 8)) != 0

    @staticmethod
    def load(fin):
        # Read super block at offset 1024
        fin.seek(1024, os.SEEK_SET)
        buf = fin.read(EXTFS_SUPER_BLOCK_STRUCT_SIZE)
        if buf is None or len(buf) != EXTFS_SUPER_BLOCK_STRUCT_SIZE:
            return None
        sb = _from_buffer_copy(ExtfsSuperBlock, buf)
        if sb.magic != EXTFS_SUPER_MAGIC:
            return None
        return Extfs(fin, sb)

#===============================================================================
#===============================================================================
class SparseHeader(object):
    _FMT = "<IHHHHIIII"
    def __init__(self):
        self.magic = SPARSE_HEADER_MAGIC
        self.major_version = SPARSE_MAJOR_VERSION
        self.minor_version = SPARSE_MINOR_VERSION
        self.file_hdr_sz = SPARSE_HEADER_SIZE
        self.chunk_hdr_sz = CHUNK_HEADER_SIZE
        self.blk_sz = 0
        self.total_blks = 0
        self.total_chunks = 0
        self.image_checksum = 0

    def read(self, fd):
        buf = fd.read(SPARSE_HEADER_SIZE)
        if len(buf) < SPARSE_HEADER_SIZE:
            raise ValueError("Failed to read file header")
        fields = struct.unpack(SparseHeader._FMT, buf)
        self.magic = fields[0]
        self.major_version = fields[1]
        self.minor_version = fields[2]
        self.file_hdr_sz = fields[3]
        self.chunk_hdr_sz = fields[4]
        self.blk_sz = fields[5]
        self.total_blks = fields[6]
        self.total_chunks = fields[7]
        self.image_checksum = fields[8]

        # Do some consistency checks
        if self.magic != SPARSE_HEADER_MAGIC:
            raise ValueError("Bad header magic: 0x%04x (0x%04x)" % (
                    self.magic, SPARSE_HEADER_MAGIC))
        if self.major_version != SPARSE_MAJOR_VERSION and \
                self.minor_version != SPARSE_MINOR_VERSION:
            raise ValueError("Bad version: %d.%d (%d.%d)" % (
                    self.major_version, self.minor_version,
                    SPARSE_MAJOR_VERSION, SPARSE_MINOR_VERSION))
        if self.file_hdr_sz < SPARSE_HEADER_SIZE:
            raise ValueError("Bad file header size: %d (%d)" % (
                    self.file_hdr_sz, SPARSE_HEADER_SIZE))
        if self.chunk_hdr_sz < CHUNK_HEADER_SIZE:
            raise ValueError("Bad chunk header size: %d (%d)" % (
                    self.chunk_hdr_sz, CHUNK_HEADER_SIZE))

        # Skip extra header bytes
        if self.file_hdr_sz - SPARSE_HEADER_SIZE > 0:
            fd.seek(self.file_hdr_sz - SPARSE_HEADER_SIZE, os.SEEK_CUR)

    def write(self, fd):
        buf = struct.pack(SparseHeader._FMT, self.magic,
                self.major_version, self.minor_version,
                self.file_hdr_sz, self.chunk_hdr_sz,
                self.blk_sz, self.total_blks,
                self.total_chunks, self.image_checksum)
        fd.write(buf)

    def __repr__(self):
        return ("{magic=0x%04x, major=%d, minor=%d, file_hdr_sz=%d chunk_hdr_sz=%d, " +
                "blk_sz=%d, total_blks=%d, total_chunks=%d, image_checksum=0x%04x}") % (
                self.magic, self.major_version, self.minor_version,
                self.file_hdr_sz, self.chunk_hdr_sz, self.blk_sz,
                self.total_blks, self.total_chunks, self.image_checksum)

#===============================================================================
#===============================================================================
class ChunkHeader(object):
    _FMT = "<HHII"
    def __init__(self, headerSize=CHUNK_HEADER_SIZE):
        self.headerSize = headerSize
        self.chunk_type = 0
        self.reserved1 = 0
        self.chunk_sz = 0
        self.total_sz = 0

    def read(self, fd):
        buf = fd.read(CHUNK_HEADER_SIZE)
        fields = struct.unpack(ChunkHeader._FMT, buf)
        self.chunk_type = fields[0]
        self.reserved1 = fields[1]
        self.chunk_sz = fields[2]
        self.total_sz = fields[3]

        # Do some consistency checks
        if self.total_sz < self.headerSize:
            raise ValueError("Bad chunk total size: %d (%d)" % (
                    self.total_sz, self.headerSize))

        # Skip extra header bytes
        if self.headerSize - CHUNK_HEADER_SIZE > 0:
            fd.seek(self.headerSize - SPARSE_HEADER_SIZE, os.SEEK_CUR)

    def write(self, fd):
        buf = struct.pack(ChunkHeader._FMT, self.chunk_type,
                self.reserved1, self.chunk_sz, self.total_sz)
        fd.write(buf)

    def __repr__(self):
        return "{type=%s, chunk_sz=%d, total_sz=%d}" % (
                getChunkTypeStr(self.chunk_type), self.chunk_sz, self.total_sz)

#===============================================================================
#===============================================================================
class Chunk(object):
    _COPY_SIZE = 65536
    _ZERO_BUF = "\x00" * 65536
    def __init__(self, headerSize=CHUNK_HEADER_SIZE):
        self.header = ChunkHeader(headerSize)
        self.value = 0
        self.offset = 0
        self.length = 0

    def finalizeHeader(self, blockSize):
        alignLen = alignUp(self.length, blockSize)
        self.header.chunk_sz = alignLen // blockSize
        if self.header.chunk_type == CHUNK_TYPE_RAW:
            self.header.total_sz = CHUNK_HEADER_SIZE + alignLen
        elif self.header.chunk_type == CHUNK_TYPE_FILL:
            self.header.total_sz = CHUNK_HEADER_SIZE + 4
        elif self.header.chunk_type == CHUNK_TYPE_SKIP:
            self.header.total_sz = CHUNK_HEADER_SIZE
        else:
            raise ValueError("Unsupported chunk type: %s" %
                    getChunkTypeStr(self.header.chunk_type))

    def readSparseImage(self, fin, blockSize):
        self.header.read(fin)
        self.offset = fin.tell()
        self.length = self.header.chunk_sz * blockSize
        if self.header.chunk_type == CHUNK_TYPE_RAW:
            if self.header.total_sz != self.header.headerSize + self.length:
                raise ValueError("Bad raw chunk total size: %d (%d)" % (
                        self.header.total_sz, self.header.headerSize + self.length))
            fin.seek(self.length, os.SEEK_CUR)
        elif self.header.chunk_type == CHUNK_TYPE_FILL:
            if self.header.total_sz != self.header.headerSize + 4:
                raise ValueError("Bad fill chunk total size: %d (%d)" % (
                        self.header.total_sz, self.header.headerSize + 4))
            self.value = struct.unpack("<I", fin.read(4))[0]
        elif self.header.chunk_type == CHUNK_TYPE_SKIP:
            if self.header.total_sz != self.header.headerSize:
                raise ValueError("Bad skip chunk total size: %d (%d)" % (
                        self.header.total_sz, self.header.headerSize))
        else:
            raise ValueError("Unsupported chunk type: %s" %
                    getChunkTypeStr(self.header.chunk_type))

    def _getFillBuf(self):
        if self.value == 0:
            return Chunk._ZERO_BUF
        else:
            fillBuf = StringIO()
            valBuf = struct.pack("<I", self.value)
            for _ in range(0, Chunk._COPY_SIZE // 4):
                fillBuf.write(valBuf)
            return fillBuf.getvalue()

    def _writeRaw(self, fin, fout):
        fin.seek(self.offset, os.SEEK_SET)
        remaining = self.length
        while remaining > 0:
            buf = fin.read(min(remaining, Chunk._COPY_SIZE))
            fout.write(buf)
            remaining -= len(buf)

    def _writeFillBuf(self, fout, fillBuf):
        remaining = self.length
        while remaining > 0:
            tmpLen = min(remaining, Chunk._COPY_SIZE)
            fout.write(fillBuf[0:tmpLen])
            remaining -= tmpLen

    def writeRawImage(self, fin, fout):
        if self.header.chunk_type == CHUNK_TYPE_RAW:
            self._writeRaw(fin, fout)
        elif self.header.chunk_type == CHUNK_TYPE_FILL:
            self._writeFillBuf(fout, self._getFillBuf())
        elif self.header.chunk_type == CHUNK_TYPE_SKIP:
            self._writeFillBuf(fout, Chunk._ZERO_BUF)
        else:
            raise ValueError("Unsupported chunk type: %s" %
                    getChunkTypeStr(self.header.chunk_type))

    def writeSparseImage(self, fin, fout):
        self.header.write(fout)
        if self.header.chunk_type == CHUNK_TYPE_RAW:
            self._writeRaw(fin, fout)
        elif self.header.chunk_type == CHUNK_TYPE_FILL:
            fout.write(struct.pack("<I", self.value))
        elif self.header.chunk_type == CHUNK_TYPE_SKIP:
            # Only header, not data
            pass
        else:
            raise ValueError("Unsupported chunk type: %s" %
                    getChunkTypeStr(self.header.chunk_type))

    def __repr__(self):
        return "{header=%s, val=0x%02x, off=%d, len=%d}" % (
                repr(self.header), self.value, self.offset, self.length)

#===============================================================================
#===============================================================================
class SparseFile(object):
    def __init__(self):
        self.header = SparseHeader()
        self.chunks = []

    def _addChunk(self, chunkType, value, offset, length):
        chunk = Chunk()
        chunk.header.chunk_type = chunkType
        chunk.value = value
        chunk.offset = offset
        chunk.length = length
        chunk.finalizeHeader(self.header.blk_sz)
        logging.debug(repr(chunk))
        self.chunks.append(chunk)

    def finalizeHeader(self, fileSize):
        self.header.total_blks = fileSize // self.header.blk_sz
        self.header.total_chunks = len(self.chunks)

    def readRawImage(self, fin, blockSize, extfs):
        curChunkType = None
        curVal = 0
        curOff = 0
        curLen = 0
        blockNum = 0

        # Determine file size
        fin.seek(0, os.SEEK_END)
        fileSize = fin.tell()
        fin.seek(0, os.SEEK_SET)
        logging.info("Read raw image: fileSize=%d blockSize=%d extfs=%s",
                fileSize, blockSize, extfs is not None)

        # Process input file
        self.header.blk_sz = blockSize
        while fin.tell() < fileSize:
            # Read block
            buf = fin.read(blockSize)

            # Determine kind for this block
            chunkType = CHUNK_TYPE_RAW
            if extfs is not None and not extfs.isBlockUsed(blockNum):
                chunkType = CHUNK_TYPE_SKIP
            elif len(buf) == blockSize:
                # determine value to check for filling
                if curChunkType != CHUNK_TYPE_FILL:
                    curVal = struct.unpack("<I", buf[0:4])[0]
                for i in range(0, blockSize, 4):
                    val = struct.unpack("<I", buf[i:i+4])[0]
                    if val != curVal:
                        break
                else:
                    chunkType = CHUNK_TYPE_FILL

            # Append to current chunk if same kind
            if chunkType == curChunkType:
                curLen += len(buf)
            else:
                # Finish current chunk, start a new one
                if curChunkType is not None:
                    self._addChunk(curChunkType, curVal, curOff, curLen)
                curOff += curLen
                curLen = len(buf)
                curChunkType = chunkType

            blockNum += 1

        # Finish last chunk and header
        if curChunkType is not None:
            self._addChunk(curChunkType, curVal, curOff, curLen)
        self.finalizeHeader(fileSize)

    def readSparseImage(self, fin):
        self.header.read(fin)
        logging.info("Read sparse image: %s", repr(self.header))
        for _ in range(0, self.header.total_chunks):
            chunk = Chunk()
            chunk.readSparseImage(fin, self.header.blk_sz)
            logging.debug(repr(chunk))
            self.chunks.append(chunk)

    def writeRawImage(self, fin, fout):
        for chunk in self.chunks:
            chunk.writeRawImage(fin, fout)

    def writeSparseImage(self, fin, fout):
        logging.info("Write sparse image: %s", repr(self.header))
        self.header.write(fout)
        for chunk in self.chunks:
            chunk.writeSparseImage(fin, fout)

    def __repr__(self):
        return "\n".join(
                ["header=%s" % repr(self.header)] +
                ["chunk[%d]=%s" % (i, repr(self.chunks[i]))
                        for i in range(0, len(self.chunks))])

#===============================================================================
#===============================================================================
def raw2Sparse(fin, fout, blockSize, extfs):
    sparseFile = SparseFile()
    sparseFile.readRawImage(fin, blockSize, extfs)
    sparseFile.writeSparseImage(fin, fout)

#===============================================================================
#===============================================================================
def sparse2Raw(fin, fout):
    sparseFile = SparseFile()
    sparseFile.readSparseImage(fin)
    sparseFile.writeRawImage(fin, fout)

#===============================================================================
# Main function.
#===============================================================================
def main():
    options = parseArgs()
    setupLog(options)
    inFilePath = options.inFile
    outFilePath = options.outFile

    # Open input image file
    try:
        fin = open(inFilePath, "rb")
    except IOError as ex:
        logging.error("Failed to open file: %s [err=%d %s]",
                inFilePath, ex.errno, ex.strerror)
        sys.exit(1)

    # Create output image file
    try:
        fout = open(outFilePath, "wb")
    except IOError as ex:
        logging.error("Failed to create file: %s [err=%d %s]",
                outFilePath, ex.errno, ex.strerror)
        sys.exit(1)

    try:
        if options.doSparse:
            # Is it a extfs image ?
            extfs = Extfs.load(fin)
            if extfs is not None:
                options.blockSize = extfs.blockSize
            raw2Sparse(fin, fout, options.blockSize, extfs)
        else:
            sparse2Raw(fin, fout)
    except ValueError as ex:
        logging.error(str(ex))
        sys.exit(1)

    fin.close()
    fout.close()

#===============================================================================
# Setup option parser and parse command line.
#===============================================================================
def parseArgs():
    parser = argparse.ArgumentParser()

    parser.add_argument("inFile", help="Input file")
    parser.add_argument("outFile", help="Output file")

    parser.add_argument("--sparse",
        dest="doSparse",
        action="store_true",
        default=True,
        help="create a sparse image from a raw image (default)")

    parser.add_argument("--unsparse",
        dest="doSparse",
        action="store_false",
        default=True,
        help="create a raw image from a sparse image")

    parser.add_argument("--size",
        type=int,
        dest="blockSize",
        default=4096,
        metavar="SIZE",
        help="block size (default: 4096 or auto for ext images)")

    parser.add_argument("-q",
        dest="quiet",
        action="store_true",
        default=False,
        help="be quiet")
    parser.add_argument("-v",
        dest="verbose",
        action="count",
        default=0,
        help="verbose output (more verbose if specified twice)")

    return parser.parse_args()

#===============================================================================
# Setup logging system.
#===============================================================================
def setupLog(options):
    logging.basicConfig(
        level=logging.WARNING,
        format="[%(levelname)s] %(message)s",
        stream=sys.stderr)
    logging.addLevelName(logging.CRITICAL, "C")
    logging.addLevelName(logging.ERROR, "E")
    logging.addLevelName(logging.WARNING, "W")
    logging.addLevelName(logging.INFO, "I")
    logging.addLevelName(logging.DEBUG, "D")

    # setup log level
    if options.quiet:
        logging.getLogger().setLevel(logging.CRITICAL)
    elif options.verbose >= 2:
        logging.getLogger().setLevel(logging.DEBUG)
    elif options.verbose >= 1:
        logging.getLogger().setLevel(logging.INFO)

#===============================================================================
# Entry point.
#===============================================================================
if __name__ == "__main__":
    main()
