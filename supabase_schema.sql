-- ============================================
-- GhostCall Supabase Schema
-- Run this in: Supabase → SQL Editor → New Query
-- ============================================

-- Users table (no real names, no emails, no phone numbers)
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  call_number VARCHAR(20) NOT NULL,
  password_hash TEXT NOT NULL,
  use_random_number BOOLEAN DEFAULT FALSE,
  show_as_unknown BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Note: call_number is NOT UNIQUE — users can share numbers (as discussed)
-- Add index for lookup performance
CREATE INDEX IF NOT EXISTS idx_users_number_hash 
  ON users(call_number, password_hash);

-- Rooms table (ephemeral — deleted after call ends)
CREATE TABLE IF NOT EXISTS rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_code VARCHAR(8) UNIQUE NOT NULL,
  host_id UUID REFERENCES users(id) ON DELETE CASCADE,
  host_number TEXT NOT NULL DEFAULT 'Unknown',
  status VARCHAR(20) DEFAULT 'waiting',
  -- status values: waiting | ringing | active | ended
  requester_id UUID REFERENCES users(id) ON DELETE SET NULL,
  requester_number TEXT,
  offer JSONB,    -- WebRTC SDP offer
  answer JSONB,   -- WebRTC SDP answer
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-delete rooms older than 30 minutes (cleanup)
-- Run this as a scheduled Supabase Edge Function or cron
-- DELETE FROM rooms WHERE created_at < NOW() - INTERVAL '30 minutes';

CREATE INDEX IF NOT EXISTS idx_rooms_code ON rooms(room_code);
CREATE INDEX IF NOT EXISTS idx_rooms_status ON rooms(status);

-- ICE Candidates (for WebRTC NAT traversal)
CREATE TABLE IF NOT EXISTS ice_candidates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID REFERENCES rooms(id) ON DELETE CASCADE,
  sender TEXT NOT NULL,  -- 'host' or 'joiner'
  candidate JSONB NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ice_room ON ice_candidates(room_id, sender);

-- ============================================
-- Row Level Security (RLS) — IMPORTANT
-- ============================================

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE ice_candidates ENABLE ROW LEVEL SECURITY;

-- Allow anonymous read/write (app uses anon key)
-- For production, tighten these policies with proper auth

CREATE POLICY "users_anon_all" ON users
  FOR ALL TO anon USING (true) WITH CHECK (true);

CREATE POLICY "rooms_anon_all" ON rooms
  FOR ALL TO anon USING (true) WITH CHECK (true);

CREATE POLICY "ice_anon_all" ON ice_candidates
  FOR ALL TO anon USING (true) WITH CHECK (true);

-- ============================================
-- Realtime — Enable for signaling
-- ============================================
-- In Supabase Dashboard:
-- → Database → Replication → Enable for: rooms, ice_candidates
-- ============================================
