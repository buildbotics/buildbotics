DELETE FROM mysql.proc WHERE db = "buildbotics";


-- Profile
CREATE PROCEDURE GetProfileID(INOUT _name VARCHAR(64))
BEGIN
  SELECT id FROM profiles
    WHERE name = _name AND NOT disabled AND NOT redirect INTO _name;
END;


CREATE PROCEDURE GetProfile(IN _name VARCHAR(64))
BEGIN
  SELECT * FROM profiles
    WHERE name = _name AND NOT disabled AND NOT redirect;
END;


CREATE PROCEDURE PutProfile(IN _name VARCHAR(64), IN _profile MEDIUMBLOB)
BEGIN
  INSERT INTO profiles (name, profile) VALUES (_name, _profile)
    ON DUPLICATE KEY
    UPDATE profile = VALUES (profile);
END;


-- Follow
CREATE PROCEDURE GetFollowing(IN _profile VARCHAR(64))
BEGIN
  CALL GetProfileID(_profile);

  SELECT p.*
    FROM profiles p
    INNER JOIN followers f ON p.id = f.followed_id
    WHERE f.follower_id = _profile;
END;


CREATE PROCEDURE GetFollowers(IN _profile VARCHAR(64))
BEGIN
  CALL GetProfileID(_profile);

  SELECT p.*
    FROM profiles p
    INNER JOIN followers f ON p.id = f.follower_id
    WHERE f.followed_id = _profile;
END;


CREATE PROCEDURE Follow(IN follower VARCHAR(64), IN followed VARCHAR(64))
BEGIN
  CALL GetProfileID(follower);
  CALL GetProfileID(followed);
  INSERT INTO followers VALUES (follower, followed);
END;


CREATE PROCEDURE Unfollow(IN follower VARCHAR(64), IN followed VARCHAR(64))
BEGIN
  CALL GetProfileID(follower);
  CALL GetProfileID(followed);
  DELETE FROM followers
    WHERE follower_id = follower AND followed_id = followed;
END;


-- Stars
CREATE PROCEDURE GetStarredThings(IN _profile VARCHAR(64))
BEGIN
  CALL GetProfileID(_profile);
  SELECT t.*
    FROM things t
    INNER JOIN stars s ON t.id = s.thing_id
    WHERE s.profile_id = _profile;
END;


CREATE PROCEDURE StarThing(IN _profile VARCHAR(64), IN _thing VARCHAR(64),
  IN _owner VARCHAR(64), IN _type CHAR(8))
BEGIN

  CALL GetProfileID(_profile);
  CALL GetThingID(_thing, _owner, _type);

  INSERT INTO stars VALUES (_profile, _thing);
END;


-- Badges
CREATE PROCEDURE GetBadges(IN _profile VARCHAR(64))
BEGIN
  CALL GetProfileID(_profile);
  SELECT b.*
    FROM badges b
    INNER JOIN profile_badges pb ON b.id = pb.badge_id
    WHERE pb.profile_id = _profile;
END;


CREATE PROCEDURE GrantBadge(IN _profile VARCHAR(64), IN _badge VARCHAR(64))
BEGIN
  CALL GetProfileID(_profile);
  INSERT INTO profile_badges VALUES (_profile,
    (SELECT id FROM badges WHERE name = _badge));
END;


CREATE PROCEDURE RevokeBadge(IN _profile VARCHAR(64), IN _badge VARCHAR(64))
BEGIN
  CALL GetProfileID(_profile);
  DELETE FROM profile_badges
    WHERE profile_id = _profile AND
      badge_id IN (SELECT id FROM badges WHERE name = _badge);
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
CREATE PROCEDURE GetThingID(INOUT _thing VARCHAR(64), IN _owner VARCHAR(64),
  IN _type CHAR(8))
BEGIN
  CALL GetProfileID(_owner);
  SELECT id FROM things
    WHERE name = _thing AND owner_id = _owner AND
      type = _type AND NOT redirect INTO _thing;
END;


CREATE PROCEDURE GetThings(IN _profile VARCHAR(64), IN _type CHAR(8),
  IN _unpublished BOOL)
BEGIN
  CALL GetProfileID(_profile);

  IF _type IS null THEN
    SELECT * FROM things
      WHERE owner_id = _profile AND
        NOT redirect AND (_unpublished OR published);

  ELSE
    SELECT * FROM things
      WHERE owner_id = _profile AND
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


CREATE PROCEDURE CreateThing(IN _name VARCHAR(64), IN _owner VARCHAR(64),
  IN  _parent VARCHAR(64), IN  _parent_owner VARCHAR(64), IN _type CHAR(8))
BEGIN
  CALL GetThingID(_parent, _parent_owner, _type);
  CALL GetProfileID(_owner);

  INSERT INTO things
    (owner_id, parent_id, name, type, value) VALUES
      (_owner, _parent, _name, _type, '{}');
END;


-- Tags
CREATE PROCEDURE GetTags()
BEGIN
  SELECT name, count FROM tags ORDER BY count DESC;
END;


CREATE PROCEDURE AddTag(IN _tag VARCHAR(64))
BEGIN
  INSERT INTO tags (name) VALUES(_tag) ON DUPLICATE KEY UPDATE id = id;
END;


CREATE PROCEDURE DeleteTag(IN _tag VARCHAR(64))
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION ROLLBACK;

  START TRANSACTION;

  UPDATE things
    SET tags = REPLACE(REPLACE(tags, CONCAT(_tag, ','), ''), _tag, '')
    WHERE MATCH(tags) AGAINST(CONCAT('+', _tag) IN BOOLEAN MODE);

  DELETE FROM tags WHERE name = _tag;

  COMMIT;
END;


CREATE PROCEDURE TagThing(IN _owner VARCHAR(64), IN _thing VARCHAR(64),
  IN _tag VARCHAR(64))
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION ROLLBACK;

  START TRANSACTION;

  CALL GetProfileID(_owner);

  UPDATE tags SET count = count + 1 WHERE name = _tag;

  UPDATE things
    SET tags = CONCAT_WS(',', _tag, tags)
    WHERE name = _thing AND owner_id = _owner AND
      (tags IS NULL OR NOT FIND_IN_SET(_tag, tags));

  COMMIT;
END;


CREATE PROCEDURE UntagThing(IN _owner VARCHAR(64), IN _thing VARCHAR(64),
  IN _tag VARCHAR(64))
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION ROLLBACK;

  START TRANSACTION;

  CALL GetProfileID(_owner);

  UPDATE tags SET count = count - 1 WHERE name = _tag;

  UPDATE things
    SET tags = REPLACE(REPLACE(tags, CONCAT(_tag, ','), ''), _tag, '')
    WHERE name = _thing AND owner_id = _owner;

  COMMIT;
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
    FROM profiles WHERE NOT disabled AND NOT redirect HAVING 0 < score
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
    IF _query IS null THEN
      SET _orderBy = 'stars';
    ELSE
      SET _orderBy = 'score';
    END IF;
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

  SET @s = 'SELECT *';

  IF _query IS NOT null THEN
    SET @s = CONCAT(@s, ', MATCH(name, brief, text, tags) AGAINST(',
      QUOTE(_query), ' IN BOOLEAN MODE) AS score');
  END IF;

  SET @s = CONCAT(@s, ' FROM things WHERE published AND NOT redirect');

  IF _query IS NOT null THEN
    SET @s = CONCAT(@s, ' HAVING 0 < score');
  END IF;

  IF _license IS NOT null THEN
    SET @s = CONCAT(@s, ' AND license = ', QUOTE(_license));
  END IF;

  SET @s = CONCAT(@s, ' ORDER BY ', _orderBy, ' ', @dir);

  IF _query IS NOT null AND _orderBy <> 'score' THEN
    SET @s = CONCAT(@s, ', score');
  END IF;

  SET @s = CONCAT(@s, ' LIMIT ? OFFSET ?');

  SET @limit = _limit;
  SET @offset = _offset;

  PREPARE stmt FROM @s;
  EXECUTE stmt USING @limit, @offset;
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
