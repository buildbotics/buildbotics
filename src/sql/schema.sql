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
  `pending_avatar` VARCHAR(256),
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


INSERT INTO licenses (name)
  VALUES
  ('Public domain'),
  ('GNU Public License v2.0+'),
  ('GNU Public License v3.0+'),
  ('MIT License'),
  ('BSD License'),
  ('Creative Commons - Attrib License v4.0'),
  ('Creative Commons - Attrib,NoDeriv License v4.0'),
  ('Creative Commons - Attrib,ShareAlike License v4.0'),
  ('Creative Commons - Attrib,NonCom License v4.0'),
  ('Creative Commons - Attrib,NonCom,NoDeriv License v4.0'),
  ('Creative Commons - Attrib,NonCom,ShareAlike License v4.0')
  ON DUPLICATE KEY UPDATE url = url;

UPDATE licenses
  SET url = 'http://wikipedia.org/wiki/Public_domain', description =
   'Releasing a work in to the $name gives up all copyright '
   'claims to the work.  This is the least restricive option and allows anyone '
   'to do anything they like with the work.'
  WHERE name = 'Public domain';

UPDATE licenses
  SET url = 'http://opensource.org/licenses/GPL-2.0', description =
   'The $name is a popular Open-Source license which allows mostly '
   'unrestricted non-comercial use of the work provided that users who '
   'make modifications to the work and publish any part of it also publish '
   'their modifications under the $name or optionally under a later version of '
   'the GPL.'
  WHERE name ='GNU Public License v2.0+';

UPDATE licenses
  SET url = 'http://opensource.org/licenses/GPL-3.0', description =
   'The $name is a popular Open-Source license which allows mostly '
   'unrestricted non-comercial use of the work provided that users who '
   'make modifications to the work and publish any part of it also publish '
   'the changes they have made under the $name or optionally under a later '
   'version of the GPL.'
  WHERE name = 'GNU Public License v3.0+';

UPDATE licenses
  SET url = 'http://opensource.org/licenses/MIT', description =
   'The $name is a free software license originating at the Massachusetts '
   'Institute of Technology (MIT).  It is a permissive free software license, '
   'meaning that it permits reuse within proprietary and non-proprietary '
   'software provided that all copies and derivative works include a copy of '
   'the $name terms and the original copyright notice.'
  WHERE name = 'MIT License';

UPDATE licenses
  SET url = 'http://opensource.org/licenses/BSD-2-Clause', description =
   'The $name is a free software license originating at Berkeley University.  '
   'It allows almost unlimited freedom with the software so long as users '
   'include the BSD copyright notice in copies and derived works.'
  WHERE name = 'BSD License';

UPDATE licenses
  SET url = 'http://creativecommons.org/licenses/by/4.0/', description =
   'The less restrictive, $name, gives users maximum freedom to do what they '
   'want with the work but requires they give appropriate credit, provide a '
   'link to the license, and indicate if changes were made.'
  WHERE name = 'Creative Commons - Attrib License v4.0';

UPDATE licenses
  SET url = 'http://creativecommons.org/licenses/by-nd/4.0/', description =
   'The $name gives users freedom to use the work but requires they give '
   'appropriate credit and provide a link to the license but does not allow '
   'publishing derivitave works.'
  WHERE name = 'Creative Commons - Attrib,NoDeriv License v4.0';

UPDATE licenses
  SET url = 'http://creativecommons.org/licenses/by-sa/4.0/', description =
   'The $name gives users freedom to use the work but requires they give '
   'appropriate credit, provide a link to the license and if they '
   'publish derivitave works those works must also be published under the '
   '$name.'
  WHERE name = 'Creative Commons - Attrib,ShareAlike License v4.0';

UPDATE licenses
  SET url = 'http://creativecommons.org/licenses/by-nc/4.0/', description =
   'The $name, gives users freedom to use the work for non-commercial '
   'purposes and requires they give appropriate credit, provide a link to the '
   'license, and indicate if changes were made.'
  WHERE name = 'Creative Commons - Attrib,NonCom License v4.0';

UPDATE licenses
  SET url = 'http://creativecommons.org/licenses/by-nc-nd/4.0/', description =
   'The $name, gives users freedom to use the work for non-commercial '
   'purposes and requires they give appropriate credit and provide a link to '
   'the license but does not allow publishing derivitave works.'
  WHERE name = 'Creative Commons - Attrib,NonCom,NoDeriv License v4.0';

UPDATE licenses
  SET url = 'http://creativecommons.org/licenses/by-nc-sa/4.0/', description =
   'The $name, gives users freedom to use the work for non-commercial '
   'purposes and requires they give appropriate credit, provide a link to the '
   'license and if they publish derivitave works those works must also be '
   'published under the $name.'
  WHERE name = 'Creative Commons - Attrib,NonCom,ShareAlike License v4.0';



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
  `license`      VARCHAR(64) DEFAULT 'BSD License',
  `tags`         TEXT,
  `instructions` MEDIUMTEXT,

  `published`    TIMESTAMP NULL,
  `created`      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `modified`     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  `comments`     INT NOT NULL DEFAULT 0,
  `stars`        INT NOT NULL DEFAULT 0,
  `children`     INT NOT NULL DEFAULT 0,
  `views`        INT NOT NULL DEFAULT 0,

  `space`        BIGINT UNSIGNED NOT NULL DEFAULT 0,

  PRIMARY KEY (`id`),
  FULLTEXT KEY `text` (`name`, `title`, `tags`, `instructions`),
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


CREATE TABLE IF NOT EXISTS thing_views (
  thing_id INT NOT NULL,
  user     VARCHAR(64) NOT NULL,
  ts       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

  UNIQUE (thing_id, user),
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
  `created`   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `modified`  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `ref`       INT,
  `text`      TEXT,
  `votes`     INT NOT NULL DEFAULT 0,

  PRIMARY KEY (`id`),
  FULLTEXT KEY `text` (`text`),
  FOREIGN KEY (`owner_id`) REFERENCES profiles(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`thing_id`) REFERENCES things(`id`) ON DELETE CASCADE,
  FOREIGN KEY (`ref`) REFERENCES comments(`id`) ON DELETE SET NULL
);


CREATE TABLE IF NOT EXISTS comment_votes (
  comment_id INT NOT NULL,
  profile_id INT NOT NULL,
  vote TINYINT NOT NULL,

  UNIQUE (comment_id, profile_id),
  FOREIGN KEY (comment_id) REFERENCES comments(id) ON DELETE CASCADE,
  FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE
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
  `id`         INT NOT NULL AUTO_INCREMENT,
  `thing_id`   INT NOT NULL,
  `name`       VARCHAR(80) NOT NULL,
  `type`       VARCHAR(64) NOT NULL,
  `space`      INT NOT NULL,
  `path`       VARCHAR(256) NOT NULL,
  `caption`    VARCHAR(256),
  `visibility` VARCHAR(8) NOT NULL,
  `created`    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `downloads`  INT UNSIGNED NOT NULL DEFAULT 0,
  `position`   INT NOT NULL DEFAULT 0,
  `confirmed`  BOOL NOT NULL DEFAULT false,

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
