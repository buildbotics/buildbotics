ALTER DATABASE buildbotics charset=utf8;


CREATE TABLE IF NOT EXISTS config (
  name VARCHAR(64),
  value VARCHAR(256),

  PRIMARY KEY (name)
);


CREATE TABLE IF NOT EXISTS profiles (
  `id`            INT AUTO_INCREMENT,
  `name`          VARCHAR(64) NOT NULL UNIQUE,
  `joined`        TIMESTAMP NOT NULL,
  `disabled`      BOOL DEFAULT false,
  `redirect`      BOOL DEFAULT false,
  `profile`       MEDIUMTEXT,
  `associations`  BLOB,
  `emails`        BLOB,
  `notifications` BLOB,
  `points`        INT NOT NULL DEFAULT 0,
  `followers`     INT NOT NULL DEFAULT 0,
  `following`     INT NOT NULL DEFAULT 0,
  `stars`         INT NOT NULL DEFAULT 0,
  `badges`        INT NOT NULL DEFAULT 0,

  PRIMARY KEY (`id`),
  FULLTEXT KEY `text` (`name`, `profile`)
);


CREATE TABLE IF NOT EXISTS followers (
  `follower_id` INT NOT NULL,
  `followed_id` INT NOT NULL,

  PRIMARY KEY (`follower_id`, `followed_id`),
  FOREIGN KEY (`follower_id`) REFERENCES profiles(id) ON DELETE CASCADE,
  FOREIGN KEY (`followed_id`) REFERENCES profiles(id) ON DELETE CASCADE
);


CREATE TABLE IF NOT EXISTS thing_type (
  `name` CHAR(8) PRIMARY KEY
);

REPLACE INTO thing_type VALUES("project");
REPLACE INTO thing_type VALUES("machine");
REPLACE INTO thing_type VALUES("tool");
REPLACE INTO thing_type VALUES("step");


CREATE TABLE IF NOT EXISTS things (
  `id`        INT NOT NULL AUTO_INCREMENT,
  `owner_id`  INT NOT NULL,
  `parent_id` INT,
  `name`      VARCHAR(64) NOT NULL,
  `type`      CHAR(8),
  `published` BOOL DEFAULT false,
  `redirect`  BOOL DEFAULT false,
  `modified`  TIMESTAMP   NOT NULL,
  `brief`     VARCHAR(256) DEFAULT "",
  `text`      TEXT DEFAULT "",
  `tags`      TEXT DEFAULT "",
  `comments`  INT NOT NULL DEFAULT 0,
  `value`      MEDIUMBLOB,

  PRIMARY KEY (`id`),
  FULLTEXT KEY `text` (`name`, `brief`, `text`, `tags`),
  FULLTEXT KEY `tags` (`tags`),
  UNIQUE (`owner_id`, `type`, `name`),
  FOREIGN KEY (`owner_id`) REFERENCES profiles(`id`),
  FOREIGN KEY (`parent_id`) REFERENCES things(`id`),
  FOREIGN KEY (`type`) REFERENCES thing_type(`name`)
);


CREATE TABLE IF NOT EXISTS stars (
  `profile_id` INT NOT NULL,
  `thing_id` INT NOT NULL,

  PRIMARY KEY (`profile_id`, `thing_id`),
  FOREIGN KEY (`profile_id`) REFERENCES profiles(id) ON DELETE CASCADE,
  FOREIGN KEY (`thing_id`) REFERENCES things(id) ON DELETE CASCADE
);


CREATE TABLE IF NOT EXISTS comments (
  `id`        INT NOT NULL AUTO_INCREMENT,
  `owner_id`  INT NOT NULL,
  `thing_id`  INT NOT NULL,
  `creation`  TIMESTAMP NOT NULL,
  `modified`  TIMESTAMP NOT NULL,
  `ref`       INT,
  `text`      TEXT DEFAULT "",

  PRIMARY KEY (`id`),
  FULLTEXT KEY `text` (`text`)
);


CREATE TABLE IF NOT EXISTS tags (
  `id`   INT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(64) NOT NULL UNIQUE,

  PRIMARY KEY (`id`)
);


CREATE TABLE IF NOT EXISTS licenses (
  `name`  VARCHAR(64),
  `value` BLOB,

  PRIMARY KEY (`name`)
);


CREATE TABLE IF NOT EXISTS badges (
  `id`     INT NOT NULL AUTO_INCREMENT,
  `name`   VARCHAR(64) NOT NULL UNIQUE,
  `issued` INT DEFAULT 0,
  `value`  BLOB,

  PRIMARY KEY (`id`)
);


CREATE TABLE IF NOT EXISTS profile_badges (
  `profile_id` INT NOT NULL,
  `badge_id`   INT NOT NULL,

  PRIMARY KEY (`profile_id`, `badge_id`),
  FOREIGN KEY (`profile_id`) REFERENCES profiles(id) ON DELETE CASCADE,
  FOREIGN KEY (`badge_id`)   REFERENCES tags(id) ON DELETE CASCADE
);


CREATE TABLE IF NOT EXISTS files (
  `id`    INT NOT NULL AUTO_INCREMENT,
  `value` BLOB,

  PRIMARY KEY (`id`)
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
  ts        TIMESTAMP NOT NULL,
  summary   VARCHAR(256),

  PRIMARY KEY (id, owner_id)
) PARTITION BY HASH(owner_id) PARTITIONS 31; -- Partition by date?
