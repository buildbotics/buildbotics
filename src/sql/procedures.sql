DELETE FROM mysql.proc WHERE db = "buildbotics";


-- Profile
CREATE PROCEDURE GetProfile(IN _name VARCHAR(64))
BEGIN
  SELECT * FROM profiles
    WHERE name = _name AND NOT disabled;
END;


CREATE PROCEDURE PutProfile(IN _name VARCHAR(64), IN _profile MEDIUMBLOB)
BEGIN
  INSERT INTO profiles SET profile = _profile
    ON DUPLICATE KEY
    UPDATE profile = VALUES(profile);
END;


-- Follow
CREATE PROCEDURE GetFollowing(IN _name VARCHAR(64))
BEGIN
  SELECT p.*
    FROM profiles p
    INNER JOIN followers f ON p.id = f.followed_id
    WHERE f.follower_id IN (SELECT id FROM profiles WHERE name = _name);
END;


CREATE PROCEDURE GetFollowers(IN _name VARCHAR(64))
BEGIN
  SELECT p.*
    FROM profiles p
    INNER JOIN followers f ON p.id = f.follower_id
    WHERE f.followed_id IN (SELECT id FROM profiles WHERE name = _name);
END;


CREATE PROCEDURE Follow(IN follower VARCHAR(64), IN followed VARCHAR(64))
BEGIN
INSERT INTO followers VALUES (
  (SELECT id FROM profiles WHERE name = follower),
  (SELECT id FROM profiles WHERE name = followed));
END;


CREATE PROCEDURE Unfollow(IN follower VARCHAR(64), IN followed VARCHAR(64))
BEGIN
DELETE FROM followers WHERE
  follower_id = (SELECT id FROM profiles WHERE name = follower) AND
  followed_id = (SELECT id FROM profiles WHERE name = followed);
END;


-- Stars
CREATE PROCEDURE GetStarredThings(IN _name VARCHAR(64))
BEGIN
  SELECT t.*
    FROM things t
    INNER JOIN stars s ON t.id = s.thing_id
    WHERE s.profile_id IN (SELECT id FROM profiles WHERE name = _name);
END;


-- Badges
CREATE PROCEDURE GetBadges(IN _name VARCHAR(64))
BEGIN
  SELECT b.*
    FROM badges b
    INNER JOIN profile_badges pb ON b.id = pb.badge_id
    WHERE pb.profile_id IN (SELECT id FROM profiles WHERE name = _name);
END;


CREATE PROCEDURE GrantBadge(IN _name VARCHAR(64), IN _badge VARCHAR(64))
BEGIN
  INSERT INTO profile_badges VALUES (
    (SELECT id FROM profiles WHERE name = _user),
    (SELECT id FROM badges WHERE name = _badge));
END;


CREATE PROCEDURE RevokeBadge(IN _name VARCHAR(64), IN _badge VARCHAR(64))
BEGIN
  DELETE FROM profile_badges WHERE
    profile_id = (SELECT id FROM profiles WHERE name = _user) AND
    badge_id = (SELECT id FROM badges WHERE name = _badge);
END;


-- Settings
CREATE PROCEDURE SetAssociations(IN _name VARCHAR(64), IN _associations BLOB)
BEGIN
  UPDATE profiles SET associations = _associations WHERE name = _name;
END;


CREATE PROCEDURE SetEmails(IN _name VARCHAR(64), IN _emails BLOB)
BEGIN
  UPDATE profiles SET emails = _emails WHERE name = _name;
END;


CREATE PROCEDURE SetNotifications(IN _name VARCHAR(64), IN _notifications BLOB)
BEGIN
  UPDATE profiles SET notifications = _notifications WHERE name = _name;
END;


-- Things
CREATE PROCEDURE GetThings(IN _name VARCHAR(64), IN _type CHAR(8),
  IN _unpublished BOOL)
BEGIN
  IF _type IS null THEN
    SELECT * FROM things
      WHERE owner_id IN (SELECT id FROM profiles WHERE name = _name) AND
        NOT redirect AND (_unpublished OR published);

  ELSE
    SELECT * FROM things
      WHERE owner_id IN (SELECT id FROM profiles WHERE name = _name) AND
        type = _type AND NOT redirect AND (_unpublished OR published);
  END IF;
END;


CREATE PROCEDURE RenameThing(IN _oldName VARCHAR(64), IN _newName VARCHAR(64))
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION ROLLBACK;

  START TRANSACTION;

  UPDATE things SET name = _newName WHERE name = _oldName;
  INSERT INTO things (name, redirect) VALUES (_oldName, true);

  COMMIT;
END;


-- Tags
CREATE PROCEDURE TagThing(IN _owner VARCHAR(64), IN _thing VARCHAR(64),
  IN _tag VARCHAR(64))
BEGIN
  UPDATE things
    SET tags = CONCAT_WS(',', _tag, tags)
    WHERE name = _thing AND
      owner_id IN (SELECT id FROM profiles WHERE name = _owner) AND
      (tags IS NULL OR NOT FIND_IN_SET(_tag, tags));
END;


CREATE PROCEDURE UntagThing(IN _owner VARCHAR(64), IN _thing VARCHAR(64),
  IN _tag VARCHAR(64))
BEGIN
  UPDATE things
    SET tags = REPLACE(REPLACE(tags, CONCAT(_tag, ','), ''), _tag, '')
    WHERE name = _thing AND
      owner_id IN (SELECT id FROM profiles WHERE name = _owner);
END;


-- Search
CREATE PROCEDURE FindProfiles(IN _query VARCHAR(256),
  IN _orderBy ENUM('points', 'followers', 'joined', 'score'), IN _limit INT,
  IN _offset INT, IN _accend BOOL)
BEGIN
  IF _orderBy IS null THEN
    SET _orderBy = 'score';
  END IF;

  IF _limit IS null THEN
    SET _limit = 10;
  END IF;

  IF _offset IS null THEN
    SET _offset = 0;
  END IF;

  IF _accend IS null THEN
    SET @dir = 'ASC';
  ELSEIF _accend THEN
    SET @dir = 'ASC';
  ELSE
    SET @dir = 'DESC';
  END IF;

  SET @s = CONCAT('SELECT *,
    MATCH(text) AGAINST(? IN BOOLEAN MODE) AS score
    FROM profiles WHERE score AND NOT disabled AND NOT redirect
    ORDER BY ', _orderBy, ' ', @dir, ', score LIMIT ? OFFSET ?');

  SET @query = _query;
  SET @limit = _limit;
  SET @offset = _offset;

  PREPARE stmt FROM @s;
  EXECUTE stmt USING @query, @limit, @offset;
  DEALLOCATE PREPARE stmt;
END;


CREATE PROCEDURE FindThings(IN _query VARCHAR(256), IN _license VARCHAR(64),
  IN _orderBy ENUM('stars', 'creation', 'modifed', 'score'), IN _limit INT,
  IN _offset INT, IN _accend BOOL)
BEGIN
  IF _orderBy IS null THEN
    SET _orderBy = 'score';
  END IF;

  IF _limit IS null THEN
    SET _limit = 10;
  END IF;

  IF _offset IS null THEN
    SET _offset = 0;
  END IF;

  IF _accend IS null THEN
    SET @dir = 'ASC';
  ELSEIF _accend THEN
    SET @dir = 'ASC';
  ELSE
    SET @dir = 'DESC';
  END IF;

  SET @s = CONCAT('SELECT *,
    MATCH(text) AGAINST(? IN BOOLEAN MODE) AS score
    FROM things WHERE score AND published AND NOT redirect');

  IF _license IS NOT null THEN
    SET @s = CONCAT(@s, 'AND license = ', QUOTE(_license), ' ');
  END IF;

  SET @s = CONCAT(@s, 'ORDER BY ', _orderBy, ' ', @dir,
    ', score LIMIT ? OFFSET ?');

  SET @query = _query;
  SET @limit = _limit;
  SET @offset = _offset;

  PREPARE stmt FROM @s;
  EXECUTE stmt USING @query, @limit, @offset;
  DEALLOCATE PREPARE stmt;
END;


CREATE PROCEDURE FindThingsByTags(IN _tags VARCHAR(256),
  IN _orderBy ENUM('stars', 'creation', 'modifed', 'score'), IN _limit INT,
  IN _offset INT, IN _accend BOOL)
BEGIN
  IF _orderBy IS null THEN
    SET _orderBy = 'score';
  END IF;

  IF _limit IS null THEN
    SET _limit = 10;
  END IF;

  IF _offset IS null THEN
    SET _offset = 0;
  END IF;

  IF _accend IS null THEN
    SET @dir = 'ASC';
  ELSEIF _accend THEN
    SET @dir = 'ASC';
  ELSE
    SET @dir = 'DESC';
  END IF;

  SET @s = CONCAT('SELECT *,
    MATCH(tags) AGAINST(? IN BOOLEAN MODE) AS score
    FROM things WHERE published AND NOT redirect HAVING 0 < score
    ORDER BY ', _orderBy, ' ', @dir, ', score LIMIT ? OFFSET ?');

  SET @tags = _tags;
  SET @limit = _limit;
  SET @offset = _offset;

  PREPARE stmt FROM @s;
  EXECUTE stmt USING @tags, @limit, @offset;
  DEALLOCATE PREPARE stmt;
END;
