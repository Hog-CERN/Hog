# Hog Generics

Hog allows you to define a set of generics/parameters[^1] to keep track of the code versioning. 
The generics are automatically filled in during the code compilation, at pre-synthesis.
We highly recommend you to publish the value of these generics/parameters to dedicated registers to be able to access the firmware versions after deploying the bit files.
To access the Hog generics/parameters you have to define the following in your top level entity.

| Generics/parameters name           | Generics type (VHDL only)     | Generics/parameters size | Generics/parameters description                                                                                                                                       |
|:------------------------|:------------------:|:-------------:|:-----------------------------------------------------------------------------------------------------------------------------------------------------------|
| GLOBAL_FWDATE           | std_logic_vector   | 32 bit         | date in which the firmware is compiled it uses d/m/Y format |
| GLOBAL_FWTIME           | std_logic_vector   | 32 bit         | time in which the firmware is compiled it uses 00H:M:S fromat  | 
| TOP_FWHASH              | std_logic_vector   | 32 bit         | hash code (git SHA) for the folder ./Top/\<project_name\> taken from the latest git commit   | 
| XML_HASH                | std_logic_vector   | 32 bit         | hash code (git SHA) for the latest commit in which at least one of the files in ./Top/\<project_name\>/xml/xm.lst has been modified, available if your project uses IPbus    |
| GLOBAL_FWVERSION        | std_logic_vector   | 32 bit         | firmware version produced by Hog, it has the form MajorMinorCommit, is produced starting from the latest tag    | 
| TOP_FWVERSION           | std_logic_vector   | 32 bit         | version for the ./Top/\<project_name\> folder, it has the form MajorMinorCommit, is produced from the latest tag   |
| XML_VERSION             | std_logic_vector   | 32 bit         | version for the ./Top/\<project_name\>/xml folder, it has the form MajorMinorCommit, is produced from the latest tag(available if your project uses IPbus) | 
| Hog_FWHASH              | std_logic_vector   | 32 bit         | hash code (git SHA) for the Hog folder   | 
| Hog_FWVERSION           | std_logic_vector   | 32 bit         | version for the Hog folder, produced from the latest tag   |
| <MYLIB\>_FWVERSION     | std_logic_vector   | 32 bit         | version for the list files used in defining library <MYLIB\>  |
| <MYLIB\>_FWHASH        | std_logic_vector   | 32 bit         | hash code (git SHA) for the files contained <MYLIB\> list file |
| <MYSUBMODULE0\>_FWHASH | std_logic_vector   | 32 bit         | hash code (git SHA) for the last commit of <MYSUBMODULE\> submodule |
| <MYEXTLIB\>_FWHASH     | std_logic_vector   | 32 bit         | hash code (git SHA) for the file contained the <MYEXTLIB\> list file |
| FLAVOUR                 | integer            |                | (integer) flavour used for generating this bit file, set if your project uses Hog flavours to produce bit files for different devices |

If you do not like to use the generics you are not obliged to do so.
The Hog scripts will define a generic with the correct name and the generic will be ignored by the HDL synthesizer.

[^1] Generics are used in VHDL language, parameters are used in verilog, systemverilog languages.
