#!/usr/bin/python3

import sys, os

PKG_CONFIG_DIR = sys.argv[1]

def switchLib(inputLine):
    # Takes "Libs: ..." line, converts all library names ending in
    # d into library names not ending in d. Except in the case of 
    # Qt5Gamepad (which already has a d).

    inputList = inputLine.split()
    outputList = []
    outputList.append(inputList[0])
    # First element is "Libs: " so disregard this
    for element in inputList[1:]:
        if element != "-lQt5Gamepad":
            if element.startswith("-lQt5") and element.endswith("d"):
                libraryName = element[5:-1]
            else:
                libraryName = element
        else:
            libraryName = "Gamepad"
        outputList.append('-lQt5' + libraryName)

    return(' '.join(outputList) + '\n')

def switchPrivateLib(inputLine):
    inputList = inputLine.split()
    outputList = []
    outputList.append(inputList[0])
    for element in inputList[1:]:
        if element != "/libQt5Gamepad.a":
            if element.startswith("/libQt5") and element.endswith("d.a"):
                libraryName = element[7:-3]
            else:
                libraryName = element
        else:
            libaryName = "Gamepad"
        outputList.append('/libQt5' + libraryName + ".a")

    return(' '.join(outputList) + '\n')


# Obtain a list of all the files we must alter

for entry in os.scandir(PKG_CONFIG_DIR):
    if entry.name.startswith('Qt5') and entry.name.endswith('.pc'):
	# Read in all the lines of the pkgconfig file
        with open(PKG_CONFIG_DIR + '/' + entry.name) as f:
            pcContent = f.readlines()

	# There will be only one of these: a line starting "Libs: "
        pcLibsContentElement = [x for x in pcContent if x.startswith("Libs: ")]
        # print('Starting with: %s' % (pcLibsContentElement[0]))
        fixedPcLibsContentElement = switchLib(pcLibsContentElement[0])
        # print('Libs line changed to: %s' % (fixedPcLibsContentElement))

        pcPrivateLibsContentElement = [x for x in pcContent if x.startswith("Libs.private: ")]
        if pcPrivateLibsContentElement:
            # print('Starting with: %s' % (pcPrivateLibsContentElement[0]))
            fixedPrivatePcLibsContentElement = switchPrivateLib(pcPrivateLibsContentElement[0])
            # print('Libs line changed to: %s' % (fixedPrivatePcLibsContentElement))
        
        # Now write the content of the .pc file to a temporary file, substituting the
        # lines we've changed where necessary.
        newPcFile = []
        for line in pcContent:
            if line.startswith("Libs: "):
                newPcFile.append(fixedPcLibsContentElement)
            elif line.startswith("Libs.private: "):
                newPcFile.append(fixedPrivatePcLibsContentElement)
            else:
                newPcFile.append(line)

        with open(PKG_CONFIG_DIR + '/' + entry.name, 'w') as fo:
            fo.writelines(newPcFile)

print('All done.')




	



