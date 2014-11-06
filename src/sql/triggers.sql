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


-- Stars
DROP TRIGGER IF EXISTS IncStars;
CREATE TRIGGER IncStars AFTER INSERT ON stars
FOR EACH ROW
BEGIN
  UPDATE profiles SET stars = stars + 1
    WHERE id = (SELECT owner_id FROM things WHERE id = NEW.thing_id);
END;

DROP TRIGGER IF EXISTS DecStars;
CREATE TRIGGER DecStars AFTER DELETE ON stars
FOR EACH ROW
BEGIN
  UPDATE profiles SET stars = stars - 1
    WHERE id = (SELECT owner_id FROM things WHERE id = OLD.thing_id);
END;


-- Badges
DROP TRIGGER IF EXISTS IncBadges;
CREATE TRIGGER IncBadges AFTER INSERT ON profile_badges
FOR EACH ROW
BEGIN
  UPDATE profiles SET badges = badges + 1 WHERE id = NEW.profile_id;
  UPDATE badges SET issued = issued + 1 WHERE id = NEW.badge_id;
END;

DROP TRIGGER IF EXISTS DecBadges;
CREATE TRIGGER DecBadges AFTER DELETE ON profile_badges
FOR EACH ROW
BEGIN
  UPDATE profiles SET badges = badges - 1 WHERE id = OLD.profile_id;
  UPDATE badges SET issued = issued - 1 WHERE id = OLD.badge_id;
END;
