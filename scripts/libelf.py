#===============================================================================
# libelf python implementation. Allow listing of sections/symbols.
#===============================================================================

import mmap
import struct

#===============================================================================
# Content of e_ident.
#===============================================================================
EI_NIDENT = 16                # Size of e_ident

EI_MAG0 = 0                   # File identification byte 0 index
ELFMAG0 = 0x7f                # Magic number byte 0
EI_MAG1 = 1                   # File identification byte 1 index
ELFMAG1 = ord("E")            # Magic number byte 1
EI_MAG2 = 2                   # File identification byte 2 index
ELFMAG2 = ord("L")            # Magic number byte 2
EI_MAG3 = 3                   # File identification byte 3 index
ELFMAG3 = ord("F")            # Magic number byte 3

EI_CLASS = 4                  # File class
ELFCLASSNONE = 0              # Invalid class
ELFCLASS32 = 1                # 32-bit objects
ELFCLASS64 = 2                # 64-bit objects

EI_DATA = 5                   # Data encoding
ELFDATANONE = 0               # Invalid data encoding
ELFDATA2LSB = 1               # 2's complement, little endian
ELFDATA2MSB = 2               # 2's complement, big endian

EI_VERSION = 6                # File version

EI_OSABI = 7                  # Operating System/ABI indication
ELFOSABI_NONE = 0             # UNIX System V ABI
ELFOSABI_HPUX = 1             # HP-UX operating system
ELFOSABI_NETBSD = 2           # NetBSD
ELFOSABI_LINUX = 3            # GNU/Linux
ELFOSABI_HURD = 4             # GNU/Hurd
ELFOSABI_SOLARIS = 6          # Solaris
ELFOSABI_AIX = 7              # AIX
ELFOSABI_IRIX = 8             # IRIX
ELFOSABI_FREEBSD = 9          # FreeBSD
ELFOSABI_TRU64 = 10           # TRU64 UNIX
ELFOSABI_MODESTO = 11         # Novell Modesto
ELFOSABI_OPENBSD = 12         # OpenBSD
ELFOSABI_OPENVMS = 13         # OpenVMS
ELFOSABI_NSK = 14             # Hewlett-Packard Non-Stop Kernel
ELFOSABI_AROS = 15            # AROS
ELFOSABI_ARM_AEABI = 64       # ARM EABI
ELFOSABI_ARM = 97             # ARM
ELFOSABI_STANDALONE = 255     # Standalone (embedded) application

EI_ABIVERSION = 8             # ABI version

EI_PAD = 9                    # Start of padding bytes

#===============================================================================
# Values for e_type, which identifies the object file type.
#===============================================================================
ET_NONE = 0                   # No file type
ET_REL = 1                    # Relocatable file
ET_EXEC = 2                   # Executable file
ET_DYN = 3                    # Shared object file
ET_CORE = 4                   # Core file
ET_NUM = 5                    # Number of defined types
ET_LOOS = 0xfe00              # Operating system-specific
ET_HIOS = 0xfeff              # Operating system-specific
ET_LOPROC = 0xff00            # Processor-specific
ET_HIPROC = 0xffff            # Processor-specific

#===============================================================================
# Legal values for e_machine (architecture).
#===============================================================================
EM_NONE = 0                   # No machine
EM_M32 = 1                    # AT&T WE 32100
EM_SPARC = 2                  # SUN SPARC
EM_386 = 3                    # Intel 80386
EM_68K = 4                    # Motorola m68k family
EM_88K = 5                    # Motorola m88k family
EM_860 = 7                    # Intel 80860
EM_MIPS = 8                   # MIPS R3000 big-endian
EM_S370 = 9                   # IBM System/370
EM_MIPS_RS3_LE = 10           # MIPS R3000 little-endian
EM_PARISC = 15                # HPPA
EM_VPP500 = 17                # Fujitsu VPP500
EM_SPARC32PLUS = 18           # Sun's "v8plus"
EM_960 = 19                   # Intel 80960
EM_PPC = 20                   # PowerPC
EM_PPC64 = 21                 # PowerPC 64-bit
EM_S390 = 22                  # IBM S390
EM_V800 = 36                  # NEC V800 series
EM_FR20 = 37                  # Fujitsu FR20
EM_RH32 = 38                  # TRW RH-32
EM_RCE = 39                   # Motorola RCE
EM_ARM = 40                   # ARM
EM_FAKE_ALPHA = 41            # Digital Alpha
EM_SH = 42                    # Hitachi SH
EM_SPARCV9 = 43               # SPARC v9 64-bit
EM_TRICORE = 44               # Siemens Tricore
EM_ARC = 45                   # Argonaut RISC Core
EM_H8_300 = 46                # Hitachi H8/300
EM_H8_300H = 47               # Hitachi H8/300H
EM_H8S = 48                   # Hitachi H8S
EM_H8_500 = 49                # Hitachi H8/500
EM_IA_64 = 50                 # Intel Merced
EM_MIPS_X = 51                # Stanford MIPS-X
EM_COLDFIRE = 52              # Motorola Coldfire
EM_68HC12 = 53                # Motorola M68HC12
EM_MMA = 54                   # Fujitsu MMA Multimedia Accelerator
EM_PCP = 55                   # Siemens PCP
EM_NCPU = 56                  # Sony nCPU embeeded RISC
EM_NDR1 = 57                  # Denso NDR1 microprocessor
EM_STARCORE = 58              # Motorola Start*Core processor
EM_ME16 = 59                  # Toyota ME16 processor
EM_ST100 = 60                 # STMicroelectronic ST100 processor
EM_TINYJ = 61                 # Advanced Logic Corp. Tinyj emb.fam
EM_X86_64 = 62                # AMD x86-64 architecture
EM_PDSP = 63                  # Sony DSP Processor
EM_FX66 = 66                  # Siemens FX66 microcontroller
EM_ST9PLUS = 67               # STMicroelectronics ST9+ 8/16 mc
EM_ST7 = 68                   # STmicroelectronics ST7 8 bit mc
EM_68HC16 = 69                # Motorola MC68HC16 microcontroller
EM_68HC11 = 70                # Motorola MC68HC11 microcontroller
EM_68HC08 = 71                # Motorola MC68HC08 microcontroller
EM_68HC05 = 72                # Motorola MC68HC05 microcontroller
EM_SVX = 73                   # Silicon Graphics SVx
EM_ST19 = 74                  # STMicroelectronics ST19 8 bit mc
EM_VAX = 75                   # Digital VAX
EM_CRIS = 76                  # Axis Communications 32-bit embedded processor
EM_JAVELIN = 77               # Infineon Technologies 32-bit embedded processor
EM_FIREPATH = 78              # Element 14 64-bit DSP Processor
EM_ZSP = 79                   # LSI Logic 16-bit DSP Processor
EM_MMIX = 80                  # Donald Knuth's educational 64-bit processor
EM_HUANY = 81                 # Harvard University machine-independent object files
EM_PRISM = 82                 # SiTera Prism
EM_AVR = 83                   # Atmel AVR 8-bit microcontroller
EM_FR30 = 84                  # Fujitsu FR30
EM_D10V = 85                  # Mitsubishi D10V
EM_D30V = 86                  # Mitsubishi D30V
EM_V850 = 87                  # NEC v850
EM_M32R = 88                  # Mitsubishi M32R
EM_MN10300 = 89               # Matsushita MN10300
EM_MN10200 = 90               # Matsushita MN10200
EM_PJ = 91                    # picoJava
EM_OPENRISC = 92              # OpenRISC 32-bit embedded processor
EM_ARC_A5 = 93                # ARC Cores Tangent-A5
EM_XTENSA = 94                # Tensilica Xtensa Architecture
EM_ALTERA_NIOS2 = 113         # Altera Nios II
EM_AARCH64 = 183              # ARM AARCH64
EM_TILEPRO = 188              # Tilera TILEPro
EM_MICROBLAZE = 189           # Xilinx MicroBlaze
EM_TILEGX = 191               # Tilera TILE-Gx
EM_NUM = 192                  #

#===============================================================================
# Values for e_version (version).
#===============================================================================
EV_NONE = 0                   # Invalid ELF version
EV_CURRENT = 1                # Current version
EV_NUM = 2                    #

#===============================================================================
# Special section indices, which may show up in st_shndx fields
#===============================================================================
SHN_UNDE = 0                  # Undefined section
SHN_LORESERVE = 0xff00        # Begin range of reserved indices
SHN_LOPROC = 0xff00           # Begin range of appl-specific
SHN_HIPROC = 0xff1f           # End range of appl-specific
SHN_LOOS = 0xff20             # OS specific semantics, lo
SHN_HIOS = 0xff3f             # OS specific semantics, hi
SHN_ABS = 0xfff1              # Associated symbol is absolute
SHN_COMMON = 0xfff2           # Associated symbol is in common
SHN_XINDEX = 0xffff           # Section index is held elsewhere
SHN_HIRESERVE = 0xffff        # End range of reserved indices

#===============================================================================
# Values for sh_type (section type).
#===============================================================================
SHT_NULL = 0                  # Section header table entry unused
SHT_PROGBITS = 1              # Program specific (private) data
SHT_SYMTAB = 2                # Link editing symbol table
SHT_STRTAB = 3                # A string table
SHT_RELA = 4                  # Relocation entries with addends
SHT_HASH = 5                  # A symbol hash table
SHT_DYNAMIC = 6               # Information for dynamic linking
SHT_NOTE = 7                  # Information that marks file
SHT_NOBITS = 8                # Section occupies no space in file
SHT_REL = 9                   # Relocation entries, no addends
SHT_SHLIB = 10                # Reserved, unspecified semantics
SHT_DYNSYM = 11               # Dynamic linking symbol table
SHT_INIT_ARRAY = 14           # Array of ptrs to init functions
SHT_FINI_ARRAY = 15           # Array of ptrs to finish functions
SHT_PREINIT_ARRAY = 16        # Array of ptrs to pre-init funcs
SHT_GROUP = 17                # Section contains a section group
SHT_SYMTAB_SHNDX = 18         # Indicies for SHN_XINDEX entries
SHT_LOOS = 0x60000000         # First of OS specific semantics
SHT_HIOS = 0x6fffffff         # Last of OS specific semantics
SHT_LOPROC = 0x70000000       # Processor-specific semantics, lo
SHT_HIPROC = 0x7fffffff       # Processor-specific semantics, hi
SHT_LOUSER = 0x80000000       # Application-specific semantics
SHT_HIUSER = 0xffffffff       # Application-specific semantics

SHT_GNU_ATTRIBUTES = 0x6ffffff5 # Object attributes
SHT_GNU_HASH = 0x6ffffff6     # GNU style symbol hash table
SHT_GNU_LIBLIST = 0x6ffffff7  # List of prelink dependencies
SHT_GNU_verdef = 0x6ffffffd   # Versions defined by file
SHT_GNU_verneed = 0x6ffffffe  # Versions needed by file
SHT_GNU_versym = 0x6fffffff   # Symbol versions

#===============================================================================
# Values for sh_flags (section flags)
#===============================================================================
SHF_WRITE = (1 << 0)          # Writable data during execution
SHF_ALLOC = (1 << 1)          # Occupies memory during execution
SHF_EXECINSTR = (1 << 2)      # Executable machine instructions
SHF_MERGE = (1 << 4)          # Data in this section can be merged
SHF_STRINGS = (1 << 5)        # Contains null terminated character strings
SHF_INFO_LINK = (1 << 6)      # sh_info holds section header table index
SHF_LINK_ORDER = (1 << 7)     # Preserve section ordering when linking
SHF_OS_NONCONFORMING = (1 << 8) # OS specific processing required
SHF_GROUP = (1 << 9)          # Member of a section group
SHF_TLS = (1 << 10)           # Thread local storage section
SHF_MASKOS = 0x0ff00000       # OS-specific semantics
SHF_MASKPROC = 0xf0000000     # Processor-specific semantics

#===============================================================================
# Values for p_type (segment type).
#===============================================================================
PT_NULL = 0                   # Program header table entry unused
PT_LOAD = 1                   # Loadable program segment
PT_DYNAMIC = 2                # Dynamic linking information
PT_INTERP = 3                 # Program interpreter
PT_NOTE = 4                   # Auxiliary information
PT_SHLIB = 5                  # Reserved
PT_PHDR = 6                   # Entry for header table itself
PT_TLS = 7                    # Thread-local storage segment
PT_NUM = 8                    # Number of defined types
PT_LOOS = 0x60000000          # Start of OS-specific
PT_HIOS = 0x6fffffff          # End of OS-specific
PT_LOPROC = 0x70000000        # Start of processor-specific
PT_HIPROC = 0x7fffffff        # End of processor-specific

PT_GNU_EH_FRAME = 0x6474e550  # GCC .eh_frame_hdr segment
PT_GNU_STACK = 0x6474e551     # Indicates stack executability
PT_GNU_RELRO = 0x6474e552     # Read-only after relocation

#===============================================================================
# Values for p_flags (segment flags).
#===============================================================================
PF_X = (1 << 0)               # Segment is executable
PF_W = (1 << 1)               # Segment is writable
PF_R = (1 << 2)               # Segment is readable
PF_MASKOS = 0x0ff00000        # OS-specific
PF_MASKPROC = 0xf0000000      # Processor-specific

#===============================================================================
# Values for ST_BIND subfield of st_info (symbol binding).
#===============================================================================
STB_LOCAL = 0                 # Local symbol
STB_GLOBAL = 1                # Global symbol
STB_WEAK = 2                  # Weak symbol
STB_NUM = 3                   # Number of defined types
STB_LOOS = 10                 # Start of OS-specific
STB_HIOS = 12                 # End of OS-specific
STB_LOPROC = 13               # Start of processor-specific
STB_HIPROC = 15               # End of processor-specific

STB_GNU_UNIQUE = 10           # Unique symbol

#===============================================================================
# Values for ST_TYPE subfield of st_info (symbol type).
#===============================================================================
STT_NOTYPE = 0                # Symbol type is unspecified
STT_OBJECT = 1                # Symbol is a data object
STT_FUNC = 2                  # Symbol is a code object
STT_SECTION = 3               # Symbol associated with a section
STT_FILE = 4                  # Symbol's name is file name
STT_COMMON = 5                # Symbol is a common data object
STT_TLS = 6                   # Symbol is thread-local data object
STT_NUM = 7                   # Number of defined types
STT_LOOS = 10                 # Start of OS-specific
STT_HIOS = 12                 # End of OS-specific
STT_LOPROC = 13               # Start of processor-specific
STT_HIPROC = 15               # End of processor-specific

STT_GNU_IFUNC = 10            # Symbol is indirect code object

#===============================================================================
# Symbol visibility specification encoded in the st_other field.
#===============================================================================
STV_DEFAULT = 0               # Default symbol visibility rules
STV_INTERNAL = 1              # Processor specific hidden class
STV_HIDDEN = 2                # Sym unavailable in other modules
STV_PROTECTED = 3             # Not preemptible, not exported

#===============================================================================
# Values for d_tag (dynamic entry type).
#===============================================================================
DT_NULL = 0                   # Marks end of dynamic section
DT_NEEDED = 1                 # Name of needed library
DT_PLTRELSZ = 2               # Size in bytes of PLT relocs
DT_PLTGOT = 3                 # Processor defined value
DT_HASH = 4                   # Address of symbol hash table
DT_STRTAB = 5                 # Address of string table
DT_SYMTAB = 6                 # Address of symbol table
DT_RELA = 7                   # Address of Rela relocs
DT_RELASZ = 8                 # Total size of Rela relocs
DT_RELAENT = 9                # Size of one Rela reloc
DT_STRSZ = 10                 # Size of string table
DT_SYMENT = 11                # Size of one symbol table entry
DT_INIT = 12                  # Address of init function
DT_FINI = 13                  # Address of termination function
DT_SONAME = 14                # Name of shared object
DT_RPATH = 15                 # Library search path (deprecated)
DT_SYMBOLIC = 16              # Start symbol search here
DT_REL = 17                   # Address of Rel relocs
DT_RELSZ = 18                 # Total size of Rel relocs
DT_RELENT = 19                # Size of one Rel reloc
DT_PLTREL = 20                # Type of reloc in PLT
DT_DEBUG = 21                 # For debugging; unspecified
DT_TEXTREL = 22               # Reloc might modify .text
DT_JMPREL = 23                # Address of PLT relocs
DT_BIND_NOW = 24              # Process relocations of object
DT_INIT_ARRAY = 25            # Array with addresses of init fct
DT_FINI_ARRAY = 26            # Array with addresses of fini fct
DT_INIT_ARRAYSZ = 27          # Size in bytes of DT_INIT_ARRAY
DT_FINI_ARRAYSZ = 28          # Size in bytes of DT_FINI_ARRAY
DT_RUNPATH = 29               # Library search path
DT_FLAGS = 30                 # Flags for the object being loaded
DT_ENCODING = 32              # Start of encoded range
DT_PREINIT_ARRAY = 32         # Array with addresses of preinit fct
DT_PREINIT_ARRAYSZ = 33       # size in bytes of DT_PREINIT_ARRAY
DT_NUM = 34                   # Number used
DT_LOOS = 0x6000000d          # Start of OS-specific
DT_HIOS = 0x6ffff000          # End of OS-specific
DT_LOPROC = 0x70000000        # Start of processor-specific
DT_HIPROC = 0x7fffffff        # End of processor-specific

# Versioning entry types. Defined as part of the GNU extension.
DT_VERSYM = 0x6ffffff0        #
DT_RELACOUNT = 0x6ffffff9     #
DT_RELCOUNT = 0x6ffffffa      #
DT_FLAGS_1 = 0x6ffffffb       # State flags, see DF_1_* below.
DT_VERDEF = 0x6ffffffc        # Address of version definition table
DT_VERDEFNUM = 0x6ffffffd     # Number of version definitions
DT_VERNEED = 0x6ffffffe       # Address of table with needed versions
DT_VERNEEDNUM = 0x6fffffff    # Number of needed versions

#===============================================================================
# Values of d_val in the DT_FLAGS entry.
#===============================================================================
DF_ORIGIN = 0x00000001        # Object may use DF_ORIGIN
DF_SYMBOLIC = 0x00000002      # Symbol resolutions starts here
DF_TEXTREL = 0x00000004       # Object contains text relocations
DF_BIND_NOW = 0x00000008      # No lazy binding for this object
DF_STATIC_TLS = 0x00000010    # Module uses the static TLS model

#===============================================================================
# State flags selectable in the d_val element of the DT_FLAGS_1 entry.
#===============================================================================
DF_1_NOW = 0x00000001         # Set RTLD_NOW for this object.
DF_1_GLOBAL = 0x00000002      # Set RTLD_GLOBAL for this object.
DF_1_GROUP = 0x00000004       # Set RTLD_GROUP for this object.
DF_1_NODELETE = 0x00000008    # Set RTLD_NODELETE for this object.
DF_1_LOADFLTR = 0x00000010    # Trigger filtee loading at runtime.
DF_1_INITFIRST = 0x00000020   # Set RTLD_INITFIRST for this object
DF_1_NOOPEN = 0x00000040      # Set RTLD_NOOPEN for this object.
DF_1_ORIGIN = 0x00000080      # $ORIGIN must be handled.
DF_1_DIRECT = 0x00000100      # Direct binding enabled.
DF_1_TRANS = 0x00000200       #
DF_1_INTERPOSE = 0x00000400   # Object is used to interpose.
DF_1_NODEFLIB = 0x00000800    # Ignore default lib search path.
DF_1_NODUMP = 0x00001000      # Object can't be dldump'ed.
DF_1_CONFALT = 0x00002000     # Configuration alternative created.
DF_1_ENDFILTEE = 0x00004000   # Filtee terminates filters search.
DF_1_DISPRELDNE = 0x00008000  # Disp reloc applied at build time.
DF_1_DISPRELPND = 0x00010000  # Disp reloc applied at run-time.

#===============================================================================
# ARM specific declarations
#===============================================================================
EF_ARM_ABI_FLOAT_SOFT = 0x200
EF_ARM_ABI_FLOAT_HARD = 0x400
EF_ARM_EABIMASK = 0xff000000
EF_ARM_EABI_UNKNOWN = 0x00000000
EF_ARM_EABI_VER1 = 0x01000000
EF_ARM_EABI_VER2 = 0x02000000
EF_ARM_EABI_VER3 = 0x03000000
EF_ARM_EABI_VER4 = 0x04000000
EF_ARM_EABI_VER5 =  0x05000000

#===============================================================================
#===============================================================================
class ElfError(Exception):
    pass

#===============================================================================
# The ELF file header. This appears at the start of every ELF file.
#===============================================================================
class ElfEhdr(object):
    size32 = 52
    size64 = 64
    def __init__(self, buf):
        # Read e_ident first so we can get information
        self.e_ident = struct.unpack("%dB" % EI_NIDENT, buf[0:EI_NIDENT])
        if self.e_ident[EI_MAG0] != ELFMAG0 \
                or self.e_ident[EI_MAG1] != ELFMAG1 \
                or self.e_ident[EI_MAG2] != ELFMAG2 \
                or self.e_ident[EI_MAG3] != ELFMAG3:
            raise ElfError("Bad magic in Ehdr")

        # Check encoding
        if not self.isLSB() or self.isMSB():
            raise ElfError("Bad encoding in Ehdr")

        # Setup format based on class
        if self.is32Bit():
            fmt = self.getFmtPrefix() + "HHIIIIIHHHHHH"
            self.size = ElfEhdr.size32
        elif self.is64Bit():
            fmt = self.getFmtPrefix() + "HHIQQQIHHHHHH"
            self.size = ElfEhdr.size64
        else:
            raise ElfError("Bad class in Ehdr")

        # Save fields (same order for 32-bit/64-bit)
        fields = struct.unpack(fmt, buf[EI_NIDENT:self.size])
        self.e_type = fields[0]       # Object file type
        self.e_machine = fields[1]    # Architecture
        self.e_version = fields[2]    # Object file version
        self.e_entry = fields[3]      # Entry point virtual address
        self.e_phoff = fields[4]      # Program header table file offset
        self.e_shoff = fields[5]      # Section header table file offset
        self.e_flags = fields[6]      # Processor-specific flags
        self.e_ehsize = fields[7]     # ELF header size in bytes
        self.e_phentsize = fields[8]  # Program header table entry size
        self.e_phnum = fields[9]      # Program header table entry count
        self.e_shentsize = fields[10] # Section header table entry size
        self.e_shnum = fields[11]     # Section header table entry count
        self.e_shstrndx = fields[12]  # Section header string table index

    def isLSB(self):
        return self.e_ident[EI_DATA] == ELFDATA2LSB
    def isMSB(self):
        return self.e_ident[EI_DATA] == ELFDATA2MSB
    def is32Bit(self):
        return self.e_ident[EI_CLASS] == ELFCLASS32
    def is64Bit(self):
        return self.e_ident[EI_CLASS] == ELFCLASS64
    def getFmtPrefix(self):
        return "<" if self.isLSB() else ">"

    def __str__(self):
        return \
                "{e_type=0x%x, e_machine=0x%x, e_version=0x%x, e_entry=0x%x, " \
                "e_phoff=0x%x, e_shoff=0x%x, e_flags=0x%x, e_ehsize=0x%x, " \
                "e_phentsize=0x%x, e_phnum=0x%x, e_shentsize=0x%x, " \
                "e_shnum=0x%x, e_shstrndx=0x%x}" % \
                (self.e_type, self.e_machine, self.e_version, self.e_entry,
                self.e_phoff, self.e_shoff, self.e_flags, self.e_ehsize,
                self.e_phentsize, self.e_phnum, self.e_shentsize,
                self.e_shnum, self.e_shstrndx)

#===============================================================================
# Section header.
#===============================================================================
class ElfShdr(object):
    size32 = 40
    size64 = 64
    def __init__(self, elf, idx, buf):
        self.idx = idx
        self.namestr = None

        # Setup format
        if elf.ehdr.is32Bit():
            fmt = elf.ehdr.getFmtPrefix() + "IIIIIIIIII"
            self.size = ElfPhdr.size32
        else:
            fmt = elf.ehdr.getFmtPrefix() + "IIQQQQIIQQ"
            self.size = ElfPhdr.size64

        # Save fields (same order for 32-bit/64-bit)
        fields = struct.unpack(fmt, buf)

        self.sh_name = fields[0]      # Section name (string tbl index)
        self.sh_type = fields[1]      # Section type
        self.sh_flags = fields[2]     # Section flags
        self.sh_addr = fields[3]      # Section virtual addr at execution
        self.sh_offset = fields[4]    # Section file offset
        self.sh_size = fields[5]      # Section size in bytes
        self.sh_link = fields[6]      # Link to another section
        self.sh_info = fields[7]      # Additional section information
        self.sh_addralign = fields[8] # Section alignment
        self.sh_entsize = fields[9]   # Entry size if section holds table

    def __str__(self):
        return \
                "{sh_name=0x%x, sh_type=0x%x, sh_flags=0x%x, sh_addr=0x%x, " \
                "sh_offset=0x%x, sh_size=0x%x, sh_link=0x%x, sh_info=0x%x, " \
                "sh_addralign=0x%x, sh_entsize=0x%x, namestr='%s'}" % \
                (self.sh_name, self.sh_type, self.sh_flags, self.sh_addr,
                self.sh_offset, self.sh_size, self.sh_link, self.sh_info,
                self.sh_addralign, self.sh_entsize, self.namestr)

#===============================================================================
# Program segment header.
#===============================================================================
class ElfPhdr(object):
    size32 = 32
    size64 = 56
    def __init__(self, elf, idx, buf):
        self.idx = idx

        # Setup format
        if elf.ehdr.is32Bit():
            fmt = elf.ehdr.getFmtPrefix() + "IIIIIIII"
            self.size = ElfPhdr.size32
        else:
            fmt = elf.ehdr.getFmtPrefix() + "IIQQQQQQ"
            self.size = ElfPhdr.size64

        # Save fields (order depends on 32-bit/64-bit)
        fields = struct.unpack(fmt, buf)
        if elf.ehdr.is32Bit():
            self.p_type = fields[0]   # Segment type
            self.p_offset = fields[1] # Segment file offset
            self.p_vaddr = fields[2]  # Segment virtual address
            self.p_paddr = fields[3]  # Segment physical address
            self.p_filesz = fields[4] # Segment size in file
            self.p_memsz = fields[5]  # Segment size in memory
            self.p_flags = fields[6]  # Segment flags
            self.p_align = fields[7]  # Segment alignment
        else:
            self.p_type = fields[0]   # Segment type
            self.p_flags = fields[1]  # Segment flags
            self.p_offset = fields[2] # Segment file offset
            self.p_vaddr = fields[3]  # Segment virtual address
            self.p_paddr = fields[4]  # Segment physical address
            self.p_filesz = fields[5] # Segment size in file
            self.p_memsz = fields[6]  # Segment size in memory
            self.p_align = fields[7]  # Segment alignment

    def __str__(self):
        return \
                "{p_type=0x%x, p_offset=0x%x, p_vaddr=0x%x, p_paddr=0x%x, " \
                "p_filesz=0x%x, p_memsz=0x%x, p_flags=0x%x, p_align=0x%x}" % \
                (self.p_type, self.p_offset, self.p_vaddr, self.p_paddr,
                self.p_filesz, self.p_memsz, self.p_flags, self.p_align)

#===============================================================================
#===============================================================================
class ElfSym(object):
    size32 = 16
    size64 = 24
    def __init__(self, elf, idx, buf):
        self.idx = idx
        self.namestr = None

        # Setup format
        if elf.ehdr.is32Bit():
            fmt = elf.ehdr.getFmtPrefix() + "IIIBBH"
            self.size = ElfSym.size32
        else:
            fmt = elf.ehdr.getFmtPrefix() + "IBBHQQ"
            self.size = ElfSym.size64

        # Save fields (order depends on 32-bit/64-bit)
        fields = struct.unpack(fmt, buf)
        if elf.ehdr.is32Bit():
            self.st_name = fields[0]  # Symbol name (string tbl index)
            self.st_value = fields[1] # Symbol value
            self.st_size = fields[2]  # Symbol size
            self.st_info = fields[3]  # Symbol type and binding
            self.st_other = fields[4] # Symbol visibility
            self.st_shndx = fields[5] # Section index
        else:
            self.st_name = fields[0]  # Symbol name (string tbl index)
            self.st_info = fields[1]  # Symbol type and binding
            self.st_other = fields[2] # Symbol visibility
            self.st_shndx = fields[3] # Section index
            self.st_value = fields[4] # Symbol value
            self.st_size = fields[5]  # Symbol size
        self.st_type = self.st_info&0xf
        self.st_bind = (self.st_info>>4)&0xf
        self.st_visibility = self.st_other&0x3

    def __str__(self):
        return \
                "{st_name=0x%x, st_value=0x%x, st_size=0x%x, st_type=0x%x, " \
                "st_bind=0x%x, st_visibility=0x%x, st_shndx=0x%x, namestr='%s'}" % \
                (self.st_name, self.st_value, self.st_size, self.st_type,
                self.st_bind, self.st_visibility, self.st_shndx, self.namestr)

#===============================================================================
#===============================================================================
class ElfDyn(object):
    size32 = 8
    size64 = 16
    strTags = [DT_NEEDED, DT_SONAME, DT_RPATH, DT_RUNPATH]
    def __init__(self, elf, idx, buf):
        self.idx = idx
        self.valstr = None

        # Setup format
        if elf.ehdr.is32Bit():
            fmt = elf.ehdr.getFmtPrefix() + "II"
            self.size = ElfDyn.size32
        else:
            fmt = elf.ehdr.getFmtPrefix() + "QQ"
            self.size = ElfDyn.size64

        # Save fields
        fields = struct.unpack(fmt, buf)
        self.d_tag = fields[0]
        self.d_val = fields[1]

    def __str__(self):
        if self.valstr is not None:
            return "{d_tag=0x%x, d_val=0x%x, valstr='%s'}" % \
                    (self.d_tag, self.d_val, self.valstr)
        else:
            return "{d_tag=0x%x, d_val=0x%x}" % \
                    (self.d_tag, self.d_val)

#===============================================================================
#===============================================================================
class Elf(object):
    def __init__(self):
        self.ehdr = None
        self.phdrTable = []
        self.shdrTable = []
        self.symTable = []
        self.dynsymTable = []
        self.dynamicEntries = []
        self._data = None

    def loadFromFile(self, filePath):
        elfFile = None
        try:
            # Open file, map it in memory and start reading it
            elfFile = open(filePath, "rb")
            self._data = mmap.mmap(elfFile.fileno(), 0, access=mmap.ACCESS_READ)
            self._read()
        except struct.error as ex:
            raise ElfError(str(ex))
        finally:
            # In any case, close file
            if elfFile:
                elfFile.close()

    def close(self):
        if self._data:
            self._data.close()
            self._data = None

    def _read(self):
        self._readEhdr()
        self._readPhdrTable()
        self._readShdrTable()
        for shdr in self.shdrTable:
            shdr.namestr = self._getString(self.ehdr.e_shstrndx, shdr.sh_name)
            if shdr.sh_type == SHT_SYMTAB:
                self._readSymTable(shdr, self.symTable)
            elif shdr.sh_type == SHT_DYNSYM:
                self._readSymTable(shdr, self.dynsymTable)
            elif shdr.sh_type == SHT_DYNAMIC:
                self._readDynamicSection(shdr)

    def _readEhdr(self):
        # Give all data, we don't known yet which size to give
        self.ehdr = ElfEhdr(self._data)

    def _readPhdrTable(self):
        size = ElfPhdr.size32 if self.ehdr.is32Bit() else ElfPhdr.size64
        for i in range(0, self.ehdr.e_phnum):
            offset = self.ehdr.e_phoff + i*self.ehdr.e_phentsize
            phdr = ElfPhdr(self, i, self._data[offset:offset+size])
            self.phdrTable.append(phdr)

    def _readShdrTable(self):
        size = ElfShdr.size32 if self.ehdr.is32Bit() else ElfShdr.size64
        for i in range(0, self.ehdr.e_shnum):
            offset = self.ehdr.e_shoff + i*self.ehdr.e_shentsize
            shdr = ElfShdr(self, i, self._data[offset:offset+size])
            self.shdrTable.append(shdr)

    def _readSymTable(self, shdr, table):
        size = ElfSym.size32 if self.ehdr.is32Bit() else ElfSym.size64
        for i in range(0, shdr.sh_size//size):
            offset = shdr.sh_offset + i*size
            sym = ElfSym(self, i, self._data[offset:offset+size])
            sym.namestr = self._getString(shdr.sh_link, sym.st_name)
            table.append(sym)

    def _readDynamicSection(self, shdr):
        size = ElfDyn.size32 if self.ehdr.is32Bit() else ElfDyn.size64
        for i in range(0, shdr.sh_size//size):
            offset = shdr.sh_offset + i*size
            dyn = ElfDyn(self, i, self._data[offset:offset+size])
            if dyn.d_tag in ElfDyn.strTags:
                dyn.valstr = self._getString(shdr.sh_link, dyn.d_val)
            self.dynamicEntries.append(dyn)
            if dyn.d_tag == DT_NULL:
                break

    def _getString(self, idx, offset):
        if idx >= len(self.shdrTable):
            return None
        shdrStr = self.shdrTable[idx]
        if offset >= shdrStr.sh_size:
            return None
        start = shdrStr.sh_offset + offset
        end = self._data.find(b"\x00", start, start + shdrStr.sh_size)
        if end == -1:
            end = start + shdrStr.sh_size
        return self._data[start:end].decode("UTF-8")

    # Compute hash of elf for section that are loadable and with data in elf.
    # @param hash : an object from 'hashlib' that support 'update' and
    # 'hexdigest' methods.
    def computeHash(self, hash):
        for shdr in self.shdrTable:
            if (shdr.sh_flags&SHF_ALLOC) != 0 and shdr.sh_type != SHT_NOBITS:
                start = shdr.sh_offset
                end = shdr.sh_offset + shdr.sh_size
                hash.update(self._data[start:end])
        return hash.hexdigest()

    def getSection(self, name):
        for shdr in self.shdrTable:
            if shdr.namestr == name:
                return shdr
        return None

    def getSectionData(self, shdr):
        return self._data[shdr.sh_offset:shdr.sh_offset+shdr.sh_size]

    def hasSection(self, name):
        return self.getSection(name) is not None

    def __str__(self):
        return "\n".join(["ehdr=%s" % self.ehdr] + \
                ["phdr[%d]=%s" % (phdr.idx, phdr) for phdr in self.phdrTable] + \
                ["shdr[%d]=%s" % (shdr.idx, shdr) for shdr in self.shdrTable] + \
                ["sym[%d]=%s" % (sym.idx, sym) for sym in self.symTable] + \
                ["dynsym[%d]=%s" % (sym.idx, sym) for sym in self.dynsymTable])

#===============================================================================
# For test.
#===============================================================================
if __name__ == "__main__":
    def main():
        import sys
        import hashlib
        try:
            elf = Elf()
            elf.loadFromFile(sys.argv[1])
            print(elf)
            print("md5:%s" % elf.computeHash(hashlib.md5())) # IGNORE:E1101
            print("sha1:%s" % elf.computeHash(hashlib.sha1())) # IGNORE:E1101
            elf.close()
        except ElfError as ex:
            print(ex)
    main()
