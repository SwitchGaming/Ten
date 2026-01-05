-- Migration: Add indexes to optimize friendship score calculation
-- These indexes significantly speed up the JOIN queries in calculate_friendship_score

-- Index for posts by user_id (for finding a user's posts quickly)
CREATE INDEX IF NOT EXISTS idx_posts_user_id ON posts(user_id);

-- Index for post_likes by user_id (for finding who liked what)
CREATE INDEX IF NOT EXISTS idx_post_likes_user_id ON post_likes(user_id);

-- Index for post_likes by post_id (for finding likes on a specific post)
CREATE INDEX IF NOT EXISTS idx_post_likes_post_id ON post_likes(post_id);

-- Composite index for post_likes (covers most query patterns)
CREATE INDEX IF NOT EXISTS idx_post_likes_user_post ON post_likes(user_id, post_id);

-- Index for post_replies by user_id
CREATE INDEX IF NOT EXISTS idx_post_replies_user_id ON post_replies(user_id);

-- Index for post_replies by post_id
CREATE INDEX IF NOT EXISTS idx_post_replies_post_id ON post_replies(post_id);

-- Composite index for post_replies
CREATE INDEX IF NOT EXISTS idx_post_replies_user_post ON post_replies(user_id, post_id);

-- Index for vibes by user_id
CREATE INDEX IF NOT EXISTS idx_vibes_user_id ON vibes(user_id);

-- Index for vibe_responses by user_id
CREATE INDEX IF NOT EXISTS idx_vibe_responses_user_id ON vibe_responses(user_id);

-- Index for vibe_responses by vibe_id
CREATE INDEX IF NOT EXISTS idx_vibe_responses_vibe_id ON vibe_responses(vibe_id);

-- Composite index for vibe_responses (covers friendship score query)
CREATE INDEX IF NOT EXISTS idx_vibe_responses_user_response ON vibe_responses(user_id, response);

-- Index for rating_history by user_id and date (for matching days query)
CREATE INDEX IF NOT EXISTS idx_rating_history_user_date ON rating_history(user_id, date);

-- Index for friendships lookup
CREATE INDEX IF NOT EXISTS idx_friendships_user_friend ON friendships(user_id, friend_id);

-- Add comments
COMMENT ON INDEX idx_posts_user_id IS 'Speeds up finding posts by a specific user';
COMMENT ON INDEX idx_post_likes_user_post IS 'Speeds up friendship score like counting';
COMMENT ON INDEX idx_post_replies_user_post IS 'Speeds up friendship score reply counting';
COMMENT ON INDEX idx_vibe_responses_user_response IS 'Speeds up friendship score vibe response counting';
COMMENT ON INDEX idx_rating_history_user_date IS 'Speeds up matching rating days calculation';
COMMENT ON INDEX idx_friendships_user_friend IS 'Speeds up friendship lookup and duration calculation';
