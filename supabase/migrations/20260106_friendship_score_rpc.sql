-- Migration: Create calculate_friendship_score RPC function
-- This function efficiently calculates the friendship score between two users
-- in a single database call, avoiding multiple round trips from the client.

CREATE OR REPLACE FUNCTION calculate_friendship_score(
    current_user_id UUID,
    friend_user_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSON;
    likes_given INT := 0;
    likes_received INT := 0;
    replies_given INT := 0;
    replies_received INT := 0;
    vibe_responses_given INT := 0;
    vibe_responses_received INT := 0;
    matching_rating_days INT := 0;
    friendship_weeks INT := 0;
    friendship_created TIMESTAMPTZ;
    total_score INT := 0;
BEGIN
    -- Get friendship creation date
    SELECT created_at INTO friendship_created
    FROM friendships
    WHERE user_id = current_user_id AND friend_id = friend_user_id
    LIMIT 1;
    
    -- Calculate friendship weeks (minimum 1 if friends)
    IF friendship_created IS NOT NULL THEN
        friendship_weeks := GREATEST(1, EXTRACT(WEEK FROM (NOW() - friendship_created))::INT);
    END IF;
    
    -- Count likes given (current user -> friend's posts)
    SELECT COUNT(*) INTO likes_given
    FROM post_likes pl
    INNER JOIN posts p ON pl.post_id = p.id
    WHERE pl.user_id = current_user_id AND p.user_id = friend_user_id;
    
    -- Count likes received (friend -> current user's posts)
    SELECT COUNT(*) INTO likes_received
    FROM post_likes pl
    INNER JOIN posts p ON pl.post_id = p.id
    WHERE pl.user_id = friend_user_id AND p.user_id = current_user_id;
    
    -- Count replies given (current user -> friend's posts)
    SELECT COUNT(*) INTO replies_given
    FROM post_replies pr
    INNER JOIN posts p ON pr.post_id = p.id
    WHERE pr.user_id = current_user_id AND p.user_id = friend_user_id;
    
    -- Count replies received (friend -> current user's posts)
    SELECT COUNT(*) INTO replies_received
    FROM post_replies pr
    INNER JOIN posts p ON pr.post_id = p.id
    WHERE pr.user_id = friend_user_id AND p.user_id = current_user_id;
    
    -- Count vibe responses given (friend responded "yes" to current user's vibes)
    SELECT COUNT(*) INTO vibe_responses_given
    FROM vibe_responses vr
    INNER JOIN vibes v ON vr.vibe_id = v.id
    WHERE vr.user_id = friend_user_id 
      AND v.user_id = current_user_id 
      AND vr.response = 'yes';
    
    -- Count vibe responses received (current user responded "yes" to friend's vibes)
    SELECT COUNT(*) INTO vibe_responses_received
    FROM vibe_responses vr
    INNER JOIN vibes v ON vr.vibe_id = v.id
    WHERE vr.user_id = current_user_id 
      AND v.user_id = friend_user_id 
      AND vr.response = 'yes';
    
    -- Count matching rating days (both users rated on the same day)
    SELECT COUNT(*) INTO matching_rating_days
    FROM (
        SELECT DATE(rh1.date) as rating_date
        FROM rating_history rh1
        WHERE rh1.user_id = current_user_id
        INTERSECT
        SELECT DATE(rh2.date) as rating_date
        FROM rating_history rh2
        WHERE rh2.user_id = friend_user_id
    ) matching_dates;
    
    -- Calculate total score with weights:
    -- - Likes: 1 point each
    -- - Replies: 2 points each  
    -- - Vibe responses: 3 points each
    -- - Matching rating days: 1 point each
    -- - Friendship duration: 1 point per week
    total_score := likes_given + likes_received +
                   (replies_given + replies_received) * 2 +
                   (vibe_responses_given + vibe_responses_received) * 3 +
                   matching_rating_days +
                   friendship_weeks;
    
    -- Build result JSON
    result := json_build_object(
        'score', total_score,
        'likes_given', likes_given,
        'likes_received', likes_received,
        'replies_given', replies_given,
        'replies_received', replies_received,
        'vibe_responses_given', vibe_responses_given,
        'vibe_responses_received', vibe_responses_received,
        'matching_rating_days', matching_rating_days,
        'friendship_weeks', friendship_weeks
    );
    
    RETURN result;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION calculate_friendship_score(UUID, UUID) TO authenticated;

-- Add comment for documentation
COMMENT ON FUNCTION calculate_friendship_score IS 
'Calculates a friendship score between two users based on their interactions:
- Likes exchanged (1 point each)
- Replies exchanged (2 points each)
- Vibe responses (3 points each)
- Days both users rated (1 point each)
- Friendship duration (1 point per week)

Returns JSON with score and breakdown.';
