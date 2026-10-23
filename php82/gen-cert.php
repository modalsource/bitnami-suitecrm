<?php
// Genera un certificato UDP self-signed per localhost per il build-time httpd -t.
// (runtime: Bitnami mette i certificati veri in /bitnami/... se montati, questo resta un fallback)
$dir = '/opt/bitnami/apache/conf/bitnami/certs';
if (!is_dir($dir)) { @mkdir($dir, 0755, true); }

$pkey = openssl_pkey_new([
    'private_key_bits' => 2048,
    'private_key_type' => OPENSSL_KEYTYPE_RSA,
]);
$csr  = openssl_csr_new(['commonName' => 'localhost'], $pkey, ['digest_alg' => 'sha256']);
$cert = openssl_csr_sign($csr, null, $pkey, 3650, ['digest_alg' => 'sha256']);

openssl_x509_export($cert, $crt);
openssl_pkey_export($pkey, $key);

file_put_contents("$dir/server.crt", $crt);
chmod("$dir/server.crt", 0644);
file_put_contents("$dir/server.key", $key);
chmod("$dir/server.key", 0600);
echo "self-signed localhost certificato generato in $dir\n";
