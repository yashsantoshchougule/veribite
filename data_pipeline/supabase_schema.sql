-- ==============================================================================
-- Supabase PostgreSQL Schema for Smart Packaged Food Scanner
-- Project: yfexwjkayfwnrcmsqvzf
-- ==============================================================================

-- 1. Products Master Cache Table
CREATE TABLE IF NOT EXISTS public.products (
    barcode TEXT PRIMARY KEY,
    product_name TEXT NOT NULL,
    brand_name TEXT,
    category TEXT,
    serving_size_g NUMERIC,
    piece_weight_g NUMERIC,
    nutrition_json JSONB,
    additives_json JSONB,
    health_score INTEGER,
    nova_grade INTEGER,
    red_cap_triggered INTEGER DEFAULT 0,
    ingredient_hash TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    cached_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Row Level Security (RLS)
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

-- Allow public read access to products
CREATE POLICY "Allow public read access on products"
ON public.products FOR SELECT
USING (true);

-- Allow authenticated and anon inserts/updates for cached products
CREATE POLICY "Allow anon insert on products"
ON public.products FOR INSERT
WITH CHECK (true);

CREATE POLICY "Allow anon update on products"
ON public.products FOR UPDATE
USING (true);

-- 2. User Profiles Table (For Phase 7 Profile Guardrails)
CREATE TABLE IF NOT EXISTS public.user_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id TEXT UNIQUE NOT NULL,
    weight_kg NUMERIC DEFAULT 65.0,
    is_child BOOLEAN DEFAULT false,
    is_diabetic BOOLEAN DEFAULT false,
    is_hypertensive BOOLEAN DEFAULT false,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow anon access on user_profiles"
ON public.user_profiles FOR ALL
USING (true);

-- 3. Scan History Table (For Phase 7 Offline-First History Sync)
CREATE TABLE IF NOT EXISTS public.scan_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id TEXT NOT NULL,
    barcode TEXT NOT NULL REFERENCES public.products(barcode) ON DELETE CASCADE,
    scanned_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.scan_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow anon access on scan_history"
ON public.scan_history FOR ALL
USING (true);

-- Create Indexes for sub-10ms queries
CREATE INDEX IF NOT EXISTS idx_products_barcode ON public.products(barcode);
CREATE INDEX IF NOT EXISTS idx_scan_history_device ON public.scan_history(device_id);
