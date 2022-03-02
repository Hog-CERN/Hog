--   Copyright 2018-2022 The University of Birmingham
--
--   Licensed under the Apache License, Version 2.0 (the "License");
--   you may not use this file except in compliance with the License.
--   You may obtain a copy of the License at
--
--       http:--www.apache.org/licenses/LICENSE-2.0
--
--   Unless required by applicable law or agreed to in writing, software
--   distributed under the License is distributed on an "AS IS" BASIS,
--   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--   See the License for the specific language governing permissions and
--   limitations under the License
.
-- Doxygen-compatible comments
--! @file
--! @brief top_<myproj>
--! @details
--! Any details you want to add
--! @author Name Surname

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

-- Change myproj to your project name
entity top_myproj is
  generic (
    -- Global Generic Variables
    GLOBAL_DATE : std_logic_vector(31 downto 0);
    GLOBAL_TIME : std_logic_vector(31 downto 0);
    GLOBAL_VER : std_logic_vector(31 downto 0);
    GLOBAL_SHA : std_logic_vector(31 downto 0);
    TOP_VER : std_logic_vector(31 downto 0);
    TOP_SHA : std_logic_vector(31 downto 0);
    CON_VER : std_logic_vector(31 downto 0);
    CON_SHA : std_logic_vector(31 downto 0);
    HOG_VER : std_logic_vector(31 downto 0);
    HOG_SHA : std_logic_vector(31 downto 0);

    --IPBus XML
    XML_SHA : std_logic_vector(31 downto 0);
    XML_VER : std_logic_vector(31 downto 0);

    -- Project Specific Lists (One for each .src file in your Top/myproj/list folder)
    MYLIB0_VER : std_logic_vector(31 downto 0);
    MYLIB0_SHA : std_logic_vector(31 downto 0);
    MYLIB1_VER : std_logic_vector(31 downto 0);
    MYLIB1_SHA : std_logic_vector(31 downto 0);

    -- External library specific variables (only if you have an external library)
    MYEXTLIB_SHA : std_logic_vector(31 downto 0);
    -- Project flavour
    FLAVOUR : integer
  );
  port (

  );
end entity; -- top_myproj

architecture behaviour of top_myproj is

begin

end architecture behaviour;