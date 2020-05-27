# Parameters/Generics

Just before the synthesis starts, the Hog pre-synthesis script feeds a set of value to the design.

This is done to link the binary file with the state of the repository at the moment of synthesis.
In order to do this Hog exploits VHDL generics or Verilog parameters[^1].
In this section the details of these generic/parameters are explained.

The values of these generics/parameters should be connected to dedicated registers that can be accessed at run time on the device (e.g. IPBus registers). 

To access the Hog generics/parameters you must define the following in your top level entity:

| Generics/parameters name           | Generics type (VHDL only)     | Generics/parameters size | Generics/parameters description                                |
|:------------------------|:------------------:|:-------------:|:------------------------------------------------------------------------------------------------|
| GLOBAL_FWDATE           | std_logic_vector   | 32 bit         | Last commit date. Format: ddmmyyyy (hex with decimal digits, no digit greater than 9 is used)  |
| GLOBAL_FWTIME           | std_logic_vector   | 32 bit         | Last commit time. Format: 00HHMMSS  (hex with decimal digits, no digit greater than 9 is used) | 
| GLOBAL_FWVERSION        | std_logic_vector   | 32 bit         | Repository version.  The version of the form m.M.p is encoded in hexadecimal as MMmmpppp  |
| GLOBAL_FWHASH           | std_logic_vector   | 32 bit         | Repository git commit hash (SHA). | 							     
| TOP_FWVERSION           | std_logic_vector   | 32 bit         | Top project folder version.  The version of the form m.M.p is encoded in hexadecimal as MMmmpppp  |
| TOP_FWHASH              | std_logic_vector   | 32 bit         | Top project folder git commit hash (SHA). | 							     
| HOG_FWVERSION           | std_logic_vector   | 32 bit         | Hog submodule version.  The version of the form m.M.p is encoded in hexadecimal as MMmmpppp  |
| HOG_FWHASH              | std_logic_vector   | 32 bit         | Hog submodule git commit hash (SHA). | 							     
| XML_VERSION             | std_logic_vector   | 32 bit         | (optional) IPbus xml version.  The version of the form m.M.p is encoded in hexadecimal as MMmmpppp  |
| XML_HASH                | std_logic_vector   | 32 bit         | (optional) IPbus xml git commit hash (SHA). | 							     
| <MYLIB\>_FWVERSION     | std_logic_vector   | 32 bit         |  (one per library, i.e. .src list file) Version of the files contained in the .src file.  The version of the form m.M.p is encoded in hexadecimal as MMmmpppp  |
| <MYLIB\>_FWHASH        | std_logic_vector   | 32 bit         |  (one per library, i.e. .src list file) Git commit hash of the files contained in the .src file (SHA). | 							     
| <MYSUBMODULE0\>_FWHASH | std_logic_vector   | 32 bit         | (one per submodule) Submodule git commit hash (SHA). |
| <MYEXTLIB\>_FWHASH     | std_logic_vector   | 32 bit         | (one per external library) Git commit hash (SHA) of the .ext file. |
| FLAVOUR                 | integer            |                | (integer) flavour used for generating this bit file, set if your project uses Hog flavours to produce bit files for different devices |

The firmware date and time are encoded to be readable in hexadecimal so 0xA, 0xB, 0xC, 0xD 0xE, and 0xF are not used. For example the date 5 July 1952 is encoded as 0x05071952 and the time 12.34.56 is encoded as 0x00123456. To guarantee synthesis reproducibility, Hog uses the last-commit date and time rather than the synthesis date and time.

Names ending with _FWHASH are used for the 7-digit SHA of the git commit, being the SHA an hexadecimal number there is no ambiguity in its conversion. Names ending with _FWVERSION are used for a numeric version of the form M.m.p encoded in hexadecimal as 0xMMmmpppp. So for example version 7.10.255 becomes 0x070A00FF.

The version and hash of a subset of files is calculated using `git log` and means the latest commit (and the latest version tag) where at least one of the files was changed. It is worth noticing that there is no one-to-one correspondence between tag and hash, because not all the commits are tagged, so a tag can correspond to several hashes, all the ones that occurred between that tag and the previous one.

Hog will provide all the generic described in the table above, but if you do not plan to use them you can just leave them unconnected or do not add them to your top module at all. The HDL synthesiser will ignore them, maybe giving a warning.


[^1]: Generics are used in VHDL language, parameters are used in Verilog, SystemVerilog languages.
