# Hog Generics

Hog allows you to define a set of generics to keep track of the code versioning. 
The generics are automatically filled in during the code compilation, at pre-sysntesis.
We suggest you to publish the value of these generics to be able to access the firmware versions after deploying the bit files.
To do so you can define the following generics in your top level entity.

| Generics name         | Generics type      | Generics size | Generics description                                                                                                           |
|:----------------------|:------------------:|:-------------:|:------------------------------------------------------------------------------------------------------------------------------:|
| GLOBAL_FWDATE         | std_logic_vector   | 8 bit         | date in wich the firmware is compiled it uses d m Y format                                                                     |
| GLOBAL_FWTIME         | std_logic_vector   | 8 bit         | time in shich the firmware is compiled it uses 00H:M:S fromat                                                                  | 
| TOP_FWHASH            | std_logic_vector   | 8 bit         | hash code for the folder ./Top/<project_name> taken from the latest git commit                                                 | 
| XML_HASH              | std_logic_vector   | 8 bit         | hash code for the folder ./Top/<project_name>/xml, available if your project uses IPbus                                        |
| GLOBAL_FWVERSION      | std_logic_vector   | 8 bit         | firmware version produced by HOG, it has the form MajorMinorCommit, is produced starting from the latest tag                   | 
| TOP_FWVERSION         | std_logic_vector   | 8 bit         | version for the ./Top/<project_name> folder, it has the form MajorMinorCommit, is produced from the latest tag                 |
| XML_VERSION           | std_logic_vector   | 8 bit         | version for the ./Top/<project_name>/xml folder, it has the form MajorMinorCommit, is produced from the latest tag(available if your project uses IPbus) | 
| HOG_FWHASH            | std_logic_vector   | 8 bit         | hash code for the HOG folder                                                                                                   | 
| HOG_FWVERSION         | std_logic_vector   | 8 bit         | version for the Hog folder, produced from the latest tag, set during pre-sysntehsis                                            |
|-----------------------|--------------------|---------------|--------------------------------------------------------------------------------------------------------------------------------|
| <MYLIB>_FWVERSION     | std_logic_vector   | 8 bit         | version for the list files used in defining library <MYLIB>                                                                    |
| <MYLIB>_FWHASH        | std_logic_vector   | 8 bit         | hash code for the list files used in defining library <MYLIB>                                                                  |
|-----------------------|--------------------|---------------|--------------------------------------------------------------------------------------------------------------------------------|
| <MYSUBMODULE0>_FWHASH | std_logic_vector   | 8 bit         | hash code for the submodule <MYSUBMODULE> taken from its latest commit                                                         |
|-----------------------|--------------------|---------------|--------------------------------------------------------------------------------------------------------------------------------|
| <MYEXTLIB>_FWHASH     | std_logic_vector   | 8 bit         | hash code for the list file containing the <MYEXTLIB> library                                                                  |
|-----------------------|--------------------|---------------|--------------------------------------------------------------------------------------------------------------------------------|
| FLAVOUR               | integer            |               | flavor used for generating this bit file, set if ypour project uses HOG flavours to produce bit files for different FPGAs      |
|-----------------------|--------------------|---------------|--------------------------------------------------------------------------------------------------------------------------------|

If you do not like to use the generics you are not obliged to do so.
The Hog scripts will define a generic with the correct name and the generic will be ignored by the HDL synthesizer.

