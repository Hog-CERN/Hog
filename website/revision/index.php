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
$minc = file_get_contents("status");
$stat = explode("\n", $minc);
$filename = "status";
date_default_timezone_set("Europe/London"); 
echo "<h2>Last design flow time: </h2>".date("F d Y H:i:s",filemtime($filename))."<br/><br/>";
$handle = fopen($filename, "rb");
$fsize = filesize($filename);
$contents = fread($handle, $fsize);
fclose($handle);
echo $minc;
?>
</div>

</body>
</html>
