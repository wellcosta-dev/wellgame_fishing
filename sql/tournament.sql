CREATE TABLE IF NOT EXISTS `wellgame_fishing_tournament` (
  `citizenid` VARCHAR(50) NOT NULL,
  `name` VARCHAR(100) NOT NULL DEFAULT '',
  `weight` FLOAT NOT NULL DEFAULT 0,
  `fish` VARCHAR(64) NOT NULL DEFAULT '',
  `updated_at` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
