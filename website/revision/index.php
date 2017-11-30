<html>
<head>
  <title>eFEX firmware flow status</title>
  <link rel="shortcut icon" href="../images/favicon.png" type="image/png">
</head>
<link href="/efex/doxygen.css" rel="stylesheet" type="text/css" media="screen" />
<link href="/efex/style.css" rel="stylesheet" type="text/css" media="screen" />
<body>
<div id="titlearea">
<table cellspacing="0" cellpadding="0">
 <tr style="height: 56px;">
  <td id="projectlogo"><img alt="Logo" src="https://webservices.web.cern.ch/webservices/Images/cernlogo.jpg"/></td>
  <td style="padding-left: 0.5em;">
   <div id="projectname">eFEX firmware automatic design-flow status </div>
   <div id="projectbrief">ATLAS l1-calo electron and tau feature extraction board</div>
  </td>
 </tr>
</table>
</div>
<a href="../"> Back </a>
<hr>
<?php
   $stati = glob("status*");
   if(count($stati)) {
    //natcasesort($stati);
   usort($stati, create_function('$b,$a', 'return filemtime($a) - filemtime($b);'));
    $i=0;
    foreach($stati as $filename) {
     echo "<h1> $filename </h1>";
     $content = file_get_contents($filename);
     date_default_timezone_set("Europe/London"); 
     echo "<p style=\"color:#36c\">".date("F d Y H:i:s",filemtime($filename))."</p>";
     echo $content;
     echo "<br/>\n";
   }
   
   } else {
   echo "<p> Sorry, no status file found... </p>";
   }
?>
</div>

</body>
</html>
