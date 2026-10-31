-- fivelog makes this table itself on start. Run it by hand only if your
-- database user can't create tables.

CREATE TABLE IF NOT EXISTS `fivelog` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `at` INT UNSIGNED NOT NULL,
    `kind` VARCHAR(24) NOT NULL,
    `src` SMALLINT UNSIGNED NULL,
    `license` VARCHAR(64) NULL,
    `name` VARCHAR(64) NULL,
    `target` VARCHAR(64) NULL,
    `target_name` VARCHAR(64) NULL,
    `text` VARCHAR(500) NOT NULL,
    `data` TEXT NULL,
    `x` FLOAT NULL,
    `y` FLOAT NULL,
    `z` FLOAT NULL,
    PRIMARY KEY (`id`),
    KEY `at` (`at`),
    KEY `kind_at` (`kind`, `at`),
    KEY `license_at` (`license`, `at`),
    KEY `target_at` (`target`, `at`)
);
