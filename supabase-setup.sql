-- ================================================================
-- NIRMEDIX PHARMA — SUPABASE DATABASE SETUP
-- Run this entire script in: Supabase → SQL Editor → Run
-- ================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ================================================================
-- TABLES
-- ================================================================

-- Products catalogue
CREATE TABLE IF NOT EXISTS products (
  id           UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name         TEXT NOT NULL,
  category     TEXT NOT NULL DEFAULT 'gi',
  form         TEXT,
  composition  TEXT,
  description  TEXT,
  image_url    TEXT DEFAULT '',
  image_url_2  TEXT DEFAULT '',
  indications  JSONB DEFAULT '[]',
  is_featured  BOOLEAN DEFAULT FALSE,
  is_active    BOOLEAN DEFAULT TRUE,
  stock_status TEXT DEFAULT 'available'
               CHECK (stock_status IN ('available','out_of_stock','coming_soon')),
  sort_order   INTEGER DEFAULT 0,
  view_count   INTEGER DEFAULT 0,
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ DEFAULT NOW()
);

-- Certifications
CREATE TABLE IF NOT EXISTS certificates (
  id          UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name        TEXT NOT NULL,
  description TEXT,
  icon        TEXT DEFAULT '✅',
  color       TEXT DEFAULT '#0077B6',
  bg_color    TEXT DEFAULT '#EBF8FF',
  logo_url    TEXT DEFAULT '',
  sort_order  INTEGER DEFAULT 0,
  is_active   BOOLEAN DEFAULT TRUE
);

-- Site settings (key-value JSON)
CREATE TABLE IF NOT EXISTS site_settings (
  key        TEXT PRIMARY KEY,
  value      JSONB NOT NULL DEFAULT '{}',
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Stats bar
CREATE TABLE IF NOT EXISTS stats (
  id         UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  num        TEXT NOT NULL,
  label      TEXT NOT NULL,
  sort_order INTEGER DEFAULT 0
);

-- Company values
CREATE TABLE IF NOT EXISTS company_values (
  id          UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  icon        TEXT DEFAULT '⭐',
  title       TEXT NOT NULL,
  description TEXT,
  sort_order  INTEGER DEFAULT 0
);

-- Distributor benefits
CREATE TABLE IF NOT EXISTS dist_benefits (
  id          UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  icon        TEXT DEFAULT '✅',
  title       TEXT NOT NULL,
  description TEXT,
  sort_order  INTEGER DEFAULT 0
);

-- Enquiries / Leads
CREATE TABLE IF NOT EXISTS enquiries (
  id            UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name          TEXT,
  phone         TEXT,
  email         TEXT,
  state         TEXT,
  business_type TEXT,
  message       TEXT,
  source        TEXT DEFAULT 'website',
  status        TEXT DEFAULT 'new'
                CHECK (status IN ('new','contacted','closed')),
  admin_notes   TEXT DEFAULT '',
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- Analytics events
CREATE TABLE IF NOT EXISTS analytics_events (
  id         UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  event_type TEXT NOT NULL,
  data       JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ================================================================
-- AUTO-UPDATE updated_at
-- ================================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_products_updated_at ON products;
CREATE TRIGGER set_products_updated_at
  BEFORE UPDATE ON products
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS set_settings_updated_at ON site_settings;
CREATE TRIGGER set_settings_updated_at
  BEFORE UPDATE ON site_settings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================
ALTER TABLE products           ENABLE ROW LEVEL SECURITY;
ALTER TABLE certificates       ENABLE ROW LEVEL SECURITY;
ALTER TABLE site_settings      ENABLE ROW LEVEL SECURITY;
ALTER TABLE stats               ENABLE ROW LEVEL SECURITY;
ALTER TABLE company_values     ENABLE ROW LEVEL SECURITY;
ALTER TABLE dist_benefits      ENABLE ROW LEVEL SECURITY;
ALTER TABLE enquiries          ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_events   ENABLE ROW LEVEL SECURITY;

-- Content tables: anyone can read, only authenticated users can write
DO $$ BEGIN
  FOR t IN SELECT unnest(ARRAY['products','certificates','site_settings','stats','company_values','dist_benefits']) LOOP
    EXECUTE format('CREATE POLICY "%s_public_read"  ON %s FOR SELECT USING (true)', t, t);
    EXECUTE format('CREATE POLICY "%s_auth_write"   ON %s FOR ALL    USING (auth.role() = ''authenticated'')', t, t);
  END LOOP;
END $$;

-- Enquiries: anyone can submit, only admins can read/update
CREATE POLICY "enquiries_public_insert" ON enquiries FOR INSERT WITH CHECK (true);
CREATE POLICY "enquiries_auth_select"   ON enquiries FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "enquiries_auth_update"   ON enquiries FOR UPDATE USING (auth.role() = 'authenticated');
CREATE POLICY "enquiries_auth_delete"   ON enquiries FOR DELETE USING (auth.role() = 'authenticated');

-- Analytics: anyone can insert, only admins can read
CREATE POLICY "analytics_public_insert" ON analytics_events FOR INSERT WITH CHECK (true);
CREATE POLICY "analytics_auth_select"   ON analytics_events FOR SELECT USING (auth.role() = 'authenticated');

-- ================================================================
-- STORAGE BUCKETS  (run in Supabase Dashboard → Storage or via API)
-- These SQL statements create the buckets if using Supabase >= 2.0
-- ================================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('product-images', 'product-images', true, 5242880, ARRAY['image/jpeg','image/png','image/webp']),
  ('cert-logos',     'cert-logos',     true, 2097152, ARRAY['image/jpeg','image/png','image/webp','image/svg+xml'])
ON CONFLICT (id) DO NOTHING;

-- Storage policies
CREATE POLICY "storage_public_read" ON storage.objects FOR SELECT USING (bucket_id IN ('product-images','cert-logos'));
CREATE POLICY "storage_auth_write"  ON storage.objects FOR INSERT WITH CHECK (auth.role() = 'authenticated' AND bucket_id IN ('product-images','cert-logos'));
CREATE POLICY "storage_auth_update" ON storage.objects FOR UPDATE USING (auth.role() = 'authenticated');
CREATE POLICY "storage_auth_delete" ON storage.objects FOR DELETE USING (auth.role() = 'authenticated');

-- ================================================================
-- SEED DATA
-- ================================================================

-- Site settings
INSERT INTO site_settings (key, value) VALUES
('company', '{
  "name": "Nirmedix Pharma",
  "fullName": "Nirmedix Pharma Pvt. Ltd.",
  "tagline": "Trusted Pharmaceutical Partner",
  "heroTitle": "Delivering Premium Healthcare Across India",
  "heroDesc": "Nirmedix Pharma Pvt. Ltd. sources WHO-GMP certified pharmaceutical formulations and supplies a comprehensive range of quality medicines to distributors and retailers across India.",
  "aboutTitle": "Your Trusted Pharma Marketing Partner",
  "aboutDesc": "Nirmedix Pharma Pvt. Ltd. is a growing pharmaceutical marketing company dedicated to making high-quality medicines accessible across India. We source formulations exclusively from WHO-GMP certified manufacturers and maintain the highest standards of quality, compliance, and service.",
  "productsTitle": "Comprehensive Range of Quality Formulations",
  "distTitle": "Partner With Us & Grow Your Business",
  "distDesc": "Join our expanding network of distributors and retailers. We offer competitive margins, dedicated support, and a comprehensive product range to help your business thrive.",
  "address": "Namghar Road, Barpeta Road, Assam — 781315",
  "phone": "+91 XXXXX XXXXX",
  "whatsapp": "91XXXXXXXXXX",
  "whatsapp_msg": "Hello, I am interested in your pharmaceutical products. Please share details.",
  "email": "info@nirmedixpharma.com",
  "hours": "Mon–Sat: 9:00 AM – 6:00 PM",
  "footerDesc": "Pharmaceutical marketing company sourcing WHO-GMP certified formulations and supplying to distributors & retailers across India.",
  "copyright": "© 2025 Nirmedix Pharma Pvt. Ltd. All rights reserved."
}'::jsonb),
('seo', '{
  "title": "Nirmedix Pharma Pvt. Ltd. — Pharmaceutical Excellence",
  "description": "Premium pharmaceutical marketing company supplying WHO-GMP certified formulations across India. Distributor enquiries welcome.",
  "keywords": "nirmedix pharma, pharmaceutical, WHO-GMP, medicines, distributor, India, Assam, barpeta road",
  "ogImage": ""
}'::jsonb)
ON CONFLICT (key) DO NOTHING;

-- Stats
INSERT INTO stats (num, label, sort_order) VALUES
('15+',    'Products',           1),
('8+',     'Therapeutic Areas',  2),
('100+',   'Distributors',       3),
('WHO-GMP','Certified Source',   4)
ON CONFLICT DO NOTHING;

-- Company values
INSERT INTO company_values (icon, title, description, sort_order) VALUES
('🎯','Quality Assurance','Every product sourced from WHO-GMP certified manufacturers with strict QC protocols.',1),
('🚀','Pan-India Reach','Extensive distribution network across multiple states ensuring timely delivery.',2),
('🤝','Partner Support','Dedicated support team available to assist distributors and partners at every step.',3),
('💊','Diverse Portfolio','Wide range covering GI, pain, liver care, allergy, nutrition, and pediatric segments.',4)
ON CONFLICT DO NOTHING;

-- Distributor benefits
INSERT INTO dist_benefits (icon, title, description, sort_order) VALUES
('💰','Competitive Margins','Best-in-industry margins to maximize your profitability.',1),
('📦','Fast & Reliable Supply','Consistent stock availability with prompt order fulfillment.',2),
('🎓','Product Training','Comprehensive product knowledge and marketing support.',3),
('📋','Regulatory Support','Full documentation and compliance support provided.',4)
ON CONFLICT DO NOTHING;

-- Certificates
INSERT INTO certificates (name, description, icon, color, bg_color, sort_order) VALUES
('WHO-GMP',     'World Health Organization Good Manufacturing Practice','🏥','#0077B6','#EBF8FF',1),
('ISO 9001:2015','Quality Management System Certification',            '✅','#059669','#ECFDF5',2),
('FSSAI',       'Food Safety & Standards Authority of India',          '🛡️','#D97706','#FFFBEB',3),
('GMP',         'Good Manufacturing Practices Compliant',              '⚗️','#7C3AED','#F5F3FF',4),
('HACCP',       'Hazard Analysis Critical Control Points',             '🔬','#DC2626','#FEF2F2',5),
('DCGI',        'Drugs Controller General of India Approved',          '💊','#1E40AF','#EFF6FF',6)
ON CONFLICT DO NOTHING;

-- Products
INSERT INTO products (name, category, form, composition, description, image_url, indications, is_featured, sort_order) VALUES
('Nirmepan™-DSR','gi','Capsule · 10×10','Pantoprazole 40mg + Domperidone 30mg (Prolonged-Release)','Pantoprazole is an effective PPI that stops acid production in the stomach by binding with Proton Pump at the final stage. Domperidone accelerates transit in small intestine and acts as a trusted antiemetic, gastroprokinetic agent.','images/nirmepan-dsr.jpg','["Heart Burn","Gastric/Duodenal Ulcers","Dyspepsia","Erosive Esophagitis"]',true,1),
('Mulvitadix™-L','nutrition','Syrup · 200 ml','Lycopene 10% 2000mcg + Niacinamide 25mg + Folic Acid 100mcg + Selenium 35mcg + Zinc 3mg + Iodine 100mcg + Copper 500mcg + Vitamin B12 1mcg + Vitamin B6 1.5mg','A potent antioxidant lycopene-based multivitamin syrup. Acts as most potent scavenger of singlet species of oxygen free radicals. Supports healthy vascular function and improves insulin sensitivity.','images/mulvitadix-l.jpg','["Diabetes","High Blood Pressure","Skin Disease","Exercise-Induced Asthma","Pre-Eclampsia","Male & Female Infertility","Oxidative Stress"]',true,2),
('Nirmepan™-40','gi','Tablet · 10×10','Pantoprazole 40mg','Effective 24-hour suppression of basal and stimulated gastric acid hypersecretion. Provides fast resolution of symptoms and high healing rates with convenient once daily dosing.','images/nirmepan-40.jpg','["GERD","Gastric & Duodenal Ulcers","Hypersecretory Conditions","Erosive Esophagitis","NSAID Induced Gastritis"]',false,3),
('Silynodix™ Plus','liver','Syrup · 200 ml','Silymarin with B-Complex Syrup (Sugar Free)','Reduces hyperammonemia, improves impaired ammonia detoxification, controls cirrhosis, hyperammonemia & stable, overt, chronic hepatic encephalopathy.','images/silynodix-plus.jpg','["Hepatitis","Hepatic Encephalopathy","Liver Cirrhosis","Fatty Liver","Alcohol Induced Liver Damage"]',false,4),
('Nircalci™-XT','nutrition','Tablet · 10×10','Calcium Citrate Malate 1250mg + Vitamin K₂7 90mcg + Vitamin D3 1000 IU + Methylcobalamin 1500mcg + Zinc Oxide 15mg + Magnesium Oxide 50mg','Increases calcium absorption. Provides better suppression of PTH. Manages hypocalcaemia in dialysis patients. Essential for healthy arteries & strong bones.','images/nircalci-xt.jpg','["Osteoporosis","Osteogenesis","Post Menopausal","Renal Osteo-Dystrophy","Hypothyroidism"]',true,5),
('Apidix™-JR','pediatric','Syrup · 100 ml','Alpha-Amylase + Papain + L-Cysteine Hydrochloride Syrup','Alpha-Amylase digests starch, Papain acts as digestive aid, L-Cysteine HCl boosts glutathione levels and reduces oxidative stress.','images/apidix-jr.jpg','["Infantile Colic","Indigestion","Flatulent & Fermentative Dyspepsia","Post Feed Abdominal Distention"]',false,6),
('Aclodix™-TH4','pain','Tablet · 10×10','Aceclofenac 100mg + Thiocolchicoside 4mg','Aceclofenac exerts better safety profile over Diclofenac. Thiocolchicoside provides better pain reduction in patients with muscle spasm over Tizanidine.','images/aclodix-th4.jpg','["Sprain & Strain","Spondylosis","Skeletal Muscle Spasm","Low Back Pain","Neuromuscular Pain","Post Operative Pain","Sports Injury"]',false,7),
('Rifaxnir™-400','gi','Tablet · 10×1×10','Rifaximin 400mg','Exhibits broad-spectrum in vitro activity against gram-positive and gram-negative aerobic and anaerobic enteric bacteria. Shows low risk of inducing bacterial resistance.','images/rifaxnir-400.jpg','["Traveler''''s Diarrhea","Functional Dyspepsia","Controls SIBO Growth","Hepatic Encephalopathy"]',false,8),
('Montinir™-L Syrup','allergy','Syrup · 60 ml (Paediatric)','Levocetirizine HCl 2.5mg + Montelukast Sodium 4mg','Safe & proven formulation for kids. Levocetirizine reduces rhinorrhea and itching. Montelukast decreases nasal congestion and sleep impairment.','images/montinir-l-syrup.jpg','["Relief of Symptoms of Allergic Rhinitis","Prophylaxis in Seasonal Allergic Rhinitis","Symptoms of Perennial Allergic Rhinitis"]',false,9),
('Aclodix™-P','pain','Tablet · 10×10','Aceclofenac 100mg + Paracetamol 325mg','Aceclofenac is an effective analgesic with superior G.I. tolerability. Paracetamol is a trusted analgesic and antipyretic that enhances analgesia.','images/aclodix-p.jpg','["Post Surgical Injury","Arthritis","Tooth Extraction","Sprains & Strains","Fibrositis/Tendonitis","ENT Inflammation"]',false,10),
('Montinir™-L Tablet','allergy','Tablet · 10×10 (Adult)','Levocetirizine HCl 5mg + Montelukast Sodium 10mg','Levocetirizine blocks histamine in the body. Montelukast inhibits cysteinyl leukotriene and corrects pathophysiology of asthma.','images/montinir-l-tab.jpg','["Allergic Rhinitis","Chronic Idiopathic Urticaria","Prophylaxis & Chronic Treatment of Asthma"]',false,11),
('Livnodix™-300','liver','Tablet · 10×10','Ursodeoxycholic Acid 300mg','Stimulates impaired biliary secretion, highly effective in preventing gallstone formation. Reduces serum fibrosis markers in NASH.','images/livnodix-300.jpg','["Primary Biliary Cirrhosis","Intrahepatic Cholestasis","Non-Alcoholic Fatty Liver Disease","Cholestasis in Pregnancy"]',false,12),
('Cefixnir™-200 DT','antibiotic','Dispersible Tablet · 10×10','Cefixime 200mg (Dispersible)','Potent broad spectrum third generation cephalosporin. Excellent penetration in body tissues & macrophage with broad spectrum coverage.','images/cefixnir-200dt.jpg','["Chronic Bronchitis","Pneumonia & Sinusitis","Urinary Tract Infection","Lower Respiratory Tract Infections","Acute Otitis Media"]',false,13),
('Deflazanir™-12','allergy','Tablet · 10×10','Deflazacort 12mg','Glucocorticoid for anti-inflammatory and immunosuppressive effects. Effective in Duchenne Muscular Dystrophy. Suppresses immune system by reducing lymphocyte activity.','images/deflazanir-12.jpg','["Severe Dermatological Reactions","Bronchial Asthma","Rheumatoid Arthritis","Allergic & Inflammatory Conditions","Respiratory Distress"]',false,14),
('Aclodix™-SP','pain','Tablet · 10×10','Aceclofenac 100mg + Paracetamol 325mg + Serratiopeptidase 15mg','Aceclofenac acts as selective COX-2 Inhibitor. Serratiopeptidase possesses anti-inflammatory, anti-oedemic and fibrinolytic activity improving circulation.','images/aclodix-sp.jpg','["Low Back Pain","Spondylitis","Muscular Pain","Osteoarthritis","Sprain & Strains","Traumatic Injuries","Dental Procedure"]',false,15)
ON CONFLICT DO NOTHING;

-- ================================================================
-- HELPER VIEWS
-- ================================================================

-- Daily analytics summary
CREATE OR REPLACE VIEW daily_analytics AS
SELECT
  DATE(created_at) AS date,
  event_type,
  COUNT(*) AS count
FROM analytics_events
WHERE created_at > NOW() - INTERVAL '30 days'
GROUP BY DATE(created_at), event_type
ORDER BY date DESC;

-- Product view rankings
CREATE OR REPLACE VIEW product_rankings AS
SELECT
  p.id, p.name, p.category, p.view_count, p.stock_status,
  COUNT(ae.id) AS recent_views
FROM products p
LEFT JOIN analytics_events ae ON
  ae.event_type = 'product_view' AND
  ae.data->>'product_id' = p.id::text AND
  ae.created_at > NOW() - INTERVAL '7 days'
GROUP BY p.id, p.name, p.category, p.view_count, p.stock_status
ORDER BY recent_views DESC;

-- ================================================================
-- DONE! Next steps:
-- 1. Go to Supabase → Authentication → Users → Add User
-- 2. Set email: admin@nirmedixpharma.com, password: (your choice)
-- 3. Update SUPABASE_URL and SUPABASE_ANON_KEY in index.html and admin.html
-- ================================================================
