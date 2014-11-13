DELETE FROM mysql.proc WHERE db = "buildbotics";


-- Associations
CREATE PROCEDURE Associate(IN _provider VARCHAR(16), IN _id VARCHAR(64),
  IN _name VARCHAR(256), IN _email VARCHAR(256), IN _avatar VARCHAR(256),
  IN _profile VARCHAR(64))
BEGIN
  IF _profile IS NOT null THEN
    CALL GetProfileID(_profile);
  END IF;

  INSERT INTO associations (provider, id, name, email, avatar, profile_id)
    VALUES (_provider, _id, _name, _email, _avatar, _profile)
    ON DUPLICATE KEY UPDATE name = _name, email = _email, avatar = _avatar;
END;


CREATE PROCEDURE GetAssociation(IN _provider VARCHAR(16), IN _id VARCHAR(64))
BEGIN
  SELECT name, email, avatar, profile_id FROM associations
    WHERE provider = _provider AND id = _id;
END;


CREATE PROCEDURE Login(IN _provider VARCHAR(16), IN _id VARCHAR(64),
  IN _name VARCHAR(256), IN _email VARCHAR(256), IN _avatar VARCHAR(256))
BEGIN
  SELECT profile_id INTO @profile_id FROM associations
    WHERE provider = _provider AND id = _id;

  CALL Associate(_provider, _id, _name, _email, _avatar, null);

  UPDATE profiles SET lastlog = NOW() WHERE id = @profile_id;
END;


-- Names
CREATE PROCEDURE Register(IN _name VARCHAR(64), _provider VARCHAR(16),
  _id VARCHAR(256))
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION ROLLBACK;

  START TRANSACTION;

  IF NOT NameAllowed(_name) THEN
    SIGNAL SQLSTATE 'HY000' -- ER_SIGNAL_EXCEPTION
      SET MESSAGE_TEXT = 'Name take or invalid';
  END IF;

  SET @name = _name;

  INSERT INTO profiles (name, avatar, email)
    (SELECT @name, avatar, email FROM associations
     WHERE provider = _provider AND id = _id);

  UPDATE associations SET profile_id = LAST_INSERT_ID()
    WHERE provider = _provider AND id = _id;

  IF ROW_COUNT() != 1 THEN
    SIGNAL SQLSTATE '02000' -- ER_SIGNAL_NOT_FOUND
      SET MESSAGE_TEXT = 'Association not found';
  END IF;

  COMMIT;
END;


CREATE FUNCTION NameAllowed(_name VARCHAR(64))
RETURNS BOOL
NOT DETERMINISTIC
BEGIN
  IF CHAR_LENGTH(_name) < 3 OR _name  REGEXP '[^[:alnum:]_.]' THEN
    RETURN false;
  END IF;

  IF (SELECT id FROM profiles WHERE name = _name) THEN
    RETURN false;
  END IF;

  RETURN true;
END;


CREATE FUNCTION CleanName(_name VARCHAR(64))
RETURNS VARCHAR(64)
NOT DETERMINISTIC
BEGIN
  SET @remove = '!#$%&*+-/=?^`{|}~ \''; -- '
  SET @i = LENGTH(@remove);

  WHILE @i DO
    SET _name = REPLACE(_name, SUBSTR(@remove, @i, 1), '.');
    SET @i = @i - 1;
  END WHILE;

  SET @last = 0;
  WHILE @last != LENGTH(_name) DO
    SET @last = LENGTH(_name);
    SET _name = REPLACE(_name, '..', '.');
  END WHILE;

  SET _name = TRIM('.' FROM _name);

  IF @last = 0 THEN
    RETURN null;
  END IF;

  RETURN _name;
END;


CREATE FUNCTION NameSetAdd(_set VARCHAR(256), _name VARCHAR(64))
RETURNS VARCHAR(256)
NOT DETERMINISTIC
BEGIN
  SET _name = CleanName(_name);

  IF _name IS null OR FIND_IN_SET(_name, _set) != 0 THEN
    RETURN _set;
  END IF;

  RETURN CONCAT_WS(',', _set, _name);
END;


CREATE PROCEDURE Available(IN _name VARCHAR(64))
BEGIN
  SELECT NameAllowed(_name);
END;


CREATE PROCEDURE Suggest(IN _provider VARCHAR(16), IN _id VARCHAR(256),
  IN _total INT)
BEGIN
  DECLARE i INT;
  DECLARE j INT;
  DECLARE r INT;
  DECLARE n INT;
  DECLARE count INT;
  DECLARE candidate VARCHAR(64);
  DECLARE suggest VARCHAR(256);
  DECLARE first VARCHAR(64);
  DECLARE last VARCHAR(64);
  DECLARE _name VARCHAR(64);
  DECLARE _email VARCHAR(256);

  IF _total IS null THEN
    SET _total = 5;
  END IF;

  -- Lookup association
  SELECT a.name, a.email FROM associations AS a
    WHERE provider = _provider AND id = _id
    INTO _name, _email;

  -- Suggestions from email
  SET _email = REPLACE(LCASE(SUBSTRING_INDEX(TRIM(_email), '@', 1)), ',', ' ');
  SET suggest = NameSetAdd(suggest, _email);

  -- Suggestions from name
  SET _name = REPLACE(TRIM(LCASE(_name)), ',', ' ');

  IF LOCATE(' ', _name) != 0 THEN
    SET first = SUBSTRING_INDEX(_name, ' ', 1);
    SET last = SUBSTRING_INDEX(_name, ' ', -1);

    SET suggest = NameSetAdd(suggest, CONCAT(first, '.', last));
    SET suggest = NameSetAdd(suggest, CONCAT(last, '.', first));
    SET suggest = NameSetAdd(suggest, CONCAT(LEFT(first, 1), last));
    SET suggest = NameSetAdd(suggest, CONCAT(first, last));
    SET suggest = NameSetAdd(suggest, CONCAT(last, first));

  ELSE
    SET suggest = NameSetAdd(suggest, _name);
  END IF;

  -- Get number of suggestions
  SET n = LENGTH(suggest) - LENGTH(REPLACE(suggest, ',', '')) + 1;

  -- Create temporary table
  DROP TABLE IF EXISTS suggestions;
  CREATE TEMPORARY TABLE suggestions (
    name VARCHAR(64) NOT NULL UNIQUE
  ) ENGINE=memory;

  -- Look up suggestions
  SET i = 0;
  SET j = 0;
  SET r = 0;
  SET count = 0;

  WHILE count < _total AND i < 100 DO
    SET candidate =
      SUBSTRING_INDEX(SUBSTRING_INDEX(suggest, ',', j + 1), ',', -1);

    IF r != 0 THEN
      SET candidate = CONCAT(candidate, r);
    END IF;

    IF NameAllowed(candidate) THEN
      INSERT INTO suggestions VALUES (candidate)
        ON DUPLICATE KEY UPDATE name = name;
      SET count = count + ROW_COUNT();
    END IF;

    SET i = i + 1;
    SET j = j + 1;

    IF j = n THEN
      SET j = 0;
      SET r = CEIL(RAND() * 99);
    END IF;
  END WHILE;

  -- Return results
  SELECT * FROM suggestions;

  -- Drop table
  DROP TABLE suggestions;
END;


-- Profile
CREATE PROCEDURE GetUser(IN _provider VARCHAR(16), IN _id VARCHAR(64))
BEGIN
  SELECT profile_id INTO @profile_id FROM associations
    WHERE provider = _provider AND id = _id;

  SELECT * FROM profiles
    WHERE id = @profile_id AND NOT disabled AND NOT redirect;

  IF FOUND_ROWS() != 1 THEN
    SELECT name, email, avatar FROM associations
      WHERE provider = _provider AND id = _id;

    IF FOUND_ROWS() != 1 THEN
      SIGNAL SQLSTATE '02000' -- ER_SIGNAL_NOT_FOUND
        SET MESSAGE_TEXT = 'User not found';
    END IF;
  END IF;
END;


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
