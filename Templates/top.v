//   Copyright 2018-2022 The University of Birmingham
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
// -------------------------------------------------------------------------------
// -- Description:  Template for a top verilog file, with the generic variables parsed
// --               by Hog
// --------------------------------------------------------------------------------

// Change <myproj> to your project name
module top_<myproj> # (
    // Global Generic Variables
    parameter GLOBAL_DATE  = 0,
    parameter GLOBAL_TIME  = 0,
    parameter GLOBAL_VER   = 0,
    parameter GLOBAL_SHA   = 0,

    parameter TOP_SHA     = 0,
    parameter TOP_VER     = 0,

    parameter CON_SHA     = 0,
    parameter CON_VER     = 0,

    parameter HOG_SHA     = 0,
    parameter HOG_VER     = 0,

    // Optional IPBus xml
    parameter XML_SHA     = 0,
    parameter XML_VER     = 0,

    // Project Specific Lists (One for each .src file in your Top/myproj/list folder)
    parameter <MYLIB0>_VER = 0,
    parameter <MYLIB0>_SHA = 0,
    parameter <MYLIB1>_VER = 0,
    parameter <MYLIB1>_SHA = 0,

    // External library specific variables (only if you have an external library)
    parameter <MYEXTLIB>_SHA = 0,
    // Project flavour
    parameter FLAVOUR = 0
  )
  // port declaration
  (
    // input
    // output
  ) ;

endmodule
