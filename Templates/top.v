//   Copyright 2018-2020 The University of Birmingham
//
//   Licensed under the Apache License, Version 2.0 (the "License");
//   you may not use this file except in compliance with the License.
//   You may obtain a copy of the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in writing, software
//   distributed under the License is distributed on an "AS IS" BASIS,
//   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//   See the License for the specific language governing permissions and
//   limitations under the License.

// --------------------------------------------------------------------------------
// -- Title       : top.v
// -- Project     : Default Project Name
// --------------------------------------------------------------------------------
// -- File        : top.v
// -- Author      : Davide Cieri davide.cieri@cern.ch
// -- Company     : Max-Planck-Institute For Physics, Munich
// -- Created     : Tue Feb 11 13:50:27 2020
// -- Last update : Tue Feb 11 14:26:02 2020
// -- Standard    : <Verilog>
// --------------------------------------------------------------------------------
// -- Copyright (c) 2020 Max-Planck-Institute For Physics, Munich
// -------------------------------------------------------------------------------
// -- Description:  Template for a top verilog file, with the generic variables parsed
// --               by HOG
// --------------------------------------------------------------------------------
// -- Revisions:  Revisions and documentation are controlled by
// -- the revision control system (RCS).  The RCS should be consulted
// -- on revision history.
// -------------------------------------------------------------------------------

// Change <myproj> to your project name
module top_<myproj> # (
        // Global Generic Variables
        parameter GLOBAL_FWDATE     = 0,
        parameter GLOBAL_FWTIME     = 0,
        parameter TOP_FWHASH        = 0,
        parameter XML_HASH          = 0,
        parameter GLOBAL_FWVERSION  = 0,
        parameter TOP_FWVERSION     = 0,
        parameter XML_VERSION       = 0,
        parameter HOG_FWHASH        = 0,
        parameter HOG_FWVERSION     = 0,
        // Project Specific Lists (One for each .src file in your Top/myproj/list folder)
        parameter <MYLIB0>_FWVERSION = 0,
        parameter <MYLIB0>_FWHASH    = 0,
        parameter <MYLIB1>_FWVERSION = 0,
        parameter <MYLIB1>_FWHASH    = 0,
        // Submodule Specific variables (only if you have a submodule, one per submodule)
        parameter <MYSUBMODULE0>_FWHASH = 0,
        parameter <MYSUBMODULE1>_FWHASH = 0,
        // External library specific variables (only if you have an external library)
        parameter <MYEXTLIB>_FWHASH = 0,
        // Project flavour
        parameter FLAVOUR = 0
    )
  // port declaration
  (
    // input
    // output
  ) ;


endmodule
