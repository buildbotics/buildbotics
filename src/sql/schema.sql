ALTER DATABASE buildbotics charset=utf8;


CREATE TABLE IF NOT EXISTS config (
  name VARCHAR(64),
  value VARCHAR(256),

  PRIMARY KEY (name)
);


CREATE TABLE IF NOT EXISTS notifications (
  id INT AUTO_INCREMENT,
  name VARCHAR(64),
  PRIMARY KEY (id)
) AUTO_INCREMENT = 0;


CREATE TABLE IF NOT EXISTS authorizations (
  id INT AUTO_INCREMENT,
  name VARCHAR(64),
  PRIMARY KEY (id)
) AUTO_INCREMENT = 0;


CREATE TABLE IF NOT EXISTS profiles (
  `id`             INT AUTO_INCREMENT,
  `name`           VARCHAR(64) NOT NULL UNIQUE,
  `joined`         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `lastseen`       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `disabled`       BOOL NOT NULL DEFAULT false,
  `fullname`       VARCHAR(256),
  `location`       VARCHAR(256),
  `avatar`         VARCHAR(256),
  `url`            VARCHAR(256),
  `bio`            TEXT,
  `points`         INT NOT NULL DEFAULT 0,
  `followers`      INT NOT NULL DEFAULT 0,
  `following`      INT NOT NULL DEFAULT 0,
  `stars`          INT NOT NULL DEFAULT 0,
  `badges`         INT NOT NULL DEFAULT 0,
  `space`          BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `auth`           BIGINT UNSIGNED NOT NULL DEFAULT 0,

  PRIMARY KEY (`id`),
  FULLTEXT KEY `text` (`name`, `fullname`, `location`, `bio`)
);


CREATE TABLE IF NOT EXISTS profile_redirects (
  `old_profile` VARCHAR(64) NOT NULL,
  `new_profile` VARCHAR(64) NOT NULL,

  UNIQUE (`old_profile`)
);


CREATE TABLE IF NOT EXISTS settings (
  id             INT,
  email          VARCHAR(256),
  authorizations BIT(64) NOT NULL DEFAULT 0,
  notifications  BIT(64) NOT NULL DEFAULT 0,

  PRIMARY KEY (id),
  FOREIGN KEY (id) REFERENCES profiles(id) ON DELETE CASCADE
);


CREATE TABLE IF NOT EXISTS providers (
  name VARCHAR(16),
  PRIMARY KEY (name)
);


INSERT INTO providers
  VALUES ('google'), ('github'), ('facebook'), ('twitter')
  ON DUPLICATE KEY UPDATE name = name;



CREATE TABLE IF NOT EXISTS associations (
  provider   VARCHAR(16) NOT NULL,
  id         VARCHAR(64) NOT NULL,
  name       VARCHAR(256) NOT NULL,
  email      VARCHAR(256) NOT NULL,
  avatar     VARCHAR(256) NOT NULL,
  profile_id INT,

  PRIMARY KEY (provider, id),
  FOREIGN KEY (provider) REFERENCES providers(name) ON DELETE CASCADE,
  FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE
);


CREATE TABLE IF NOT EXISTS followers (
  `follower_id` INT NOT NULL,
  `followed_id` INT NOT NULL,

  PRIMARY KEY (`follower_id`, `followed_id`),
  FOREIGN KEY (`follower_id`) REFERENCES profiles(id) ON DELETE CASCADE,
  FOREIGN KEY (`followed_id`) REFERENCES profiles(id) ON DELETE CASCADE
);


CREATE TABLE IF NOT EXISTS licenses (
  `name`           VARCHAR(64),
  `url`            VARCHAR(256),

  PRIMARY KEY (`name`)
);


INSERT INTO licenses
  VALUES
  ('Public domain', 'http://wikipedia.org/wiki/Public_domain'),
  ('GNU Public License v2.0', 'http://opensource.org/licenses/GPL-2.0'),
  ('GNU Public License v3.0', 'http://opensource.org/licenses/GPL-3.0'),
  ('MIT License', 'http://opensource.org/licenses/MIT'),
  ('BSD License', 'http://opensource.org/licenses/BSD-2-Clause'),
  ('Creative Commons - Attribution License v4.0',
  'http://creativecommons.org/licenses/by/4.0/'),
  ('Creative Commons - Attribution-NoDerivatives License v4.0',
  'http://creativecommons.org/licenses/by-nd/4.0/'),
  ('Creative Commons - Attribution-ShareAlike License v4.0',
  'http://creativecommons.org/licenses/by-sa/4.0/'),
  ('Creative Commons - Attribution-NonCommercial License v4.0',
  'http://creativecommons.org/licenses/by-nc/4.0/'),
  ('Creative Commons - Attribution-NonCommercial-NoDerivatives License v4.0',
  'http://creativecommons.org/licenses/by-nc-nd/4.0/'),
  ('Creative Commons - Attribution-NonCommercial-ShareAlike License v4.0',
  'http://creativecommons.org/licenses/by-nc-sa/4.0/')
  ON DUPLICATE KEY UPDATE name = name;


CREATE TABLE IF NOT EXISTS thing_type (
  `name` CHAR(8) PRIMARY KEY
);


INSERT INTO thing_type
  VALUES ('project'), ('machine'), ('tool')
  ON DUPLICATE KEY UPDATE name = name;


CREATE TABLE IF NOT EXISTS things (
  `id`           INT NOT NULL AUTO_INCREMENT,
  `parent_id`    INT,

  `owner_id`     INT NOT NULL,
  `name`         VARCHAR(64) NOT NULL,
  `type`         CHAR(8) NOT NULL,
  `title`        VARCHAR(128),
  `url`          VARCHAR(256),
  `instructions` MEDIUMTEXT,
  `license`      VARCHAR(64) DEFAULT 'BSD License',
  `tags`         TEXT,

  `published`    TIMESTAMP NULL,

  `created`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `modified`     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  `comments`     INT NOT NULL DEFAULT 0,
  `stars`        INT NOT NULL DEFAULT 0,
  `children`     INT NOT NULL DEFAULT 0,

  `space`        BIGINT UNSIGNED NOT NULL DEFAULT 0,

  PRIMARY KEY (`id`),
  FULLTEXT KEY `text` (`name`, `title`, `instructions`, `tags`),
  UNIQUE (`owner_id`, `name`),
  FOREIGN KEY (`owner_id`) REFERENCES profiles(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`parent_id`) REFERENCES things(`id`) ON DELETE SET NULL,
  FOREIGN KEY (`type`) REFERENCES thing_type(`name`),
  FOREIGN KEY (`license`) REFERENCES licenses(`name`) ON DELETE SET NULL
);


CREATE TABLE IF NOT EXISTS thing_redirects (
  `old_owner` VARCHAR(64) NOT NULL,
  `new_owner` VARCHAR(64) NOT NULL,
  `old_thing` VARCHAR(64) NOT NULL,
  `new_thing` VARCHAR(64) NOT NULL,

  UNIQUE (`old_owner`, `old_thing`)
);


CREATE TABLE IF NOT EXISTS stars (
  `profile_id` INT NOT NULL,
  `thing_id`   INT NOT NULL,
  `created`    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (`profile_id`, `thing_id`),
  FOREIGN KEY (`profile_id`) REFERENCES profiles(id) ON DELETE CASCADE,
  FOREIGN KEY (`thing_id`) REFERENCES things(id) ON DELETE CASCADE
);


CREATE TABLE IF NOT EXISTS comments (
  `id`        INT NOT NULL AUTO_INCREMENT,
  `owner_id`  INT NOT NULL,
  `thing_id`  INT NOT NULL,
  `created`   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `modified`  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `ref`       INT,
  `text`      TEXT,

  PRIMARY KEY (`id`),
  FULLTEXT KEY `text` (`text`),
  FOREIGN KEY (`owner_id`) REFERENCES profiles(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`thing_id`) REFERENCES things(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`ref`) REFERENCES comments(`id`) ON DELETE SET NULL
);


CREATE TABLE IF NOT EXISTS tags (
  `id`    INT NOT NULL AUTO_INCREMENT,
  `name`  VARCHAR(64) NOT NULL UNIQUE,
  `count` INT NOT NULL DEFAULT 0,

  FULLTEXT KEY `tags` (`name`),
  PRIMARY KEY (`id`)
);


CREATE TABLE IF NOT EXISTS thing_tags (
  `thing_id` INT NOT NULL,
  `tag_id`   INT NOT NULL,

  PRIMARY KEY (`thing_id`, `tag_id`),
  FOREIGN KEY (`thing_id`) REFERENCES things(id) ON DELETE CASCADE,
  FOREIGN KEY (`tag_id`) REFERENCES tags(id) ON DELETE CASCADE
);


CREATE TABLE IF NOT EXISTS badges (
  `id`          INT NOT NULL AUTO_INCREMENT,
  `name`        VARCHAR(64) NOT NULL UNIQUE,
  `issued`      INT DEFAULT 0,
  `points`      INT DEFAULT 0,
  `description` VARCHAR(256),
  `auth`        BIGINT UNSIGNED NOT NULL DEFAULT 0,

  PRIMARY KEY (`id`)
);


CREATE TABLE IF NOT EXISTS profile_badges (
  `profile_id` INT NOT NULL,
  `badge_id`   INT NOT NULL,

  PRIMARY KEY (`profile_id`, `badge_id`),
  FOREIGN KEY (`profile_id`) REFERENCES profiles(id) ON DELETE CASCADE,
  FOREIGN KEY (`badge_id`) REFERENCES badges(id) ON DELETE CASCADE
);


CREATE TABLE IF NOT EXISTS files (
  `id`        INT NOT NULL AUTO_INCREMENT,
  `thing_id`  INT NOT NULL,
  `name`      VARCHAR(80) NOT NULL,
  `type`      VARCHAR(64) NOT NULL,
  `space`     INT NOT NULL,
  `url`       VARCHAR(256) NOT NULL,
  `caption`   VARCHAR(256),
  `display`   BOOL NOT NULL DEFAULT true,
  `created`   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `downloads` INT UNSIGNED NOT NULL DEFAULT 0,
  `position`  INT NOT NULL DEFAULT 0,
  `confirmed` BOOL NOT NULL DEFAULT false,

  PRIMARY KEY (`id`),
  UNIQUE (`thing_id`, `name`),
  FOREIGN KEY (`thing_id`) REFERENCES things(id) ON DELETE CASCADE
);


CREATE TABLE IF NOT EXISTS event_actions (
  name VARCHAR(16),
  PRIMARY KEY (name)
);


INSERT INTO event_actions
  VALUES
    -- Profile actions
    ('badge'), ('follow'),
    -- Thing actions
    ('publish'), ('rename'), ('star'), ('comment')
  ON DUPLICATE KEY UPDATE name = name;


CREATE TABLE IF NOT EXISTS event_object_types (
  name VARCHAR(16),
  PRIMARY KEY (name)
);


INSERT INTO event_object_types
  VALUES ('profile'), ('thing'), ('comment'), ('badge')
  ON DUPLICATE KEY UPDATE name = name;


CREATE TABLE IF NOT EXISTS events (
  id INT NOT NULL AUTO_INCREMENT,
  ts          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  subject_id  INT NOT NULL,
  action      VARCHAR(16) NOT NULL,
  object_type VARCHAR(16) NOT NULL,
  object_id   INT NOT NULL,

  PRIMARY KEY (id, subject_id),
  FOREIGN KEY (`subject_id`) REFERENCES profiles(id) ON DELETE CASCADE,
  FOREIGN KEY (`action`) REFERENCES event_actions(name),
  FOREIGN KEY (`object_type`) REFERENCES event_object_types(name)
);
