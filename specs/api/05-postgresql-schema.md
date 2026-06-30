# Schema PostgreSQL

## Conventions

- Tous les identifiants primaires sont des UUID.
- Toutes les tables principales ont `created_at`, `updated_at`.
- Les suppressions utilisateur/garage/colis doivent etre logiques via `deleted_at` quand necessaire.
- Les enums peuvent etre implementes en `TEXT CHECK (...)` ou en vrais types PostgreSQL. Les `CHECK` facilitent les migrations.
- Les montants utilisent `NUMERIC(12,2)`.
- Les coordonnees utilisent `NUMERIC(10,7)`.

## Extensions

```sql
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "citext";
```

## users

```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email CITEXT UNIQUE,
  phone TEXT UNIQUE NOT NULL,
  full_name TEXT NOT NULL,
  password_hash TEXT,
  pin_hash TEXT,
  role TEXT NOT NULL CHECK (role IN ('client', 'driver', 'admin', 'super_admin')),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'deleted')),
  profile_photo TEXT,
  address TEXT,
  city TEXT,
  region TEXT,
  gender TEXT CHECK (gender IN ('male', 'female', 'other')),
  garage_id UUID,
  driver_status TEXT CHECK (driver_status IN ('available', 'busy', 'offline')),
  rating NUMERIC(3,2) DEFAULT 0,
  total_deliveries INTEGER NOT NULL DEFAULT 0,
  completed_deliveries INTEGER NOT NULL DEFAULT 0,
  cancelled_deliveries INTEGER NOT NULL DEFAULT 0,
  is_email_verified BOOLEAN NOT NULL DEFAULT FALSE,
  is_phone_verified BOOLEAN NOT NULL DEFAULT FALSE,
  is_profile_complete BOOLEAN NOT NULL DEFAULT FALSE,
  last_login TIMESTAMPTZ,
  last_active_at TIMESTAMPTZ,
  deleted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

## garages

```sql
CREATE TABLE garages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  city TEXT NOT NULL,
  region TEXT NOT NULL,
  address TEXT,
  phone TEXT,
  latitude NUMERIC(10,7),
  longitude NUMERIC(10,7),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  deleted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE users
  ADD CONSTRAINT users_garage_id_fkey
  FOREIGN KEY (garage_id) REFERENCES garages(id) ON DELETE SET NULL;
```

## vehicles

```sql
CREATE TABLE vehicles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plate_number TEXT NOT NULL UNIQUE,
  model TEXT NOT NULL,
  type TEXT NOT NULL,
  capacity INTEGER NOT NULL DEFAULT 0,
  garage_id UUID NOT NULL REFERENCES garages(id),
  driver_id UUID REFERENCES users(id) ON DELETE SET NULL,
  is_available BOOLEAN NOT NULL DEFAULT TRUE,
  deleted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

## parcels

```sql
CREATE TABLE parcels (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tracking_number TEXT NOT NULL UNIQUE,
  sender_id UUID REFERENCES users(id) ON DELETE SET NULL,
  sender_name TEXT NOT NULL,
  sender_phone TEXT NOT NULL,
  sender_email TEXT,
  receiver_name TEXT NOT NULL,
  receiver_phone TEXT NOT NULL,
  receiver_email TEXT,
  receiver_address TEXT,
  description TEXT NOT NULL,
  weight NUMERIC(10,2) NOT NULL CHECK (weight >= 0),
  length NUMERIC(10,2),
  width NUMERIC(10,2),
  height NUMERIC(10,2),
  type TEXT NOT NULL DEFAULT 'package' CHECK (type IN ('document', 'package', 'fragile', 'perishable', 'valuable')),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'free', 'confirmed', 'picked_up', 'in_transit', 'arrived', 'out_for_delivery', 'delivered', 'cancelled')),
  departure_garage_id UUID NOT NULL REFERENCES garages(id),
  arrival_garage_id UUID REFERENCES garages(id),
  driver_id UUID REFERENCES users(id) ON DELETE SET NULL,
  price NUMERIC(12,2),
  proposed_price NUMERIC(12,2),
  negotiated_price NUMERIC(12,2),
  delivery_fees NUMERIC(12,2),
  total_amount NUMERIC(12,2),
  is_insured BOOLEAN NOT NULL DEFAULT FALSE,
  insurance_amount NUMERIC(12,2),
  is_urgent BOOLEAN NOT NULL DEFAULT FALSE,
  urgent_fee NUMERIC(12,2),
  is_free_for_bidding BOOLEAN NOT NULL DEFAULT FALSE,
  selected_bid_id UUID,
  payment_method TEXT CHECK (payment_method IN ('wave', 'freemMoney', 'orange_money', 'card', 'cash')),
  payment_phone_number TEXT,
  payment_status TEXT,
  signature_url TEXT,
  notes TEXT,
  pickup_date TIMESTAMPTZ,
  delivery_date TIMESTAMPTZ,
  estimated_delivery_date TIMESTAMPTZ,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  cancelled_by UUID REFERENCES users(id) ON DELETE SET NULL,
  cancellation_reason TEXT,
  cancelled_at TIMESTAMPTZ,
  deleted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

## bids

```sql
CREATE TABLE bids (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parcel_id UUID NOT NULL REFERENCES parcels(id) ON DELETE CASCADE,
  driver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  price NUMERIC(12,2) NOT NULL CHECK (price >= 0),
  message TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
  response_message TEXT,
  audio_url TEXT,
  responded_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(parcel_id, driver_id)
);

ALTER TABLE parcels
  ADD CONSTRAINT parcels_selected_bid_id_fkey
  FOREIGN KEY (selected_bid_id) REFERENCES bids(id) ON DELETE SET NULL;
```

## parcel_events

```sql
CREATE TABLE parcel_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parcel_id UUID NOT NULL REFERENCES parcels(id) ON DELETE CASCADE,
  status TEXT NOT NULL,
  description TEXT NOT NULL,
  location TEXT,
  location_lat NUMERIC(10,7),
  location_lng NUMERIC(10,7),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  user_name TEXT,
  user_role TEXT,
  photo_url TEXT,
  metadata JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

## parcel_media

```sql
CREATE TABLE parcel_media (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parcel_id UUID NOT NULL REFERENCES parcels(id) ON DELETE CASCADE,
  uploaded_by UUID REFERENCES users(id) ON DELETE SET NULL,
  media_type TEXT NOT NULL CHECK (media_type IN ('photo', 'video', 'audio', 'signature', 'proof')),
  url TEXT NOT NULL,
  filename TEXT,
  mime_type TEXT,
  size_bytes BIGINT,
  duration_seconds INTEGER,
  metadata JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

## payments

```sql
CREATE TABLE payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  parcel_id UUID REFERENCES parcels(id) ON DELETE SET NULL,
  amount NUMERIC(12,2) NOT NULL CHECK (amount >= 0),
  currency TEXT NOT NULL DEFAULT 'XOF',
  method TEXT NOT NULL CHECK (method IN ('wave', 'freemMoney', 'orange_money', 'card', 'cash')),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'refunded')),
  transaction_id TEXT UNIQUE,
  phone_number TEXT,
  reference TEXT UNIQUE,
  metadata JSONB NOT NULL DEFAULT '{}',
  receipt_url TEXT,
  validated_by UUID REFERENCES users(id) ON DELETE SET NULL,
  validated_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

## scores et score_transactions

```sql
CREATE TABLE scores (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  points INTEGER NOT NULL DEFAULT 0 CHECK (points >= 0),
  total_earned INTEGER NOT NULL DEFAULT 0,
  total_spent INTEGER NOT NULL DEFAULT 0,
  last_updated TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE score_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  amount INTEGER NOT NULL,
  type TEXT NOT NULL,
  parcel_id UUID REFERENCES parcels(id) ON DELETE SET NULL,
  description TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'completed',
  metadata JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

## notifications

```sql
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  parcel_id UUID REFERENCES parcels(id) ON DELETE CASCADE,
  bid_id UUID REFERENCES bids(id) ON DELETE SET NULL,
  sender_id UUID REFERENCES users(id) ON DELETE SET NULL,
  sender_name TEXT,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  data JSONB NOT NULL DEFAULT '{}',
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  priority TEXT NOT NULL DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

## otp_codes et refresh_tokens

```sql
CREATE TABLE otp_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  code_hash TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('login', 'verification', 'password_reset')),
  phone TEXT,
  email TEXT,
  is_used BOOLEAN NOT NULL DEFAULT FALSE,
  expires_at TIMESTAMPTZ NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE refresh_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL,
  revoked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

## advertisements et advertisement_offers

```sql
CREATE TABLE advertisements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  departure_garage_id UUID REFERENCES garages(id),
  arrival_garage_id UUID REFERENCES garages(id),
  departure_city TEXT,
  arrival_city TEXT,
  departure_at TIMESTAMPTZ,
  available_weight NUMERIC(10,2),
  proposed_price NUMERIC(12,2),
  description TEXT,
  audio_url TEXT,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed', 'cancelled')),
  metadata JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE advertisement_offers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  advertisement_id UUID NOT NULL REFERENCES advertisements(id) ON DELETE CASCADE,
  client_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  parcel_id UUID REFERENCES parcels(id) ON DELETE SET NULL,
  price NUMERIC(12,2) NOT NULL,
  message TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
  response_message TEXT,
  responded_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

## Localisation, ratings, support

```sql
CREATE TABLE driver_locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  parcel_id UUID REFERENCES parcels(id) ON DELETE SET NULL,
  latitude NUMERIC(10,7) NOT NULL,
  longitude NUMERIC(10,7) NOT NULL,
  accuracy NUMERIC(10,2),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE ratings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parcel_id UUID REFERENCES parcels(id) ON DELETE SET NULL,
  driver_id UUID REFERENCES users(id) ON DELETE CASCADE,
  rated_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE support_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  subject TEXT,
  message TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'pending', 'closed')),
  metadata JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

## Identite, favoris, adresses, messages

```sql
CREATE TABLE identity_verifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  document_type TEXT,
  document_front_url TEXT,
  document_back_url TEXT,
  rejection_reason TEXT,
  reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE favorite_garages (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  garage_id UUID NOT NULL REFERENCES garages(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, garage_id)
);

CREATE TABLE addresses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  label TEXT,
  address TEXT NOT NULL,
  city TEXT,
  region TEXT,
  latitude NUMERIC(10,7),
  longitude NUMERIC(10,7),
  is_default BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  parcel_id UUID REFERENCES parcels(id) ON DELETE SET NULL,
  body TEXT NOT NULL,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

## Audit, config, webhooks, backups

```sql
CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id UUID REFERENCES users(id) ON DELETE SET NULL,
  actor_role TEXT,
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id UUID,
  before_data JSONB,
  after_data JSONB,
  ip_address TEXT,
  user_agent TEXT,
  request_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE system_configs (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE webhooks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  url TEXT NOT NULL,
  events TEXT[] NOT NULL,
  secret TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE backups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'running', 'completed', 'failed')),
  file_url TEXT,
  size_bytes BIGINT,
  requested_by UUID REFERENCES users(id) ON DELETE SET NULL,
  completed_at TIMESTAMPTZ,
  error_message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

## Index recommandes

```sql
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_garage_id ON users(garage_id);
CREATE INDEX idx_parcels_sender_id ON parcels(sender_id);
CREATE INDEX idx_parcels_driver_id ON parcels(driver_id);
CREATE INDEX idx_parcels_status ON parcels(status);
CREATE INDEX idx_parcels_tracking_number ON parcels(tracking_number);
CREATE INDEX idx_parcels_departure_garage ON parcels(departure_garage_id);
CREATE INDEX idx_parcels_arrival_garage ON parcels(arrival_garage_id);
CREATE INDEX idx_bids_parcel_id ON bids(parcel_id);
CREATE INDEX idx_bids_driver_id ON bids(driver_id);
CREATE INDEX idx_parcel_events_parcel_id_created ON parcel_events(parcel_id, created_at DESC);
CREATE INDEX idx_notifications_user_unread ON notifications(user_id, is_read);
CREATE INDEX idx_payments_user_id ON payments(user_id);
CREATE INDEX idx_payments_parcel_id ON payments(parcel_id);
CREATE INDEX idx_score_transactions_user_created ON score_transactions(user_id, created_at DESC);
CREATE INDEX idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_logs_actor ON audit_logs(actor_id);
CREATE INDEX idx_driver_locations_driver_created ON driver_locations(driver_id, created_at DESC);
```

