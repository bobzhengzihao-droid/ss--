-- ============================================
-- 反馈表 V4.0 — Supabase 数据库初始化
-- 在 Supabase SQL Editor 中执行
-- ============================================

-- 0. 修复现有 RLS 策略（如已执行过旧版 SQL 需运行此段）
-- DROP POLICY IF EXISTS "data_all_own" ON data_store;
-- CREATE POLICY "data_all_own" ON data_store FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- 1. 老师档案表（公开读，用于登录时按姓名查邮箱）
CREATE TABLE IF NOT EXISTS public.teacher_profiles (
  id SERIAL PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  name TEXT UNIQUE NOT NULL,
  is_admin BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.teacher_profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "profiles_public_read" ON teacher_profiles FOR SELECT USING (true);
CREATE POLICY "profiles_insert" ON teacher_profiles FOR INSERT WITH CHECK (true);
CREATE POLICY "profiles_update_own" ON teacher_profiles FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 2. 数据存储表（每个老师只能读写自己的）
CREATE TABLE IF NOT EXISTS public.data_store (
  id SERIAL PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  key TEXT NOT NULL,
  value JSONB NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, key)
);

ALTER TABLE public.data_store ENABLE ROW LEVEL SECURITY;
CREATE POLICY "data_all_own" ON data_store FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- 3. 注册码表
CREATE TABLE IF NOT EXISTS public.reg_codes (
  id SERIAL PRIMARY KEY,
  code TEXT UNIQUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO reg_codes (code) VALUES ('english2024')
ON CONFLICT (code) DO NOTHING;

-- 4. 触发器：新用户创建时自动写入 teacher_profiles
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.teacher_profiles (user_id, name)
  VALUES (NEW.id, NEW.raw_user_meta_data->>'name');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- 5. 校验注册码的 RPC 函数
CREATE OR REPLACE FUNCTION check_reg_code(input_code TEXT, teacher_name TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM reg_codes WHERE code = input_code) THEN
    IF EXISTS (SELECT 1 FROM teacher_profiles WHERE name = teacher_name) THEN
      RAISE EXCEPTION '该姓名已注册';
    END IF;
    RETURN TRUE;
  END IF;
  RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
