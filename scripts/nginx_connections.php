<?php

$url = 'http://mynginxurl/status';

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $url);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
$resultat = curl_exec ($ch);
curl_close($ch);
$array = explode(" ", $resultat);
$lb1 = $array[2];

echo $lb1;

?>

