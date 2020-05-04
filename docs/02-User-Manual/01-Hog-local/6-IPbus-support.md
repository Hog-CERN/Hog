# IPbus support

HOG supports IPbus by including few features specific for this package.
The IPbus submodule and the generated VHDL files must be included in your project using the `*.sub` and `*.src` [files](09-List-files.md).

HOG helps you keep track of the xml file versioning by usage of dedicated generics in the VHDL and node tags in the xml.
To allow for this your project must include a dedicated xml folder and a dedicated list file located under `./Top/<project_name>/xml/xml.lst`. Note that the xml and VHDL files can be located anywhere in your project since HOG will use this file to retrieve the needed files.

## xml.lst

This file contains a list of the xml files used to generate the IPbus modules together with the generated modules, each line has the form:

```
 <path_to_xml>/<address_table>.xml <path_to_vhd>/<generated_file>.vhd
```

During Pre-synthesis, HOG will loop over the files contained tin this file to retrieve the SHA of the latest commit in which at least one of them was modified.
The path to the generated module is needed since in the future we foresee that HOG will use IPbus python scripts to verify that the generated modules correspond to the xml files.

### IPbus xml files

HOG can back annotate the included xmls with the SHA evaluated as described above.
To your software to correctly assess the validity of the used xmls, then  you must foresee the presence of a dedicated register where to store the value of the [HOG generic](../02-MAinteiner-Manual/07-Hog-generics).
The node corresponding to this registers is expected to have the following structure:

```xml
    <node id="GitSHA" permission="r" address="0x-"  tags="xmlgitsha=__GIT_SHA__" description="XML Git commit 7-digit SHA of top file">
```

During Pre-synthesis, HOG will replace `__GIT_SHA__` with the SHA of the latest commit in which at least one of xmls was modified.
HOG will also set the `XML_HASH` generic in your top level to correspond to the same SHA.
The user can now verify it is using the correct version of the xmls by comparing the `GitSHA` register content with the `GitSHA` register tag.

The same is valid for the xml version.
In this case the node is expected to have the following structure:

```xml
<node id="Version" permission="r" address="0x-" tags="xmlversion=__VERSION__"  description="version of XML files">
    <node id="Patch" mask="0xffff" description="Patch Number"/>
    <node id="Minor_Version" mask="0xff0000" description="Minor Version Number"/>
    <node id="Major_Version" mask="0xff000000" description="Major Version Number"/>
</node>
```

The `__VERSION__` will be set to the version of the xml files taken from the last tag in which at least one of the xml files included in xml.lst was modified.
The same value will be reported in the `XML_VERSION` generic of the top level of your project.
The user can now verify it is using the correct version of the xmls by comparing the `GitSHA` register content with the `GitSHA` register tag.
