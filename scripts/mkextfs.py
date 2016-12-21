#===============================================================================
# Generate a file system image in 'extfs' format.
#===============================================================================

import os, logging
import stat
import ctypes
import mmap
import random
import time

EXTFS_SUPER_MAGIC = 0xef53

# Codes for operating systems
EXTFS_OS_LINUX = 0
EXTFS_OS_HURD = 1
EXTFS_OS_MASIX = 2
EXTFS_OS_FREEBSD = 3
EXTFS_OS_LITES = 4

# Revision levels
EXTFS_GOOD_OLD_REV = 0      # The good old (original) format
EXTFS_DYNAMIC_REV = 1       # V2 format w/ dynamic inode sizes

# Special inode numbers
EXTFS_BAD_INO = 1           # Bad blocks inode
EXTFS_ROOT_INO = 2          # Root inode
EXTFS_BOOT_LOADER_INO = 5   # Boot loader inode
EXTFS_UNDEL_DIR_INO = 6     # Undelete directory inode
EXTFS_RESIZE_INO = 7        # Reserved group descriptors inode (ext3fs+)
EXTFS_JOURNAL_INO = 8       # Journal inode (ext3fs+)
EXTFS_FIRST_INO = 11        # First non-reserved inode

# Constants relative to the data blocks
EXTFS_NDIR_BLOCKS = 12
EXTFS_IND_BLOCK = EXTFS_NDIR_BLOCKS
EXTFS_DIND_BLOCK = EXTFS_IND_BLOCK + 1
EXTFS_TIND_BLOCK = EXTFS_DIND_BLOCK + 1
EXTFS_N_BLOCKS = EXTFS_TIND_BLOCK + 1

EXTFS_NAME_LEN = 255

EXTFS_EXT_MAGIC = 0xf30a
EXTFS_EXT_ENTRY_SIZE = 12

# EXTFS_SUPER_BLOCK::feature_compat
EXTFS_FEATURE_COMPAT_DIR_PREALLOC = 0x0001
EXTFS_FEATURE_COMPAT_IMAGIC_INODES = 0x0002
EXTFS_FEATURE_COMPAT_HAS_JOURNAL = 0x0004
EXTFS_FEATURE_COMPAT_EXT_ATTR = 0x0008
EXTFS_FEATURE_COMPAT_RESIZE_INODE = 0x0010
EXTFS_FEATURE_COMPAT_DIR_INDEX = 0x0020

# EXTFS_SUPER_BLOCK::feature_ro_compat
EXTFS_FEATURE_RO_COMPAT_SPARSE_SUPER = 0x0001
EXTFS_FEATURE_RO_COMPAT_LARGE_FILE = 0x0002
EXTFS_FEATURE_RO_COMPAT_BTREE_DIR = 0x0004
EXTFS_FEATURE_RO_COMPAT_HUGE_FILE = 0x0008      # ext4fs+
EXTFS_FEATURE_RO_COMPAT_GDT_CSUM = 0x0010       # ext4fs+
EXTFS_FEATURE_RO_COMPAT_DIR_NLINK = 0x0020      # ext4fs+
EXTFS_FEATURE_RO_COMPAT_EXTRA_ISIZE = 0x0040    # ext4fs+

# EXTFS_SUPER_BLOCK::feature_incompat
EXTFS_FEATURE_INCOMPAT_COMPRESSION = 0x0001
EXTFS_FEATURE_INCOMPAT_FILETYPE = 0x0002
EXTFS_FEATURE_INCOMPAT_RECOVER = 0x0004
EXTFS_FEATURE_INCOMPAT_JOURNAL_DEV = 0x0008
EXTFS_FEATURE_INCOMPAT_META_BG = 0x0010
EXTFS_FEATURE_INCOMPAT_EXTENTS = 0x0040     # ext4fs+
EXTFS_FEATURE_INCOMPAT_64BIT = 0x0080       # ext4fs+
EXTFS_FEATURE_INCOMPAT_MMP = 0x0100         # ext4fs+
EXTFS_FEATURE_INCOMPAT_FLEX_BG = 0x0200     # ext4fs+

# EXTFS_GROUP_DESC::flags
EXTFS_BG_INODE_UNINIT = 0x0001              # Inode table/bitmap not in use (ext4fs+)
EXTFS_BG_BLOCK_UNINIT = 0x0002              # Block bitmap not in use (ext4fs+)
EXTFS_BG_INODE_ZEROED = 0x0004              # On-disk itable initialized to zero (ext4fs+)

# EXTFS_INODE::flags
EXTFS_INODE_FLAG_SECRM = 0x00000001         # Secure deletion
EXTFS_INODE_FLAG_UNRM = 0x00000002          # Undelete
EXTFS_INODE_FLAG_COMPR = 0x00000004         # Compress file
EXTFS_INODE_FLAG_SYNC = 0x00000008          # Synchronous updates
EXTFS_INODE_FLAG_IMMUTABLE = 0x00000010     # Immutable file
EXTFS_INODE_FLAG_APPEND = 0x00000020        # Writes to file may only append
EXTFS_INODE_FLAG_NODUMP = 0x00000040        # Do not dump file
EXTFS_INODE_FLAG_NOATIME = 0x00000080       # Do not update atime
EXTFS_INODE_FLAG_DIRTY = 0x00000100         #
EXTFS_INODE_FLAG_COMPRBLK = 0x00000200      # One or more compressed clusters
EXTFS_INODE_FLAG_NOCOMP = 0x00000400        # Don't compress
EXTFS_INODE_FLAG_ECOMPR = 0x00000800        # Compression error
EXTFS_INODE_FLAG_INDEX = 0x00001000         # Hash-indexed directory
EXTFS_INODE_FLAG_IMAGIC = 0x00002000        # AFS directory
EXTFS_INODE_FLAG_JOURNAL_DATA = 0x00004000  # (ext3fs+)
EXTFS_INODE_FLAG_NOTAIL = 0x00008000        # File tail should not be merged
EXTFS_INODE_FLAG_DIRSYNC = 0x00010000       # Dir sync behaviour (directories only)
EXTFS_INODE_FLAG_TOPDIR = 0x00020000        # Top of directory hierarchies
EXTFS_INODE_FLAG_HUGE_FILE = 0x00040000     # Set to each huge file (ext4fs+)
EXTFS_INODE_FLAG_EXTENTS = 0x00080000       # Inode uses extents (ext4fs+)
EXTFS_INODE_FLAG_EXT_MIGRATE = 0x00100000   # Inode is migrating (ext4fs+)
EXTFS_INODE_FLAG_RESERVED = 0x80000000      # Reserved for ext lib

# Size of structures
EXTFS_SUPER_BLOCK_STRUCT_SIZE = 1024
EXTFS_GROUP_DESC_V2_STRUCT_SIZE = 32
EXTFS_GROUP_DESC_V3_STRUCT_SIZE = 32
EXTFS_GROUP_DESC_V4_STRUCT_SIZE = 64
EXTFS_INODE_V2_STRUCT_SIZE = 128
EXTFS_INODE_V3_STRUCT_SIZE = 132
EXTFS_INODE_V4_STRUCT_SIZE = 156

EXTFS_DIRENTRY_STRUCT_NO_NAME_SIZE = 8

# Extfs directory file types. Only the low 3 bits are used.
# The other bits are reserved for now.
EXTFS_FILE_TYPE_UNKNOWN = 0
EXTFS_FILE_TYPE_REGULAR = 1
EXTFS_FILE_TYPE_DIR = 2
EXTFS_FILE_TYPE_CHARDEV = 3
EXTFS_FILE_TYPE_BLOCKDEV = 4
EXTFS_FILE_TYPE_FIFO = 5
EXTFS_FILE_TYPE_SOCKET = 6
EXTFS_FILE_TYPE_SYMLINK = 7
EXTFS_FILE_TYPE_MAX = 8

EXTFS_FILE_TYPE_FROM_STAT_TYPE = {
    stat.S_IFREG: EXTFS_FILE_TYPE_REGULAR,
    stat.S_IFDIR: EXTFS_FILE_TYPE_DIR,
    stat.S_IFCHR: EXTFS_FILE_TYPE_CHARDEV,
    stat.S_IFBLK: EXTFS_FILE_TYPE_BLOCKDEV,
    stat.S_IFIFO: EXTFS_FILE_TYPE_FIFO,
    stat.S_IFSOCK: EXTFS_FILE_TYPE_SOCKET,
    stat.S_IFLNK: EXTFS_FILE_TYPE_SYMLINK,
}

#===============================================================================
# Wrapper just to avoid errors with pylint saying that methods
# from_buffer and from_address does not exist for class deriving from ctypes
# structures.
#===============================================================================
def _from_buffer(cls, buf, off=0):
    return cls.from_buffer(buf, off)

#===============================================================================
#===============================================================================
def _from_address(cls, addr):
    return cls.from_address(addr)

#===============================================================================
# Structure of the super block
# Journaling support valid if EXTFS_FEATURE_COMPAT_HAS_JOURNAL
# 64-bit support valid if EXTFS_FEATURE_COMPAT_64BIT
#===============================================================================
class ExtfsSuperBlock(ctypes.LittleEndianStructure):
    _fields_ = [
        ("inodes_count", ctypes.c_uint32),          # Inodes count
        ("blocks_count", ctypes.c_uint32),          # Blocks count
        ("r_blocks_count", ctypes.c_uint32),        # Reserved blocks count
        ("free_blocks_count", ctypes.c_uint32),     # Free blocks count
        ("free_inodes_count", ctypes.c_uint32),     # Free inodes count
        ("first_data_block", ctypes.c_uint32),      # First Data Block
        ("log_block_size", ctypes.c_uint32),        # Block size
        ("log_frag_size", ctypes.c_uint32),         # Fragment size
        ("blocks_per_group", ctypes.c_uint32),      # Blocks per group
        ("frags_per_group", ctypes.c_uint32),       # Fragments per group
        ("inodes_per_group", ctypes.c_uint32),      # Inodes per group
        ("mtime", ctypes.c_uint32),                 # Mount time
        ("wtime", ctypes.c_uint32),                 # Write time
        ("mnt_count", ctypes.c_uint16),             # Mount count
        ("max_mnt_count", ctypes.c_uint16),         # Maximal mount count
        ("magic", ctypes.c_uint16),                 # Magic signature
        ("state", ctypes.c_uint16),                 # File system state
        ("errors", ctypes.c_uint16),                # Behaviour when detecting errors
        ("minor_rev_level", ctypes.c_uint16),       # Minor revision level
        ("lastcheck", ctypes.c_uint32),             # Time of last check
        ("checkinterval", ctypes.c_uint32),         # Max. time between checks
        ("creator_os", ctypes.c_uint32),            # OS
        ("rev_level", ctypes.c_uint32),             # Revision level
        ("def_resuid", ctypes.c_uint16),            # Default uid for reserved blocks
        ("def_resgid", ctypes.c_uint16),            # Default gid for reserved blocks
        # These fields are for EXTFS_DYNAMIC_REV superblocks only.
        ("first_ino", ctypes.c_uint32),             # First non-reserved inode
        ("inode_size", ctypes.c_uint16),            # Size of inode structure
        ("block_group_nr", ctypes.c_uint16),        # Block group # of this superblock
        ("feature_compat", ctypes.c_uint32),        # Compatible feature set
        ("feature_incompat", ctypes.c_uint32),      # Incompatible feature set
        ("feature_ro_compat", ctypes.c_uint32),     # Readonly-compatible feature set
        ("uuid", ctypes.c_uint8 * 16),              # 128-bit uuid for volume
        ("volume_name", ctypes.c_uint8 * 16),       # Volume name
        ("last_mounted", ctypes.c_uint8 * 64),      # Directory where last mounted
        ("algorithm_usage_bitmap", ctypes.c_uint32),# For compression
        ("prealloc_blocks", ctypes.c_uint8),        # Nr of blocks to try to preallocate
        ("prealloc_dir_blocks", ctypes.c_uint8),    # Nr to preallocate for dirs
        ("reserved_gdt_blocks", ctypes.c_uint16),   # Per group desc for online growth (ext3fs+)
        ("journal_uuid", ctypes.c_uint8 * 16),      # uuid of journal superblock
        ("journal_inum", ctypes.c_uint32),          # Inode number of journal file
        ("journal_dev", ctypes.c_uint32),           # Device number of journal file
        ("last_orphan", ctypes.c_uint32),           # Start of list of inodes to delete
        ("hash_seed", ctypes.c_uint32 * 4),         # HTREE hash seed
        ("def_hash_version", ctypes.c_uint8),       # Default hash version to use
        ("reserved_char_pad", ctypes.c_uint8),      #
        ("desc_size", ctypes.c_uint16),             # Size of group descriptor (ext4fs+)
        ("default_mount_opts", ctypes.c_uint32),    #
        ("first_meta_bg", ctypes.c_uint32),         # First metablock block group
        # (ext3fs+)
        ("mkfs_time", ctypes.c_uint32),             # When the filesystem was created
        ("jnl_blocks", ctypes.c_uint32 * 17),       # Backup of the journal inode
        ("blocks_count_hi", ctypes.c_uint32),       # Blocks count
        ("r_blocks_count_hi", ctypes.c_uint32),     # Reserved blocks count
        ("free_blocks_count_hi", ctypes.c_uint32),  # Free blocks count
        ("min_extra_isize", ctypes.c_uint16),       # All inodes have at least # bytes
        ("want_extra_isize", ctypes.c_uint16),      # New inodes should reserve # bytes
        ("flags", ctypes.c_uint32),                 # Miscellaneous flags
        ("raid_stride", ctypes.c_uint16),           # U16 : RAID stride
        ("mmp_interval", ctypes.c_uint16),          # Seconds to wait in MMP checking
        ("mmp_block", ctypes.c_uint64),             # Block for multi-mount protection
        ("raid_stripe_width", ctypes.c_uint32),     # Blocks on all data disks (N*stride)
        ("log_groups_per_flex", ctypes.c_uint8),    # FLEX_BG group size
        ("reserved_char_pad2", ctypes.c_uint8),     #
        ("reserved_pad", ctypes.c_uint16),          #
        ("kbytes_written", ctypes.c_uint64),        # Nr of lifetime kilobytes written (ext4fs+)
        ("reserved", ctypes.c_uint32 * 160),        # Padding to the end of the block
    ]
assert ctypes.sizeof(ExtfsSuperBlock) == EXTFS_SUPER_BLOCK_STRUCT_SIZE

#===============================================================================
# Structure of a blocks group descriptor
#===============================================================================

# Common part
class ExtfsGroupDescCommon(ctypes.LittleEndianStructure):
    _fields_ = [
        ("block_bitmap", ctypes.c_uint32),          # Blocks bitmap block
        ("inode_bitmap", ctypes.c_uint32),          # Inodes bitmap block
        ("inode_table", ctypes.c_uint32),           # Inodes table block
        ("free_blocks_count", ctypes.c_uint16),     # Free blocks count
        ("free_inodes_count", ctypes.c_uint16),     # Free inodes count
        ("used_dirs_count", ctypes.c_uint16),       # Directories count
        ("flags", ctypes.c_uint16),                 # EXTFS_BG_flags (ext4fs+)
    ]

# ext2
class ExtfsGroupDescV2(ExtfsGroupDescCommon):
    _fields_ = [
        ("reserved", ctypes.c_uint32 * 3),          # Reserved
    ]

# ext3 is same as ext2
ExtfsGroupDescV3 = ExtfsGroupDescV2

# ext4
class ExtfsGroupDescV4(ExtfsGroupDescCommon):
    _fields_ = [
        ("reserved", ctypes.c_uint32 * 2),          # Reserved
        ("itable_unused", ctypes.c_uint16),         # Unused inodes count
        ("checksum", ctypes.c_uint16),              # crc16(sb_uuid+group+desc)
        # (ext4fs+) when 64-bit block number support is enabled
        ("block_bitmap_hi", ctypes.c_uint32),       # Blocks bitmap block MSB
        ("inode_bitmap_hi", ctypes.c_uint32),       # Inodes bitmap block MSB
        ("inode_table_hi", ctypes.c_uint32),        # Inodes table block MSB
        ("free_blocks_count_hi", ctypes.c_uint16),  # Free blocks count MSB
        ("free_inodes_count_hi", ctypes.c_uint16),  # Free inodes count MSB
        ("used_dirs_count_hi", ctypes.c_uint16),    # Directories count MSB
        ("itable_unused_hi", ctypes.c_uint16),      # Unused inodes count MSB
        ("reserved2", ctypes.c_uint32 * 3),
    ]

assert ctypes.sizeof(ExtfsGroupDescV2) == EXTFS_GROUP_DESC_V2_STRUCT_SIZE
assert ctypes.sizeof(ExtfsGroupDescV3) == EXTFS_GROUP_DESC_V3_STRUCT_SIZE
assert ctypes.sizeof(ExtfsGroupDescV4) == EXTFS_GROUP_DESC_V4_STRUCT_SIZE

#===============================================================================
# Structure of an inode on the disk
#===============================================================================

# Common part
class ExtfsInodeCommon(ctypes.LittleEndianStructure):
    _fields_ = [
        ("mode", ctypes.c_uint16),                  # File mode
        ("uid", ctypes.c_uint16),                   # Low 16 bits of Owner Uid
        ("size", ctypes.c_uint32),                  # Size in bytes
        ("atime", ctypes.c_uint32),                 # Access time
        ("ctime", ctypes.c_uint32),                 # Inode Change time
        ("mtime", ctypes.c_uint32),                 # Modification time
        ("dtime", ctypes.c_uint32),                 # Deletion Time
        ("gid", ctypes.c_uint16),                   # Low 16 bits of Group Id
        ("links_count", ctypes.c_uint16),           # Links count
        ("blocks", ctypes.c_uint32),                # Blocks count
        ("flags", ctypes.c_uint32),                 # File flags
        ("version", ctypes.c_uint32),               #
        ("block", ctypes.c_uint32 * EXTFS_N_BLOCKS),# Pointers to blocks
        ("generation", ctypes.c_uint32),            # File version (for NFS)
        ("file_acl", ctypes.c_uint32),              # File ACL
    ]

# ext2
class ExtfsInodeV2(ExtfsInodeCommon):
    _fields_ = [
        ("dir_acl", ctypes.c_uint32),       # Directory ACL
        ("faddr", ctypes.c_uint32),         # fragment address
        ("frag", ctypes.c_uint8),           # Fragment number
        ("fsize", ctypes.c_uint8),          # Fragment size
        ("pad1", ctypes.c_uint16),          #
        ("uid_high", ctypes.c_uint16),      #
        ("gid_high", ctypes.c_uint16),      #
        ("reserved2", ctypes.c_uint32),     #
    ]

# ext3
class ExtfsInodeV3(ExtfsInodeCommon):
    _fields_ = [
        ("dir_acl", ctypes.c_uint32),       # Directory ACL
        ("faddr", ctypes.c_uint32),         # fragment address
        ("frag", ctypes.c_uint8),           # Fragment number
        ("fsize", ctypes.c_uint8),          # Fragment size
        ("pad1", ctypes.c_uint16),          #
        ("uid_high", ctypes.c_uint16),      #
        ("gid_high", ctypes.c_uint16),      #
        ("reserved2", ctypes.c_uint32),     #
        ("extra_isize", ctypes.c_uint16),   #
        ("pad1", ctypes.c_uint16),          #
    ]

# ext4
class ExtfsInodeV4(ExtfsInodeCommon):
    _fields_ = [
        ("size_high", ctypes.c_uint32),     #
        ("obso_faddr", ctypes.c_uint32),    # Obsoleted fragment address
        ("blocks_high", ctypes.c_uint16),   #
        ("file_acl_high", ctypes.c_uint16), #
        ("uid_high", ctypes.c_uint16),      #
        ("gid_high", ctypes.c_uint16),      #
        ("reserved2", ctypes.c_uint32),     #
        ("extra_isize", ctypes.c_uint16),   #
        ("pad1", ctypes.c_uint16),          #
        ("ctime_extra", ctypes.c_uint32),   # Extra Change time      (nsec << 2 | epoch)
        ("mtime_extra", ctypes.c_uint32),   # Extra Modification time(nsec << 2 | epoch)
        ("atime_extra", ctypes.c_uint32),   # Extra Access time      (nsec << 2 | epoch)
        ("crtime", ctypes.c_uint32),        # File Creation time
        ("crtime_extra", ctypes.c_uint32),  # Extra FileCreationtime (nsec << 2 | epoch)
        ("version_hi", ctypes.c_uint32),    # High 32 bits for 64-bit version
    ]

assert ctypes.sizeof(ExtfsInodeV2) == EXTFS_INODE_V2_STRUCT_SIZE
assert ctypes.sizeof(ExtfsInodeV3) == EXTFS_INODE_V3_STRUCT_SIZE
assert ctypes.sizeof(ExtfsInodeV4) == EXTFS_INODE_V4_STRUCT_SIZE

#===============================================================================
# Structure of a directory entry (actual name length is in name_len)
#===============================================================================
class ExtfsDirEntry(ctypes.LittleEndianStructure):
    _fields_ = [
        ("inode", ctypes.c_uint32),                     # Inode number
        ("rec_len", ctypes.c_uint16),                   # Directory entry length
        ("name_len", ctypes.c_uint8),                   # Name length
        ("file_type", ctypes.c_uint8),                  # File type
        ("name", ctypes.c_uint8 * (EXTFS_NAME_LEN + 1)),# File name (null-terminated)
    ]
assert ctypes.sizeof(ExtfsDirEntry) == EXTFS_DIRENTRY_STRUCT_NO_NAME_SIZE + EXTFS_NAME_LEN + 1

#===============================================================================
# This is the extent on-disk structure. It's used at the bottom of the tree.
#===============================================================================
class ExtfsExtent(ctypes.LittleEndianStructure):
    _fields_ = [
        ("block", ctypes.c_uint32),         # First logical block extent covers
        ("len", ctypes.c_uint16),           # Number of blocks covered by extent
        ("start_hi", ctypes.c_uint16),      # High 16 bits of physical block
        ("start_lo", ctypes.c_uint32),      # Low 32 bits of physical block
    ]
assert ctypes.sizeof(ExtfsExtent) == EXTFS_EXT_ENTRY_SIZE

#===============================================================================
# This is index on-disk structure. It's used at all the levels except the bottom.
#===============================================================================
class ExtfsExtentIdx(ctypes.LittleEndianStructure):
    _fields_ = [
        ("block", ctypes.c_uint32),         # Index covers logical blocks from 'block'
        ("leaf_lo", ctypes.c_uint32),       # Physical block of the next level.
        ("leaf_hi", ctypes.c_uint16),       # High 16 bits of physical block
        ("unused", ctypes.c_uint16),        #
    ]
assert ctypes.sizeof(ExtfsExtentIdx) == EXTFS_EXT_ENTRY_SIZE

#===============================================================================
# Each block (leaves and indexes), even inode-stored has header.
#===============================================================================
class ExtfsExtentHeader(ctypes.LittleEndianStructure):
    _fields_ = [
        ("magic", ctypes.c_uint16),         # Probably will support different formats
        ("entries", ctypes.c_uint16),       # Number of valid entries
        ("max", ctypes.c_uint16),           # Capacity of store in entries
        ("depth", ctypes.c_uint16),         # Has tree real underlying blocks?
        ("generation", ctypes.c_uint32),    # Generation of the tree
    ]

#===============================================================================
#===============================================================================
class ExtfsJournalSuperBlock(ctypes.BigEndianStructure):
    _fields_ = [
        ("magic", ctypes.c_uint32),         #
        ("blocktype", ctypes.c_uint32),     #
        ("sequence", ctypes.c_uint32),      #
        ("blocksize", ctypes.c_uint32),     # Journal device blocksize
        ("maxlen", ctypes.c_uint32),        # Total blocks in journal file
        ("first", ctypes.c_uint32),         # First block of log information
        ("sequence", ctypes.c_uint32),      # First commit ID expected in log
        ("start", ctypes.c_uint32),         # blocknr of start of log
        ("errno", ctypes.c_int32),          # Error value
        ("feature_compat", ctypes.c_uint32),    # compatible feature set
        ("feature_incompat", ctypes.c_uint32),  # incompatible feature set
        ("feature_ro_compat", ctypes.c_uint32), # readonly-compatible feature set
        ("uuid", ctypes.c_uint8 * 16),          # 128-bit uuid for journal
        ("nr_users", ctypes.c_uint32),          # Nr of filesystems sharing log
        ("dynsuper", ctypes.c_uint32),          # Blocknr of dynamic superblock copy
        ("max_transaction", ctypes.c_uint32),   # Limit of journal blocks per trans
        ("max_trans_data", ctypes.c_uint32),    # Limit of data blocks per trans
        ("padding", ctypes.c_uint32 * 44),      #
        ("users", ctypes.c_uint8 * 16 * 48),    # ids of all fs'es sharing the log
    ]
assert ctypes.sizeof(ExtfsJournalSuperBlock) == 1024

JFS_MAGIC_NUMBER = 0xc03b3998
JFS_DESCRIPTOR_BLOCK = 1
JFS_COMMIT_BLOCK = 2
JFS_SUPERBLOCK_V1 = 3
JFS_SUPERBLOCK_V2 = 4
JFS_REVOKE_BLOCK = 5

#===============================================================================
#===============================================================================
class Extfs(object):
    LOG_BLOCKSIZE = 0
    BLOCKSIZE = 1024 * (1 << LOG_BLOCKSIZE)
    MAX_BLOCKS_PER_GROUP = BLOCKSIZE * 8
    MAX_INODES_PER_GROUP = BLOCKSIZE * 8
    INODE_BLOCKSIZE = 512
    INOBLK = BLOCKSIZE // INODE_BLOCKSIZE
    INODE_RATIO = 4096
    RESERVED_RATIO = 5

    def __init__(self, buf, blockCount, inodeCount, reservedBlockCount, version=2):
        self.buf = buf
        self.sb = _from_buffer(ExtfsSuperBlock, self.buf, 1024)
        self.groups = []
        logging.debug("blockCount=%d", blockCount)
        logging.debug("inodeCount=%d", inodeCount)

        # Always use v2 structures
        # Inode v3 and v4 requires inode size to be 256 instead of 128
        # Group desc v3 is same as v2
        # Group desc v4 is for 64-bit block numbers (big images)
        self.inodeStructType = ExtfsInodeV2
        self.inodeStructSize = EXTFS_INODE_V2_STRUCT_SIZE
        self.groupDescStructType = ExtfsGroupDescV2
        self.groupDescStructSize = EXTFS_GROUP_DESC_V2_STRUCT_SIZE

        # Check parameters
        if reservedBlockCount < 0:
            raise ValueError("Bad reserved block count")
        if inodeCount < EXTFS_FIRST_INO:
            raise ValueError("Bad inode count")
        if blockCount < 8:
            raise ValueError("Bad block count")

        firstDataBlock = 1 if (Extfs.BLOCKSIZE == 1024) else 0
        logging.debug("firstDataBlock=%d", firstDataBlock)

        # Determine number of groups
        minGroupCount = ((inodeCount + Extfs.MAX_INODES_PER_GROUP - 1) //
                Extfs.MAX_INODES_PER_GROUP)
        groupCount = ((blockCount - firstDataBlock + Extfs.MAX_BLOCKS_PER_GROUP - 1) //
                Extfs.MAX_BLOCKS_PER_GROUP)
        if groupCount < minGroupCount:
            groupCount = minGroupCount
        logging.debug("groupCount=%d", groupCount)

        # Determine number of blocks per group, shall be a multiple of 8
        blocksPerGroup = (blockCount - firstDataBlock + groupCount - 1) // groupCount
        if blocksPerGroup % 8 != 0:
            blocksPerGroup += 8 - blocksPerGroup % 8
        logging.debug("blocksPerGroup=%d", blocksPerGroup)
        assert blocksPerGroup <= Extfs.MAX_BLOCKS_PER_GROUP

        # Determine number of inodes per group
        inodesPerGroup = (inodeCount + groupCount - 1) // groupCount
        if inodesPerGroup < 16:
            inodesPerGroup = 16
        if inodesPerGroup > Extfs.MAX_INODES_PER_GROUP:
            inodesPerGroup = Extfs.MAX_INODES_PER_GROUP
        if inodesPerGroup % 8 != 0:
            inodesPerGroup += 8 - inodesPerGroup % 8
        logging.debug("inodesPerGroup=%d", inodesPerGroup)

        groupDescSize = groupCount * self.groupDescStructSize
        groupDescSize = (groupDescSize + Extfs.BLOCKSIZE - 1) // Extfs.BLOCKSIZE
        inodeTableSize = inodesPerGroup * self.inodeStructSize
        inodeTableSize = (inodeTableSize + Extfs.BLOCKSIZE - 1) // Extfs.BLOCKSIZE
        logging.debug("groupDescSize=%d", groupDescSize)
        logging.debug("inodeTableSize=%d", inodeTableSize)

        # Overhead per group : superblock, the block group descriptors,
        # the block bitmap, the inode bitmap, the inode table
        overheadPerGroup = 1 + groupDescSize + 1 + 1 + inodeTableSize
        if blockCount - firstDataBlock < overheadPerGroup * groupCount:
            raise ValueError("Too much overhead")
        freeBlockCount = blockCount - firstDataBlock - overheadPerGroup * groupCount
        freeBlocksPerGroup = blocksPerGroup - overheadPerGroup
        logging.debug("overheadPerGroup=%d", overheadPerGroup)
        logging.debug("freeBlockCount=%d", freeBlockCount)
        logging.debug("freeBlocksPerGroup=%d", freeBlocksPerGroup)

        # Check that last group has enough room for internal stuff
        blockCountInLastGroup = (blockCount - firstDataBlock) % blocksPerGroup
        logging.debug("blockCountInLastGroup=%d", blockCountInLastGroup)
        if blockCountInLastGroup > 0 and blockCountInLastGroup <= overheadPerGroup:
            raise ValueError("Last block group too small")

        # Create the superblock for an empty filesystem
        self.sb.inodes_count = inodesPerGroup * groupCount
        self.sb.blocks_count = blockCount
        self.sb.r_blocks_count = reservedBlockCount
        self.sb.free_blocks_count = freeBlockCount
        self.sb.free_inodes_count = self.sb.inodes_count - EXTFS_FIRST_INO + 1
        self.sb.first_data_block = firstDataBlock
        self.sb.log_block_size = Extfs.LOG_BLOCKSIZE
        self.sb.log_frag_size = self.sb.log_block_size
        self.sb.blocks_per_group = blocksPerGroup
        self.sb.frags_per_group = blocksPerGroup
        self.sb.inodes_per_group = inodesPerGroup
        self.sb.magic = EXTFS_SUPER_MAGIC
        self.sb.creator_os = EXTFS_OS_LINUX

        # Additional field for EXTFS_DYNAMIC_REV revision
        self.sb.rev_level = EXTFS_DYNAMIC_REV
        self.sb.first_ino = EXTFS_FIRST_INO
        self.sb.inode_size = self.inodeStructSize
        self.sb.block_group_nr = 0
        self.sb.feature_compat = 0
        self.sb.feature_incompat = EXTFS_FEATURE_INCOMPAT_FILETYPE
        self.sb.feature_ro_compat = 0

        # Need to specify some more info if using 64-bit block group desc
        if self.groupDescStructSize >= EXTFS_GROUP_DESC_V4_STRUCT_SIZE:
            self.sb.desc_size = self.groupDescStructSize
            self.sb.feature_incompat |= EXTFS_FEATURE_INCOMPAT_64BIT

        # Generate uuid
        for i in range(0, 16):
            self.sb.uuid[i] = random.randint(0, 255)

        # Setup group descriptors
        bbmpos = firstDataBlock + 1 + groupDescSize
        ibmpos = bbmpos + 1
        itblpos = ibmpos + 1
        for i in range(0, groupCount):
            # Get group descriptor structure (in first block group)
            group = _from_buffer(self.groupDescStructType, self.buf,
                    firstDataBlock * Extfs.BLOCKSIZE +
                    Extfs.BLOCKSIZE +
                    i * self.groupDescStructSize)

            # Setup free block count
            if freeBlockCount > freeBlocksPerGroup:
                group.free_blocks_count = freeBlocksPerGroup
                freeBlockCount -= freeBlocksPerGroup
            else:
                group.free_blocks_count = freeBlockCount
                freeBlockCount = 0

            # Setup free inode count
            if i == 0:
                group.free_inodes_count = inodesPerGroup - EXTFS_FIRST_INO + 2
            else:
                group.free_inodes_count = inodesPerGroup

            # Other fields
            group.used_dirs_count = 0
            group.block_bitmap = bbmpos
            group.inode_bitmap = ibmpos
            group.inode_table = itblpos

            # Add in array, update block positions
            self.groups.append(group)
            bbmpos += blocksPerGroup
            ibmpos += blocksPerGroup
            itblpos += blocksPerGroup

        # Mark non-filesystem blocks and inodes as allocated
        # Mark system blocks and inodes as allocated
        for i in range(0, len(self.groups)):
            group = self.groups[i]
            bbm = self.getGroupBBM(i)
            ibm = self.getGroupIBM(i)

            # Non-filesystem blocks
            for j in range(group.free_blocks_count + overheadPerGroup, Extfs.BLOCKSIZE * 8):
                Extfs.allocate(bbm, j)

            # System blocks
            for j in range(0, overheadPerGroup):
                Extfs.allocate(bbm, j)

            # Non-filesystem inodes
            for j in range(self.sb.inodes_per_group, Extfs.BLOCKSIZE * 8):
                Extfs.allocate(ibm, j)

            # System inodes
            if i == 0:
                for j in range(0, EXTFS_FIRST_INO - 1):
                    Extfs.allocate(ibm, j)

        # Make root inode and directory
        self.groups[0].free_inodes_count -= 1
        self.groups[0].used_dirs_count = 1
        inode = self.getInode(EXTFS_ROOT_INO)
        inode.mode = (stat.S_IFDIR |
                stat.S_IRWXU | stat.S_IRGRP | stat.S_IROTH |
                stat.S_IXGRP | stat.S_IXOTH)
        inode.ctime = 0
        inode.mtime = 0
        inode.atime = 0
        self.addToDir(EXTFS_ROOT_INO, EXTFS_ROOT_INO, ".")
        self.addToDir(EXTFS_ROOT_INO, EXTFS_ROOT_INO, "..")

        # Add lost+found directory, and journal for ext3+
        self.addLostFoundDir()
        if version >= 3:
            self.addJournal()

    def finalize(self):
        groupDescSize = len(self.groups) * self.groupDescStructSize
        groupDescSize = (groupDescSize + Extfs.BLOCKSIZE - 1) // Extfs.BLOCKSIZE
        for grp in range(1, len(self.groups)):
            # Copy super block in other groups
            srcStart = 1024
            srcStop = srcStart + EXTFS_SUPER_BLOCK_STRUCT_SIZE
            dstStart = (self.sb.first_data_block + grp * self.sb.blocks_per_group) \
                    * Extfs.BLOCKSIZE
            dstStop = dstStart + EXTFS_SUPER_BLOCK_STRUCT_SIZE
            self.buf[dstStart:dstStop] = self.buf[srcStart:srcStop]
            # Copy group descriptors in other groups
            srcStart = (self.sb.first_data_block + 1) * Extfs.BLOCKSIZE
            srcStop = srcStart + groupDescSize * Extfs.BLOCKSIZE
            dstStart = (self.sb.first_data_block + 1 + grp * self.sb.blocks_per_group) \
                    * Extfs.BLOCKSIZE
            dstStop = dstStart + groupDescSize * Extfs.BLOCKSIZE
            self.buf[dstStart:dstStop] = self.buf[srcStart:srcStop]
        self.sb.wtime = int(time.time())
        self.sb.lastcheck = self.sb.wtime
        self.sb.state = 1

    @staticmethod
    def allocate(buf, item=-1):
        if item >= 0:
            buf[item // 8] |= (1 << (item % 8))
            return item

        for i in range(0, len(buf)):
            bits = buf[i]
            if bits != 0xff:
                for j in range(0, 8):
                    if (bits & (1 << j)) == 0:
                        return Extfs.allocate(buf, i * 8 + j)
        return -1

    # Return a given block from filesystem
    def getBlock(self, blk):
        blockType = ctypes.c_uint8 * Extfs.BLOCKSIZE
        return blockType.from_buffer(self.buf, blk * Extfs.BLOCKSIZE)

    # Return a given inode from filesystem
    def getInode(self, inum):
        grp = self.getGroupOfInode(inum)
        off = self.groups[grp].inode_table * Extfs.BLOCKSIZE
        off += self.getIBMOffset(inum) * self.inodeStructSize
        return _from_buffer(self.inodeStructType, self.buf, off)

    # Get group block bitmap (bbm) given the group number
    def getGroupBBM(self, grp):
        return self.getBlock(self.groups[grp].block_bitmap)

    # Get group inode bitmap (ibm) given the group number
    def getGroupIBM(self, grp):
        return self.getBlock(self.groups[grp].inode_bitmap)

    # Given an inode number find the group it belongs to
    def getGroupOfInode(self, inum):
        return (inum - 1) // self.sb.inodes_per_group

    # Given an inode number find its offset within the inode bitmap that covers it
    def getIBMOffset(self, inum):
        return inum - 1 - self.getGroupOfInode(inum) * self.sb.inodes_per_group

    def getInodeBlock(self, inum, idx):
        inode = self.getInode(inum)
        numPerBlock = Extfs.BLOCKSIZE // 4
        idxList = []

        # Level of indirection required
        if idx < EXTFS_NDIR_BLOCKS:
            idxList = [idx]
        elif idx < EXTFS_NDIR_BLOCKS + numPerBlock:
            idx -= EXTFS_NDIR_BLOCKS
            idxList = [
                EXTFS_IND_BLOCK,
                idx
            ]
        elif idx < EXTFS_NDIR_BLOCKS + numPerBlock * numPerBlock:
            idx -= EXTFS_NDIR_BLOCKS + numPerBlock
            idxList = [
                EXTFS_DIND_BLOCK,
                idx // numPerBlock,
                idx % numPerBlock
            ]
        elif idx < EXTFS_NDIR_BLOCKS + numPerBlock * numPerBlock * numPerBlock:
            idx -= EXTFS_NDIR_BLOCKS + numPerBlock * numPerBlock
            idxList = [
                EXTFS_TIND_BLOCK,
                idx // (numPerBlock * numPerBlock),
                (idx // numPerBlock) % numPerBlock,
                idx % numPerBlock
            ]
        else:
            raise MemoryError("Invalid inode block index : %d" % idx)

        blockNumArray = ctypes.cast(inode.block, ctypes.POINTER(ctypes.c_uint32))
        for i in range(0, len(idxList)):
            if blockNumArray[idxList[i]] == 0:
                blockNumArray[idxList[i]] = self.allocBlock(inum)
                inode.blocks += Extfs.INOBLK
            block = self.getBlock(blockNumArray[idxList[i]])
            blockNumArray = ctypes.cast(block, ctypes.POINTER(ctypes.c_uint32))
        return block

    # Allocate a block
    def allocBlock(self, inum):
        # Try to allocate a block in same group
        grp = self.getGroupOfInode(inum)
        if self.groups[grp].free_blocks_count > 0:
            blk = Extfs.allocate(self.getGroupBBM(grp))
            assert blk >= 0
        else:
            # Search a group with free block
            for grp in range(0, len(self.groups)):
                if self.groups[grp].free_blocks_count > 0:
                    blk = Extfs.allocate(self.getGroupBBM(grp))
                    assert blk >= 0
                    break
            else:
                raise MemoryError("Failed to allocate block for inode : %d" % inum)
        # Update stats and return block number
        self.groups[grp].free_blocks_count -= 1
        self.sb.free_blocks_count -= 1
        return self.sb.first_data_block + grp * self.sb.blocks_per_group + blk

    def allocNode(self):
        # Search a group with free inode
        for grp in range(0, len(self.groups)):
            if self.groups[grp].free_inodes_count > 0:
                inum = Extfs.allocate(self.getGroupIBM(grp))
                assert inum >= 0
                self.groups[grp].free_inodes_count -= 1
                self.sb.free_inodes_count -= 1
                return grp * self.sb.inodes_per_group + inum + 1
        raise MemoryError("Failed to allocate inode")

    def extendBlock(self, inum, data, amount, nocopy=False):
        inode = self.getInode(inum)
        src = data
        srcOff = 0
        srcLen = amount

        # Is there room in last block of inode ?
        if inode.size % Extfs.BLOCKSIZE != 0:
            dst = self.getInodeBlock(inum, inode.size // Extfs.BLOCKSIZE)
            dstOff = inode.size % Extfs.BLOCKSIZE
            dstLen = Extfs.BLOCKSIZE - inode.size % Extfs.BLOCKSIZE
            cpyLen = min(srcLen, dstLen)
            if not nocopy:
                ctypes.memmove(
                        _from_address(ctypes.c_void_p, ctypes.addressof(dst) + dstOff),
                        (ctypes.c_uint8 * cpyLen).from_buffer_copy(src, srcOff),
                        cpyLen)
            inode.size += cpyLen
            srcOff += cpyLen
            srcLen -= cpyLen

        # Continue with aligned block copy
        while srcLen > 0:
            dst = self.getInodeBlock(inum, inode.size // Extfs.BLOCKSIZE)
            cpyLen = min(srcLen, Extfs.BLOCKSIZE)
            if not nocopy:
                ctypes.memmove(dst,
                        (ctypes.c_uint8 * cpyLen).from_buffer_copy(src, srcOff),
                        cpyLen)
            inode.size += cpyLen
            srcOff += cpyLen
            srcLen -= cpyLen

    def addToDir(self, parent_inum, inum, name):
        parent_inode = self.getInode(parent_inum)
        inode = self.getInode(inum)
        name = name.encode("UTF-8")
        nlen = len(name)
        reclen = EXTFS_DIRENTRY_STRUCT_NO_NAME_SIZE + (nlen + 3) & (~3)
        # Search a free entry in last block
        if parent_inode.size != 0:
            idx = (parent_inode.size // Extfs.BLOCKSIZE) - 1
            block = self.getInodeBlock(parent_inum, idx)
            # For all dir entries in block
            off = 0
            while off < Extfs.BLOCKSIZE \
                    and off + EXTFS_DIRENTRY_STRUCT_NO_NAME_SIZE < Extfs.BLOCKSIZE:
                dent = _from_address(ExtfsDirEntry, ctypes.addressof(block) + off)
                # If empty dir entry, large enough, use it
                if dent.inode == 0 and dent.rec_len >= reclen:
                    dent.inode = inum
                    inode.links_count += 1
                    dent.name_len = nlen
                    dent.file_type = EXTFS_FILE_TYPE_FROM_STAT_TYPE[stat.S_IFMT(inode.mode)]
                    ctypes.memmove(dent.name,
                            (ctypes.c_uint8 * dent.name_len).from_buffer_copy(name),
                            dent.name_len)
                    return
                # If entry with enough room (last one?), shrink it & use it
                min_rec_len = EXTFS_DIRENTRY_STRUCT_NO_NAME_SIZE + ((dent.name_len + 3) & ~3)
                if dent.rec_len >= min_rec_len + reclen:
                    reclen = dent.rec_len
                    dent.rec_len = min_rec_len
                    reclen -= dent.rec_len
                    dent = _from_address(ExtfsDirEntry, ctypes.addressof(dent) + dent.rec_len)
                    dent.rec_len = reclen
                    dent.inode = inum
                    inode.links_count += 1
                    dent.name_len = nlen
                    dent.file_type = EXTFS_FILE_TYPE_FROM_STAT_TYPE[stat.S_IFMT(inode.mode)]
                    ctypes.memmove(dent.name,
                            (ctypes.c_uint8 * dent.name_len).from_buffer_copy(name),
                            dent.name_len)
                    return

                # Continue with next entry, break if record length seems wrong
                off += dent.rec_len
                if dent.rec_len == 0:
                    break

        # We found no free entry in the directory, so we add a block
        buf = bytearray(Extfs.BLOCKSIZE)
        dent = _from_buffer(ExtfsDirEntry, buf)
        dent.inode = inum
        inode.links_count += 1
        dent.rec_len = Extfs.BLOCKSIZE
        dent.name_len = nlen
        dent.file_type = EXTFS_FILE_TYPE_FROM_STAT_TYPE[stat.S_IFMT(inode.mode)]
        ctypes.memmove(dent.name,
                (ctypes.c_uint8 * dent.name_len).from_buffer_copy(name),
                dent.name_len)
        self.extendBlock(parent_inum, buf, Extfs.BLOCKSIZE)

    # Create a simple inode
    def addNode(self, parent_inum, entry):
        inum = self.allocNode()
        logging.debug("Alloc inode %d for '%s'", inum, entry.filePath)
        inode = self.getInode(inum)
        inode.mode = entry.st.st_mode
        inode.uid = entry.st.st_uid
        inode.gid = entry.st.st_gid
        inode.atime = int(entry.st.st_atime)
        inode.ctime = int(entry.st.st_ctime)
        inode.mtime = int(entry.st.st_mtime)
        self.addToDir(parent_inum, inum, entry.fileName)
        return inum

    def addDirNode(self, parent_inum, entry):
        inum = self.addNode(parent_inum, entry)
        self.addToDir(inum, inum, ".")
        self.addToDir(inum, parent_inum, "..")
        self.groups[self.getGroupOfInode(inum)].used_dirs_count += 1
        return inum

    def addFileNode(self, parent_inum, entry):
        inum = self.addNode(parent_inum, entry)
        if entry.st.st_size > 0:
            self.extendBlock(inum, entry.getData(), entry.st.st_size)
        return inum

    def addSymlinkNode(self, parent_inum, entry):
        inum = self.addNode(parent_inum, entry)
        inode = self.getInode(inum)
        if entry.st.st_size < 4 * EXTFS_N_BLOCKS:
            inode.size = entry.st.st_size
            ctypes.memmove(inode.block,
                    (ctypes.c_uint8 * entry.st.st_size).from_buffer_copy(entry.getData()),
                     entry.st.st_size)
            return inum
        self.extendBlock(inum, entry.getData(), entry.st.st_size)
        return inum

    def addDevNode(self, parent_inum, entry):
        inum = self.addNode(parent_inum, entry)
        inode = self.getInode(inum)
        inode.block[0] = entry.st.st_dev

    def addLostFoundDir(self):
        class FakeStat(object): pass
        class FakeEntry(object):
            def __init__(self, filePath, fileName):
                self.filePath = filePath
                self.fileName = fileName
                self.st = FakeStat()
        entry = FakeEntry("lost+found", "lost+found")
        entry.st.st_mode = stat.S_IFDIR | stat.S_IRWXU
        entry.st.st_uid = 0
        entry.st.st_gid = 0
        entry.st.st_atime = time.time()
        entry.st.st_mtime = entry.st.st_atime
        entry.st.st_ctime = entry.st.st_atime
        return self.addDirNode(EXTFS_ROOT_INO, entry)

    def addJournal(self):
        # Setup inode
        inum = EXTFS_JOURNAL_INO
        inode = self.getInode(inum)
        inode.mode = stat.S_IFREG | stat.S_IRUSR | stat.S_IWUSR
        inode.links_count = 1

        # Setup journal superblock
        content = bytearray(Extfs.BLOCKSIZE)
        jsb = _from_buffer(ExtfsJournalSuperBlock, content)
        jsb.magic = JFS_MAGIC_NUMBER
        jsb.blocktype = JFS_SUPERBLOCK_V2
        jsb.blocksize = Extfs.BLOCKSIZE
        jsb.maxlen = 1024
        jsb.nr_users = 1
        jsb.first = 1
        jsb.sequence = 1
        for i in range(0, 16):
            jsb.uuid[i] = self.sb.uuid[i]

        # Write journal super block and pad with empty data
        self.extendBlock(inum, content, Extfs.BLOCKSIZE)
        empty = bytearray(Extfs.BLOCKSIZE)
        for _ in range(1, jsb.maxlen):
            self.extendBlock(inum, empty, Extfs.BLOCKSIZE)

        # Update fd super block
        self.sb.feature_compat |= EXTFS_FEATURE_COMPAT_HAS_JOURNAL
        self.sb.journal_inum = EXTFS_JOURNAL_INO

    def populate(self, parent_inum, tree):
        for child in tree.children.values():
            if stat.S_IFMT(child.st.st_mode) == stat.S_IFDIR:
                inum = self.addDirNode(parent_inum, child)
                self.populate(inum, child)
            elif stat.S_IFMT(child.st.st_mode) == stat.S_IFREG:
                self.addFileNode(parent_inum, child)
            elif stat.S_IFMT(child.st.st_mode) == stat.S_IFLNK:
                self.addSymlinkNode(parent_inum, child)

#===============================================================================
#===============================================================================
def genImage(image, root, version=2):
    os.ftruncate(image.fout.fileno(), image.size)
    buf = mmap.mmap(image.fout.fileno(), image.size)
    blockCount = image.size // Extfs.BLOCKSIZE
    inodeCount = (blockCount * Extfs.BLOCKSIZE) // Extfs.INODE_RATIO
    reservedBlockCount = (blockCount * Extfs.RESERVED_RATIO) // 100
    fs = Extfs(buf, blockCount, inodeCount, reservedBlockCount, version)
    fs.populate(EXTFS_ROOT_INO, root)
    fs.finalize()
    try:
        buf.close()
    except BufferError:
        # FIXME: 'cannot close exported pointers exist' with python3
        pass
