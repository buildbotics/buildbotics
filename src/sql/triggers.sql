-- Things
DROP TRIGGER IF EXISTS UpdateThings;
CREATE TRIGGER UpdateThings AFTER UPDATE ON things
FOR EACH ROW
BEGIN
  -- Events
  IF NOT IFNULL(OLD.published, false) AND IFNULL(NEW.published, false) THEN
    CALL Event(NEW.owner_id, 'publish', NEW.id);

  ELSE
    IF NEW.published IS NOT NULL THEN
      IF OLD.name != NEW.name THEN
        CALL Event(NEW.owner_id, 'rename', NEW.id);
      END IF;
    END IF;
  END IF;

  -- Space
  IF NEW.space != OLD.space THEN
    UPDATE profiles
      SET space = space + NEW.space - OLD.space
      WHERE id = OLD.owner_id;
  END IF;
END;


DROP TRIGGER IF EXISTS DeleteThings;
CREATE TRIGGER DeleteThings AFTER DELETE ON things
FOR EACH ROW
BEGIN
  DELETE FROM events WHERE object_type = 'thing' AND object_id = OLD.id;
END;


-- Thing Views
DROP TRIGGER IF EXISTS InsertThingViews;
CREATE TRIGGER InsertThingViews AFTER INSERT ON thing_views
FOR EACH ROW
BEGIN
  UPDATE things
    SET views = views + 1
    WHERE id = NEW.thing_id;
END;


-- Followers
DROP TRIGGER IF EXISTS InsertFollowers;
CREATE TRIGGER InsertFollowers AFTER INSERT ON followers
FOR EACH ROW
BEGIN
  -- Event
  CALL Event(NEW.follower_id, 'follow', NEW.followed_id);

  -- Inc profile followers
  UPDATE profiles SET followers = followers + 1
    WHERE id = NEW.followed_id;

  -- Inc profile following
  UPDATE profiles SET following = following + 1
    WHERE id = NEW.follower_id;
END;

DROP TRIGGER IF EXISTS DeleteFollowers;
CREATE TRIGGER DeleteFollowers AFTER DELETE ON followers
FOR EACH ROW
BEGIN
  -- Dec profile followers
  UPDATE profiles SET followers = followers - 1
    WHERE id = OLD.followed_id;

  -- Dec profile following
  UPDATE profiles SET following = following - 1
    WHERE id = OLD.follower_id;
END;


-- Tags
DROP TRIGGER IF EXISTS InsertThingTags;
CREATE TRIGGER InsertThingTags AFTER INSERT ON thing_tags
FOR EACH ROW
BEGIN
  DECLARE _tag VARCHAR(64);

  SELECT name INTO _tag FROM tags WHERE id = NEW.tag_id;

  -- Add thing tag
  UPDATE things
    SET tags = CONCAT(IFNULL(tags, ''), '#', _tag, ',')
    WHERE id = NEW.thing_id AND
      (tags IS NULL OR NOT FIND_IN_SET(_tag, tags));

  -- Inc tag count
  UPDATE tags SET count = count + 1
    WHERE id = NEW.tag_id;
END;

DROP TRIGGER IF EXISTS DeleteThingTags;
CREATE TRIGGER DeleteThingTags AFTER DELETE ON thing_tags
FOR EACH ROW
BEGIN
  DECLARE _tag VARCHAR(64);

  SELECT name INTO _tag FROM tags WHERE id = OLD.tag_id;

  -- Remove thing tag
  UPDATE things
    SET tags = REPLACE(tags, CONCAT('#', _tag, ','), '')
    WHERE id = OLD.thing_id;

  -- Dec tag count
  UPDATE tags SET count = count - 1
    WHERE id = OLD.tag_id;
END;


-- Stars
DROP TRIGGER IF EXISTS InsertStars;
CREATE TRIGGER InsertStars AFTER INSERT ON stars
FOR EACH ROW
BEGIN
  -- Event
  CALL Event(NEW.profile_id, 'star', NEW.thing_id);

  -- Inc profile stars
  UPDATE profiles SET stars = stars + 1
    WHERE id = (SELECT owner_id FROM things WHERE id = NEW.thing_id);

  -- Inc thing stars
  UPDATE things SET stars = stars + 1 WHERE id = NEW.thing_id;
END;

DROP TRIGGER IF EXISTS DeleteStars;
CREATE TRIGGER DeleteStars AFTER DELETE ON stars
FOR EACH ROW
BEGIN
  -- Dec profile stars
  UPDATE profiles SET stars = stars - 1
    WHERE id = (SELECT owner_id FROM things WHERE id = OLD.thing_id);
  UPDATE things SET stars = stars - 1 WHERE id = OLD.thing_id;
END;


-- Comments
DROP TRIGGER IF EXISTS InsertComments;
CREATE TRIGGER InsertComments AFTER INSERT ON comments
FOR EACH ROW
BEGIN
  -- Event
  CALL Event(NEW.owner_id, 'comment', NEW.id);

  -- Inc thing comments
  UPDATE things SET comments = comments + 1 WHERE id = NEW.thing_id;
END;

DROP TRIGGER IF EXISTS DeleteComments;
CREATE TRIGGER DeleteComments AFTER DELETE ON comments
FOR EACH ROW
BEGIN
  -- Dec thing comments
  UPDATE things SET comments = comments - 1 WHERE id = OLD.thing_id;
END;


-- Profile Badges
DROP TRIGGER IF EXISTS InsertProfileBadges;
CREATE TRIGGER InsertProfileBadges AFTER INSERT ON profile_badges
FOR EACH ROW
BEGIN
  DECLARE badge_auth BIGINT UNSIGNED DEFAULT 0;

  -- Event
  CALL Event(NEW.profile_id, 'badge', NEW.badge_id);

  -- Inc profile badges
  SELECT auth FROM badges WHERE id = NEW.badge_id INTO badge_auth;

  UPDATE profiles
    SET badges = badges + 1, auth = auth & badge_auth
    WHERE id = NEW.profile_id;

  UPDATE badges SET issued = issued + 1 WHERE id = NEW.badge_id;
END;

DROP TRIGGER IF EXISTS DeleteProfileBadges;
CREATE TRIGGER DeleteProfileBadges AFTER DELETE ON profile_badges
FOR EACH ROW
BEGIN
  DECLARE badge_auth BIGINT UNSIGNED DEFAULT 0;

  -- Dec profile badges
  SELECT auth FROM badges WHERE id = OLD.badge_id INTO badge_auth;

  UPDATE profiles
    SET badges = badges - 1, auth = auth & ~badge_auth
    WHERE id = OLD.profile_id;

  UPDATE badges SET issued = issued - 1 WHERE id = OLD.badge_id;
END;


-- Files
DROP TRIGGER IF EXISTS InsertFiles;
CREATE TRIGGER InsertFiles AFTER INSERT ON files
FOR EACH ROW
BEGIN
  -- Space
  UPDATE things
    SET space = space + NEW.space, modified = CURRENT_TIMESTAMP
    WHERE id = NEW.thing_id;
END;


DROP TRIGGER IF EXISTS UpdateFiles;
CREATE TRIGGER UpdateFiles AFTER UPDATE ON files
FOR EACH ROW
BEGIN
  -- Space
  IF NEW.space != OLD.space THEN
    UPDATE things
      SET space = space + NEW.space - OLD.space, modified = CURRENT_TIMESTAMP
      WHERE id = OLD.thing_id;
  END IF;
END;


DROP TRIGGER IF EXISTS DeleteFiles;
CREATE TRIGGER DeleteFiles AFTER DELETE ON files
FOR EACH ROW
BEGIN
  -- Space
  UPDATE things
    SET space = space - OLD.space, modified = CURRENT_TIMESTAMP
    WHERE id = OLD.thing_id;
END;
