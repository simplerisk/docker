<?php
/**
 * Headless database schema upgrade. Runs SimpleRisk's core release-by-release
 * schema upgrade (run_database_upgrade_structured, defined in
 * includes/upgrade.php) against the database, with no HTTP context and no
 * credentials beyond the DB connection. Requiring upgrade.php pulls in the full
 * app bootstrap (bootstrap.php loads config.php + functions.php and is
 * PHP_SAPI==='cli' aware), so db_open() and the upgrade run standalone. Emits
 * the structured per-release JSON result to stdout and exits 0 on success,
 * 1 on failure.
 *
 * Triggered by the DB_UPGRADE entrypoint mode; runs against the instance's own
 * database (the same SIMPLERISK_DB_* env as the serving container).
 */

require_once('/var/www/simplerisk/includes/upgrade.php');

$db     = db_open();
$result = run_database_upgrade_structured($db);
db_close($db);

fwrite(STDOUT, json_encode($result, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . "\n");
exit(!empty($result['success']) ? 0 : 1);
