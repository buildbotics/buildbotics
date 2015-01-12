DELETE FROM mysql.proc WHERE db = "buildbotics";

-- Functions
CREATE FUNCTION FormatTS(_ts TIMESTAMP)
RETURNS VARCHAR(32)
DETERMINISTIC
BEGIN
  RETURN
    DATE_FORMAT(CONVERT_TZ(_ts, @@session.time_zone, '+00:00'), '%Y-%m-%dT%TZ');
END;


-- Associations
CREATE PROCEDURE Associate(IN _provider VARCHAR(16), IN _id VARCHAR(64),
  IN _name VARCHAR(256), IN _email VARCHAR(256), IN _avatar VARCHAR(256))
BEGIN
  INSERT INTO associations (provider, id, name, email, avatar)
    VALUES (_provider, _id, _name, _email, _avatar)
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
  DECLARE _profile_id INT;

  SELECT profile_id FROM associations
    WHERE provider = _provider AND id = _id
    INTO _profile_id;

  CALL Associate(_provider, _id, _name, _email, _avatar);

  UPDATE profiles SET lastseen = NOW() WHERE id = _profile_id;

  SELECT name, auth FROM profiles WHERE id = _profile_id;
END;


-- Names
CREATE PROCEDURE Register(IN _name VARCHAR(64), _provider VARCHAR(16),
  _id VARCHAR(256))
BEGIN
  DECLARE profile_id INT;
  DECLARE avatar VARCHAR(256);
  DECLARE email VARCHAR(256);

  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION ROLLBACK;

  START TRANSACTION;

  IF NOT NameAllowed(_name) THEN
    SIGNAL SQLSTATE 'HY000' -- ER_SIGNAL_EXCEPTION
      SET MESSAGE_TEXT = 'Name taken or invalid';
  END IF;

  -- Look up association
  SELECT a.avatar, a.email FROM associations a
    WHERE a.provider = _provider AND a.id = _id
    INTO avatar, email;

  -- Create profile
  INSERT INTO profiles (name, avatar) VALUES (_name, avatar);
  SET profile_id = LAST_INSERT_ID();
  -- Create settings
  INSERT INTO settings (id, email) VALUES (profile_id, email);

  -- Update association
  UPDATE associations a SET a.profile_id = profile_id
    WHERE a.provider = _provider AND a.id = _id;

  -- Check for errors
  IF ROW_COUNT() != 1 THEN
    SIGNAL SQLSTATE '02000' -- ER_SIGNAL_NOT_FOUND
      SET MESSAGE_TEXT = 'Association not found';
  END IF;

  COMMIT;
END;


CREATE FUNCTION ValidName(_name VARCHAR(64))
RETURNS BOOL
NOT DETERMINISTIC
BEGIN
  IF CHAR_LENGTH(_name) < 2 OR _name  REGEXP '[^[:alnum:]_.]' THEN
    RETURN false;
  END IF;

  RETURN true;
END;


CREATE FUNCTION NameAllowed(_name VARCHAR(64))
RETURNS BOOL
NOT DETERMINISTIC
BEGIN
  IF NOT ValidName(_name) THEN
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
CREATE FUNCTION GetProfileID(_name VARCHAR(64))
RETURNS INT
NOT DETERMINISTIC
BEGIN
  DECLARE profile_id INT;

  SELECT id FROM profiles
    WHERE name = _name AND NOT disabled INTO profile_id;

  RETURN profile_id;
END;


CREATE PROCEDURE GetUser(IN _provider VARCHAR(16), IN _id VARCHAR(64))
BEGIN
  DECLARE profile_id INT;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION, NOT FOUND
  BEGIN
    SELECT name, avatar FROM associations
      WHERE provider = _provider AND id = _id;

    IF FOUND_ROWS() != 1 THEN
      SIGNAL SQLSTATE '02000' -- ER_SIGNAL_NOT_FOUND
        SET MESSAGE_TEXT = 'User not found';
    END IF;
  END;

  SELECT a.profile_id FROM associations a
    WHERE a.provider = _provider AND a.id = _id
    INTO profile_id;

  CALL GetProfileByID(profile_id, true);
END;


CREATE PROCEDURE GetProfileByID(IN _profile_id INT, IN _unpublished BOOL)
BEGIN
  SELECT name, joined, lastseen, fullname, location, avatar, url, bio, points,
    followers, following, stars, badges FROM profiles
    WHERE id = _profile_id AND NOT disabled;

  IF FOUND_ROWS() != 1 THEN
    SIGNAL SQLSTATE '02000' -- ER_SIGNAL_NOT_FOUND
      SET MESSAGE_TEXT = 'Profile not found';
  END IF;

  CALL GetThingsByID(_profile_id, null, null, _unpublished, null);
  CALL GetFollowersByID(_profile_id);
  CALL GetFollowingByID(_profile_id);
  CALL GetStarredThingsByID(_profile_id);
  CALL GetBadgesByID(_profile_id);
END;


CREATE PROCEDURE GetProfile(IN _profile VARCHAR(64), IN _unpublished BOOL)
BEGIN
  SET _profile = GetProfileID(_profile);
  CALL GetProfileByID(_profile, _unpublished);
END;


CREATE PROCEDURE PutProfile(IN _profile VARCHAR(64), IN _fullname VARCHAR(256),
  IN _location VARCHAR(256), IN _url VARCHAR(256), IN _bio TEXT)
BEGIN
  UPDATE profiles
    SET
      fullname = IFNULL(_fullname, fullname),
      location = IFNULL(_location, location),
      url      = IFNULL(_url, url),
      bio      = IFNULL(_bio, bio)
    WHERE
      id = GetProfileID(_profile);
END;


-- Follow
CREATE PROCEDURE GetFollowingByID(IN _profile_id INT)
BEGIN
  SELECT name AS followed, avatar
    FROM profiles
    INNER JOIN followers f ON id = f.followed_id
    WHERE f.follower_id = _profile_id;
END;


CREATE PROCEDURE GetFollowing(IN _profile VARCHAR(64))
BEGIN
  CALL GetFollowingByID(GetProfileID(_profile));
END;


CREATE PROCEDURE GetFollowersByID(IN _profile_id INT)
BEGIN
  SELECT name as follower, avatar
    FROM profiles
    INNER JOIN followers f ON id = f.follower_id
    WHERE f.followed_id = _profile_id;
END;


CREATE PROCEDURE GetFollowers(IN _profile VARCHAR(64))
BEGIN
  CALL GetFollowersByID(GetProfileID(_profile));
END;


CREATE PROCEDURE Follow(IN follower VARCHAR(64), IN followed VARCHAR(64))
BEGIN
  SET follower = GetProfileID(follower);
  SET followed = GetProfileID(followed);
  INSERT INTO followers VALUES (follower, followed);
END;


CREATE PROCEDURE Unfollow(IN follower VARCHAR(64), IN followed VARCHAR(64))
BEGIN
  SET follower = GetProfileID(follower);
  SET followed = GetProfileID(followed);
  DELETE FROM followers
    WHERE follower_id = follower AND followed_id = followed;
END;


-- Stars
CREATE PROCEDURE GetStarredThingsByID(IN _profile_id INT)
BEGIN
  -- Keep in sync with GetThingsByID()
  SELECT t.name starred, p.name owner, t.type, t.title, t.comments, t.stars,
    t.children, GetFileURL(p.name, t.name, f.name) image
    FROM things t
    LEFT JOIN files f ON f.id = GetFirstImageIDByID(t.id)
    INNER JOIN stars s ON t.id = s.thing_id
    INNER JOIN profiles p ON owner_id = p.id
    WHERE s.profile_id = _profile_id;
END;


CREATE PROCEDURE GetStarredThings(IN _profile VARCHAR(64))
BEGIN
    CALL GetStarredThingsByID(GetProfileID(_profile));
END;


CREATE PROCEDURE GetThingStarsByID(IN _thing_id INT)
BEGIN
    SELECT p.name profile, p.avatar FROM stars s
      INNER JOIN profiles p ON p.id = profile_id
      WHERE s.thing_id = _thing_id
      ORDER BY s.created;
END;


CREATE PROCEDURE StarThing(IN _profile VARCHAR(64), IN _owner VARCHAR(64),
  IN _thing VARCHAR(64))
BEGIN
  SET _profile = GetProfileID(_profile);
  SET _thing = GetThingID(_owner, _thing);

  INSERT INTO stars (profile_id, thing_id) VALUES (_profile, _thing)
    ON DUPLICATE KEY UPDATE profile_id = profile_id;
END;


CREATE PROCEDURE UnstarThing(IN _profile VARCHAR(64), IN _owner VARCHAR(64),
  IN _thing VARCHAR(64))
BEGIN
  SET _profile = GetProfileID(_profile);
  SET _thing = GetThingID(_owner, _thing);

  DELETE FROM stars
    WHERE profile_id = _profile AND thing_id = _thing;
END;


-- Badges
CREATE PROCEDURE GetBadgesByID(IN _profile_id INT)
BEGIN
  SELECT name AS badge, description
    FROM badges
    INNER JOIN profile_badges pb ON id = pb.badge_id
    WHERE pb.profile_id = _profile_id;
END;


CREATE PROCEDURE GetBadges(IN _profile VARCHAR(64))
BEGIN
    CALL GetBadgesByID(GetProfileID(_profile));
END;


CREATE PROCEDURE GrantBadge(IN _profile VARCHAR(64), IN _badge VARCHAR(64))
BEGIN
  INSERT INTO profile_badges VALUES (GetProfileID(_profile),
    (SELECT id FROM badges WHERE name = _badge));
END;


CREATE PROCEDURE RevokeBadge(IN _profile VARCHAR(64), IN _badge VARCHAR(64))
BEGIN
  DELETE FROM profile_badges
    WHERE profile_id = GetProfileID(_profile) AND
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
CREATE FUNCTION GetThingIDByID(_owner_id VARCHAR(64), _name VARCHAR(64))
RETURNS INT
NOT DETERMINISTIC
BEGIN
  DECLARE thing_id INT;

  SELECT id FROM things
    WHERE name = _name AND owner_id = _owner_id
    INTO thing_id;

  RETURN thing_id;
END;


CREATE FUNCTION GetThingID(_owner VARCHAR(64), _name VARCHAR(64))
RETURNS INT
NOT DETERMINISTIC
BEGIN
  RETURN GetThingIDByID(GetProfileID(_owner), _name);
END;


CREATE PROCEDURE GetThingsByID(IN _owner_id INT, IN _name VARCHAR(64),
  IN _type CHAR(8), IN _unpublished BOOL, IN _owner VARCHAR(64))
BEGIN
  IF _owner IS null THEN
    SELECT name FROM profiles WHERE id = _owner_id INTO _owner;
  END IF;

  SELECT t.name thing, _owner owner, t.type, title, published,
    FormatTS(t.created) created, FormatTS(t.modified) modified, comments, stars,
    children, GetFileURL(_owner, t.name, f.name) image
    FROM things t
    LEFT JOIN files f ON f.id = GetFirstImageIDByID(t.id)
    WHERE owner_id = _owner_id AND
      (_name IS null OR t.name = _name) AND
      (_type IS null OR t.type = _type) AND
      (_unpublished OR t.published);
END;


CREATE PROCEDURE GetThings(IN _owner VARCHAR(64), IN _name VARCHAR(64),
  IN _type CHAR(8), IN _unpublished BOOL)
BEGIN
  CALL GetThingsByID(GetProfileID(_owner), _name, _type, _unpublished, _owner);
END;


CREATE PROCEDURE ThingAvailable(IN _owner VARCHAR(64), IN _name VARCHAR(64))
BEGIN
  SET _owner = GetProfileID(_owner);

  IF _owner IS null OR
    (SELECT id FROM things WHERE name = _name AND owner_id = _owner) THEN
    SELECT false;
  ELSE
    SELECT ValidName(_name);
  END IF;
END;


CREATE PROCEDURE GetThing(IN _owner VARCHAR(64), IN _name VARCHAR(64),
  IN _unpublished BOOL)
BEGIN
  DECLARE _owner_id INT;
  DECLARE _thing_id INT;

  SET _owner_id = GetProfileID(_owner);
  SET _thing_id = GetThingIDByID(_owner_id, _name);

  IF _thing_id IS NOT null THEN
    SELECT t.name name, _owner owner, t.type, t.title,
      t.published, FormatTS(t.created) created, FormatTS(t.modified) modified,
      t.url, t.description, t.tags, t.comments, t.stars, t.children, t.license,
      l.url license_url, CONCAT(p.name, '/', parent.name) parent
      FROM things t
      LEFT JOIN things parent ON parent.id = t.parent_id
      LEFT JOIN profiles p ON p.id = parent.owner_id
      LEFT JOIN licenses l ON l.name = t.license
      WHERE t.owner_id = _owner_id AND t.name = _name AND
        (_unpublished OR t.published);

    IF FOUND_ROWS() != 1 THEN
      SIGNAL SQLSTATE '02000' -- ER_SIGNAL_NOT_FOUND
       SET MESSAGE_TEXT = 'Thing not found';
    END IF;

    -- Steps
    SELECT id step, name, FormatTS(created) created,
      FormatTS(modified) modified, description FROM steps
      WHERE thing_id = _thing_id
      ORDER BY position;

    -- Files
    SELECT f.name file, type, FormatTS(f.created) created, downloads, caption,
      display, space size, GetFileURL(_owner, _name, f.name) url
      FROM files f
      LEFT JOIN steps ON steps.id = step_id
      WHERE f.thing_id = _thing_id
      ORDER BY f.display, f.position, f.created;

    -- Comments
    CALL GetCommentsByID(_thing_id);

    -- Stars
    CALL GetThingStarsByID(_thing_id);
  END IF;
END;


CREATE PROCEDURE RenameThing(IN _owner VARCHAR(64), IN _old_name VARCHAR(64),
  IN _new_name VARCHAR(64))
BEGIN
  DECLARE _owner_id INT;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION ROLLBACK;

  SET _owner_id = GetProfileID(_owner);

  START TRANSACTION;

  UPDATE things SET name = _new_name
    WHERE owner_id = _owner_id AND name = _old_name;

  INSERT INTO thing_redirects
    (old_owner, new_owner, old_thing, new_thing) VALUES
    (_owner, _owner, _old_name, _new_name)
    ON DUPLICATE KEY UPDATE new_owner = _owner, new_thing = _new_name;

  COMMIT;
END;


CREATE PROCEDURE PutThing(IN _owner VARCHAR(64), IN _name VARCHAR(64),
  IN _type CHAR(8), IN _title VARCHAR(256), IN _url VARCHAR(256),
  IN _description TEXT, IN _license VARCHAR(64), IN _published BOOL)
BEGIN
  SET _owner = GetProfileID(_owner);

  IF NOT ValidName(_name) THEN
    SIGNAL SQLSTATE 'HY000' -- ER_SIGNAL_EXCEPTION
      SET MESSAGE_TEXT = 'Thing name invalid';
  END IF;

  INSERT INTO things
      (owner_id, name, type, title, url, description, license, published)
    VALUES
      (_owner, _name, _type, _title, _url, _description, _license, _published)
    ON DUPLICATE KEY UPDATE
      title       = IFNULL(_title, title),
      url         = IFNULL(_url, url),
      description = IFNULL(_description, description),
      license     = IFNULL(_license, license),
      published   = IFNULL(_published, published),
      modified    = CURRENT_TIMESTAMP;
END;


CREATE PROCEDURE DuplicateThing(IN _owner VARCHAR(64), IN _name VARCHAR(64),
  IN  _parent_owner VARCHAR(64), IN  _parent VARCHAR(64))
BEGIN
  SET _parent = GetThingID(_parent_owner, _parent);

  INSERT INTO things
    (owner_id, parent_id, name)
    VALUES (GetProfileID(_owner), _parent, _name);

  -- TODO Copy thing fields and steps
END;

-- Steps
CREATE FUNCTION GetStepIDByID(_thing_id VARCHAR(64), _name VARCHAR(64))
RETURNS INT
NOT DETERMINISTIC
BEGIN
  DECLARE step_id INT;

  SELECT id FROM steps
    WHERE name = _name AND thing_id = _thing_id
    INTO step_id;

  RETURN step_id;
END;


CREATE FUNCTION GetStepID(_owner VARCHAR(64), _thing VARCHAR(64),
  _name VARCHAR(64))
RETURNS INT
NOT DETERMINISTIC
BEGIN
  RETURN GetStepIDByID(GetThingID(_owner, _thing), _name);
END;


-- Tags
CREATE PROCEDURE GetTags()
BEGIN
  SELECT name, count FROM tags WHERE 0 < count ORDER BY count DESC;
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


CREATE PROCEDURE ParseTags(IN _tags VARCHAR(256))
BEGIN
  DECLARE i INT;
  DECLARE _tag VARCHAR(64);

  DROP TEMPORARY TABLE IF EXISTS parsedTags;
  CREATE TEMPORARY TABLE parsedTags (`tag` VARCHAR(64) NOT NULL UNIQUE);

  REPEAT
    SET i = LOCATE(',', _tags);

    IF i = 0 THEN
      SET _tag = TRIM(_tags);

    ELSE
      SET _tag = TRIM(LEFT(_tags, i - 1));
      SET _tags = RIGHT(_tags, CHAR_LENGTH(_tags) - i);
    END IF;

    IF CHAR_LENGTH(_tag) THEN
      INSERT INTO parsedTags VALUES(_tag) ON DUPLICATE KEY UPDATE tag = tag;
    END IF;

  UNTIL i = 0
  END REPEAT;
END;


CREATE PROCEDURE TagThing(IN _owner VARCHAR(64), IN _thing VARCHAR(64),
  IN _tag VARCHAR(64))
BEGIN
  INSERT INTO tags (name, count) VALUES (_tag, 0)
    ON DUPLICATE KEY UPDATE name = name;

  SELECT id INTO _tag FROM tags WHERE name = _tag;

  INSERT INTO thing_tags VALUES (GetThingID(_owner, _thing), _tag)
    ON DUPLICATE KEY UPDATE thing_id = thing_id;
END;


CREATE PROCEDURE MultiTagThing(IN _owner VARCHAR(64), IN _thing VARCHAR(64),
  IN _tags VARCHAR(256))
BEGIN
  DECLARE done BOOLEAN DEFAULT FALSE;
  DECLARE _tag VARCHAR(64);
  DECLARE cur CURSOR FOR SELECT tag FROM parsedTags;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done := TRUE;

  START TRANSACTION;

  CALL ParseTags(_tags);

  OPEN cur;

  REPEAT
    FETCH cur INTO _tag;
    IF NOT done THEN
      CALL TagThing(_owner, _thing, _tag);
    END IF;
    UNTIL done
  END REPEAT;

  COMMIT;
END;


CREATE PROCEDURE UntagThing(IN _owner VARCHAR(64), IN _thing VARCHAR(64),
  IN _tag VARCHAR(64))
BEGIN
  SELECT id INTO _tag FROM tags WHERE name = _tag;

  DELETE FROM thing_tags
    WHERE thing_id = GetThingID(_owner, _thing) AND tag_id = _tag;
END;


CREATE PROCEDURE MultiUntagThing(IN _owner VARCHAR(64), IN _thing VARCHAR(64),
  IN _tags VARCHAR(256))
BEGIN
  DECLARE done BOOLEAN DEFAULT FALSE;
  DECLARE _tag VARCHAR(64);
  DECLARE cur CURSOR FOR SELECT tag FROM parsedTags;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done := TRUE;

  START TRANSACTION;

  CALL ParseTags(_tags);

  OPEN cur;

  REPEAT
    FETCH cur INTO _tag;
    IF NOT done THEN
      CALL UntagThing(_owner, _thing, _tag);
    END IF;
    UNTIL done
  END REPEAT;

  COMMIT;
END;


-- Comments
CREATE PROCEDURE GetCommentsByID(IN _thing_id INT)
BEGIN
    SELECT c.id comment, s.name step, p.name owner, p.avatar, ref,
      FormatTS(c.created) created, FormatTS(c.modified) modified, c.text
      FROM comments c
      LEFT JOIN profiles p ON p.id = owner_id
      LEFT JOIN steps s ON s.id = step_id
      WHERE c.thing_id = _thing_id
      ORDER BY c.created;
END;


CREATE PROCEDURE PostComment(IN _owner VARCHAR(64), IN _thing_owner VARCHAR(64),
  IN _thing VARCHAR(64), IN _step INT, IN _ref INT, IN _text TEXT)
BEGIN
  INSERT INTO comments (owner_id, thing_id, step_id, ref, text)
    VALUES (GetProfileID(_owner), GetThingID(_thing_owner, _thing), _step, _ref,
      _text);

  SELECT LAST_INSERT_ID() id;
END;


CREATE PROCEDURE UpdateComment(IN _owner VARCHAR(64), IN _comment INT,
  IN _text TEXT)
BEGIN
  UPDATE comments
    SET text = _text, modified = CURRENT_TIMESTAMP
    WHERE id = _comment AND owner_id = GetProfileID(_owner);
END;


CREATE PROCEDURE DeleteComment(IN _owner VARCHAR(64), IN _comment INT)
BEGIN
  DELETE FROM comments
    WHERE id = _comment AND owner_id = GetProfileID(_owner);
END;


-- Files
CREATE FUNCTION GetFirstImageIDByID(_thing_id INT)
RETURNS INT
NOT DETERMINISTIC
BEGIN
  DECLARE _id INT;

  SET _id = (
    SELECT id FROM files
      WHERE thing_id = _thing_id AND display
      ORDER BY position LIMIT 1);

  RETURN _id;
END;


CREATE FUNCTION GetFileURL(_owner VARCHAR(64), _thing VARCHAR(64),
  _name VARCHAR(64))
RETURNS VARCHAR(256)
DETERMINISTIC
BEGIN
  RETURN CONCAT('/', _owner, '/', _thing, '/', _name);
END;


CREATE PROCEDURE PutFile(IN _owner VARCHAR(64), IN _thing VARCHAR(64),
  IN _name VARCHAR(256), IN _step VARCHAR(64), IN _type VARCHAR(64),
  IN _space INT, IN _url VARCHAR(256), IN _caption VARCHAR(256),
  IN _display BOOL)
BEGIN
  SET _thing = GetThingID(_owner, _thing);
  SET _step = GetStepIDByID(_thing, _step);

  INSERT INTO files
    (thing_id, step_id, name, type, space, url, caption, display)
    VALUES (_thing, _step, _name, _type, _space, _url, _caption, _display)
    ON DUPLICATE KEY UPDATE
      step_id = IFNULL(_step, step_id),
      url     = IFNULL(_url, url),
      caption = IFNULL(_caption, caption),
      display = IFNULL(_display, display);
END;


CREATE PROCEDURE GetFile(IN _owner VARCHAR(64), IN _thing VARCHAR(64),
  IN _name VARCHAR(256))
BEGIN
  SELECT f.name AS name, s.name step, type, space, url, caption, display,
    FormatTS(f.created) created, downloads, f.position position FROM files f
    LEFT JOIN steps s ON s.id = step_id
    WHERE f.thing_id = GetThingID(_owner, _thing) AND f.name = _name;
END;


CREATE PROCEDURE DownloadFile(IN _owner VARCHAR(64), IN _thing VARCHAR(64),
  IN _name VARCHAR(256))
BEGIN
  DECLARE _file_id INT;
  DECLARE _url VARCHAR(256);

  SELECT id, url INTO _file_id, _url FROM files
    WHERE thing_id = GetThingID(_owner, _thing) AND name = _name
    FOR UPDATE;

  UPDATE files SET downloads = downloads + 1
    WHERE id = _file_id;

  IF _url IS null THEN
    SIGNAL SQLSTATE '02000' -- ER_SIGNAL_NOT_FOUND
      SET MESSAGE_TEXT = 'File not found';
  ELSE
    SELECT _url url;
  END IF;
END;


CREATE PROCEDURE RenameFile(IN _owner VARCHAR(64), IN _thing VARCHAR(64),
  IN _old_name VARCHAR(256), IN _new_name VARCHAR(256))
BEGIN
  UPDATE files SET name = _new_name
    WHERE thing_id = GetThingID(_owner, _thing) AND name = _old_name;
END;


CREATE PROCEDURE DeleteFile(IN _owner VARCHAR(64), IN _thing VARCHAR(64),
  IN _name VARCHAR(256))
BEGIN
  DELETE FROM files
    WHERE thing_id = GetThingID(_owner, _thing) AND name = _name;
END;


CREATE PROCEDURE DuplicateFile(IN _owner VARCHAR(64), IN _thing VARCHAR(64),
  IN _name VARCHAR(256), IN _new_owner VARCHAR(64), IN _new_thing VARCHAR(64))
BEGIN
  CREATE TEMPORARY TABLE duplicateFileTable
    SELECT * FROM files
      WHERE thing_id = GetThingID(_owner, _thing) AND name = _name;

  UPDATE duplicateFileTable
    SET id = NULL, thing_id = GetThingID(_new_owner, _new_thing);

  INSERT INTO files SELECT * FROM duplicateFileTable;

  DROP TEMPORARY TABLE IF EXISTS duplicateFileTable;
END;


CREATE PROCEDURE ConfirmFile(IN _owner VARCHAR(64), IN _thing VARCHAR(64),
  IN _name VARCHAR(256), IN _type VARCHAR(64), IN _space INT)
BEGIN
  UPDATE files
    SET type = _type, space = _space, confirmed = true
    WHERE thing_id = GetThingID(_owner, _thing) AND name = _name;
END;


-- Licenses
CREATE PROCEDURE GetLicenses()
BEGIN
  SELECT name, url FROM licenses;
END;


-- Search
CREATE PROCEDURE FindProfiles(IN _query VARCHAR(256),
  IN _orderBy ENUM('points', 'followers', 'joined', 'score'), IN _limit INT,
  IN _offset INT)
BEGIN
  -- Query
  IF TRIM(_query) = '' THEN
    SET _query = null;
  END IF;

  -- Order by
  IF _orderBy IS null THEN
    SET _orderBy = 'score';
  END IF;

  -- Limit
  IF _limit IS null THEN
    SET _limit = 10;
  END IF;

  -- Offset
  IF _offset IS null THEN
    SET _offset = 0;
  END IF;

  SET SQL_SELECT_LIMIT = _limit;

  -- Select
  SELECT p.name profile, p.avatar, p.points, p.followers, p.joined,
      MATCH(p.name, p.fullname, p.location, p.bio)
      AGAINST(_query IN BOOLEAN MODE) score

    FROM profiles p

    WHERE
      NOT disabled

    HAVING
      (_query IS null OR 0 < score)

    ORDER BY
      CASE _orderBy
        WHEN 'joined' THEN p.joined
      END ASC,
      CASE _orderBy
        WHEN 'points' THEN p.points
        WHEN 'followers' THEN p.followers
        WHEN 'score' THEN score
      END DESC;

  SET SQL_SELECT_LIMIT = DEFAULT;
END;


CREATE PROCEDURE FindThings(IN _query VARCHAR(256), IN _license VARCHAR(64),
  IN _orderBy ENUM('stars', 'created', 'modified', 'score'), IN _limit INT,
  IN _offset INT)
BEGIN
  -- Query
  IF TRIM(_query) = '' THEN
    SET _query = null;
  END IF;

  -- Order by
  IF _orderBy IS null THEN
    IF _query IS null THEN
      SET _orderBy = 'stars';
    ELSE
      SET _orderBy = 'score';
    END IF;
  END IF;

  -- Limit
  IF _limit IS null THEN
    SET _limit = 10;
  END IF;

  -- Offset
  IF _offset IS null THEN
    SET _offset = 0;
  END IF;

  SET SQL_SELECT_LIMIT = _limit;

  -- Select
  SELECT t.name thing, p.name owner, t.type, t.title,
      FormatTS(t.created) created, FormatTS(t.modified) modified,
      t.comments, t.stars, t.children, GetFileURL(p.name, t.name, f.name) image,
      MATCH(t.name, t.title, t.description, t.tags)
      AGAINST(_query IN BOOLEAN MODE) score

    FROM things t
      LEFT JOIN files f ON f.id = GetFirstImageIDByID(t.id)
      INNER JOIN profiles p ON t.owner_id = p.id

    WHERE
      t.published AND
      (_license IS null OR t.license = _license)

    HAVING
      (_query IS null OR 0 < score)

    ORDER BY
      CASE _orderBy
        WHEN 'created' THEN t.created
        WHEN 'modifed' THEN t.modified
      END ASC,
      CASE _orderBy
        WHEN 'stars' THEN t.stars
        WHEN 'score' THEN score
      END DESC;

  SET SQL_SELECT_LIMIT = DEFAULT;
END;
