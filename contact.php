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

// IMPORTANTE: cambia "tu-dominio.com" por el dominio real donde quede
// alojada la web (ej. benamar.agency) para que los emails no acaben en spam.
$headers   = [];
$headers[] = 'From: BENAMAR Web <no-reply@tu-dominio.com>';
$headers[] = 'Reply-To: ' . $email;
$headers[] = 'Content-Type: text/plain; charset=UTF-8';

$sent = @mail($to, $subject, $body, implode("\r\n", $headers));

if ($sent) {
    echo json_encode(['success' => true]);
} else {
    http_response_code(500);
    echo json_encode(['success' => false, 'error' => 'send_failed']);
}
