-- Followers
DROP TRIGGER IF EXISTS IncFollowers;
CREATE TRIGGER IncFollowers AFTER INSERT ON followers
FOR EACH ROW
BEGIN
  UPDATE profiles SET followers = followers + 1
    WHERE id = NEW.followed_id;
  UPDATE profiles SET following = following + 1
    WHERE id = NEW.follower_id;
END;

DROP TRIGGER IF EXISTS DecFollowers;
CREATE TRIGGER DecFollowers AFTER DELETE ON followers
FOR EACH ROW
BEGIN
  UPDATE profiles SET followers = followers - 1
    WHERE id = OLD.followed_id;
  UPDATE profiles SET following = following - 1
    WHERE id = OLD.follower_id;
END;


-- Tags
DROP TRIGGER IF EXISTS IncTagCount;
CREATE TRIGGER IncTagCount AFTER INSERT ON thing_tags
FOR EACH ROW
BEGIN
  DECLARE _tag VARCHAR(64);

  SELECT name INTO _tag FROM tags WHERE id = NEW.tag_id;

  UPDATE things
    SET tags = CONCAT(IFNULL(tags, ''), '#', _tag, ',')
    WHERE id = NEW.thing_id AND
      (tags IS NULL OR NOT FIND_IN_SET(_tag, tags));

  UPDATE tags SET count = count + 1
    WHERE id = NEW.tag_id;
END;

DROP TRIGGER IF EXISTS DecTagCount;
CREATE TRIGGER DecTagCount AFTER DELETE ON thing_tags
FOR EACH ROW
BEGIN
  DECLARE _tag VARCHAR(64);

  SELECT name INTO _tag FROM tags WHERE id = OLD.tag_id;

  UPDATE things
    SET tags = REPLACE(tags, CONCAT('#', _tag, ','), '')
    WHERE id = OLD.thing_id;

  UPDATE tags SET count = count - 1
    WHERE id = OLD.tag_id;
END;


-- Stars
DROP TRIGGER IF EXISTS IncStars;
CREATE TRIGGER IncStars AFTER INSERT ON stars
FOR EACH ROW
BEGIN
  UPDATE profiles SET stars = stars + 1
    WHERE id = (SELECT owner_id FROM things WHERE id = NEW.thing_id);
  UPDATE things SET stars = stars + 1 WHERE id = NEW.thing_id;
END;

DROP TRIGGER IF EXISTS DecStars;
CREATE TRIGGER DecStars AFTER DELETE ON stars
FOR EACH ROW
BEGIN
  UPDATE profiles SET stars = stars - 1
    WHERE id = (SELECT owner_id FROM things WHERE id = OLD.thing_id);
  UPDATE things SET stars = stars - 1 WHERE id = OLD.thing_id;
END;


-- Comments
DROP TRIGGER IF EXISTS IncComments;
CREATE TRIGGER IncComments AFTER INSERT ON comments
FOR EACH ROW
BEGIN
  UPDATE things SET comments = comments + 1 WHERE id = NEW.thing_id;
END;

DROP TRIGGER IF EXISTS DecComments;
CREATE TRIGGER DecComments AFTER DELETE ON comments
FOR EACH ROW
BEGIN
  UPDATE things SET comments = comments - 1 WHERE id = OLD.thing_id;
END;


-- Badges
DROP TRIGGER IF EXISTS IncBadges;
CREATE TRIGGER IncBadges AFTER INSERT ON profile_badges
FOR EACH ROW
BEGIN
  DECLARE badge_auth BIGINT UNSIGNED DEFAULT 0;

  SELECT auth FROM badges WHERE id = NEW.badge_id INTO badge_auth;

  UPDATE profiles
    SET badges = badges + 1, auth = auth & badge_auth
    WHERE id = NEW.profile_id;

  UPDATE badges SET issued = issued + 1 WHERE id = NEW.badge_id;
END;

DROP TRIGGER IF EXISTS DecBadges;
CREATE TRIGGER DecBadges AFTER DELETE ON profile_badges
FOR EACH ROW
BEGIN
  DECLARE badge_auth BIGINT UNSIGNED DEFAULT 0;

  SELECT auth FROM badges WHERE id = OLD.badge_id INTO badge_auth;

  UPDATE profiles
    SET badges = badges - 1, auth = auth & ~badge_auth
    WHERE id = OLD.profile_id;

  UPDATE badges SET issued = issued - 1 WHERE id = OLD.badge_id;
END;


-- Space
DROP TRIGGER IF EXISTS AddFile;
CREATE TRIGGER AddFile AFTER INSERT ON files
FOR EACH ROW
BEGIN
  UPDATE things
    SET space = space + NEW.space, modified = CURRENT_TIMESTAMP
    WHERE id = NEW.thing_id;
END;


DROP TRIGGER IF EXISTS UpdateFile;
CREATE TRIGGER UpdateFile AFTER UPDATE ON files
FOR EACH ROW
BEGIN
  IF NEW.space != OLD.space THEN
    UPDATE things
      SET space = space + NEW.space - OLD.space, modified = CURRENT_TIMESTAMP
      WHERE id = OLD.thing_id;
  END IF;
END;


DROP TRIGGER IF EXISTS UpdateThingSpace;
CREATE TRIGGER UpdateThingSpace AFTER UPDATE ON things
FOR EACH ROW
BEGIN
  IF NEW.space != OLD.space THEN
    UPDATE profiles
      SET space = space + NEW.space - OLD.space
      WHERE id = OLD.owner_id;
  END IF;
END;


DROP TRIGGER IF EXISTS DelFile;
CREATE TRIGGER DelFile AFTER DELETE ON files
FOR EACH ROW
BEGIN
  UPDATE things
    SET space = space - OLD.space, modified = CURRENT_TIMESTAMP
    WHERE id = OLD.thing_id;
END;
