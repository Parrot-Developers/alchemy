

#===============================================================================
#===============================================================================
def expand(infilepath, outfilepath, handler):
    with open(infilepath, "r") as fin, open(outfilepath, "w") as fout:
        for line in fin:
            # Do we have a lone substitution pattern ?
            stripped = line.strip(" \t\n")
            if stripped.startswith("{{") and stripped.endswith("}}"):
                # Get replacement text
                start = line.find("{{")
                end = line.find("}}")
                text = handler(line[start+2:end])
                # Write lines from replacement text with same indent
                indent = line[0:start]
                for line2 in text.split("\n"):
                    if line2:
                        fout.write(indent)
                        fout.write(line2)
                        fout.write("\n")
                continue

            # Search patterns in line
            idx = 0
            while idx < len(line):
                # Search next substitution pattern
                start = line.find("{{", idx)
                end = line.find("}}", idx)
                if start < 0 or end < 0:
                    # No pattern found
                    fout.write(line[idx:])
                    break
                else:
                    # Write text up to pattern then replacement text
                    text = handler(line[start+2:end])
                    fout.write(line[idx:start])
                    fout.write(text)
                    idx = end + 2
