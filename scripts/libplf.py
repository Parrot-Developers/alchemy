#===============================================================================
# libplf python implementation.
#===============================================================================

import sys, os
import subprocess
import re

#===============================================================================
#===============================================================================

# Get programs from environment if set
PLFTOOL = os.environ.get("PLFTOOL", "plftool")
PLFBATCH = os.environ.get("PLFBATCH", "plfbatch")

#===============================================================================
# Plf file information.
#===============================================================================
class PlfFileInfo(object):
	def __init__(self):
		self.sectionIdxMap = {}
		self.sections = []
		self.pfields = []

	# We need to keep track of the number of sections of each type to set
	# correctly the idx for query
	def addSection(self, section):
		self.sections.append(section)
		idx = self.sectionIdxMap.get(section.type, 0)
		self.sectionIdxMap[section.type] = idx + 1
		section.idxSection = idx 

	def load(self, plfFilePath):
		# List all sections and parse them
		res = plftoolExec(["-W", plfFilePath])
		for line in res.split("\n"):
			if line.startswith("  p_"):
				pfield = PlfFieldInfo()
				if pfield.load(line):
					self.pfields.append(pfield)
			else:
				section = PlfSectionInfo()
				if section.load(line):
					self.addSection(section)

	# Output identical to 'plftool -W'
	def dump(self, output):
		output.write("PLF header:\n")
		for pfield in self.pfields:
			output.write("  %-18s = %s%s\n" % (pfield.name, pfield.value,
				" " + pfield.extra if pfield.extra else ""))
		output.write("PLF Sections:\n")
		output.write("Nr     Type              Address    Size     [deflated] Path\n")
		for section in self.sections:
			section.dump(output)

#===============================================================================
# Plf field
#===============================================================================
class PlfFieldInfo(object):
	_reField = re.compile(r"\s*([^ ]*)\s*=\s([^ ]*)(\s(.*))?")
	def __init__(self):
		self.name = ""
		self.value = ""
		self.extra = ""

	def load(self, data):
		match = PlfFieldInfo._reField.match(data)
		if match is None:
			return False
		self.name = match.group(1)
		self.value = match.group(2)
		if match.group(4):
			self.extra = match.group(4).strip()
		return True

#===============================================================================
# Format of a line of 'plftool -W' :
# [idx] type address size [deflated] path
#   idx      : index of section : decimal.
#   type     : type of section : string
#   address  : address : hexadecimal starting with 0x.
#   size     : size : decimal.
#   deflated : deflated size : decimal or '--------'.
#   path     : file path : string.
#
# For U_UNIXFILE, path format is : 
# [mode uid: gid] path
#   mode     : file mode : octal.
#   uid      : file uid : decimal.
#   gid      : file gid : decimal.
#   path     : file path : string.
#===============================================================================
class PlfSectionInfo(object):
	_reSectionInfo = re.compile(
			r"\[(\d*)\]\s*(\w*)\s*(0x[0-9a-fA-F]*)\s*(\d*)\s*" +
			r"\[([\- 0-9]*)\] (.*)")
	_reUnixFilePath = re.compile("\[([0-7]*)\s*(\d*):\s*(\d*)\] (.*)")
	def __init__(self):
		# We track 2 indices : one global and one by section type
		# Standard fields
		self.idxPlf = -1
		self.idxSection = -1
		self.type = ""
		self.address = 0
		self.size = 0
		self.deflated = 0
		self.mode = 0
		self.uid = 0
		self.gid = 0
		self.path = ""

	def load(self, data):
		# Parse data
		match = PlfSectionInfo._reSectionInfo.match(data)
		if match is None:
			return False
		# Standard fields
		self.idxPlf = int(match.group(1), 10)
		self.type = match.group(2)
		self.address = int(match.group(3), 16)
		self.size = int(match.group(4), 10)
		if "-" in match.group(5):
			self.deflated = 0
		else:
			self.deflated = int(match.group(5), 10)
		# Path
		self.path = match.group(6)
		if self.type == "U_UNIXFILE":
			matchPath = PlfSectionInfo._reUnixFilePath.match(self.path)
			if matchPath is not None:
				self.mode = int(matchPath.group(1), 8)
				self.uid = int(matchPath.group(2), 10)
				self.gid = int(matchPath.group(3), 10)
				self.path = matchPath.group(4)
		return True

	# Output identical to 'plftool -W'
	def dump(self, output):
		pathStr = self.path
		if self.type == "U_UNIXFILE":
			pathStr = ("[%06o %4d:%4d] %s" % (self.mode, self.uid, self.gid, self.path))
		deflatedStr = "--------"
		if self.deflated != 0:
			deflatedStr = "%8d" % self.deflated
		output.write("[%03d]  %-17s 0x%08x %-8d [%s] %s\n" % (self.idxPlf,
				self.type, self.address, self.size, deflatedStr, pathStr))

#===============================================================================
# Execute plfbatch command.
#===============================================================================
def plfbatchExec(plfFilePath, action, data):
	args = [PLFBATCH, action, plfFilePath]
	process = subprocess.Popen(args, stdin=subprocess.PIPE,
			stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
	return process.communicate(data)[0].rstrip("\n")

#===============================================================================
# Execute plftool command.
#===============================================================================
def plftoolExec(args):
	args = [PLFTOOL] + args
	process = subprocess.Popen(args, stdout=subprocess.PIPE)
	return process.communicate()[0].rstrip("\n")

#===============================================================================
# For test.
#===============================================================================
if __name__ == "__main__":
	def main():
		for plfFilePath in sys.argv[1:]:
			plf = PlfFileInfo()
			plf.load(plfFilePath)
			plf.dump(sys.stdout)
	main()
