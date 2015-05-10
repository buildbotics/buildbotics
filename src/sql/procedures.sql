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
  IF TRIM(_name) = '' THEN
    SIGNAL SQLSTATE 'HY000' -- ER_SIGNAL_EXCEPTION
      SET MESSAGE_TEXT = 'Name cannot be empty';
  END IF;

  IF TRIM(_email) = '' THEN
    SET _email = null;
  END IF;

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
DETERMINISTIC
BEGIN
  IF CHAR_LENGTH(_name) < 2 OR _name  REGEXP '[^[:alnum:]_.]' THEN
    RETURN false;
  END IF;

  RETURN FIND_IN_SET(_name,
    'explore,learn,create,tags,settings,login,register') = 0;
END;


CREATE FUNCTION NameAllowed(_name VARCHAR(64))
RETURNS BOOL
NOT DETERMINISTIC
READS SQL DATA
BEGIN
  IF _name IS NULL OR NOT ValidName(_name) THEN
    RETURN false;
  END IF;

  IF (SELECT id FROM profiles WHERE name = _name) THEN
    RETURN false;
  END IF;

  RETURN true;
END;


CREATE FUNCTION CleanName(_name VARCHAR(64))
RETURNS VARCHAR(64)
DETERMINISTIC
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
DETERMINISTIC
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


-- Authorizations
CREATE FUNCTION GetAuthFlag(_name VARCHAR(64))
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
  DECLARE _id INT;
  SELECT id INTO _id FROM authorizations WHERE name = _name;
  RETURN _id;
END;


-- Profile
CREATE FUNCTION GetProfileID(_name VARCHAR(64))
RETURNS INT
NOT DETERMINISTIC
READS SQL DATA
BEGIN
  DECLARE profile_id INT;

  SELECT id FROM profiles
    WHERE name = _name AND NOT disabled INTO profile_id;

  RETURN profile_id;
END;


CREATE PROCEDURE GetUser(IN _provider VARCHAR(16), IN _id VARCHAR(64))
BEGIN
  DECLARE _profile_id INT;
  DECLARE _name VARCHAR(64);
  DECLARE _avatar VARCHAR(256);
  DECLARE _auth BIGINT;

  -- Lookup association
  SELECT profile_id, name, avatar
    INTO _profile_id, _name, _avatar
    FROM associations
    WHERE provider = _provider AND id = _id;

  -- Error if not found
  IF FOUND_ROWS() = 0 THEN
    SIGNAL SQLSTATE '02000' -- ER_SIGNAL_NOT_FOUND
      SET MESSAGE_TEXT = 'User not found';
  END IF;

  -- Check if profile exists and get auth
  SELECT auth FROM profiles WHERE id = _profile_id INTO _auth;

  IF FOUND_ROWS() THEN
    CALL GetProfileByID(_profile_id);
    SELECT name auth FROM authorizations WHERE (_auth & (1 << (id - 1)));

  ELSE
    SELECT _name, _avatar;
  END IF;
END;


CREATE PROCEDURE GetProfileByID(IN _profile_id INT)
BEGIN
  SELECT name, FormatTS(joined) joined, FormatTS(lastseen) lastseen, fullname,
    location, url, bio, points, followers, following, stars, badges, comments
    FROM profiles
    WHERE id = _profile_id AND NOT disabled;

  IF FOUND_ROWS() != 1 THEN
    SIGNAL SQLSTATE '02000' -- ER_SIGNAL_NOT_FOUND
      SET MESSAGE_TEXT = 'Profile not found';
  END IF;

  CALL GetThingsByID(_profile_id, null, null);
  CALL GetFollowersByID(_profile_id);
  CALL GetFollowingByID(_profile_id);
  CALL GetStarredThingsByID(_profile_id);
  CALL GetBadgesByID(_profile_id);
  CALL GetEventsByID(_profile_id, null, null, null, false,
    now() - INTERVAL 1 month, null);
END;


CREATE PROCEDURE GetProfile(IN _profile VARCHAR(64))
BEGIN
  SET _profile = GetProfileID(_profile);
  CALL GetProfileByID(_profile);
END;


CREATE PROCEDURE GetProfileAvatar(IN _profile VARCHAR(64))
BEGIN
  SELECT avatar, 'avatar' FROM profiles WHERE name = _profile;
END;


CREATE PROCEDURE PutProfileAvatar(IN _profile VARCHAR(64), IN _url VARCHAR(256))
BEGIN
  UPDATE profiles SET pending_avatar = _url WHERE name = _profile;
END;


CREATE PROCEDURE ConfirmProfileAvatar(IN _profile VARCHAR(64),
  IN _url VARCHAR(256))
BEGIN
  UPDATE profiles SET avatar = _url
    WHERE name = _profile AND pending_avatar = _url;
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
      name = _profile;
END;


-- Follow
CREATE PROCEDURE GetFollowingByID(IN _profile_id INT)
BEGIN
  SELECT name, points, followers, badges, FormatTS(joined) joined
    FROM profiles
    INNER JOIN followers f ON id = f.followed_id
    WHERE f.follower_id = _profile_id
    ORDER BY f.created DESC;
END;


CREATE PROCEDURE GetFollowing(IN _profile VARCHAR(64))
BEGIN
  CALL GetFollowingByID(GetProfileID(_profile));
END;


CREATE PROCEDURE GetFollowersByID(IN _profile_id INT)
BEGIN
  SELECT name, points, followers, badges, FormatTS(joined) joined
    FROM profiles
    INNER JOIN followers f ON id = f.follower_id
    WHERE f.followed_id = _profile_id
    ORDER BY f.created DESC;
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
  SELECT t.name, p.name owner, p.points owner_points, t.type, t.title,
    t.comments, t.stars, t.children, t.views,
    GetFileURL(p.name, t.name, f.name) image,
    IF(t.published IS null, null, FormatTS(t.published)) published
    FROM things t
    LEFT JOIN files f ON f.id = GetFirstImageIDByID(t.id)
    INNER JOIN stars s ON t.id = s.thing_id
    INNER JOIN profiles p ON owner_id = p.id
    WHERE s.profile_id = _profile_id
    ORDER BY s.created DESC;
END;


CREATE PROCEDURE GetStarredThings(IN _profile VARCHAR(64))
BEGIN
    CALL GetStarredThingsByID(GetProfileID(_profile));
END;


CREATE PROCEDURE GetThingStarsByID(IN _thing_id INT)
BEGIN
    SELECT p.name, p.points FROM stars s
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
CREATE FUNCTION GetBadgeID(_name VARCHAR(64))
RETURNS INT
NOT DETERMINISTIC
READS SQL DATA
BEGIN
  DECLARE badge_id INT;
  SELECT id FROM badges WHERE name = _name INTO badge_id;
  RETURN badge_id;
END;


CREATE PROCEDURE GetBadgesByID(IN _profile_id INT)
BEGIN
  SELECT name, description
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
  INSERT INTO profile_badges
    VALUES (GetProfileID(_profile), GetBadgeID(_badge));
END;


CREATE PROCEDURE RevokeBadge(IN _profile VARCHAR(64), IN _badge VARCHAR(64))
BEGIN
  DELETE FROM profile_badges
    WHERE profile_id = GetProfileID(_profile) AND badge_id = GetBadgeID(_badge);
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
READS SQL DATA
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
READS SQL DATA
BEGIN
  RETURN GetThingIDByID(GetProfileID(_owner), _name);
END;


CREATE PROCEDURE GetThingsByID(IN _owner_id INT, IN _name VARCHAR(64),
  IN _type CHAR(8))
BEGIN
  SELECT t.name, p.name owner, p.points owner_points, t.type, title,
    IF(t.published IS null, null, FormatTS(t.published)) published,
    FormatTS(t.created) created, FormatTS(t.modified) modified, t.comments,
    t.stars, children, views, GetFileURL(p.name, t.name, f.name) image
    FROM things t
    LEFT JOIN profiles p ON p.id = _owner_id
    LEFT JOIN files f ON f.id = GetFirstImageIDByID(t.id)
    WHERE owner_id = _owner_id AND
      (_name IS null OR t.name = _name) AND
      (_type IS null OR t.type = _type)
    ORDER BY t.created DESC;
END;


CREATE PROCEDURE GetThings(IN _owner VARCHAR(64), IN _name VARCHAR(64),
  IN _type CHAR(8))
BEGIN
  CALL GetThingsByID(GetProfileID(_owner), _name, _type);
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
  IN _user VARCHAR(64))
BEGIN
  DECLARE _owner_id INT;
  DECLARE _thing_id INT;

  SET _owner_id = GetProfileID(_owner);
  SET _thing_id = GetThingIDByID(_owner_id, _name);

  IF _owner_id IS null OR _thing_id IS null THEN
    SIGNAL SQLSTATE '02000' -- ER_SIGNAL_NOT_FOUND
     SET MESSAGE_TEXT = 'Thing not found';
  END IF;

  -- Views
  INSERT INTO thing_views (thing_id, user)
    VALUES (_thing_id, _user)
    ON DUPLICATE KEY UPDATE thing_id = thing_id;

  -- Thing
  SELECT t.name, _owner owner, o.points owner_points, t.type, t.title,
    IF(t.published IS null, null, FormatTS(t.published)) published,
    FormatTS(t.created) created, FormatTS(t.modified) modified,
    t.url, t.tags, t.instructions, t.comments, t.stars, t.children, t.views,
    t.license, l.url license_url, CONCAT(p.name, '/', parent.name) parent

    FROM things t

    LEFT JOIN things parent ON parent.id = t.parent_id
    LEFT JOIN profiles p ON p.id = parent.owner_id
    LEFT JOIN profiles o ON o.id = _owner_id
    LEFT JOIN licenses l ON l.name = t.license

    WHERE t.owner_id = _owner_id AND t.name = _name;

  IF FOUND_ROWS() != 1 THEN
    SIGNAL SQLSTATE '02000' -- ER_SIGNAL_NOT_FOUND
     SET MESSAGE_TEXT = 'Thing not found';
  END IF;

  -- Files
  SELECT f.name, type, FormatTS(f.created) created, downloads, caption,
    visibility, space size, GetFileURL(_owner, _name, f.name) url
    FROM files f
    WHERE f.thing_id = _thing_id AND f.confirmed
    ORDER BY f.position, f.created;

  -- Comments
  CALL GetCommentsByID(_thing_id);

  -- Stars
  CALL GetThingStarsByID(_thing_id);
END;


CREATE PROCEDURE RenameThing(IN _owner VARCHAR(64), IN _old_name VARCHAR(64),
  IN _new_name VARCHAR(64))
BEGIN
  DECLARE _owner_id INT;

  SET _owner_id = GetProfileID(_owner);

  IF NOT ValidName(_new_name) THEN
    SIGNAL SQLSTATE 'HY000' -- ER_SIGNAL_EXCEPTION
      SET MESSAGE_TEXT = 'Thing name invalid';
  END IF;

  START TRANSACTION;

  UPDATE things SET name = _new_name
    WHERE owner_id = _owner_id AND name = _old_name;

  INSERT INTO thing_redirects
    (old_owner, new_owner, old_thing, new_thing) VALUES
    (_owner, _owner, _old_name, _new_name)
    ON DUPLICATE KEY UPDATE new_owner = _owner, new_thing = _new_name;

  COMMIT;
END;


CREATE PROCEDURE PublishThing(IN _owner VARCHAR(64), IN _name VARCHAR(64))
BEGIN
  UPDATE things
    SET published = CURRENT_TIMESTAMP
    WHERE owner_id = GetProfileID(_owner)
      AND name = _name
      AND published IS NULL;
END;


CREATE PROCEDURE PutThing(IN _owner VARCHAR(64), IN _name VARCHAR(64),
  IN _type CHAR(8), IN _title VARCHAR(256), IN _url VARCHAR(256),
  IN _license VARCHAR(64), IN _instructions MEDIUMTEXT)
BEGIN
  SET _owner = GetProfileID(_owner);

  IF NOT ValidName(_name) THEN
    SIGNAL SQLSTATE 'HY000' -- ER_SIGNAL_EXCEPTION
      SET MESSAGE_TEXT = 'Thing name invalid';
  END IF;

  INSERT INTO things
      (owner_id, name, type, title, url, license, instructions)

    VALUES
      (_owner, _name, _type, _title, _url, IFNULL(_license, 'BSD License'),
       instructions)

    ON DUPLICATE KEY UPDATE
      title        = IFNULL(_title, title),
      url          = IFNULL(_url, url),
      license      = IFNULL(_license, license),
      instructions = IFNULL(_instructions, instructions),
      modified     = CURRENT_TIMESTAMP;
END;


CREATE PROCEDURE DuplicateThing(IN _owner VARCHAR(64), IN _name VARCHAR(64),
  IN  _parent_owner VARCHAR(64), IN  _parent VARCHAR(64))
BEGIN
  SET _parent = GetThingID(_parent_owner, _parent);

  INSERT INTO things
    (owner_id, parent_id, name)
    VALUES (GetProfileID(_owner), _parent, _name);

  -- TODO Copy thing fields
END;


CREATE PROCEDURE DeleteThing(IN _owner VARCHAR(64), IN _name VARCHAR(64))
BEGIN
  DELETE FROM things WHERE owner_id = GetProfileID(_owner) AND name = _name;
END;


-- Tags
CREATE PROCEDURE GetTags(_limit INT)
BEGIN
  IF _limit IS null THEN
    SET _limit = 100;
  END IF;

  SELECT name, count
    FROM tags
    WHERE 0 < count
    ORDER BY count DESC
    LIMIT _limit;
END;


CREATE PROCEDURE AddTag(IN _tag VARCHAR(64))
BEGIN
  INSERT INTO tags (name) VALUES(_tag) ON DUPLICATE KEY UPDATE id = id;
END;


CREATE PROCEDURE DeleteTag(IN _tag VARCHAR(64))
BEGIN
  DECLARE _tag_id INT;

  START TRANSACTION;

  -- Get tag ID
  SELECT id INTO _tag_id FROM tags WHERE name = _tag;

  -- Delete thing_tags
  -- Note trigger will remove tags from things
  DELETE FROM thing_tags WHERE tag_id = _tag_id;

  -- Delete tag
  DELETE FROM tags WHERE id = _tag_id;

  COMMIT;
END;


CREATE PROCEDURE FindThingsByTag(IN _tags VARCHAR(256), IN _limit INT,
  IN _offset INT)
BEGIN
  DECLARE _length INT;

  -- Get length of list
  SET _tags = TRIM(BOTH ',' FROM _tags);
  SET _length = LENGTH(_tags) - LENGTH(REPLACE(_tags, ',', '')) + 1;

  -- Limit
  IF _limit IS null THEN
    SET _limit = 100;
  END IF;

  -- Offset
  IF _offset IS null THEN
    SET _offset = 0;
  END IF;

  SET SQL_SELECT_LIMIT = _limit;

  SELECT t.name, p.name owner, p.points owner_points, t.type, t.title,
    IF(t.published IS null, null, FormatTS(t.published)) published,
    FormatTS(t.created) created, FormatTS(t.modified) modified,
    t.comments, t.stars, t.children, t.views,
    GetFileURL(p.name, t.name, f.name) image

    FROM things t
      LEFT JOIN files f ON f.id = GetFirstImageIDByID(t.id)
      INNER JOIN profiles p ON t.owner_id = p.id

    WHERE
      t.id IN (
        SELECT thing_id FROM thing_tags
          LEFT JOIN tags ON thing_tags.tag_id = tags.id
          WHERE FIND_IN_SET(tags.name, _tags)
          GROUP BY thing_id
          HAVING COUNT(thing_id) = _length

      ) AND t.published IS NOT NULL

    ORDER BY t.stars DESC, t.created DESC;

  SET SQL_SELECT_LIMIT = DEFAULT;
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
    SELECT c.id comment, p.name owner, p.points owner_points, ref,
      FormatTS(c.created) created, FormatTS(c.modified) modified, c.text,
      c.votes
      FROM comments c
      LEFT JOIN profiles p ON p.id = owner_id
      WHERE c.thing_id = _thing_id
      ORDER BY c.votes DESC, c.created DESC;
END;


CREATE PROCEDURE PostComment(IN _owner VARCHAR(64), IN _thing_owner VARCHAR(64),
  IN _thing VARCHAR(64), IN _ref INT, IN _text TEXT)
BEGIN
  INSERT INTO comments (owner_id, thing_id, ref, text)
    VALUES (GetProfileID(_owner), GetThingID(_thing_owner, _thing), _ref,
      _text);

  SELECT LAST_INSERT_ID() id;

  CALL UpvoteComment(_owner, LAST_INSERT_ID());
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


CREATE PROCEDURE UpvoteComment(IN _owner VARCHAR(64), IN _comment INT)
BEGIN
  SET _owner = GetProfileID(_owner);

  INSERT INTO comment_votes
    VALUES (_comment, _owner, 1)
    ON DUPLICATE KEY UPDATE vote = LEAST(1, vote + 1);

  -- Error if duplicate
  IF ROW_COUNT() = 0 THEN
    SIGNAL SQLSTATE 'HY000' -- ER_SIGNAL_EXCEPTION
      SET MESSAGE_TEXT = 'Comment already upvoted.';
  END IF;
END;


CREATE PROCEDURE DownvoteComment(IN _owner VARCHAR(64), IN _comment INT)
BEGIN
  SET _owner = GetProfileID(_owner);

  INSERT INTO comment_votes
    VALUES (_comment, _owner, -1)
    ON DUPLICATE KEY UPDATE vote = GREATEST(-1, vote - 1);

  -- Error if duplicate
  IF ROW_COUNT() = 0 THEN
    SIGNAL SQLSTATE 'HY000' -- ER_SIGNAL_EXCEPTION
      SET MESSAGE_TEXT = 'Comment already downvoted.';
  END IF;
END;


-- Files
CREATE FUNCTION GetFirstImageIDByID(_thing_id INT)
RETURNS INT
NOT DETERMINISTIC
READS SQL DATA
BEGIN
  DECLARE _id INT;

  SET _id = (
    SELECT id FROM files
      WHERE thing_id = _thing_id AND visibility != 'download'
      ORDER BY position, created LIMIT 1);

  RETURN _id;
END;


CREATE FUNCTION GetFileURL(_owner VARCHAR(64), _thing VARCHAR(64),
  _name VARCHAR(64))
RETURNS VARCHAR(256)
DETERMINISTIC
BEGIN
  RETURN CONCAT('/', _owner, '/', _thing, '/', _name);
END;


CREATE PROCEDURE UploadFile(IN _owner VARCHAR(64), IN _thing VARCHAR(64),
  IN _name VARCHAR(256), IN _type VARCHAR(64),
  IN _space INT, IN _path VARCHAR(256), IN _caption VARCHAR(256),
  IN _visibility VARCHAR(8))
BEGIN
  DECLARE EXIT HANDLER FOR SQLSTATE '23000' BEGIN
    DECLARE _text VARCHAR(256);
    SET _text = CONCAT('File ', _name, ' already exists');
    SIGNAL SQLSTATE '23000' SET MESSAGE_TEXT = _text;
  END;

  SET _thing = GetThingID(_owner, _thing);

  INSERT INTO files
    (thing_id, name, type, space, path, caption, visibility)
    VALUES (_thing, _name, _type, _space, _path, _caption, _visibility)
    ON DUPLICATE KEY UPDATE
      type       = IFNULL(_type, type),
      space      = IFNULL(_space, space),
      path       = IFNULL(_path, path),
      caption    = IFNULL(_caption, caption),
      visibility = IFNULL(_visibility, visibility);
END;


CREATE PROCEDURE UpdateFile(IN _owner VARCHAR(64), IN _thing VARCHAR(64),
  IN _name VARCHAR(256), IN _caption VARCHAR(256),
  IN _visibility VARCHAR(8), IN _rename VARCHAR(256))
BEGIN
  SET _thing = GetThingID(_owner, _thing);

  UPDATE files
    SET
      name       = IFNULL(_rename, name),
      caption    = IFNULL(_caption, caption),
      visibility = IFNULL(_visibility, visibility)
    WHERE
      thing_id = _thing AND
      name = _name;
END;


CREATE PROCEDURE GetFile(IN _owner VARCHAR(64), IN _thing VARCHAR(64),
  IN _name VARCHAR(256))
BEGIN
  SELECT f.name, type, space, path, caption, visibility,
    FormatTS(f.created) created, downloads, f.position position FROM files f
    WHERE f.thing_id = GetThingID(_owner, _thing) AND f.name = _name;
END;


CREATE PROCEDURE DownloadFile(IN _owner VARCHAR(64), IN _thing VARCHAR(64),
  IN _name VARCHAR(256), IN _count BOOLEAN)
BEGIN
  DECLARE _file_id INT;
  DECLARE _path VARCHAR(256);
  DECLARE _type VARCHAR(64);

  SELECT id, path, type INTO _file_id, _path, _type FROM files
    WHERE thing_id = GetThingID(_owner, _thing) AND name = _name;

  IF _count THEN
    UPDATE files SET downloads = downloads + 1
      WHERE id = _file_id;
  END IF;

  IF _path IS null THEN
    SIGNAL SQLSTATE '02000' -- ER_SIGNAL_NOT_FOUND
      SET MESSAGE_TEXT = 'File not found';
  ELSE
    SELECT _path path, _type type;
  END IF;
END;


CREATE PROCEDURE FileMove(IN _owner VARCHAR(64), IN _thing VARCHAR(64),
  IN _name VARCHAR(256), IN _up BOOLEAN)
BEGIN
  DECLARE _thing_id INT;
  DECLARE _file_id INT;
  DECLARE _position INT;
  DECLARE _next_id INT;

  START TRANSACTION;

  -- Get thing ID
  SET _thing_id = GetThingID(_owner, _thing);

  -- Get current file ID and position
  SELECT id, position INTO _file_id, _position FROM files
    WHERE thing_id = _thing_id AND name = _name;

  -- Get next/prev file ID
  SET _next_id = (
    SELECT id FROM files
      WHERE thing_id = _thing_id AND
        IF(_up, position < _position, _position < position)
      ORDER BY IF(_up, -position, position)
      LIMIT 1);

  -- Swap positions
  UPDATE
    files f1
    JOIN files f2 ON f1.id = _file_id AND f2.id = _next_id
    SET f1.position = f2.position, f2.position = f1.position;

  COMMIT;
END;


CREATE PROCEDURE FileUp(IN _owner VARCHAR(64), IN _thing VARCHAR(64),
  IN _name VARCHAR(256))
BEGIN
  CALL FileMove(_owner, _thing, _name, true);
END;


CREATE PROCEDURE FileDown(IN _owner VARCHAR(64), IN _thing VARCHAR(64),
  IN _name VARCHAR(256))
BEGIN
  CALL FileMove(_owner, _thing, _name, false);
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
  IN _name VARCHAR(256))
BEGIN
  UPDATE files
    SET confirmed = true
    WHERE thing_id = GetThingID(_owner, _thing) AND name = _name;
END;


-- Licenses
CREATE PROCEDURE GetLicenses()
BEGIN
  SELECT name, url, description FROM licenses;
END;


-- Search
CREATE PROCEDURE FindProfiles(IN _query VARCHAR(256), IN _limit INT,
  IN _offset INT)
BEGIN
  -- Query
  IF TRIM(_query) = '' THEN
    SET _query = null;
  END IF;

  -- Limit
  IF _limit IS null THEN
    SET _limit = 100;
  END IF;

  -- Offset
  IF _offset IS null THEN
    SET _offset = 0;
  END IF;

  SET SQL_SELECT_LIMIT = _limit;

  -- Select
  SELECT p.name, p.points, p.followers, p.badges,
      FormatTS(p.joined) joined, MATCH(p.name, p.fullname, p.location, p.bio)
      AGAINST(_query IN BOOLEAN MODE) score

    FROM profiles p

    WHERE
      NOT disabled

    HAVING
      (_query IS null OR 0 < score)

    ORDER BY score DESC, p.points DESC, p.joined ASC;

  SET SQL_SELECT_LIMIT = DEFAULT;
END;


CREATE PROCEDURE FindThings(IN _query VARCHAR(256), IN _license VARCHAR(64),
  IN _limit INT, IN _offset INT)
BEGIN
  -- Query
  IF TRIM(_query) = '' THEN
    SET _query = null;
  END IF;

  -- Limit
  IF _limit IS null THEN
    SET _limit = 100;
  END IF;

  -- Offset
  IF _offset IS null THEN
    SET _offset = 0;
  END IF;

  SET SQL_SELECT_LIMIT = _limit;

  -- Select
  SELECT t.name, p.name owner, p.points owner_points, t.type, t.title,
    IF(t.published IS null, null, FormatTS(t.published)) published,
    FormatTS(t.created) created, FormatTS(t.modified) modified,
    t.comments, t.stars, t.children, t.views,
    GetFileURL(p.name, t.name, f.name) image,
    MATCH(t.name, t.title, t.tags, t.instructions)
    AGAINST(_query IN BOOLEAN MODE) score

    FROM things t
      LEFT JOIN files f ON f.id = GetFirstImageIDByID(t.id)
      INNER JOIN profiles p ON t.owner_id = p.id

    WHERE
      (_license IS null OR t.license = _license) AND
      t.published IS NOT NULL

    HAVING
      (_query IS null OR 0 < score)

    ORDER BY score DESC, t.stars DESC, t.created DESC;

  SET SQL_SELECT_LIMIT = DEFAULT;
END;


-- Events
CREATE FUNCTION GetObjectType(_action VARCHAR(16))
RETURNS VARCHAR(16)
DETERMINISTIC
BEGIN
  CASE
    WHEN _action = 'comment' THEN RETURN 'comment';
    WHEN _action = 'badge' THEN RETURN 'badge';
    WHEN _action IN ('follow', 'badge') THEN RETURN 'profile';
    ELSE RETURN 'thing';
  END CASE;
END;


CREATE PROCEDURE Event(IN _subject_id INT, IN _action VARCHAR(16),
  IN _object_id INT)
BEGIN
  INSERT INTO events (subject_id, action, object_type, object_id)
  VALUES (_subject_id, _action, GetObjectType(_action), _object_id);
END;


CREATE PROCEDURE GetEventsByID(IN _subject_id INT, IN _action VARCHAR(16),
  IN _object_type VARCHAR(16), IN _object_id INT, IN _following BOOLEAN,
  IN _since TIMESTAMP, IN _limit INT)
BEGIN
  IF _limit IS null THEN
    SET _limit = 100;
  END IF;

  IF _following IS null THEN
    SET _following = false;
  END IF;

  SELECT FormatTS(e.ts) ts, s.name subject, e.action, e.object_type,
    COALESCE(
      p.name,
      CONCAT(tp.name, '/', t.name),
      CONCAT(cp.name, '/', ct.name, '#comment-', c.id),
      CONCAT('/badges', b.name)
    ) path

    FROM events e

    LEFT JOIN profiles s  ON s.id = e.subject_id

    LEFT JOIN profiles p  ON e.object_type = 'profile' AND p.id = e.object_id

    LEFT JOIN things t    ON e.object_type = 'thing'   AND t.id = e.object_id
    LEFT JOIN profiles tp ON e.object_type = 'thing'   AND tp.id = t.owner_id

    LEFT JOIN comments c  ON e.object_type = 'comment' AND c.id = e.object_id
    LEFT JOIN things ct   ON e.object_type = 'comment' AND ct.id = c.thing_id
    LEFT JOIN profiles cp ON e.object_type = 'comment' AND cp.id = ct.owner_id

    LEFT JOIN badges b    ON e.object_type = 'badge'   AND b.id = e.object_id

    WHERE
      (_subject_id IS null OR e.subject_id = _subject_id OR
       (_following AND e.subject_id IN (SELECT followed_id FROM followers
          WHERE follower_id = _subject_id))) AND
      (_action      IS null OR FIND_IN_SET(e.action, _action)) AND
      (_object_type IS null OR e.object_type = _object_type) AND
      (_object_id   IS null OR e.object_id   = _object_id) AND
      (_since       IS null OR _since       <= e.ts)

    ORDER BY e.id DESC

    LIMIT _limit;
END;


CREATE PROCEDURE GetEvents(IN _subject VARCHAR(64), IN _action VARCHAR(16),
  IN _object_type VARCHAR(16), IN _object VARCHAR(64), IN _owner VARCHAR(64),
  IN _following BOOLEAN, IN _since TIMESTAMP, IN _limit INT)
BEGIN
  DECLARE _subject_id INT;
  DECLARE _object_id INT;
  DECLARE _owner_id INT;
  DECLARE _action_type VARCHAR(16);

  SET _subject_id = GetProfileID(_subject);

  IF _object IS NOT null THEN
    IF _object_type IS null THEN
      SIGNAL SQLSTATE 'HY000' -- ER_SIGNAL_EXCEPTION
        SET MESSAGE_TEXT = '"object_type" must be used with "object"';
    END IF;

    IF _action IS NOT null AND _object_type != GetObjectType(_action) THEN
      SIGNAL SQLSTATE 'HY000' -- ER_SIGNAL_EXCEPTION
        SET MESSAGE_TEXT = '"object_type" does not agree with "action"';
    END IF;

    IF _object_type = 'thing' THEN
      IF _owner IS NULL THEN
        SIGNAL SQLSTATE 'HY000' -- ER_SIGNAL_EXCEPTION
          SET MESSAGE_TEXT = '"owner" must be used with "thing" object';
      END IF;
    ELSE
      IF _owner IS NOT NULL THEN
        SIGNAL SQLSTATE 'HY000' -- ER_SIGNAL_EXCEPTION
          SET MESSAGE_TEXT =
            '"owner" is not appropriate with non-thing object';
      END IF;
    END IF;

    CASE _object_type
      WHEN 'profile' THEN SET _object_id = GetProfileID(_object);
      WHEN 'thing' THEN SET _object_id = GetThingID(_owner, _object);
      WHEN 'badge' THEN SET _object_id = GetBadgeID(_object);
      ELSE
        SET @message_text =
          CONCAT('Invalid "object_type" "', _object_type, '"');
        SIGNAL SQLSTATE 'HY000' -- ER_SIGNAL_EXCEPTION
          SET MESSAGE_TEXT = @message_text;
    END CASE;
  END IF;

  IF NOT _subject IS null AND _subject_id IS null THEN
    SIGNAL SQLSTATE '02000' -- ER_SIGNAL_NOT_FOUND
      SET MESSAGE_TEXT = 'Subject not found';
  END IF;

  IF NOT _object IS null AND _object_id IS null THEN
    SET @message_text = CONCAT(_object_type, ' not found');
    SIGNAL SQLSTATE '02000' -- ER_SIGNAL_NOT_FOUND
      SET MESSAGE_TEXT = @message_text;
  END IF;

  CALL GetEventsByID(_subject_id, _action, _object_type, _object_id, _following,
    _since, _limit);
END;


CREATE PROCEDURE Maintenance()
BEGIN
  -- Clean thing views
  DELETE FROM thing_views WHERE ts < now() - INTERVAL 1 day;

  -- Clean old unconfirmed files
  DELETE FROM files WHERE created < now() - INTERVAL 6 hour AND NOT confirmed;
END;
