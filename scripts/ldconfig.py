#!/usr/bin/env python3

import sys, os, logging
import argparse
import ctypes
import glob
import mmap
import struct

import libelf

LD_SO_CACHE = "/etc/ld.so.cache"
LD_SO_CONF = "/etc/ld.so.conf"

FORMAT_OLD = "old"
FORMAT_COMPAT = "compat"
FORMAT_NEW = "new"

FLAG_TYPE_MASK = 0x00ff
FLAG_LIBC4 = 0x0000
FLAG_ELF = 0x0001
FLAG_ELF_LIBC5 = 0x0002
FLAG_ELF_LIBC6 = 0x0003

FLAG_REQUIRED_MASK = 0xff00
FLAG_SPARC_LIB64 = 0x0100
FLAG_IA64_LIB64 = 0x0200
FLAG_X8664_LIB64 = 0x0300
FLAG_S390_LIB64 = 0x0400
FLAG_POWERPC_LIB64 = 0x0500
FLAG_MIPS64_LIBN32 = 0x0600
FLAG_MIPS64_LIBN64 = 0x0700
FLAG_X8664_LIBX32 = 0x0800
FLAG_ARM_LIBHF = 0x0900
FLAG_AARCH64_LIB64 = 0x0a00
FLAG_ARM_LIBSF = 0x0b00
FLAG_MIPS_LIB32_NAN2008 = 0x0c00
FLAG_MIPS64_LIBN32_NAN2008 = 0x0d00
FLAG_MIPS64_LIBN64_NAN2008 = 0x0e00
FLAG_RISCV_FLOAT_ABI_SOFT = 0x0f00
FLAG_RISCV_FLOAT_ABI_DOUBLE = 0x1000

_FLAGS_TYPE = {
    FLAG_LIBC4: "libc4",
    FLAG_ELF: "ELF",
    FLAG_ELF_LIBC5: "libc5",
    FLAG_ELF_LIBC6: "libc6",
}

_FLAGS_REQUIRED = {
    FLAG_SPARC_LIB64: "64bit",
    FLAG_IA64_LIB64: "IA-64",
    FLAG_X8664_LIB64: "x86-64",
    FLAG_S390_LIB64: "64bit",
    FLAG_POWERPC_LIB64: "64bit",
    FLAG_MIPS64_LIBN32: "N32",
    FLAG_MIPS64_LIBN64: "64bit",
    FLAG_X8664_LIBX32: "x32",
    FLAG_ARM_LIBHF: "hard-float",
    FLAG_AARCH64_LIB64: "AArch64",
    FLAG_ARM_LIBSF: "soft-float",
    FLAG_MIPS_LIB32_NAN2008: "nan2008",
    FLAG_MIPS64_LIBN32_NAN2008: "N32,nan2008",
    FLAG_MIPS64_LIBN64_NAN2008: "64bit,nan2008",
    FLAG_RISCV_FLOAT_ABI_SOFT: "soft-float",
    FLAG_RISCV_FLOAT_ABI_DOUBLE: "double-float",
}

_HWCAPS_X86 = {
    "sse2": 1 << 0,
    "x86_64": 1 << 1,
    "avx512_1": 1 << 2,

    "i586": 1 << 48,
    "i686": 1 << 49,
    "haswell": 1 << 50,
    "xeon_phi": 1 << 51,
}
_HWCAPS_X64 = _HWCAPS_X86

_HWCAPS_ARM = {
    "swp": 1 << 0,
    "half": 1 << 1,
    "thumb": 1 << 2,
    "26bit": 1 << 3,
    "fastmult": 1 << 4,
    "fpa": 1 << 5,
    "vfp": 1 << 6,
    "edsp": 1 << 7,
    "java": 1 << 8,
    "iwmmxt": 1 << 9,
    "crunch": 1 << 10,
    "thumbee": 1 << 11,
    "neon": 1 << 12,
    "vfpv3": 1 << 13,
    "vfpv3d16": 1 << 14,
    "tls": 1 << 15,
    "vfpv4": 1 << 16,
    "idiva": 1 << 17,
    "idivt": 1 << 18,
    "vfpd32": 1 << 19,
    "lpae": 1 << 20,
    "evtstrm": 1 << 21,
}

_HWCAPS_AARCH64 = {
    "fp": 1 << 0,
    "asimd": 1 << 1,
    "evtstrm": 1 << 2,
    "aes": 1 << 3,
    "pmull": 1 << 4,
    "sha1": 1 << 5,
    "sha2": 1 << 6,
    "crc32": 1 << 7,
    "atomics": 1 << 8,
    "fphp": 1 << 9,
    "asimdhp": 1 << 10,
    "cpuid": 1 << 11,
    "asimdrdm": 1 << 12,
    "jscvt": 1 << 13,
    "fcma": 1 << 14,
    "lrcpc": 1 << 15,
    "dcpop": 1 << 16,
    "sha3": 1 << 17,
    "sm3": 1 << 18,
    "sm4": 1 << 19,
    "asimddp": 1 << 20,
    "sha512": 1 << 21,
    "sve": 1 << 22,
}

_OS_TYPE = {
    0: "Linux",
    1: "Hurd",
    2: "Solaris",
    3: "FreeBSD",
    4: "kNetBSD",
    5: "Syllable",
}

#===============================================================================
#===============================================================================
CACHE_MAGIC = b"ld.so-1.7.0"
CACHE_MAGIC_NEW = b"glibc-ld.so.cache"
CACHE_VERSION = b"1.1"

class CacheHeader(ctypes.LittleEndianStructure):
    _fields_ = [
        ("magic", ctypes.c_char * 11),
        ("_pad", ctypes.c_uint8),
        ("nlibs", ctypes.c_uint32),
    ]
assert ctypes.sizeof(CacheHeader) == 16

class CacheEntry(ctypes.LittleEndianStructure):
    _fields_ = [
        ("flags", ctypes.c_uint32),
        ("key", ctypes.c_uint32),
        ("value", ctypes.c_uint32),
    ]
assert ctypes.sizeof(CacheEntry) == 12

class CacheHeaderNew(ctypes.LittleEndianStructure):
    _fields_ = [
        ("magic", ctypes.c_char * 17),
        ("version", ctypes.c_char * 3),
        ("nlibs", ctypes.c_uint32),
        ("len_strings", ctypes.c_uint32),
        ("unused", ctypes.c_uint32 * 5),
    ]
assert ctypes.sizeof(CacheHeaderNew) == 48

class CacheEntryNew(ctypes.LittleEndianStructure):
    _fields_ = [
        ("flags", ctypes.c_uint32),
        ("key", ctypes.c_uint32),
        ("value", ctypes.c_uint32),
        ("osversion", ctypes.c_uint32),
        ("hwcap", ctypes.c_uint64),
    ]
assert ctypes.sizeof(CacheEntryNew) == 24

#===============================================================================
# Wrapper just to avoid errors with pylint saying that methods
# from_buffer and from_address does not exist for class deriving from ctypes
# structures.
#===============================================================================
def _from_buffer(cls, buf, off=0):
    return cls.from_buffer(buf, off)

def _from_address(cls, addr):
    return cls.from_address(addr)

#===============================================================================
#===============================================================================
class Library(object):
    def __init__(self, libdir, filename, soname, flags, osversion, hwcap):
        self.libdir = libdir
        self.filename = filename
        self.soname = soname
        self.filepath = os.path.join(self.libdir, self.soname)
        self.soname_utf8 = self.soname.encode("UTF-8")
        self.filepath_utf8 = self.filepath.encode("UTF-8")
        self.flags = flags
        self.osversion = osversion
        self.hwcap = hwcap
        self.bits_hwcap = 0
        for bit in range(0, 64):
            if (self.hwcap & (1 << bit)) != 0:
                self.bits_hwcap += 1

    def cmp(self, other):
        res = Context.libcmp(self.soname, other.soname)
        if res != 0:
            return res
        elif self.flags != other.flags:
            return self.flags - other.flags
        elif self.bits_hwcap != other.bits_hwcap:
            return self.bits_hwcap - other.bits_hwcap
        elif self.hwcap != other.hwcap:
            return self.hwcap - other.hwcap
        elif self.osversion != other.osversion:
            return self.osversion - other.osversion
        else:
            return 0

    def __lt__(self, other):
        return self.cmp(other) > 0

#===============================================================================
#===============================================================================
class Context(object):
    def __init__(self, options):
        self.options = options
        self.cache_filepath = self._get_abs_path(options.cache)
        self.conf_filepath = self._get_abs_path(options.conf)
        self.libdirs = []
        self.libdirs_by_ino = {}
        self.hwcapdirs = []
        self.libs = []

        self._hwcaps = {
            "x86": _HWCAPS_X86,
            "x64": _HWCAPS_X64,
            "arm": _HWCAPS_ARM,
            "aarch64": _HWCAPS_AARCH64,
        }.get(options.arch, {})

    def build_cache(self):
        self._parse_conf(self.conf_filepath)
        self._add_libdir("/lib")
        self._add_libdir("/lib64")
        self._add_libdir("/libx32")
        while self.libdirs:
            self._search_dir(self.libdirs.pop(0))
        self.libs.sort()

    def save_cache(self):
        # Save in a temp file and rename to final path
        logging.info("Creating '%s'", self.cache_filepath)
        with open(self.cache_filepath + ".tmp", "wb") as fout:
            self._save_cache(fout)
        os.rename(self.cache_filepath + ".tmp", self.cache_filepath)

    def print_cache(self):
        # Open read-only and map copy-on-write so we can use ctypes.from_buffer
        # that requires writable buffer even if we will only read from it
        with open(self.cache_filepath, "rb") as fin:
            buf = mmap.mmap(fin.fileno(), 0, access=mmap.ACCESS_COPY)
            self._print_cache(buf)

    def _save_cache(self, fout):
        total_strlen = 0
        entry_count = 0
        entry_count_new = 0
        for lib in self.libs:
            total_strlen += len(lib.soname_utf8) + len(lib.filepath_utf8) + 2
            entry_count += 1 if lib.hwcap == 0 else 0
            entry_count_new += 1

        # Duplicate last entry in compat mode if number of entries is odd.
        # This is to make sure that the new header that will follow will
        # be properly aligned on a 8-byte boundary
        if self.options.fmt == FORMAT_COMPAT and entry_count % 2 == 1:
            duplicate_last_entry = True
            entry_count += 1
        else:
            duplicate_last_entry = False

        # The start of string table is different based on format
        strtable_start = 0
        if self.options.fmt != FORMAT_OLD:
            strtable_start += ctypes.sizeof(CacheHeaderNew)
            strtable_start += entry_count_new * ctypes.sizeof(CacheEntryNew)

        # Old format or compat
        if self.options.fmt != FORMAT_NEW:
            # Header
            header = CacheHeader(magic=CACHE_MAGIC,
                    _pad=0,
                    nlibs=entry_count)
            fout.write(header)

            # Entries
            str_offset = strtable_start
            last_entry = None
            for lib in self.libs:
                if lib.hwcap == 0:
                    entry = CacheEntry(flags=lib.flags,
                            key=str_offset,
                            value=str_offset+len(lib.soname_utf8)+1)
                    fout.write(entry)
                    last_entry = entry
                str_offset += len(lib.soname_utf8) + len(lib.filepath_utf8) + 2

            # Duplicate last entry if needed
            if duplicate_last_entry:
                fout.write(last_entry)

        # New format or compat
        if self.options.fmt != FORMAT_OLD:
            # Header (shall be aligned on a 8-byte boundary)
            header_new = CacheHeaderNew(magic=CACHE_MAGIC_NEW,
                    version = CACHE_VERSION,
                    nlibs=entry_count_new,
                    len_strings=total_strlen,
                    unused=(0, 0, 0, 0, 0))
            assert fout.tell() % 8 == 0
            fout.write(header_new)

            # Entries
            str_offset = strtable_start
            for lib in self.libs:
                entry_new = CacheEntryNew(flags=lib.flags,
                        key=str_offset,
                        value=str_offset+len(lib.soname_utf8)+1,
                        osversion=lib.osversion,
                        hwcap=lib.hwcap)
                fout.write(entry_new)
                str_offset += len(lib.soname_utf8) + len(lib.filepath_utf8) + 2

        # Strings
        for lib in self.libs:
            fout.write(lib.soname_utf8)
            fout.write(b"\0")
            fout.write(lib.filepath_utf8)
            fout.write(b"\0")

    def _print_cache(self, buf):
        # Get old header from buffer
        def get_header(buf, off=0):
            if len(buf) < off + ctypes.sizeof(CacheHeader):
                return None
            header = _from_buffer(CacheHeader, buf, off)
            if header.magic != CACHE_MAGIC:
                return None
            return header

        # Get new header from buffer
        def get_header_new(buf, off=0):
            if len(buf) < off + ctypes.sizeof(CacheHeaderNew):
                return None
            header_new = _from_buffer(CacheHeaderNew, buf, off)
            if header_new.magic != CACHE_MAGIC_NEW:
                return None
            if header_new.version != CACHE_VERSION:
                return None
            return header_new

        # Get a string from the buffer (they are null-terminated)
        def get_string(off):
            end = buf.find(b'\0', strtable_start + off)
            if end == -1:
                return ""
            return buf[strtable_start+off:end].decode("UTF-8")

        def print_entry(soname, flags, osversion, hwcap, filepath):
            flags_type = _FLAGS_TYPE.get(flags & FLAG_TYPE_MASK, "unknown")
            flags_required = _FLAGS_REQUIRED.get(flags & FLAG_REQUIRED_MASK,
                    str(flags & FLAG_REQUIRED_MASK))

            if hwcap != 0:
                hwcap_str = (", hwcap: %#.16x" % hwcap)
            else:
                hwcap_str = ""

            if osversion != 0:
                ostype = _OS_TYPE.get((osversion >> 24) & 0xff, "Unknown OS")
                osversion_str = ", OS ABI: %s %d.%d.%d" % (ostype,
                        (osversion >> 16) & 0xff,
                        (osversion >> 8) & 0xff,
                        osversion & 0xff)
            else:
                osversion_str = ""

            print("\t%s (%s,%s%s%s) => %s" % (
                    soname, flags_type, flags_required,
                    hwcap_str, osversion_str, filepath))

        # Is it new format without the old one ?
        header_new = get_header_new(buf)
        if header_new is not None:
            fmt = FORMAT_NEW
            entries_new = _from_buffer(CacheEntryNew * header_new.nlibs,
                    buf, ctypes.sizeof(CacheHeaderNew))
            strtable_start = 0
        else:
            # Is it old format ?
            header = get_header(buf)
            if header is not None:
                fmt = FORMAT_OLD
                entries = _from_buffer(CacheEntry * header.nlibs,
                        buf, ctypes.sizeof(CacheHeader))
                off = ctypes.sizeof(CacheHeader) + \
                        header.nlibs * ctypes.sizeof(CacheEntry)
                strtable_start = off

                # Check for a new cache embedded in the old format
                header_new = get_header_new(buf, off)
                if header_new is not None:
                    fmt = FORMAT_NEW
                    entries_new = _from_buffer(CacheEntryNew * header_new.nlibs,
                            buf, off + ctypes.sizeof(CacheHeaderNew))
            else:
                logging.error("'%s' is not a valid cache file",
                        self.cache_filepath)
                return

        if fmt == FORMAT_OLD:
            print("%d libs found in cache `%s'" % (
                    header.nlibs, self.cache_filepath))
            for entry in entries:
                print_entry(get_string(entry.key),
                        entry.flags, 0, 0,
                        get_string(entry.value))
        elif fmt == FORMAT_NEW:
            print("%d libs found in cache `%s'" % (
                    header_new.nlibs, self.cache_filepath))
            for entry_new in entries_new:
                print_entry(get_string(entry_new.key),
                        entry_new.flags, entry_new.osversion, entry_new.hwcap,
                        get_string(entry_new.value))

    def _get_abs_path(self, path):
        if self.options.root_dirpath:
            return os.path.join(self.options.root_dirpath, path.lstrip("/"))
        else:
            return path

    def _add_libdir(self, libdir):
        dirpath = self._get_abs_path(libdir)
        try:
            stres = os.stat(dirpath)
            if (stres.st_dev, stres.st_ino) not in self.libdirs_by_ino:
                logging.debug("Add directory '%s", dirpath)
                self.libdirs.append(libdir)
                self.libdirs_by_ino[(stres.st_dev, stres.st_ino)] = libdir
            else:
                logging.debug("Skipping duplicate directory '%s", dirpath)
        except FileNotFoundError:
            logging.debug("Skipping missing directory '%s", dirpath)

    def _add_lib(self, lib):
        logging.info("Adding '%s' -> %s'", lib.soname, lib.filepath)
        self.libs.append(lib)

    def _parse_conf(self, filepath):
        logging.info("Parsing conf file '%s'", filepath)
        with open(filepath, "r") as fin:
            for line in fin:
                # Remove comments, replace tabs by spaces and strip
                if "#" in line:
                    line = line.split("#", 1)[0]
                line = line.replace("\t", " ").strip()
                if line.startswith("include "):
                    for pattern in line[8:].split(" "):
                        self._parse_conf_include(pattern)
                elif line.startswith("hwcap "):
                    # Ignore 'hwcap'
                    logging.warning("Skipping line '%s'", line)
                elif line:
                    if "=" in line:
                        line, flags = line.split("=", 1)[0]
                        logging.warning("Ignoring flag '%s' for '%s",
                                flags, line)
                    self._add_libdir(line)

    def _parse_conf_include(self, pattern):
        for filepath in sorted(glob.glob(self._get_abs_path(pattern))):
            self._parse_conf(filepath)

    def _search_dir(self, libdir):
        dirpath = self._get_abs_path(libdir)
        hwcap = self._get_hwcap(libdir)

        logging.info("Searching directory '%s'", dirpath)
        entries = {}
        for entry in sorted(os.listdir(dirpath)):
            if os.path.isdir(os.path.join(dirpath, entry)):
                if self._is_hwcap_platform(entry):
                    self._add_libdir(os.path.join(libdir, entry))
            elif os.path.isfile(os.path.join(dirpath, entry)):
                if (entry.startswith("lib") or entry.startswith("ld-")) and \
                        ".so" in entry:
                    self._process_file(entries, libdir, entry)
        for soname in sorted(entries.keys()):
            filename, _, flags, osversion = entries[soname]
            lib = Library(libdir, filename, soname, flags, osversion, hwcap)
            self._add_lib(lib)

    def _is_hwcap_platform(self, name):
        return name in self._hwcaps

    def _get_hwcap(self, libdir):
        hwcap = 0
        for name in reversed(libdir.split("/")):
            try:
                hwcap |= self._hwcaps[name]
            except KeyError:
                break
        return hwcap

    def _process_file(self, entries, libdir, filename):
        filepath = self._get_abs_path(os.path.join(libdir, filename))
        logging.debug("Processing file '%s'", filepath)

        # Load as elf
        elf = libelf.Elf()
        try:
            elf.loadFromFile(filepath)
        except libelf.ElfError as ex:
            # Not an elf, log unless it is a linker script
            if not Context._is_linker_script(filepath):
                logging.error("'%s': %s", filepath, str(ex))
            return
        if elf.ehdr.e_type != libelf.ET_DYN:
            return

        soname, flags, osversion = Context._process_file_elf(filepath, elf)
        elf.close()

        islink = os.path.islink(filepath)
        if islink:
            if filename != soname and \
                    (not filename.endswith(".so") or \
                    not soname.startswith(filename)):
                islink = False
            else:
                soname = filename

        if soname in entries:
            # Prefer a file to a link
            # otherwise check which one is newer
            old_filename, old_islink, old_flags, _ = entries[soname]
            if flags != old_flags:
                logging.warning("Flag mismatch between '%s and '%s' in '%s'",
                        filename, old_filename, self._get_abs_path(libdir))
            elif (not islink and old_islink) or \
                    (islink != old_islink and \
                     Context.libcmp(filename, old_filename) > 0):
                entries[soname] = (filename, islink, flags, osversion)
        else:
            entries[soname] = (filename, islink, flags, osversion)

    @staticmethod
    def _process_file_elf(filepath, elf):
        # Extract SONAME and osversion
        soname = Context._elf_extract_soname(elf) or os.path.basename(filepath)
        osversion = Context._elf_extract_osversion(elf)

        # Extract flags
        flags = FLAG_ELF
        if elf.ehdr.e_machine == libelf.EM_386:
            if soname == "ld-linux.so.2":
                flags = FLAG_ELF
            else:
                flags = Context._process_file_elf_i386(elf)
        elif elf.ehdr.e_machine == libelf.EM_ARM:
            flags = Context._process_file_elf_arm(elf)
        elif elf.ehdr.e_machine == libelf.EM_X86_64:
            flags = Context._process_file_elf_x86_64(elf)
        elif elf.ehdr.e_machine == libelf.EM_AARCH64:
            flags = Context._process_file_elf_aarch64(elf)
        else:
            logging.warning("Unsupported machine architecture %d for '%s",
                    elf.ehdr.e_machine, filepath)

        return (soname, flags, osversion)

    @staticmethod
    def _elf_extract_soname(elf):
        for entry in elf.dynamicEntries:
            if entry.d_tag == libelf.DT_SONAME:
                return entry.valstr
        return None

    @staticmethod
    def _elf_extract_osversion(elf):
        for shdr in elf.shdrTable:
            if shdr.sh_type == libelf.SHT_NOTE and \
                    shdr.namestr == ".note.ABI-tag":
                data = elf.getSectionData(shdr)
                if len(data) >= 32:
                    fmt = elf.ehdr.getFmtPrefix() + "IIIIIIII"
                    words = struct.unpack(fmt, data[0:32])
                    if words[0] == 4 and words[1] == 16 and \
                            words[2] == 1 and words[3] == 0x554e47:
                        return (words[4] << 24) | (words[5] << 16) | \
                                (words[6] << 8) | words[7]
        return 0

    @staticmethod
    def _process_file_elf_i386(elf):
        if elf.ehdr.is32Bit():
            return FLAG_ELF_LIBC6
        else:
            return FLAG_ELF

    @staticmethod
    def _process_file_elf_arm(elf):
        eabi = elf.ehdr.e_flags & libelf.EF_ARM_EABIMASK
        if eabi == libelf.EF_ARM_EABI_VER5:
            if (elf.ehdr.e_flags & libelf.EF_ARM_ABI_FLOAT_HARD) != 0:
                return FLAG_ARM_LIBHF | FLAG_ELF_LIBC6
            elif (elf.ehdr.e_flags & libelf.EF_ARM_ABI_FLOAT_SOFT) != 0:
                return FLAG_ARM_LIBSF | FLAG_ELF_LIBC6
            else:
                return FLAG_ELF_LIBC6
        else:
            return FLAG_ELF

    @staticmethod
    def _process_file_elf_x86_64(elf):
        if elf.ehdr.is64Bit():
            return FLAG_X8664_LIB64 | FLAG_ELF_LIBC6
        elif elf.ehdr.is32Bit():
            return FLAG_X8664_LIBX32 | FLAG_ELF_LIBC6
        else:
            return FLAG_ELF

    @staticmethod
    def _process_file_elf_aarch64(elf):
        if elf.ehdr.is64Bit():
            return FLAG_AARCH64_LIB64 | FLAG_ELF_LIBC6
        else:
            return FLAG_ELF

    @staticmethod
    def _is_linker_script(filepath):
        # Look for some text in beginning of file
        with open(filepath, "r") as fin:
            contents = fin.read(512)
            return "GROUP" in contents or \
                "INPUT" in contents or \
                "GNU ld script" in contents

    @staticmethod
    def libcmp(path1, path2):
        class CIter(object):
            def __init__(self, string):
                self.string = string
                self.idx = 0
            def peek(self):
                if self.idx < len(self.string):
                    if isinstance(self.string, str):
                        return ord(self.string[self.idx])
                    else:
                        return self.string[self.idx]
                else:
                    return 0
            def next(self):
                char = self.peek()
                self.idx += 1
                return char

        def isdigit(char):
            return char >= ord('0') and char <= ord('9')

        iter1 = CIter(path1)
        iter2 = CIter(path2)

        while True:
            char1 = iter1.peek()
            char2 = iter2.peek()
            if isdigit(char1):
                if isdigit(char2):
                    # Must compare this numerically
                    val1 = iter1.next() - ord('0')
                    val2 = iter2.next() - ord('0')
                    while isdigit(iter1.peek()):
                        val1 = val1 * 10 + iter1.next()
                    while isdigit(iter2.peek()):
                        val2 = val2 * 10 + iter2.next()
                    if val1 != val2:
                        return val1 - val2
                else:
                    return 1
            elif isdigit(char2):
                return -1
            elif char1 != char2:
                return char1 - char2
            elif char1 == 0 and char2 == 0:
                return 0
            else:
                char1 = iter1.next()
                char2 = iter2.next()

#===============================================================================
#===============================================================================
def main():
    options = parse_args()
    setup_log(options)
    ctx = Context(options)
    if options.build_cache:
        if options.link:
            logging.warning("Creation of missing links not implemented")
        ctx.build_cache()
        ctx.save_cache()
    if options.print_cache:
        ctx.print_cache()

#===============================================================================
# Setup option parser and parse command line.
#===============================================================================
def parse_args():
    parser = argparse.ArgumentParser(description="ldconfig(8) clone")

    parser.add_argument("-c", "--fmt",
        dest="fmt",
        default=FORMAT_COMPAT,
        choices=[FORMAT_OLD, FORMAT_COMPAT, FORMAT_NEW],
        help="Cache format to use.")

    parser.add_argument("-C", "--cache",
        metavar="CACHE",
        dest="cache",
        default=LD_SO_CACHE,
        help="Use cache instead of %s." % LD_SO_CACHE)

    parser.add_argument("-f", "--conf",
        metavar="CONF",
        dest="conf",
        default=LD_SO_CONF,
        help="Use conf instead of %s." % LD_SO_CONF)

    parser.add_argument("-N",
        dest="build_cache",
        action="store_false",
        default=True,
        help="Don't rebuild the cache.")

    parser.add_argument("-p", "--print-cache",
        dest="print_cache",
        action="store_true",
        default=False,
        help="Print the libraries stored in the cache.")

    parser.add_argument("-r", "--root",
        metavar="ROOT",
        dest="root_dirpath",
        default=None,
        help="Use ROOT as the root directory.")

    parser.add_argument("-X",
        dest="link",
        action="store_false",
        default=True,
        help="Don't update links.")


    parser.add_argument("-a", "--arch",
        dest="arch",
        default=None,
        choices=["x86", "x64", "arm", "aarch64"],
        help="Architecture to use for correct selection of hwcap.")

    parser.add_argument("-q",
        dest="quiet",
        action="store_true",
        default=False,
        help="Be quiet.")
    parser.add_argument("-v",
        dest="verbose",
        action="count",
        default=0,
        help="Verbose output (more verbose if specified twice).")

    return parser.parse_args()

#===============================================================================
# Setup logging system.
#===============================================================================
def setup_log(options):
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

if __name__ == "__main__":
    main()
