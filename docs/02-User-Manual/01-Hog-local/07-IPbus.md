# Hog and IPbus
Hog supports [IPbus](http://ipbus.web.cern.ch/ipbus/) by handling IPbus xml files and VHDL address maps.

To use IPbus with Hog, include it as a submodule in your HDL repository (in the root folder). Include ipbus files in a `.sub` [list file](02-List-files.md).

## Embedding of version and SHA in the xml files
Hog keeps track of the version and SHA of the xml files by means of two dedicated generics/parameters (XML_VER and XML_SHA) and edicated node tags in the xmls.

To allow for this, your top project-directory must include an `xml` directory containing a file named: `<repository>/Top/<project_name>/xml/xml.lst`.

Note that the xml and VHDL files can be located anywhere in your project.

## xml.lst

This file contains a list of the xml files used to generate the IPbus modules together with the generated VHDL address decode files, each line has the form:

```
 <path_to_xml>/<address_table>.xml <path_to_vhd>/<generated_file>.vhd
```

During Pre-synthesis, Hog will loop over the files contained tin this file to retrieve the SHA of the latest commit in which at least one of them was modified.
The path to the generated module is needed since in the future we foresee that Hog will use IPbus python scripts to verify that the generated modules correspond to the xml files.

### IPbus xml files
Hog can back annotate the included xmls with the SHA evaluated as described above.
This can be used by software to correctly assess if the used xmls correspond to the firmware loaded on the device.

You can acheive this by defining a dedicated register where to store the value of the [Hog generic](../03-parameters-generics.md): `XML_SHA`.

The node corresponding to this registers is expected to have the following structure:

```xml
    <node id="gitSHA" permission="r" address="0x-"  tags="xmlgitsha=__GIT_SHA__" description="XML git commit 7-digit SHA of top file">
```

During Pre-synthesis, Hog will replace `__GIT_SHA__` with the SHA of the latest commit in which at least one of xmls was modified.
Hog will also set the `XML_SHA` generic in your top level to correspond to the same SHA.
The user can now verify it is using the correct version of the xmls by comparing the `gitSHA` register content with the `gitSHA` register tag.

The same procedure is done for the xml version.
In this case the node is expected to have the following structure:

```xml
<node id="Version" permission="r" address="0x-" tags="xmlversion=__VERSION__"  description="version of XML files">
    <node id="Patch" mask="0xffff" description="Patch Number"/>
    <node id="Minor_Version" mask="0xff0000" description="Minor Version Number"/>
    <node id="Major_Version" mask="0xff000000" description="Major Version Number"/>
</node>
```

The `__VERSION__` will be set to the version of the xml files taken from the last tag in which at least one of the xml files included in xml.lst was modified.
The same value will be reported in the `XML_VER` generic of the top level of your project.

## Automatic creation and checking of address maps against xml file
