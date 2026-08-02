-- Migration: Create leaderboard_stats table for FluentUp
CREATE TABLE IF NOT EXISTS public.leaderboard_stats (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT NOT NULL DEFAULT 'Learner',
    total_xp INTEGER NOT NULL DEFAULT 0,
    current_streak INTEGER NOT NULL DEFAULT 0,
    coins INTEGER NOT NULL DEFAULT 0,
    is_public BOOLEAN NOT NULL DEFAULT true,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable Row Level Security (RLS)
ALTER TABLE public.leaderboard_stats ENABLE ROW LEVEL SECURITY;

-- Allow all authenticated users to read public leaderboard entries
CREATE POLICY "Allow public read access to leaderboard_stats"
    ON public.leaderboard_stats
    FOR SELECT
    TO authenticated
    USING (is_public = true OR auth.uid() = user_id);

-- Allow users to insert/update only their own leaderboard record
CREATE POLICY "Allow individual insert/update access to leaderboard_stats"
    ON public.leaderboard_stats
    FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);
