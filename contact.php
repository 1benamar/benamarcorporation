<?php
/**
 * Maneja el envío del formulario de contacto de la web.
 * Recibe POST desde main.js (fetch) y envía un email a BENAMAR.
 * Requiere hosting con PHP (Hostinger lo trae activado por defecto).
 */

header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'error' => 'method_not_allowed']);
    exit;
}

function clean_field($value) {
    $value = trim($value ?? '');
    // Evita inyección de cabeceras en el email
    $value = str_replace(["\r", "\n"], '', $value);
    return $value;
}

$name    = clean_field($_POST['name'] ?? '');
$email   = clean_field($_POST['email'] ?? '');
$company = clean_field($_POST['company'] ?? '');
$service = clean_field($_POST['service'] ?? '');
$message = trim($_POST['message'] ?? '');

if ($name === '' || $email === '' || $service === '' || $message === '') {
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'missing_fields']);
    exit;
}

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'invalid_email']);
    exit;
}

// Destino: el email de BENAMAR que recibe las solicitudes
$to = 'benamarcorporation@gmail.com';
$subject = 'Nueva solicitud web - ' . $service . ' (' . $name . ')';

$body  = "Nombre: {$name}\n";
$body .= "Email: {$email}\n";
if ($company !== '') {
    $body .= "Empresa: {$company}\n";
}
$body .= "Servicio de interes: {$service}\n\n";
$body .= "Mensaje:\n{$message}\n";

// El remitente debe ser del propio dominio: los proveedores de correo
// descartan o mandan a spam los mensajes con un remitente ajeno al servidor.
$from = 'contact@benamar.es';

// Codifica el asunto para que tildes y eñes lleguen legibles
$encoded_subject = '=?UTF-8?B?' . base64_encode($subject) . '?=';

$headers   = [];
$headers[] = 'From: BENAMAR Web <' . $from . '>';
$headers[] = 'Reply-To: ' . $email;
$headers[] = 'MIME-Version: 1.0';
$headers[] = 'Content-Type: text/plain; charset=UTF-8';

$sent = @mail($to, $encoded_subject, $body, implode("\r\n", $headers), '-f' . $from);

if ($sent) {
    echo json_encode(['success' => true]);
} else {
    // Si el correo del servidor falla, la solicitud se guarda en disco para
    // que no se pierda. El nombre empieza por punto y el .htaccess bloquea
    // esas rutas, así que el archivo no es accesible desde fuera.
    $registro  = str_repeat('-', 60) . "\n";
    $registro .= 'Fecha: ' . date('Y-m-d H:i:s') . "\n";
    $registro .= $body;
    @file_put_contents(__DIR__ . '/.solicitudes-no-enviadas.log', $registro, FILE_APPEND | LOCK_EX);

    http_response_code(500);
    echo json_encode(['success' => false, 'error' => 'send_failed']);
}
