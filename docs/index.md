# UNDER CONSTRUCTION

 <div style='text-align:center'>
   <b style='color:black;font-size:50px'> 
   	Our site is coming soon!!
   </b>
   <div style='color:gray;font-size:25px'>
   	Here's a taste of what it will contain!
   </div>
 </div>

# Hog: HDL on git

## Introduction
Coordinating firmware development among many international collaborators is becoming a very widespread problem in particle physics. Guaranteeing firmware synthesis with P&R reproducibility and assuring traceability of binary files is paramount. Hog tackles these issues by exploiting advanced Git features and being deeply integrated with HDL IDE, with particular attention to Intellectual Properties (IP) handling.

## Rationale
In order to guarantee firmware synthesis and P&R reproducibility, we need absolute control of:
- HDL source files
- Constraint files
- Vivado settings (such as synthesis and implementation strategies)

Every time we produce a bit file, we must know exactly how it was produced
- Consistent automatically calculated version number embedded in firmware registers
- Never merge a “broken” commit to official branch
	- If this happens, developers starting from official commit will have a broken starting point
	- To avoid this the Automatic Workflow system was designed

## What is Hog
Hog is a set of Tcl/Shell scripts plus a suitable methodology to allow a fruitful use of Git as a HDL repository and guarantee synthesis reproducibility and binary file traceability. Tcl scripts, able to recreate the projects are committed to the repository. This permits the build to be Vivado-version independent and ensures that all the modifications done to the project (synthesis/implementation strategies, new files, settings) are propagated to the repository, allowing reproducibility.
In order to make the system more user friendly, all the source files used in each project are listed in special list files, together with properties (such as VHDL 2008 compatibility) that are read out by the Tcl scripts and imported into the project as different libraries, helping readability.

To guarantee binary file traceability, we link it permanently to a specific git commit. Thus, the git-commit hash (SHA) is embedded into the binary file via VHDL generic and stored into firmware registers. This is done by means of a pre-synthesis script which interacts with the git repository. Both the project creation script and the pre/post synthesis scripts are written in Tcl (compatible with Xilnx and Altera) and make use of a utility library designed for this purpose, including functions to handle git, parse tags, read list files, etc.

## HOG user manual

Here you can find a simple user manual on the HDL On Git (HOG) tools.\
If you want to contribute to the project please read the [Contributing](../99-Contributing/index.md) section.

## Contacts

For questions related to the HOG package, please get in touch with [HOG support](mailto:hog@cern.ch).\
For anything related to this site, please get in touch with [Nicolò Biesuz](mailto:nbiesuz@cern.ch).

