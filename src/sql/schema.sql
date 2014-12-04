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
  `lastlog`        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `disabled`       BOOL NOT NULL DEFAULT false,
  `redirect`       BOOL NOT NULL DEFAULT false,
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

  PRIMARY KEY (`id`),
  FULLTEXT KEY `text` (`name`, `fullname`, `location`, `bio`)
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
  `brief`          TEXT,
  `description`    MEDIUMTEXT,
  `shareable`      BOOL NOT NULL DEFAULT true,
  `commercial_use` BOOL NOT NULL DEFAULT true,
  `attribution`    BOOL NOT NULL DEFAULT false,

  PRIMARY KEY (`name`)
);


CREATE TABLE IF NOT EXISTS thing_type (
  `name` CHAR(8) PRIMARY KEY
);


INSERT INTO thing_type
  VALUES ('project'), ('machine'), ('tool')
  ON DUPLICATE KEY UPDATE name = name;


CREATE TABLE IF NOT EXISTS things (
  `id`         INT NOT NULL AUTO_INCREMENT,
  `owner_id`   INT NOT NULL,
  `parent_id`  INT,
  `name`       VARCHAR(64) NOT NULL,
  `type`       CHAR(8),
  `published`  BOOL DEFAULT false,
  `redirect`   BOOL DEFAULT false,
  `created`    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `modified`   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `brief`      VARCHAR(256) DEFAULT '',
  `url`        VARCHAR(256) DEFAULT '',
  `text`       TEXT DEFAULT '',
  `tags`       TEXT DEFAULT '',
  `comments`   INT NOT NULL DEFAULT 0,
  `stars`      INT NOT NULL DEFAULT 0,
  `children`   INT NOT NULL DEFAULT 0,
  `license`    VARCHAR(64),

  PRIMARY KEY (`id`),
  FULLTEXT KEY `text` (`name`, `brief`, `text`, `tags`),
  UNIQUE (`owner_id`, `type`, `name`),
  FOREIGN KEY (`owner_id`) REFERENCES profiles(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`parent_id`) REFERENCES things(`id`) ON DELETE SET NULL,
  FOREIGN KEY (`type`) REFERENCES thing_type(`name`) ON DELETE SET NULL,
  FOREIGN KEY (`license`) REFERENCES licenses(`name`) ON DELETE SET NULL
);


CREATE TABLE IF NOT EXISTS steps (
  `id`         INT NOT NULL AUTO_INCREMENT,
  `owner_id`   INT NOT NULL,
  `thing_id`   INT NOT NULL,
  `name`       VARCHAR(64) NOT NULL,
  `created`    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `modified`   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `position`   INT DEFAULT 0,
  `text`       TEXT DEFAULT '',

  PRIMARY KEY (`id`),
  FULLTEXT KEY `text` (`name`, `text`),
  UNIQUE (`thing_id`, `name`),
  FOREIGN KEY (`owner_id`) REFERENCES profiles(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`thing_id`) REFERENCES things(`id`) ON DELETE CASCADE
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
  `step_id`   INT,
  `creation`  TIMESTAMP NOT NULL,
  `modified`  TIMESTAMP NOT NULL,
  `ref`       INT,
  `text`      TEXT DEFAULT '',

  PRIMARY KEY (`id`),
  FULLTEXT KEY `text` (`text`),
  FOREIGN KEY (`owner_id`) REFERENCES profiles(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`thing_id`) REFERENCES things(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`step_id`) REFERENCES steps(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`ref`) REFERENCES comments(`id`) ON DELETE SET NULL
);


CREATE TABLE IF NOT EXISTS tags (
  `id`    INT NOT NULL AUTO_INCREMENT,
  `name`  VARCHAR(64) NOT NULL UNIQUE,
  `count` INT NOT NULL DEFAULT 0,

  PRIMARY KEY (`id`)
);


CREATE TABLE IF NOT EXISTS badges (
  `id`          INT NOT NULL AUTO_INCREMENT,
  `name`        VARCHAR(64) NOT NULL UNIQUE,
  `issued`      INT DEFAULT 0,
  `points`      INT DEFAULT 0,
  `description` VARCHAR(256),

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
  `step_id`   INT,
  `name`      VARCHAR(256) NOT NULL,
  `type`      VARCHAR(64) NOT NULL,
  `url`       VARCHAR(256) NOT NULL,
  `caption`   VARCHAR(256) NOT NULL,
  `display`   BOOL NOT NULL DEFAULT true,
  `creation`  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `downloads` INT NOT NULL DEFAULT 0,
  `position`  INT DEFAULT 0,

  PRIMARY KEY (`id`),
  UNIQUE (`thing_id`, `name`),
  FOREIGN KEY (`thing_id`) REFERENCES things(id) ON DELETE CASCADE,
  FOREIGN KEY (`step_id`) REFERENCES steps(id) ON DELETE CASCADE
);


CREATE TABLE IF NOT EXISTS events (
  id INT NOT NULL AUTO_INCREMENT,
  owner_id  INT NOT NULL,
  type      ENUM('comment', 'badge', 'tag', 'license', 'step',
                 'project', 'tool', 'machine', 'file'),
  action    ENUM('create', 'rename', 'update', 'delete'),
  target_id INT,
  target_owner_id INT,
  url       VARCHAR(256),
  points    INT,
  ts        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  summary   VARCHAR(256),

  PRIMARY KEY (id, owner_id)
) PARTITION BY HASH(owner_id) PARTITIONS 31; -- Partition by date?
