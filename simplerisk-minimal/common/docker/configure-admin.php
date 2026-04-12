<?php
if (php_sapi_name() !== 'cli') { exit(1); }

require_once('/var/www/simplerisk/includes/functions.php');
require_once('/var/www/simplerisk/includes/permissions.php');

$username = getenv('ADMIN_USERNAME') ?: null;
$password = getenv('ADMIN_PASSWORD') ?: null;
$email    = getenv('ADMIN_EMAIL')    ?: null;
$name     = getenv('ADMIN_NAME')     ?: 'Administrator';

if (!$username || !$password || !$email) {
    fwrite(STDERR, "ADMIN_USERNAME, ADMIN_PASSWORD, and ADMIN_EMAIL are required.\n");
    exit(1);
}

$db   = db_open();
$stmt = $db->prepare("SELECT COUNT(*) FROM user");
$stmt->execute();
$count = (int)$stmt->fetchColumn();
db_close($db);

if ($count > 0) {
    echo "Database already has users, skipping admin user creation.\n";
    exit(0);
}

if (get_id_by_user($username)) {
    echo "User '{$username}' already exists, skipping.\n";
    exit(0);
}

$salt = '';
$values = array_merge(range(0, 9), range('a', 'z'), range('A', 'Z'));
for ($i = 0; $i < 20; $i++) {
    $salt .= $values[array_rand($values)];
}
set_time_limit(120);
$hash = crypt($password, '$2a$15$' . md5($salt));

$user_id = add_user(
    'simplerisk',
    $username,
    $email,
    $name,
    $salt,
    $hash,
    [],
    1,
    1,
    0,
    0,
    0,
    get_possible_permission_ids()
);

echo "Admin user '{$username}' created with ID {$user_id}.\n";
