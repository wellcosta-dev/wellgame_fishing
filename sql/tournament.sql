CREATE TABLE IF NOT EXISTS `wellgame_fishing_tournament` (
  `citizenid` VARCHAR(50) NOT NULL,
  `name` VARCHAR(100) NOT NULL DEFAULT '',
  `weight` FLOAT NOT NULL DEFAULT 0,
  `fish` VARCHAR(64) NOT NULL DEFAULT '',
  `updated_at` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Winner's prize waits here if they were offline when the tournament ended;
-- paid out + row deleted on their next login (see server/fishing.lua QBCore:Server:PlayerLoaded).
CREATE TABLE IF NOT EXISTS `wellgame_fishing_pending_prizes` (
  `citizenid` VARCHAR(50) NOT NULL,
  `cash` INT NOT NULL DEFAULT 0,
  `pp` INT NOT NULL DEFAULT 0,
  `reason` VARCHAR(100) NOT NULL DEFAULT '',
  `created_at` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Personal catch log/collection — one row per (player, species) ever caught.
CREATE TABLE IF NOT EXISTS `wellgame_fishing_log` (
  `citizenid` VARCHAR(50) NOT NULL,
  `fish_key` VARCHAR(64) NOT NULL,
  `count` INT NOT NULL DEFAULT 0,
  `best_weight` FLOAT NOT NULL DEFAULT 0,
  `best_length` INT NOT NULL DEFAULT 0,
  `first_caught_at` INT NOT NULL DEFAULT 0,
  `last_caught_at` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`citizenid`, `fish_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
