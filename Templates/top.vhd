--------------------------------------------------------------------------------
-- Title       : top.vhd
-- Project     : Default Project Name
--------------------------------------------------------------------------------
-- File        : top.vhd
-- Author      : Davide Cieri davide.cieri@cern.ch
-- Company     : Max-Planck-Institute For Physics, Munich
-- Created     : Tue Feb 11 13:50:27 2020
-- Last update : Tue Feb 11 14:26:02 2020
-- Standard    : <VHDL-2008 | VHDL-2002 | VHDL-1993 | VHDL-1987>
--------------------------------------------------------------------------------
-- Copyright (c) 2020 Max-Planck-Institute For Physics, Munich
-------------------------------------------------------------------------------
-- Description:  Template for a top vhdl file, with the generic variables parsed
--               by HOG
--------------------------------------------------------------------------------
-- Revisions:  Revisions and documentation are controlled by
-- the revision control system (RCS).  The RCS should be consulted
-- on revision history.
-------------------------------------------------------------------------------


-- Doxygen-compatible comments
--! @file
--! @brief top_<myproj>
--! @details 
--! Any details you want to add
--! @author Name Surname

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Change <myproj> to your project name
entity top_<myproj> is
    generic (
        -- Global Generic Variables
        GLOBAL_FWDATE       : std_logic_vector(7 downto 0);
        GLOBAL_FWTIME       : std_logic_vector(7 downto 0);
        OFFICIAL            : std_logic_vector(7 downto 0);
        TOP_FWHASH          : std_logic_vector(7 downto 0);
        XML_HASH            : std_logic_vector(7 downto 0);
        GLOBAL_FWVERSION    : std_logic_vector(7 downto 0);
        TOP_FWVERSION       : std_logic_vector(7 downto 0);
        XML_VERSION         : std_logic_vector(7 downto 0);
        HOG_FWHASH          : std_logic_vector(7 downto 0);
        -- Project Specific Lists (One for each .src file in your Top/myproj/list folder)
        <MYLIB0>_FWVERSION    : std_logic_vector(7 downto 0);
        <MYLIB0>_FWHASH       : std_logic_vector(7 downto 0);
        <MYLIB1>_FWVERSION    : std_logic_vector(7 downto 0);
        <MYLIB1>_FWHASH       : std_logic_vector(7 downto 0);
        -- Submodule Specific variables (only if you have a submodule, one per submodule)
        <MYSUBMODULE0>_FWHASH : std_logic_vector(7 downto 0);
        <MYSUBMODULE1>_FWHASH : std_logic_vector(7 downto 0);
        -- External library specific variables (only if you have an external library)
        <MYEXTLIB>_FWHASH       : std_logic_vector(7 downto 0);
        -- Project flavour
        FLAVOUR             : integer
    );
  port (
    
  ) ;
end entity ; -- top_myproj

architecture behaviour of top_<myproj> is

begin
    
end architecture behaviour;